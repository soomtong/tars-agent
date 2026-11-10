# HANDOFF: 명세 재검토와 결정(ADR 0004~0010) 완료, 다음은 M0와 cyber C1 (2026-11-10)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 현재는 명세와 TODO만 있고 코드는 없다.

사용자 지시 두 개가 이번 세션의 방향이다.

- "review specs and to-dos. modernize, respectable, makable. claude code is role model of ours. many questions and right answers are your decisions." 열린 질문을 묻지 않고 직접 결정한다.
- "we will build missing features of cyber lang, like std stuffs. things we need, we make." Cyber에 없는 것은 호스트로 돌려 막지 않고 cyber에 만든다.

## 현재 브랜치

`main` = origin/main. 이번 세션의 문서 변경은 커밋하고 push했다. 커밋과 push는 Claude에게 위임돼 있다: 의미 있는 변경이 생기면 묻지 않고 커밋하고 push한다 (docs/decisions/feedback-commit-delegation.md).

## 완료된 작업

- [x] docs/spec/00~08 전면 재작성, 09는 이력으로 표시하고 "재검토에서 바꾼 것"과 "닫은 질문" 절 추가
- [x] docs/TODO.md를 M0~M6(단계마다 게이트)와 C 줄기(cyber 쪽 작업)로 재구성
- [x] ADR 0004 세션당 프로세스 하나, 데몬 agentd는 후속
- [x] ADR 0005 코드는 이 저장소, cyber는 build.zig.zon 의존으로 정적 링크, C ABI를 runtime/cy.zig 한 파일로 감쌈, sha256 릴리스를 tars devlayer가 들임
- [x] ADR 0006 능력은 Zig comptime 표 하나에서 정의(Cyber 선언, 프롬프트 사양, JSON Schema 생성). direct 모드(JSON 도구)를 대조군으로 M0부터. 판정 기준: 첫 시도 validate 70% 이상, 성공률이 direct보다 5%p 넘게 낮지 않음
- [x] ADR 0007 프로파일(주입 집합, 세션 고정)과 모드(게이트 판정, 세션 중 변경) 분리. proc.exec(인자 배열)와 proc.sh(셸 문자열). Landlock 샌드박스, auto 모드는 샌드박스가 있을 때만. 설정은 JSON 세 층
- [x] ADR 0008 세션은 JSONL 하나, 히스토리는 덧붙이기만, 컴팩션은 요약으로 새 히스토리, 재개 때 VM은 복원하지 않음
- [x] ADR 0009 v1에서 뺀 것과 되살리는 조건
- [x] ADR 0010 없는 것은 Cyber에 만든다. 순수 계산(json, regex, time)은 cyber 표준 모듈, 세계에 닿는 것만 능력. 시계 읽기 능력은 clock.now
- [x] docs/deps.md 신규, README.md와 MEMORY.md 갱신, ADR 0001과 0002에 이후 결정 반영
- [x] 낡은 사실 정정: cyber에 메모리 상한(cl_vm_set_memory_limit)과 스택 상한(cl_vm_set_stack_limit)이 있다. 비-main await의 프로세스 종료 경로는 2026-11-08에 고쳐졌다

## 시도했으나 실패한 접근

- 정규식과 JsonValue를 v1에서 빼고 JSON을 호스트 능력(json.get 등)으로 주기: 처음에 "만들 수 있음" 기준으로 뺐으나 사용자가 "things we need, we make"로 뒤집었다. ADR 0010으로 되돌렸다. Cyber에 없는 것을 범위에서 빼거나 호스트로 우회하는 안을 다시 내지 않는다.
- 다중 세션 데몬 agentd를 v1 중심에 두기: 이전 HANDOFF의 확정 사항이었으나 0004에서 세션당 프로세스 하나로 바꿨다. 사용자가 이 변경에 아직 명시적으로 답하지 않았다. 반대하면 0004만 되돌린다.
- 세션 재개 때 과거 코드를 재생해 VM 복원: 파일 쓰기와 명령 실행 같은 부작용이 다시 일어난다. 폐기 (0008).
- 히스토리 중간을 요약으로 바꿔치기하는 컴팩션: 현재 Claude 모델의 사고 블록 규칙과 프롬프트 캐시를 깬다. 폐기 (0008).
- 셸 문자열을 파싱해 읽기 전용 여부를 판정하는 분류기: 우회가 쉬워 안전 장치로 못 쓴다. 폐기 (0007).
- tars.* 능력의 모의 구현: tars 터미널에 외부 제어 채널이 없어 상대가 없다. 폐기 (0009).
- 방식 B(순수 Cyber CLI) 스파이크, docs/design.md와 docs/fork-plan.md: 뺌 (0009).

