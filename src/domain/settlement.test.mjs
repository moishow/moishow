import test from 'node:test';
import assert from 'node:assert/strict';
import { splitEven, splitProportionally, sumMoney } from './money.mjs';
import { calculateCancellation, settleRound, settleEvent } from './settlement.mjs';

test('equal allocation conserves won using stable user order',()=>{
  assert.deepEqual(splitEven(100,['c','b','a']),[{userId:'a',amount:34},{userId:'b',amount:33},{userId:'c',amount:33}]);
});
test('proportional refund leaves only won rounding for reserve',()=>{
  const result=splitProportionally(10000,['a','b','c'].map(userId=>({userId,amount:10000})));
  assert.deepEqual(result,{allocations:['a','b','c'].map(userId=>({userId,amount:3333})),remainder:1});
});
test('large proportional products do not lose precision',()=>{
  const amount=Number.MAX_SAFE_INTEGER-1;
  const result=splitProportionally(amount,[{userId:'a',amount:3000000000000000},{userId:'b',amount:3000000000000000}]);
  assert.equal(result.allocations[0].amount,4503599627370495);assert.equal(result.remainder,0);
});
test('zero allocation supports no people only when amount is zero',()=>{
  assert.deepEqual(splitEven(0,[]),[]);assert.throws(()=>splitEven(1,[]),RangeError);
});
test('invalid monetary inputs and overflow are rejected',()=>{
  for(const amount of [-1,0.5,NaN,Infinity,'10',Number.MAX_SAFE_INTEGER+1])assert.throws(()=>splitEven(amount,['a']));
  assert.throws(()=>sumMoney([Number.MAX_SAFE_INTEGER,1]),RangeError);
  assert.throws(()=>splitEven(1,['a','a']));assert.throws(()=>splitEven(1,['']));
  assert.throws(()=>splitProportionally(1,[{userId:'a',amount:0}]));
  assert.throws(()=>splitProportionally(1,[{userId:'a',amount:1},{userId:'a',amount:1}]));
});
test('cancellation nets fee against confirmed paid amount',()=>{
  assert.deepEqual(calculateCancellation({paid:30000,fee:5000}),{charge:5000,refund:25000,outstanding:0});
  assert.deepEqual(calculateCancellation({paid:0,fee:5000}),{charge:5000,refund:0,outstanding:5000});
  assert.deepEqual(calculateCancellation({paid:30000,fee:0}),{charge:0,refund:30000,outstanding:0});
  assert.deepEqual(calculateCancellation({paid:2000,fee:5000}),{charge:5000,refund:0,outstanding:3000});
});
const baseRound=(overrides={})=>({id:'r1',expense:100000,attendeeIds:['a','b','c','d'],cancellations:[],...overrides});
test('only received cancellation fees reduce attendee burden',()=>{
  const result=settleRound(baseRound({cancellations:[{userId:'x',fee:20000,received:0}]}));
  assert.equal(result.attendeeCharges[0].amount,25000);assert.equal(result.pendingCancellation,20000);
  const paid=settleRound(baseRound({cancellations:[{userId:'x',fee:20000,received:20000}]}));
  assert.equal(paid.attendeeCharges[0].amount,20000);
});
test('excess cancellation fees are refunded proportionally with rounding reserve',()=>{
  const result=settleRound(baseRound({expense:20000,cancellations:['x','y','z'].map(userId=>({userId,fee:10000,received:10000}))}));
  assert.equal(result.attendeeCharges.reduce((n,p)=>n+p.amount,0),0);
  assert.deepEqual(result.cancellationRefunds.map(p=>p.amount),[3333,3333,3333]);assert.equal(result.reserveRemainder,1);
});
test('zero attendees retain expense and host loss without dividing by zero',()=>{
  const result=settleRound(baseRound({attendeeIds:[],cancellations:[{userId:'x',fee:60000,received:60000}]}));
  assert.deepEqual(result.attendeeCharges,[]);assert.equal(result.hostContribution,40000);
});
test('zero expense refunds received fees without assigning attendee burden',()=>{
  const result=settleRound(baseRound({expense:0,attendeeIds:[],cancellations:[{userId:'x',fee:5000,received:5000}]}));
  assert.equal(result.cancellationRefunds[0].amount,5000);assert.equal(result.hostContribution,0);assert.equal(result.reserveRemainder,0);
});
test('round input rejects duplicate roles and unbacked cancellation receipts',()=>{
  assert.throws(()=>settleRound(baseRound({cancellations:[{userId:'a',fee:10,received:10}]})));
  assert.throws(()=>settleRound(baseRound({cancellations:[{userId:'x',fee:10,received:11}]})));
  assert.throws(()=>settleRound(baseRound({cancellations:[{userId:'x',fee:10,received:5},{userId:'x',fee:10,received:5}]})));
});
const receipt=(id,userId,amount,confirmed=true)=>({id,userId,amount,confirmed});
test('event combines two rounds into a single personal refund',()=>{
  const result=settleEvent({hostId:'host',rounds:[baseRound({cancellations:[{userId:'x',fee:20000,received:20000}]}),baseRound({id:'r2',expense:40000})],receipts:['a','b','c','d'].map(id=>receipt(id,id,40000)).concat(receipt('x','x',20000)),refunds:[]});
  const a=result.positions.find(p=>p.userId==='a');assert.equal(a.obligation,30000);assert.equal(a.refund,10000);assert.equal(a.additional,0);
});
test('partial receipts and unconfirmed reports cannot overstate payment',()=>{
  const result=settleEvent({hostId:'host',rounds:[baseRound({expense:30000,attendeeIds:['a']})],receipts:[receipt('p1','a',10000),receipt('p2','a',20000,false)],refunds:[]});
  assert.equal(result.positions[0].received,10000);assert.equal(result.positions[0].additional,20000);
});
test('previously issued refund is not paid again after recalculation',()=>{
  const input={hostId:'host',rounds:[baseRound({expense:25000,attendeeIds:['a']})],receipts:[receipt('p','a',30000)],refunds:[receipt('f','a',5000)]};
  assert.equal(settleEvent(input).positions[0].refund,0);
  input.refunds[0].confirmed=false;assert.equal(settleEvent(input).positions[0].refund,5000);
});
test('disjoint round participants pay only for attended rounds',()=>{
  const result=settleEvent({hostId:'host',rounds:[baseRound({expense:100,attendeeIds:['a']}),baseRound({id:'r2',expense:200,attendeeIds:['b']})],receipts:[],refunds:[]});
  assert.deepEqual(result.positions.map(p=>[p.userId,p.additional]),[['a',100],['b',200]]);
});
test('duplicate round or ledger IDs are rejected rather than counted twice',()=>{
  assert.throws(()=>settleEvent({hostId:'host',rounds:[baseRound(),baseRound()],receipts:[],refunds:[]}));
  assert.throws(()=>settleEvent({hostId:'host',rounds:[baseRound()],receipts:[receipt('p','a',1),receipt('p','a',1)],refunds:[]}));
});
test('orphan confirmed payment is returned, not silently lost',()=>{
  const result=settleEvent({hostId:'host',rounds:[],receipts:[receipt('p','a',100)],refunds:[]});
  assert.equal(result.positions[0].refund,100);
});
test('received cancellation contributions must be backed by confirmed event receipts',()=>{
  assert.throws(()=>settleEvent({hostId:'host',rounds:[baseRound({cancellations:[{userId:'x',fee:20000,received:20000}]})],receipts:[receipt('p','x',20000,false)],refunds:[]}));
});
test('the same receipt cannot back cancellation fees in two rounds beyond its amount',()=>{
  const cancellation={userId:'x',fee:20000,received:20000};
  assert.throws(()=>settleEvent({hostId:'host',rounds:[baseRound({cancellations:[cancellation]}),baseRound({id:'r2',cancellations:[cancellation]})],receipts:[receipt('p','x',20000)],refunds:[]}));
});
test('confirmed event receipt and refund totals must stay within safe KRW range across users',()=>{
  const maximum=Number.MAX_SAFE_INTEGER;
  assert.throws(()=>settleEvent({hostId:'host',rounds:[],receipts:[receipt('a','one',maximum),receipt('b','two',1)]}),RangeError);
  assert.throws(()=>settleEvent({hostId:'host',rounds:[],refunds:[receipt('a','one',maximum),receipt('b','two',1)]}),RangeError);
  const ignored=settleEvent({hostId:'host',rounds:[],receipts:[receipt('a','one',maximum,false),receipt('b','two',1,false)]});
  assert.deepEqual(ignored.positions,[]);
});
test('functions do not mutate caller objects',()=>{
  const input={hostId:'host',rounds:[baseRound({attendeeIds:['b','a']})],receipts:[receipt('p','a',1)],refunds:[]};
  const before=structuredClone(input);settleEvent(input);assert.deepEqual(input,before);
});
test('round conservation across expense, attendees, pending fees and won reserve',()=>{
  for(let expense=0;expense<121;expense+=7)for(let count=0;count<5;count++)for(let received=0;received<51;received+=5){
    const round=settleRound({id:'r',expense,attendeeIds:Array.from({length:count},(_,i)=>'a'+i),cancellations:[{userId:'x',fee:50,received}]});
    const charges=[...round.attendeeCharges,...round.cancellationCharges].reduce((sum,p)=>sum+p.amount,0)+round.hostContribution;
    assert.equal(charges,expense+round.pendingCancellation+round.reserveRemainder);
  }
});
