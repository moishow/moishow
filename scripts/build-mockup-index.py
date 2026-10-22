"""Index original browser JPEG captures without transcoding."""
from pathlib import Path
import hashlib, json, struct
from html import escape

root=Path(__file__).resolve().parents[1]
folder=root/'design/system/mockups'
screens=json.loads((root/'design/system/screen-catalog.json').read_text(encoding='utf-8'))
def jpeg_size(raw):
    if raw[:2] != b'\xff\xd8': raise ValueError('not a JPEG capture')
    offset = 2
    while offset < len(raw):
        if raw[offset] != 255: raise ValueError('invalid JPEG marker')
        while raw[offset] == 255: offset += 1
        marker = raw[offset]; offset += 1
        if marker in (216,217): continue
        length = int.from_bytes(raw[offset:offset+2], 'big')
        if marker in (192,193,194):
            return int.from_bytes(raw[offset+5:offset+7],'big'), int.from_bytes(raw[offset+3:offset+5],'big')
        offset += length
    raise ValueError('missing JPEG frame')

manifest=[]
cards=[]
for screen in screens:
    path=folder/f'{screen["id"]}.jpg'
    raw=path.read_bytes()
    width,height=jpeg_size(raw)
    if len(raw)<10000 or height<500:raise ValueError(f'capture appears incomplete: {path}')
    manifest.append(dict(screen=screen['id'],file=path.name,width=width,height=height,sha256=hashlib.sha256(raw).hexdigest(),capture='browser-full-page',policy='1.0'))
    cards.append(f'<article><a href="../screen_v1/{screen["id"]}.html"><h2>{screen["id"]} · {escape(screen["title"])}</h2></a><a href="{path.name}"><img src="{path.name}" alt="{escape(screen["title"])} 전체 화면" loading="lazy"></a><p>{escape(screen["note"])}</p></article>')
(folder/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(folder/'index.html').write_text('<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>전체 JPEG 목업 — 모이쇼</title><link rel="stylesheet" href="../tokens.css"><link rel="stylesheet" href="../../../assets/hub.css"></head><body><main class="hub"><a href="../../../index.html">설계 허브</a><h1>현재 화면 JPEG 목업</h1><p>2026-10-22 · 정책 v1.0 · 실제 HTML 브라우저 렌더링. 인증·실이체·저장 미연동.</p><div class="mockup-grid">'+''.join(cards)+'</div></main></body></html>\n',encoding='utf-8')
print(f'Indexed {len(manifest)} verified JPEG captures.')
