# 0029 외부 프로토콜의 범위: MCP, ACP, AHP, A2A

상태: 사용자 결정 (2026-11-18). 추천안을 받아들임.

## 결정

네 프로토콜은 서로 다른 층에 붙는다. 모두 지원하지 않고, 프로토콜마다 우리 구조의 어느 접점에 붙는지에 따라 정한다.

~~~text
          [다른 에이전트]  <-- A2A (에이전트끼리)

  [UI 여럿] <-- AHP --> [호스트/데몬]          = agentd 자리 (ADR 0004)
                             |
  [UI 하나] <-- ACP --> [tars-agent 코어]      = 프런트엔드 자리 (stream-json)
                             |
                        [능력 표] <-- MCP --> [도구 서버]   = caps 자리
~~~

| 프로토콜 | 무엇을 잇나 | 접점 | 결정 |
|---|---|---|---|
| MCP 클라이언트 | 에이전트와 도구 서버 | 능력 표의 런타임 항목 (06) | 지원. M6 |
| MCP 서버 방향 | 다른 에이전트가 tars 능력을 씀 | 능력 표의 JSON Schema | 후속. M6 뒤쪽 |
| ACP (Agent Client Protocol) | 편집기 하나와 에이전트 하나. stdio, JSON-RPC | 헤드리스 프런트엔드 | v1에는 없다. 코어-프런트엔드 이벤트 타입의 대조 기준으로 쓴다. 어댑터는 M6 뒤 |
| AHP (Agent Host Protocol) | UI 여럿이 세션 상태 하나를 공유. WebSocket, JSON-RPC | agentd | 지금은 없다. agentd를 설계할 때 자체 프로토콜보다 먼저 검토한다 |
| A2A | 서로 모르는 에이전트끼리 작업 위임. HTTP, agent card | 없음 | 범위 밖 |

## 근거

- MCP 클라이언트는 코딩 에이전트가 바깥 도구를 얻는 표준 길이다. 구조는 이미 준비돼 있다(ADR 0006, 0021).
- ACP는 stream-json과 같은 자리의 표준이다. 코어-프런트엔드 이벤트 타입이 ACP의 `session/update`(message chunk, tool_call, tool_call_update, plan)와 `session/request_permission`으로 손실 없이 옮겨지면, 어댑터는 프런트엔드 하나로 끝난다.
- AHP는 스스로를 "N개 클라이언트를 공유 세션 위에서 조율하는 층"이라 하고, 에이전트 쪽으로는 ACP를 쓴다("AHP is a coordination layer. ACP is a communication layer."). 정본 상태 트리, `serverSeq` 순서, 재접속 재생이 핵심이다. v1은 세션당 프로세스 하나라(ADR 0004) 이 문제가 없고, agentd가 생길 때 생긴다. 확인 시점(2026-11-18)에 1.0, 1.1이 있고 1.2는 draft다. 참조 구현은 VS Code agent host이고 pi용 pi-ahp가 있다.
- AHP의 `ahp-terminal` 채널은 사람의 UI가 호스트의 터미널을 보고 제어권을 나누는 쪽이다. tars.* 능력은 에이전트가 tars 패널을 조작하는 쪽이다. 방향이 반대라 AHP가 ADR 0013의 제어 채널을 대신하지 않는다.
- A2A는 범용 에이전트 사이의 위임이다. ADR 0013(코딩 에이전트, 범용으로 넓히지 않음)에 걸린다. 서브에이전트는 프로세스 안의 두 번째 VM으로 한다(06).

## 이벤트 타입을 정할 때 볼 것 (ACP 대조)

- ACP에서는 클라이언트가 `fs/*`, `terminal/*`를 제공할 수 있다. 그러면 능력 본체를 바깥에 위임하고 비동기로 받아야 한다. 승인 대기의 미완료 Future 경로(ADR 0011)를 다시 쓸 수 있는지 능력 표 설계 때 확인한다.
- CodeAct의 `run` 스크립트 하나는 능력 호출 여럿을 품는다. ACP의 tool_call을 스크립트 하나에 맞출지, 능력 호출 하나에 맞출지는 이벤트 타입과 함께 정한다.

## 되살리는 조건

- A2A: 범위(ADR 0013)가 바뀔 때.
- ACP 어댑터를 M6 안으로: tars나 개발 호스트에서 ACP 편집기로 tars-agent를 쓸 필요가 생길 때.
