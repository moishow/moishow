# 정산_내역 — wireflow (lo-fi)
```mermaid
flowchart TD
  MY[마이 ‘최근 정산 내역’] -->|전체보기| L[내역 전체<br/>기간·모임 필터 · 영구 보관]
  L --> I[항목 상세<br/>일시·금액·상대·상태 배지]
  L -->|내보내기| CSV[개인 CSV]
```
