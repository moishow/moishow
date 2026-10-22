package com.moishow.settlement;

import org.junit.jupiter.api.Test;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
import static com.moishow.settlement.SettlementCalculator.*;

class SettlementCalculatorTest {
    private final SettlementCalculator calculator = new SettlementCalculator();
    private RoundInput round(String id, long expense, List<String> attendees, List<Cancellation> fees) {
        return new RoundInput(id, expense, attendees, fees);
    }
    private Receipt payment(String id, String user, long amount, boolean confirmed) {
        return new Receipt(id, user, amount, confirmed);
    }
    @Test void evenAllocationUsesStableUserOrder() {
        assertEquals(List.of(new Allocation("a",34),new Allocation("b",33),new Allocation("c",33)), calculator.splitEven(100,List.of("c","b","a")));
    }
    @Test void proportionalRefundLeavesWonRemainder() {
        var result=calculator.splitProportionally(10000,List.of(new Allocation("a",10000),new Allocation("b",10000),new Allocation("c",10000)));
        assertEquals(List.of(new Allocation("a",3333),new Allocation("b",3333),new Allocation("c",3333)),result.allocations());
        assertEquals(1,result.remainder());
    }
    @Test void proportionalProductDoesNotOverflowLong() {
        var result=calculator.splitProportionally(MAX_MONEY-1,List.of(new Allocation("a",3000000000000000L),new Allocation("b",3000000000000000L)));
        assertEquals(4503599627370495L,result.allocations().getFirst().amount());assertEquals(0,result.remainder());
    }
    @Test void rejectsInvalidAmountsAndDuplicates() {
        assertThrows(IllegalArgumentException.class,()->calculator.splitEven(-1,List.of("a")));
        assertThrows(IllegalArgumentException.class,()->calculator.splitEven(MAX_MONEY+1,List.of("a")));
        assertThrows(IllegalArgumentException.class,()->calculator.splitEven(1,List.of("a","a")));
        assertThrows(IllegalArgumentException.class,()->calculator.splitEven(1,List.of("")));
        assertThrows(IllegalArgumentException.class,()->calculator.splitProportionally(1,List.of(new Allocation("a",0))));
    }
    @Test void zeroPeopleOnlyAllowZeroEvenSplit() {
        assertEquals(List.of(),calculator.splitEven(0,List.of()));
        assertThrows(IllegalArgumentException.class,()->calculator.splitEven(1,List.of()));
    }
    @Test void cancellationChargesOnlyAgreedFeeAndHandlesPartialPayment() {
        assertEquals(new CancellationBalance(5000,25000,0),calculator.calculateCancellation(30000,5000));
        assertEquals(new CancellationBalance(5000,0,5000),calculator.calculateCancellation(0,5000));
        assertEquals(new CancellationBalance(0,30000,0),calculator.calculateCancellation(30000,0));
        assertEquals(new CancellationBalance(5000,0,3000),calculator.calculateCancellation(2000,5000));
    }
    @Test void unpaidCancellationFeeDoesNotReduceAttendeeBurden() {
        var result=calculator.settleRound(round("r",100000,List.of("a","b","c","d"),List.of(new Cancellation("x",20000L,0L))));
        assertEquals(25000,result.attendeeCharges().getFirst().amount());assertEquals(20000,result.pendingCancellation());
    }
    @Test void receivedCancellationFeeReducesAttendeeBurden() {
        var result=calculator.settleRound(round("r",100000,List.of("a","b","c","d"),List.of(new Cancellation("x",20000L,20000L))));
        assertEquals(20000,result.attendeeCharges().getFirst().amount());
    }
    @Test void excessFeesRefundByRatioWithOneWonReserve() {
        var fees=List.of(new Cancellation("x",10000L,10000L),new Cancellation("y",10000L,10000L),new Cancellation("z",10000L,10000L));
        var result=calculator.settleRound(round("r",20000,List.of("a"),fees));
        assertEquals(0,result.attendeeCharges().getFirst().amount());assertEquals(1,result.reserveRemainder());
        assertEquals(9999,result.cancellationRefunds().stream().mapToLong(Allocation::amount).sum());
    }
    @Test void zeroAttendeesAssignShortfallToHost() {
        var result=calculator.settleRound(round("r",100000,List.of(),List.of(new Cancellation("x",60000L,60000L))));
        assertTrue(result.attendeeCharges().isEmpty());assertEquals(40000,result.hostContribution());
    }
    @Test void zeroExpenseReturnsAllReceivedFees() {
        var result=calculator.settleRound(round("r",0,List.of(),List.of(new Cancellation("x",5000L,5000L))));
        assertEquals(5000,result.cancellationRefunds().getFirst().amount());assertEquals(0,result.hostContribution());
    }
    @Test void rejectsOverReceivedFeesAndConflictingRoles() {
        assertThrows(IllegalArgumentException.class,()->calculator.settleRound(round("r",100,List.of(),List.of(new Cancellation("x",10L,11L)))));
        assertThrows(IllegalArgumentException.class,()->calculator.settleRound(round("r",100,List.of("a"),List.of(new Cancellation("a",10L,10L)))));
    }
    @Test void combinesRoundsIntoOnePersonalRefund() {
        var ids=List.of("a","b","c","d");
        var result=calculator.settleEvent(new EventInput("host",List.of(round("r1",100000,ids,List.of(new Cancellation("x",20000L,20000L))),round("r2",40000,ids,List.of())),List.of(payment("p","a",40000,true),payment("f","x",20000,true)),List.of()));
        var a=result.positions().stream().filter(p->p.userId().equals("a")).findFirst().orElseThrow();
        assertEquals(30000,a.obligation());assertEquals(10000,a.refund());assertEquals(0,a.additional());
    }
    @Test void ignoresUnconfirmedReportsAndRequestsOnlyRemainder() {
        var result=calculator.settleEvent(new EventInput("host",List.of(round("r",30000,List.of("a"),List.of())),List.of(payment("p","a",10000,true),payment("q","a",20000,false)),List.of()));
        assertEquals(10000,result.positions().getFirst().received());assertEquals(20000,result.positions().getFirst().additional());
    }
    @Test void previouslyPaidRefundIsNotIssuedTwice() {
        var result=calculator.settleEvent(new EventInput("host",List.of(round("r",25000,List.of("a"),List.of())),List.of(payment("p","a",30000,true)),List.of(payment("f","a",5000,true))));
        assertEquals(0,result.positions().getFirst().refund());
    }
    @Test void duplicateRoundsAndLedgerIdsAreRejected() {
        var r=round("r",1,List.of("a"),List.of());
        assertThrows(IllegalArgumentException.class,()->calculator.settleEvent(new EventInput("host",List.of(r,r),List.of(),List.of())));
        assertThrows(IllegalArgumentException.class,()->calculator.settleEvent(new EventInput("host",List.of(r),List.of(payment("p","a",1,true)),List.of(payment("p","a",1,true)))));
    }
    @Test void cancellationReceiptsMustBeBackedAndCannotBeReusedAcrossRounds() {
        var fee=List.of(new Cancellation("x",20000L,20000L));
        assertThrows(IllegalArgumentException.class,()->calculator.settleEvent(new EventInput("host",List.of(round("r",100000,List.of("a"),fee)),List.of(payment("p","x",20000,false)),List.of())));
        assertThrows(IllegalArgumentException.class,()->calculator.settleEvent(new EventInput("host",List.of(round("r",100000,List.of("a"),fee),round("r2",100000,List.of("a"),fee)),List.of(payment("p","x",20000,true)),List.of())));
    }
    @Test void orphanPaymentIsNotLost() {
        var result=calculator.settleEvent(new EventInput("host",List.of(),List.of(payment("p","a",100,true)),List.of()));
        assertEquals(100,result.positions().getFirst().refund());
    }
    @Test void totalConfirmedReceiptsAcrossDifferentUsersCannotExceedSafeRange() {
        assertThrows(IllegalArgumentException.class,()->calculator.settleEvent(new EventInput("host",List.of(),
            List.of(payment("p1","a",MAX_MONEY,true),payment("p2","b",MAX_MONEY,true)),List.of())));
    }
    @Test void totalConfirmedRefundsAcrossDifferentUsersCannotExceedSafeRange() {
        assertThrows(IllegalArgumentException.class,()->calculator.settleEvent(new EventInput("host",List.of(),List.of(),
            List.of(payment("f1","a",MAX_MONEY,true),payment("f2","b",MAX_MONEY,true)))));
    }
    @Test void combinedObligationIncludingUnpaidFeesCannotExceedSafeRange() {
        assertThrows(IllegalArgumentException.class,()->calculator.settleEvent(new EventInput("host",
            List.of(round("r",MAX_MONEY,List.of("a"),List.of(new Cancellation("x",1L,0L)))),List.of(),List.of())));
    }
    @Test void outputAdditionalAmountsAreAlsoBoundedAsAnEventTotal() {
        assertThrows(IllegalArgumentException.class,()->calculator.settleEvent(new EventInput("host",
            List.of(round("r",MAX_MONEY,List.of("a"),List.of())),List.of(),List.of(payment("f","b",MAX_MONEY,true)))));
    }
    @Test void missingRequiredCollectionsOrConfirmationIsRejected() {
        assertThrows(IllegalArgumentException.class,()->calculator.settleEvent(new EventInput("host",null,List.of(),List.of())));
        assertThrows(IllegalArgumentException.class,()->calculator.settleEvent(new EventInput("host",List.of(),List.of(new Receipt("p","a",1L,null)),List.of())));
    }
    @Test void conservationHoldsForZeroAndPositiveAttendeesWithPendingFees() {
        for(long expense=0;expense<121;expense+=7)for(int count=0;count<5;count++)for(long received=0;received<51;received+=5){
            var ids=java.util.stream.IntStream.range(0,count).mapToObj(i->"a"+i).toList();
            var r=calculator.settleRound(round("r",expense,ids,List.of(new Cancellation("x",50L,received))));
            long charges=r.attendeeCharges().stream().mapToLong(Allocation::amount).sum()+r.cancellationCharges().stream().mapToLong(Allocation::amount).sum()+r.hostContribution();
            assertEquals(expense+r.pendingCancellation()+r.reserveRemainder(),charges);
        }
    }
}