## 남은 작업

정본은 docs/TODO.md다. 구현 착수는 사용자가 시작하라고 할 때다.

- [ ] M0 스파이크 1: cyber를 Zig 의존으로 링크, 능력 2개, 호스트 로더, deny_raw_ptrs, 상한 넷, validate, persist_main. 확인 목록 여섯 항목은 `docs/spec/08-cyber-implementation.md:28`
- [ ] M0 스파이크 2: Zig std.http로 Anthropic Messages API 스트리밍 (TLS, CA 묶음)
- [ ] M0 스파이크 3: x86_64-linux-gnu 교차 빌드와 tars 게스트(QEMU) 실행
- [ ] cyber C1: json 표준 모듈과 빌드 내보내기 (cyber 저장소에서, M0 평가보다 먼저)
- [ ] Cyber 부분집합 안내 초안, eval/ 과제 20개, CodeAct 대 direct 평가, 판정을 docs/decisions에 기록하고 보고
- [ ] cyber C2: regex(역추적 없는 엔진), time 모듈. C3: 임베딩 옵션, #[bind] 문서
- [ ] M1~M6
- [ ] 미확인 사실: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5), 점 표기 모듈 이름과 기본값 매개변수가 #[bind]에서 되는지 (M0)

## 핵심 파일

- `docs/TODO.md:15` — M0 증명과 판정, `docs/TODO.md:31` — C cyber 쪽 작업 줄기
- `docs/spec/08-cyber-implementation.md:28` — M0 확인 목록, `:37` — cyber에서 만들 것(필요의 증거와 순서)
- `docs/spec/02-agent-loop.md` — 모델 요청 규칙, 스텝 절차, 실패 분류, 컴팩션, 재개
- `docs/spec/04-builtin-tools.md` — v1 능력 목록, 능력이 아닌 표준 모듈
- `docs/spec/05-permissions-security.md` — 위협 모델, 세 층, 모드 표, 규칙 문법
- `docs/decisions/0004~0010` — 이번 세션의 결정, `MEMORY.md` — 색인
- `/Users/dp/Repository/cyberscript/src/include/cyber.h` — libcyber C API
- `/Users/dp/Repository/cyberscript/examples/libcyber/host_tool.c` — 능력 바인딩 패턴의 본보기
- `/Users/dp/Repository/cyberscript/docs/decisions/project_embedding_agent_loop.md` — 임베딩 규칙과 측정값
- `/Users/dp/Repository/tars-linux/devlayer/manifest.toml:581` — cyber가 devlayer에 들어가는 방식 (tars-agent도 같은 길)

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg와 fd. 문서 코드 펜스는 ~~~. 결정은 docs/decisions에 파일로 남기고 MEMORY.md에 한 줄.
2. 설계 선택지를 계속 묻지 않고 추천안으로 정해 진행한다. 이전 확정을 바꾸면 무엇을 바꿨는지 눈에 띄게 보고한다.
3. 구현을 시작하라는 지시가 오면 docs/TODO.md의 M0부터. 먼저 위 cyber 파일 셋(cyber.h, host_tool.c, project_embedding_agent_loop.md)을 읽는다. 스파이크 셋과 cyber C1(json 모듈)은 나란히 할 수 있고, 평가는 C1 뒤다.
4. cyber에 만들 것은 `docs/spec/08-cyber-implementation.md:37`의 표에 필요의 증거와 함께 올린다. 작업은 soomtong/cyber(/Users/dp/Repository/cyberscript)에서 그 저장소의 절차(테스트, 발견 이슈 기록, 릴리스 노트)를 따른다. 지금까지 cyber와 tars-linux는 읽기만 했다. tars-linux는 사용자 지시 없이 고치지 않는다.
5. Anthropic API 세부(사고, effort, 캐시, stop_reason, 모델 ID)는 기억에 기대지 말고 구현할 때 최신 문서로 다시 확인한다. 02 문서의 규칙은 2026-11-10 기준이고 기본 모델은 claude-opus-5-5로 적었다.
