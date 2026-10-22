import { settleEvent } from '../src/domain/settlement.mjs';

const form = document.querySelector('#calculator');
const format = value => `${value.toLocaleString('ko-KR')}원`;
function calculate(event) {
  event?.preventDefault();
  const error = document.querySelector('#error');
  error.textContent = '';
  try {
    const values = Object.fromEntries([...new FormData(form)].map(([name,value])=>[name,Number(value)]));
    if (!Number.isInteger(values.count) || values.count < 0 || values.count > 1000) throw new RangeError('참석자 수는 0~1,000 사이 정수로 입력해주세요.');
    const attendeeIds = Array.from({length:values.count},(_,index)=>index===0?'me':`person-${String(index).padStart(4,'0')}`);
    const result = settleEvent({
      hostId:'me',
      rounds:[
        {id:'r1',expense:values.expense1,attendeeIds,cancellations:values.fee?[{userId:'cancelled',fee:values.fee,received:values.fee}]:[]},
        {id:'r2',expense:values.expense2,attendeeIds,cancellations:[]},
      ],
      receipts:[{id:'my-payment',userId:'me',amount:values.paid,confirmed:true},{id:'fee-payment',userId:'cancelled',amount:values.fee,confirmed:true}],
      refunds:[{id:'my-refund',userId:'me',amount:values.refunded,confirmed:true}],
    });
    const me = result.positions.find(item=>item.userId==='me') ?? {obligation:0,received:0,refunded:0,additional:0,refund:0};
    document.querySelector('#result').textContent = me.refund?`${format(me.refund)} 환불`:me.additional?`${format(me.additional)} ${values.count===0?'주최자 미충당액':'추가 납부'}`:'잔여 차액 0원';
    const rows=[['전체 지출',result.totalExpense],['나의 최종 부담',me.obligation],['나의 확인 입금',me.received],['기지급 환불',me.refunded],['확인된 취소 비용',values.fee],['취소비 환불 원 단위 잔여',result.reserveRemainder],['참석0명 주최자 부담',result.hostContribution]];
    const body=document.querySelector('#breakdown');body.replaceChildren();
    for(const [label,value] of rows){const row=document.createElement('tr');const name=document.createElement('th');name.textContent=label;const amount=document.createElement('td');amount.textContent=format(value);amount.className='num';row.append(name,amount);body.append(row);}
  } catch (cause) {
    error.textContent=cause.message;
    document.querySelector('#result').textContent='입력값을 확인해주세요';
    document.querySelector('#breakdown').replaceChildren();
  }
}
form.addEventListener('submit',calculate);
calculate();
