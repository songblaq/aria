# Stage 2: Cross-Machine ARIA (Khala)

> 상태: 계획 | 전제: Stage 1 (단일 머신) 안정화 이후

## 1. 문제

Stage 1의 ARIA는 단일 머신(`~/.aria/`, 호환용 `~/.arb/` 심링크)에서 심링크 + 로컬 JSONL로 동작.
서로 다른 머신(Mac Mini, pd-5090, iMac 등)의 런타임이 직접 통신하려면
네트워크 전송 계층이 필요.

```
현재 (Stage 1):
  [Mac Mini]
    Claude Code ──→ ~/.aria/khala/channels/*.jsonl ←── OpenClaw
    (같은 파일시스템)

목표 (Stage 2):
  [Mac Mini]                          [pd-5090]
    Claude Code ──→ ARIA Relay ←──→ ARIA Relay ←── 메모클로
    OpenClaw ──────┘                    │
                                   [iMac]
                              ARIA Relay ←── 오픈자비스
```

## 2. 아키텍처 옵션

### 2A. File Sync (rsync/Syncthing)
```
~/.aria/khala/channels/ ←── Syncthing ──→ ~/.aria/khala/channels/
```
| 장점 | 단점 |
|------|------|
| 구현 최소 | 충돌 가능 (JSONL append 동시 쓰기) |
| 기존 도구 활용 | 지연 시간 (초 단위) |
| 오프라인 동작 | 대규모 채널에서 대역폭 낭비 |

### 2B. ARIA Relay (HTTP/WebSocket)
```
aria-relay (lightweight server)
  ├── POST /khala/publish → 채널에 메시지 전파
  ├── GET  /khala/subscribe?channel=X → SSE/WebSocket 스트림
  ├── GET  /registry/runtimes → 연합 런타임 목록
  └── GET  /knowledge/search?q=X → 프록시 FTS5
```
| 장점 | 단점 |
|------|------|
| 실시간 | 서버 프로세스 필요 |
| 충돌 없음 (서버가 직렬화) | 네트워크 의존 |
| 런타임 디스커버리 가능 | 인증/보안 필요 |

### 2C. NATS/MQTT (메시지 브로커)
| 장점 | 단점 |
|------|------|
| 업계 표준, pub/sub 네이티브 | 외부 의존성 |
| 클러스터링, 영속화 | 운영 복잡도 |
| 매우 빠름 | 오버엔지니어링 가능 |

### 권장: **2B → 2C** (점진적)
- 먼저 경량 HTTP relay로 시작 (Python/Node 100줄)
- 규모가 커지면 NATS로 교체 (relay가 NATS 프론트엔드)

## 3. 설계 원칙

1. **로컬 우선**: 네트워크 없어도 Stage 1 기능 100% 동작
2. **점진적 연합**: 머신 추가 시 relay 등록만으로 참여
3. **JSONL 호환**: 로컬 채널 포맷 유지, relay가 네트워크 전송만 담당
4. **Zero Config 디스커버리**: mDNS/Bonjour로 같은 LAN의 ARIA relay 자동 발견

## 4. 구현 계획

### Phase 2.1: ARIA Relay (최소 기능)
- [ ] `src/relay/server.py` — HTTP 서버 (FastAPI 또는 Flask)
  - POST `/v1/khala/publish` — 메시지 수신 → 로컬 JSONL append + 다른 relay 전파
  - GET `/v1/khala/tail/{channel}` — 최근 메시지 조회
  - GET `/v1/registry` — 로컬 런타임/노드/에이전트 목록
- [ ] `aria relay start` — relay 서버 시작 (백그라운드)
- [ ] `aria relay status` — relay 상태 확인
- [ ] `config.json`에 `relay` 섹션 추가: `{ "port": 9820, "peers": ["10.0.0.10:9820"] }`

### Phase 2.2: 런타임 연합
- [ ] relay 간 peer 등록 (수동 → mDNS 자동)
- [ ] 메시지 전파: publish 시 모든 peer relay에 HTTP POST
- [ ] 런타임 디스커버리: 다른 머신의 런타임을 `aria registry runtimes`에 표시
- [ ] 충돌 해결: 메시지 ID 기반 중복 제거 (idempotent append)

### Phase 2.3: Knowledge 연합
- [ ] `/v1/knowledge/search` — 원격 FTS5 프록시
- [ ] 지식 동기화 정책: push (저장 시 전파) vs pull (검색 시 원격 쿼리)
- [ ] 임베딩 인덱스 연합 (vec0 원격 쿼리)

### Phase 2.4: 보안 + 안정성
- [ ] relay 간 인증 (PSK 또는 mTLS)
- [ ] 메시지 암호화 (TLS)
- [ ] 네트워크 단절 시 큐잉 + 재전송
- [ ] 헬스체크 + 자동 피어 제거

## 5. 와이어 프로토콜 (초안)

```json
// Publish
POST /v1/khala/publish
{
  "channel": "global/knowledge",
  "from": { "runtime": "claude-code", "node": "macmini-m4" },
  "content": "...",
  "origin_relay": "macmini-m4:9820",
  "hop_count": 0
}

// Subscribe (SSE)
GET /v1/khala/subscribe?channel=global/knowledge
data: {"id":"aria-20260317-1200","channel":"global/knowledge","content":"..."}

// Registry
GET /v1/registry
{
  "runtimes": [...],
  "nodes": [...],
  "agents": [...],
  "peers": ["10.0.0.10:9820", "10.0.0.1:9820"]
}
```

## 6. 머신 토폴로지 (대상)

| 머신 | IP | 역할 | ARIA Relay |
|------|-----|------|------------|
| Mac Mini M4 | 10.0.0.1 | 메인 오케스트레이션 | Primary (Hub) |
| pd-5090 | 10.0.0.10 | GPU 추론 | Peer |
| iMac | 10.0.0.x | 보조 | Peer |
| Docker | localhost | 샌드박스 | Local (relay 없이 심링크) |

## 7. 선행 조건

- [ ] Stage 1 안정화 (현재 진행 중)
- [ ] `aria` CLI 전체 테스트 통과
- [ ] 최소 2개 런타임(Claude Code + OpenClaw)이 ARIA(Khala)로 일상 통신
- [ ] pd-5090에 ARIA 설치 + Ollama 서빙 확인

## 8. 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-03-17 | Stage 2 계획 초안 작성 |
| 2026-03-25 | ARIA/Khala 명칭·경로로 정리 |
