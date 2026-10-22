package com.moishow.settlement;

import java.math.BigInteger;
import java.util.*;

/** Pure KRW calculation. Inputs represent verified facts, not external transfers. */
public final class SettlementCalculator {
    public static final long MAX_MONEY = 9_007_199_254_740_991L;
    public record Allocation(String userId, long amount) {}
    public record ProportionalResult(List<Allocation> allocations, long remainder) {}
    public record CancellationBalance(long charge, long refund, long outstanding) {}
    public record Cancellation(String userId, Long fee, Long received) {}
    public record RoundInput(String id, Long expense, List<String> attendeeIds, List<Cancellation> cancellations) {}
    public record Receipt(String id, String userId, Long amount, Boolean confirmed) {}
    public record EventInput(String hostId, List<RoundInput> rounds, List<Receipt> receipts, List<Receipt> refunds) {}
    public record RoundResult(String roundId, long expense, List<Allocation> attendeeCharges,
        List<Allocation> cancellationCharges, List<Allocation> cancellationRefunds,
        long receivedCancellation, long pendingCancellation, long reserveRemainder, long hostContribution) {}
    public record Position(String userId, long obligation, long received, long refunded,
        long net, long additional, long refund) {}
    public record EventResult(List<RoundResult> rounds, List<Position> positions, long totalExpense,
        long pendingCancellation, long reserveRemainder, long hostContribution) {}

