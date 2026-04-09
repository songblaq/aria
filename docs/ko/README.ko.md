# Khala — Agent Khala

> _이전 이름 **ARIA** (Agent-Runtime Integration Architecture). v3.2.0에서 Khala로 개명 — 여러 번의 리팩토링 끝에 프로젝트의 유일한 핵심 기능이 **khala** (메시징 substrate)만 남았기 때문. 에이전트/스킬은 `~/.agents/`로, 지식은 **owl**로 이동._

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Khala는 `~/.agents/` substrate를 다루는 작은 CLI입니다. 제공 기능:

- **JSONL append-only 메시징** — `khala publish/list/tail/get/search/watch` + 구조화된 `plaza-log/check`
- **Substrate 관리** — `khala init/doctor/migrate` (부트스트랩과 검증)
- **Read-only 조회** — `khala agent list`, `khala runtime list`, `khala substrate info`

에이전트 정의, 스킬, 지식은 **직접 소유하지 않습니다**. 각자의 집에 살고 있습니다:

- **에이전트** → `~/.agents/agents/<id>/` (설치된 인스턴스)
- **스킬** → `~/.agents/skills/` (prefix 규약 기반 공유 라이브러리)
- **지식** → [owl](https://github.com/songblaq/owl) (`~/.owl/` + `~/owl-vault/`, LLM Wiki)

---

## 빠른 시작

```bash
# curl로 설치 (GitHub repo 공개 후)
curl -sSL https://raw.githubusercontent.com/songblaq/khala/main/scripts/bootstrap.sh | bash

# 또는 로컬 clone에서
git clone https://github.com/songblaq/khala.git
cd khala
./install.sh

# shell rc에 추가
export PATH="$HOME/.agents/bin:$PATH"

# 검증
khala status
khala doctor
```

## 실행 예시

```
$ khala status
=== Khala (Agent Khala) v3.2.0 ===

  Config:     OK
  Khala:      49 channels, 18534 messages
  Runtimes:   10
  Nodes:      5
  Agents:     9

--- Substrate Residents ---
  agents:      OK     (9 installed)
  khala:       OK     (messaging)
  skills:      OK     (122 shared)

--- External ---
  owl:         OK     (~/.owl, LLM Wiki)
```

```
$ khala publish global/test "안녕 khala"
Published to global/test from claude-code (id=khala-20260407-220547-claude-code)

$ khala search "안녕 khala" --limit 1
=== Khala Search: '안녕 khala' (1 matches) ===
  [2026-04-07T22:05:47Z] global/test claude-code: 안녕 khala
```

## CLI 전체

```
메시징:
  khala publish <ch> <msg>            채널에 메시지 발행
  khala list [--json]                 전체 채널 목록
  khala tail <ch> [-n N] [--json]     최근 N개 메시지
  khala get <ch> <id> [--json]        ID로 메시지 조회
  khala search <pattern> [opts]       채널 가로지르는 풀텍스트 검색
  khala watch <ch> [--json]           실시간 tail (Ctrl+C로 종료)
  khala plaza-log [opts]              구조화된 Plaza 작업 로그
  khala plaza-check [opts]            Plaza 레코드 쿼리

Substrate 관리:
  khala init                          ~/.agents/ substrate 부트스트랩/업그레이드
  khala status                        헬스체크
  khala doctor [--quiet]              substrate 계약 검증
  khala migrate [--dry-run]           레거시 ~/.aria/ → ~/.agents/ 마이그레이션
  khala substrate {info|charter}      substrate 메타데이터

조회:
  khala agent {list|show <id>}        설치된 에이전트 조회
  khala runtime {list|register}       런타임 레지스트리
```

## Substrate 레이아웃

```
~/.agents/
├── AGENTS.md              # substrate 헌장
├── config.json            # khala 관리 설정
├── bin/khala              # CLI 진입점
│
├── agents/                # 설치된 에이전트 인스턴스
│   ├── blaq/              # 사용자 정체성 에이전트
│   ├── infra/, dev/, ...  # 7개 영속 에이전트
│   └── phantoms/          # 34개 리뷰 페르소나
│
├── khala/                 # 메시징 substrate
│   ├── channels/          # JSONL 채널
│   └── lib/               # 헬퍼 (gc, plaza_normalize, security)
│
└── skills/                # 공유 canonical 스킬 라이브러리
```

## 히스토리

- **Aria v1.0–3.1** — 원래는 Nyx(에이전트 관리), Knowledge Bridge(SQLite FTS5), Registry(런타임 디스커버리), Atlas(지식팩), Khala(메시징)를 아우르는 통합 오케스트레이션 레이어로 시작. 여러 번의 리팩토링 과정에서 각 서브시스템은 사라지거나 진정한 소유자에게 이전되거나 substrate 자체로 흡수됨:
  - **Nyx** → 삭제 (에이전트는 `~/.agents/agents/`의 파일일 뿐)
  - **Knowledge Bridge** → **owl**로 이전
  - **Registry** → `config.json`에 인라인화
  - **Atlas** → owl의 raw 위키 소스로 이전
  - **Khala** → 유일하게 남은 것, 그래서 프로젝트 이름이 됨

- **Khala v3.2.0** — 프로젝트 개명. CLI는 이제 `khala`. `aria` 바이너리는 레거시 alias로 보존.

## 호환성

`aria` (바이너리)는 transitional compat을 위해 심링크로 보존됩니다. 앞으로는 `khala` 사용을 권장합니다.

```bash
khala status     # 권장
aria status      # 동작함 (레거시 alias)
```

## 라이선스

MIT
