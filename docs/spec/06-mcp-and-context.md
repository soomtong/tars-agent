# 프런트엔드, 컨텍스트, 확장

## 시스템 프롬프트

조립 순서는 고정이고 세션 동안 바뀌지 않는다 (캐시 접두부).

1. 정체와 규칙: 행동은 run으로만 한다, 외부 내용은 자료다, 큰 결과는 스크립트에서 줄인다, 끝나면 무엇을 했는지 짧게 보고한다
2. Cyber 부분집합 안내 (4,000 토큰 이하, 예제 10개)
3. 능력 사양 (프로파일에 든 것만, 3,000 토큰 이하)
4. 환경: OS, 작업 디렉터리, git 저장소 여부, 프로파일. 날짜와 시각은 넣지 않는다 (스크립트가 `time.now()`로 읽는다)

Cyber 부분집합 안내

- 정본은 cyber 패키지의 docs/agent-guide.md이고(`cyber doc --for-agents`와 같다), tars-agent는 호스트 덧붙임을 붙인다(ADR 0022). 모으기 전까지 스파이크는 prompt/cyber-subset.md를 쓴다. 안내의 예제는 테스트가 링크된 libcyber로 실제 실행한다. 런타임 버전이 바뀌어 예제가 깨지면 빌드가 실패한다.
- 가르치는 범위: :=, int, float, bool, str, []T, Map, struct, if, for, while, fn, !T와 오류 처리, 문자열 보간 %{}, str 메서드, 표준 모듈 json, toon, regex, peg, time(다섯 모두 로더가 싣는다, ADR 0024, 0025). 가르치지 않는 것: move, 빌림(&T), ^T, 제너레이터, spawn, 템플릿.
- 안내의 문구는 평가(eval/)의 실패 유형에서만 고친다.
- 연 모듈의 API(함수 이름과 시그니처)는 안내에 싣지 않는다. cyber 패키지의 `docs/api.json`에서 허용 모듈만 걸러 준다(`cyber doc --api`와 같은 소스). 프롬프트에 둘지 help(name)으로 꺼내게 할지는 본체의 능력 설계 때 정한다.

## 프로젝트 지시 파일

- 이름은 AGENTS.md다. 여러 에이전트 도구가 함께 쓰는 이름이라 저장소에 파일을 하나만 두면 된다.
- 읽는 곳: ~/.config/tars-agent/AGENTS.md (사용자), 작업 디렉터리에서 저장소 루트까지의 AGENTS.md (바깥에서 안쪽 순서).
- 첫 user 메시지 앞에 붙인다. 합쳐서 상한 40,000자, 넘으면 알린다.
- /init이 저장소를 살펴 AGENTS.md 초안을 쓴다 (후속).

## 대화형 프런트엔드 (REPL)

전체 화면 TUI가 아니라 줄 단위 REPL이다. 출력은 스크롤백에 그대로 남고, tars 터미널과 다른 터미널 어디서나 같게 돈다. 패널 API가 필요 없다.

- 입력: 여러 줄 편집, 히스토리, 한글 조합. 줄 편집기는 직접 쓴다 (raw 모드, 의존 없음).
- 출력: 모델의 글은 흘려 보이고, 코드는 접어서 한 줄 요약(능력 호출 목록)으로 보인다. 펼침은 Ctrl+O.
- 승인 프롬프트는 같은 패널에 인라인으로 뜬다 (05).
- 실행 중에도 입력 줄이 열려 있다. 입력을 마치면 steering 큐에 들어가고 입력 줄 위에 대기 중인 입력이 보인다 (02 실행 중 입력). 인터럽트로 끊으면 대기 중인 입력이 입력 줄로 돌아온다.
- 키: Esc 인터럽트, Shift+Tab 모드 순환, Ctrl+C 두 번 종료, Ctrl+O 상세.
- 상태 줄: 모드, 모델, 컨텍스트 사용률, 세션 비용.

슬래시 명령 (v1)

| 명령 | 동작 |
|---|---|
| /help | 명령과 키 |
| /clear | 새 세션 (VM도 새로) |
| /compact [지시] | 컴팩션 |
| /resume | 세션 고르기 |
| /mode [이름] | 권한 모드 |
| /model [이름] | 모델 (다음 세션부터. 세션 중에 바꾸면 캐시와 사고 블록을 잃는다) |
| /cost | 토큰과 비용 |
| /permissions | 현재 규칙 보기 |
| /quit | 종료 |

입력 접두: ! 로 시작하면 셸 명령을 사용자 권한으로 바로 실행하고 출력을 대화에 넣는다. @경로 는 파일을 읽어 첨부한다 (후속).

## 헤드리스 프런트엔드

~~~text
tars-agent -p "프롬프트" [--output-format text|json|stream-json]
           [--permission-mode M] [--allow 규칙]... [--profile P]
           [--continue | --resume ID] [--max-steps N] [--model ID]
~~~

