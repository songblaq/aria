---
name: aria
description: "ARIA — aria status, khala, knowledge, registry"
metadata:
  aria:
    version: "0.1.0"
---

# ARIA — Agent-Runtime Integration Architecture

Runtime 간 에이전트 통신 + 지식 공유.

## CLI

```bash
aria status                         # 전체 상태
aria khala publish <channel> <msg>  # 메시지 발행
aria khala tail <channel> [n]       # 최근 메시지
aria knowledge search <query>       # FTS5 검색
aria registry runtimes              # 런타임 목록
aria registry info <id>             # 상세 정보
```

## 경로

- App data: `~/.aria/`
- Project: https://github.com/songblaq/aria
