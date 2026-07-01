/* 마크다운 뷰어 — 옆의 .md 를 fetch 해 marked.js + mermaid.js 로 렌더한다.
   내용을 .html 로 복사하지 않으므로 .md 가 단일 소스로 유지된다.
   GitHub Pages 에서 .md 가 정적 파일로 서빙되도록 저장소 루트에 .nojekyll 이 필요하다. */
(function () {
  var mount = document.querySelector('[data-md-src]');
  if (!mount) return;
  var src = mount.getAttribute('data-md-src');
  var blob = mount.getAttribute('data-gh-blob') || '';
  var body = document.createElement('div');
  body.className = 'doc-body';
  mount.appendChild(body);

  function fail(msg) {
    body.innerHTML =
      '<div class="doc-error"><p>' + msg + '</p>' +
      (blob ? '<p><a href="' + blob + '">GitHub에서 원본 보기 →</a></p>' : '') +
      '</div>';
  }

  if (!window.marked) { fail('마크다운 렌더러(marked)를 불러오지 못했습니다.'); return; }
  marked.setOptions({ gfm: true, breaks: false });

  fetch(src)
    .then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
    .then(function (md) {
      body.innerHTML = marked.parse(md);

      // ```mermaid 코드블록 → <div class="mermaid">
      body.querySelectorAll('code.language-mermaid').forEach(function (code) {
        var pre = code.closest('pre');
        var div = document.createElement('div');
        div.className = 'mermaid';
        div.textContent = code.textContent;
        (pre || code).replaceWith(div);
      });

      // 넓은 표는 가로 스크롤 래퍼로 감싼다
      body.querySelectorAll('table').forEach(function (t) {
        var w = document.createElement('div');
        w.className = 'table-scroll';
        t.parentNode.insertBefore(w, t);
        w.appendChild(t);
      });

      if (window.mermaid && body.querySelector('.mermaid')) {
        try {
          mermaid.initialize({ startOnLoad: false, theme: 'neutral', securityLevel: 'loose' });
          mermaid.run({ nodes: body.querySelectorAll('.mermaid') });
        } catch (e) { /* 렌더 실패 시 원본 텍스트 유지 */ }
      }
    })
    .catch(function (e) {
      fail('문서를 불러오지 못했습니다 (' + e.message + '). 로컬 file:// 로 열면 브라우저 보안정책상 막힐 수 있으니 GitHub Pages(https) 에서 확인하세요.');
    });
})();