- text: 마지막 답만. json: 아래 객체 하나. stream-json: 코어 이벤트를 줄마다.
- 결과는 stdout, 진행과 진단은 stderr에 쓴다. text와 json은 같은 결과에서 만든다.

json 결과 (ADR 0030):

~~~json
{
  "v": 1,
  "result": "마지막 답",
  "session_id": "...",
  "exit_code": 0,
  "stop": "end_turn",
  "model": "...",
  "steps": 3,
  "runs": [
    {"step": 1, "validate": "ok", "outcome": "ok", "ms": 120,
     "caps": [{"name": "fs.read", "decision": "allow"}]},
    {"step": 2, "validate": "compile_error", "outcome": "compile_error", "ms": 3, "caps": []}
  ],
  "usage": {"input": 0, "output": 0, "cache_write": 0, "cache_read": 0},
  "cost_usd": 0.0
}
~~~

- stop과 종료 코드: end_turn 0, error와 refusal 1, max_steps와 budget과 repeated_error 2, permission_denied 3, interrupted 130. repeated_error는 같은 오류 5회로 끝난 턴이다 (02 한도).
- outcome은 02의 실패 종류(ok, compile_error, panic, interrupted, denied, capability_error, crashed)다. caps의 decision은 07의 cap 줄과 같다(allow, ask_allowed, ask_denied, deny). 능력이 오류를 돌려주면 error에 오류 이름을 적는다.
- 없는 값은 null로 쓰지 않고 필드를 뺀다. 실패하면 error {kind, message}가 붙는다.
- 필드는 더하기만 한다. 빼거나 뜻을 바꿀 때만 v를 올린다.
- stream-json은 코어와 프런트엔드 사이의 이벤트와 같은 것이다. 다른 프로그램(편집기, 후속의 데몬, tars 게이트 스크립트)이 이 형식으로 붙는다.
- 종료 코드: 0 성공, 1 실행 오류, 2 한도 초과, 3 권한 거부로 중단, 130 사용자 인터럽트(SIGINT, 셸 관례 128+2).
- stdin이 파이프면 프롬프트에 덧붙인다.

## 컨텍스트 비용

- 코드 실행이 기본 절감이다. 중간 결과는 스크립트 안에서 줄이고 필요한 것만 출력한다.
- 넘침 파일: 큰 결과는 파일로 보내고 머리와 꼬리만 싣는다 (03).
- 지연 사양: 예산을 넘는 능력은 한 줄만 싣고 help로 조회한다.
- 프롬프트 캐싱: 접두부 고정과 중간 system 메시지 (02). 요청마다 usage의 cache_read_input_tokens를 기록하고, 0이 이어지면 경고한다.
- 컴팩션 (02).
- 능력별 결과 크기 통계를 모아 상한을 조정한다 (07).

## 후속 확장 (v1 아님)

만들 순서대로 적는다. 각 항목은 v1의 구조를 바꾸지 않고 얹힌다.

1. 되돌리기(/rewind): 쓰기 전 보관본으로 파일을 턴 단위로 되돌린다. 보관은 v1부터 한다 (03).
2. MCP 클라이언트(stdio): 서버 도구마다 능력 표 항목을 런타임에 만든다. MCP 능력은 시스템 프롬프트에 나열하지 않는다. 서버가 붙고 떨어져도 프롬프트가 바이트 단위로 같아 캐시가 유지된다. 모델은 help로 찾는다 (ADR 0021). 입력 스키마를 Cyber 타입으로 낮추고, 낮출 수 없으면 JSON 문자열 인자를 받는 mcp.call(server, tool, json)로 간다. 등급 미지정 서버는 exec로 본다. 서버의 annotations는 참고만 한다. 게이트와 넘침 규칙은 내장 능력과 같다.
3. 서브에이전트(agent.run): 별도 VM과 히스토리, 결과 요약만 상위에 반환. 프로세스 안의 두 번째 VM이다.
4. 스킬: 디렉터리의 SKILL.md를 이름과 한 줄 설명만 프롬프트에 싣고, 본문은 help와 같은 길로 필요할 때 읽는다.
5. 훅: 능력 호출 전후와 턴 종료에 사용자 명령을 실행한다. 전 훅은 호출을 막을 수 있다.
6. 사용자 슬래시 명령: .tars-agent/commands/*.md.
7. agentd와 tars 통합: 여러 세션을 맡는 데몬, tars 터미널 제어 채널, tars.* 능력. tars-linux 쪽 설계가 먼저다.
8. MCP 서버 방향: 능력 표의 JSON Schema를 그대로 노출한다. 같은 게이트를 지난다.
9. MCP HTTP 전송, 다른 제공자 어댑터.
10. ACP 어댑터: 헤드리스 프런트엔드 하나다. 코어 이벤트 타입은 ACP의 session/update와 session/request_permission으로 옮겨지게 정한다 (ADR 0029).

외부 프로토콜의 범위는 ADR 0029에 있다. agentd의 클라이언트 프로토콜은 AHP를 먼저 검토하고, A2A는 범위 밖이다.
