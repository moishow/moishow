import { renderScreen } from './prototype-render.js';
const mount = document.querySelector('[data-screen]');
try {
  const response = await fetch(new URL('./screen-catalog.json', import.meta.url));
  if (!response.ok) throw new Error('화면 데이터를 불러오지 못했습니다.');
  const screens = await response.json();
  const screen = screens.find(item => item.id === mount.dataset.screen);
  if (!screen) throw new Error('등록되지 않은 화면입니다.');
  renderScreen(mount, screen);
} catch (error) {
  mount.innerHTML = '';
  const message = document.createElement('p');
  message.textContent = `${error.message} 정적 HTTP 서버로 열어주세요.`;
  mount.append(message);
}
