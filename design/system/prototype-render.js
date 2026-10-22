const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const icon = name => `<svg class="icon" aria-hidden="true"><use href="../icons.svg#${name}"></use></svg>`;
const link = (target, label, css = '') => `<a class="${css}" href="${target}.html">${esc(label)}</a>`;

function calendar() {
  return `<section class="proto-calendar" aria-label="날짜 선택"><div class="proto-section-label">2026년 10월</div><div class="proto-days">${['19 월','20 화','21 수','22 목','23 금','24 토','25 일'].map((day,index)=>`<button type="button" class="proto-day ${index===4?'is-selected':''}" aria-pressed="${index===4}">${esc(day)}</button>`).join('')}</div><p class="proto-calendar-result" aria-live="polite">10월 23일 · 금요 저녁 모임</p></section>`;
}

export function renderScreen(mount, screen) {
  const nav = [['HOME','home','홈'],['FEED','list','피드'],['CREATE','plus','만들기'],['CHAT','users','채팅'],['MY','user','마이']];
  const hero = screen.figure ? `<section class="slab proto-hero"><div class="slab__label">${esc(screen.label)}</div><div class="proto-figure num">${esc(screen.figure)}</div><div class="proto-hero-caption">확정 정책 v1.0 · 요청과 실제 확인을 구분해요</div></section>` : '';
  const form = screen.kind==='form';
  const rows = screen.rows.map((row,index)=> {
    if(screen.kind==='toggles' && index<3) return `<div class="proto-row"><div><h2>${esc(row.title)}</h2><p>${esc(row.detail)}</p></div><button class="proto-toggle ${row.value==='켜짐'?'is-on':''}" type="button" role="switch" aria-label="${esc(row.title)} 푸시" aria-checked="${row.value==='켜짐'}"><span></span></button></div>`;
    if(form && !row.value && index<3) return `<label class="proto-field"><span>${esc(row.title)}</span><input aria-label="${esc(row.title)}" placeholder="${esc(row.detail)}" ${row.title.includes('금액')?'inputmode="numeric"':''}></label>`;
    return `<div class="proto-row ${screen.kind==='chatroom'?'proto-message':''}"><div class="proto-row-copy"><h2>${esc(row.title)}</h2><p>${esc(row.detail)}</p></div>${row.value?`<span class="proto-value num">${esc(row.value)}</span>`:''}</div>`;
  }).join('');
  mount.innerHTML = `<div class="screen surface-${screen.surface} proto-screen"><div class="proto-status"><span class="num">9:41</span><span>모이쇼 · 화면 목업</span></div><header class="appbar"><a href="HOME.html" aria-label="홈으로">${icon('chevron-left')}</a><div class="appbar__title">${esc(screen.title)}</div><a href="NOTIFICATIONS.html" aria-label="알림함">${icon('bell')}</a></header><section class="headline proto-headline"><p class="proto-kicker">${esc(screen.group)}</p><h1>${esc(screen.headline).replace(/\n/g,'<br>')}</h1><p class="proto-description">${esc(screen.subtitle)}</p></section>${screen.kind==='onboard'?'<div class="proto-mascot"><img src="../assets/mascots/mascot_blue.png" alt="모이쇼 마스코트"></div>':''}${hero}${['home','schedule'].includes(screen.kind)?calendar():''}<section class="card proto-list">${rows}</section><div class="proto-actions">${screen.actions.map((action,index)=>link(action.target,action.label,`btn btn--block ${index===0?'btn--primary':'btn--secondary'}`)).join('')}</div><p class="proto-limit">개발 기준 목업 · 인증·실이체·저장은 미연동입니다.</p><nav class="tabbar" aria-label="주 메뉴">${nav.map(([id,name,label])=>`<a class="${id==='CREATE'?'tabbar__fab':'tabbar__item'} ${screen.id===id?'is-active':''}" href="${id}.html" aria-label="${label}">${icon(name)}${id==='CREATE'?'':`<span>${label}</span>`}</a>`).join('')}</nav></div>`;
  mount.querySelectorAll('.proto-toggle').forEach(button=>button.addEventListener('click',()=>{
    const on=button.getAttribute('aria-checked')!=='true';button.setAttribute('aria-checked',String(on));button.classList.toggle('is-on',on);
  }));
  mount.querySelectorAll('.proto-day').forEach(button=>button.addEventListener('click',()=>{
    mount.querySelectorAll('.proto-day').forEach(day=>{day.classList.remove('is-selected');day.setAttribute('aria-pressed','false');});
    button.classList.add('is-selected');button.setAttribute('aria-pressed','true');
    const day=button.textContent.split(' ')[0];
    mount.querySelector('.proto-calendar-result').textContent=day==='23'?'10월 23일 · 금요 저녁 모임':day==='24'?'10월 24일 · 함께 걷는 토요일':`10월 ${day}일 · 예정된 일정이 없어요`;
  }));
}