    private long money(Long value, String name) {
        if (value == null || value < 0 || value > MAX_MONEY) throw new IllegalArgumentException(name + " must be integer KRW within the supported range");
        return value;
    }
    private long add(long left, long right) { return money(Math.addExact(left,right), "total"); }
    private String id(String value) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException("ID must not be blank");
        return value;
    }
    private <T> List<T> required(List<T> values) {
        if (values == null || values.stream().anyMatch(Objects::isNull)) throw new IllegalArgumentException("required collection or item is missing");
        if (values.size() > 10000) throw new IllegalArgumentException("too many collection items");
        return values;
    }
    private List<String> unique(List<String> values) {
        var ids = new TreeSet<String>();
        for (String value : required(values)) if (!ids.add(id(value))) throw new IllegalArgumentException("duplicate ID");
        return List.copyOf(ids);
    }
    public List<Allocation> splitEven(long amount, List<String> userIds) {
        money(amount,"amount");var ids=unique(userIds);
        if (ids.isEmpty()) {
            if (amount != 0) throw new IllegalArgumentException("positive amount requires attendees");
            return List.of();
        }
        long base=amount/ids.size(), remainder=amount%ids.size();
        var result=new ArrayList<Allocation>();
        for(int i=0;i<ids.size();i++)result.add(new Allocation(ids.get(i),base+(i<remainder?1:0)));
        return List.copyOf(result);
    }
    public ProportionalResult splitProportionally(long amount, List<Allocation> weights) {
        money(amount,"amount");required(weights);unique(weights.stream().map(Allocation::userId).toList());
        long total=0;
        for(var weight:weights)total=add(total,money(weight.amount(),"weight"));
        if(amount>0&&total==0)throw new IllegalArgumentException("positive amount requires positive weights");
        var sorted=weights.stream().sorted(Comparator.comparing(Allocation::userId)).toList();
        var result=new ArrayList<Allocation>();long allocated=0;
        for(var weight:sorted){
            long share=total==0?0:BigInteger.valueOf(amount).multiply(BigInteger.valueOf(weight.amount())).divide(BigInteger.valueOf(total)).longValueExact();
            result.add(new Allocation(weight.userId(),share));allocated=add(allocated,share);
        }
        return new ProportionalResult(List.copyOf(result),amount-allocated);
    }
    public CancellationBalance calculateCancellation(long paid,long fee) {
        money(paid,"paid");money(fee,"fee");
        return new CancellationBalance(fee,Math.max(0,paid-fee),Math.max(0,fee-paid));
    }
    public RoundResult settleRound(RoundInput input) {
        if(input==null)throw new IllegalArgumentException("round is required");
        id(input.id());long expense=money(input.expense(),"expense");
        var attendees=unique(input.attendeeIds());var fees=required(input.cancellations());
        unique(fees.stream().map(Cancellation::userId).toList());
        long received=0,pending=0;
        for(var fee:fees){
            money(fee.fee(),"fee");money(fee.received(),"received fee");
            if(fee.received()>fee.fee())throw new IllegalArgumentException("received cancellation amount exceeds agreed fee");
            if(attendees.contains(fee.userId()))throw new IllegalArgumentException("attendee and cancellation roles overlap in one round");
            received=add(received,fee.received());pending=add(pending,fee.fee()-fee.received());
        }
        long burden=Math.max(0,expense-received),excess=Math.max(0,received-expense);
        var distributed=splitProportionally(excess,fees.stream().map(f->new Allocation(f.userId(),f.received())).toList());
        var byId=new HashMap<String,Long>();distributed.allocations().forEach(a->byId.put(a.userId(),a.amount()));
        var charges=fees.stream().map(f->new Allocation(f.userId(),f.fee()-byId.get(f.userId()))).sorted(Comparator.comparing(Allocation::userId)).toList();
        return new RoundResult(input.id(),expense,attendees.isEmpty()?List.of():splitEven(burden,attendees),
            charges,distributed.allocations(),received,pending,distributed.remainder(),attendees.isEmpty()?burden:0);
    }
    private void verifyLedger(List<Receipt> records, Set<String> ids) {
        for(var record:required(records)){
            id(record.id());id(record.userId());money(record.amount(),"ledger amount");
            if(record.confirmed()==null)throw new IllegalArgumentException("confirmation must be explicit");
            if(!ids.add(record.id()))throw new IllegalArgumentException("duplicate ledger ID");
        }
    }
    private void accumulate(Map<String,Long> totals,String user,long amount) {
        totals.put(user,add(totals.getOrDefault(user,0L),amount));
    }
    public EventResult settleEvent(EventInput input) {
        if(input==null)throw new IllegalArgumentException("event is required");
        id(input.hostId());var rounds=required(input.rounds());unique(rounds.stream().map(RoundInput::id).toList());
        var ledgerIds=new HashSet<String>();verifyLedger(input.receipts(),ledgerIds);verifyLedger(input.refunds(),ledgerIds);
        var results=rounds.stream().map(this::settleRound).toList();
        var obligations=new TreeMap<String,Long>();var received=new TreeMap<String,Long>();var refunded=new TreeMap<String,Long>();
        long expense=0,pending=0,reserve=0,host=0;
        for(var round:results){
            for(var allocation:round.attendeeCharges())accumulate(obligations,allocation.userId(),allocation.amount());
            for(var allocation:round.cancellationCharges())accumulate(obligations,allocation.userId(),allocation.amount());
            if(round.hostContribution()>0)accumulate(obligations,input.hostId(),round.hostContribution());
            expense=add(expense,round.expense());pending=add(pending,round.pendingCancellation());
            reserve=add(reserve,round.reserveRemainder());host=add(host,round.hostContribution());
        }
        long totalObligation=0,totalReceived=0,totalRefunded=0;
        for(long amount:obligations.values())totalObligation=add(totalObligation,amount);
        for(var record:input.receipts())if(record.confirmed()){
            totalReceived=add(totalReceived,record.amount());
            accumulate(received,record.userId(),record.amount());
        }
        for(var record:input.refunds())if(record.confirmed()){
            totalRefunded=add(totalRefunded,record.amount());
            accumulate(refunded,record.userId(),record.amount());
        }
        var feeBacking=new HashMap<String,Long>();
        for(var round:rounds)for(var fee:round.cancellations())accumulate(feeBacking,fee.userId(),fee.received());
        for(var item:feeBacking.entrySet())if(item.getValue()>received.getOrDefault(item.getKey(),0L))throw new IllegalArgumentException("cancellation fees exceed confirmed receipts");
        var allIds=new TreeSet<String>();allIds.addAll(obligations.keySet());allIds.addAll(received.keySet());allIds.addAll(refunded.keySet());
        var positions=new ArrayList<Position>();long totalAdditional=0,totalRefundDue=0;
        for(var user:allIds){
            long due=obligations.getOrDefault(user,0L),paid=received.getOrDefault(user,0L),returned=refunded.getOrDefault(user,0L);
            long net=add(due,returned)-paid;
            long additional=Math.max(0,net),refund=Math.max(0,-net);
            totalAdditional=add(totalAdditional,additional);totalRefundDue=add(totalRefundDue,refund);
            positions.add(new Position(user,due,paid,returned,net,additional,refund));
        }
        return new EventResult(results,List.copyOf(positions),expense,pending,reserve,host);
    }
}
