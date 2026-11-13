# HANDOFF: M0 스파이크 셋 완료, 다음은 사용자의 검토와 본체 첫 단계 (2026-11-13)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 본체 코드는 아직 없다. 버릴 스파이크 코드가 spike/에 있다.

이번 세션의 흐름: 사용자가 스파이크를 Claude에게 통째로 맡겼다(결정 포함, ADR 0012의 덧붙임). 스파이크 1(호스트 경계), 2a와 2b(제공자와 최소 에이전트 루프), 3(교차 빌드와 tars 게스트)을 모두 구현하고 돌렸다. 검토 결과를 docs/spikes/에, 발견과 추천을 ADR 0017에, cyber 요청을 docs/requests/에 썼다.

## 현재 브랜치

`main` = origin/main. 작업 트리는 깨끗하다. 커밋과 push는 Claude에게 위임돼 있다 (docs/decisions/feedback-commit-delegation.md).

## 완료된 작업

- [x] 스파이크 1 (spike/s1): cyber 0.4.9를 의존으로 받아 링크, 능력 셋, 호스트 로더, 상한 넷, persist_main, validate, 승인 흐름(승인, 거부, 취소, 버린 요청, 태그 0), 동시 승인(scope, 중첩 scope). 검사 31개 통과 (macOS, tars 게스트)
- [x] 스파이크 2a (spike/s2a): 두 전송 형식의 원문 응답 여섯 개
- [x] 스파이크 2b (spike/s2): 메시지 모델, 어댑터 둘, 제공자 넷, std.http 스트리밍, direct와 codeact 루프. 과제 셋을 모델 셋으로 비교
- [x] 스파이크 3: x86_64-linux-gnu 교차 빌드, tars 게스트에서 s1 통과, 게스트 안에서 s2가 DeepSeek과 통신해 두 모드 모두 과제를 끝냄
- [x] 문서: docs/spikes/2026-11-13-m0-spikes-review.md, ADR 0017, docs/requests/cyber-m0-spike-findings.md, 08의 "M0에서 확인한 것", TODO, deps.md
- [x] (앞 세션들) ADR 0012~0016, cyber 0.4.9 고정

## 시도했으나 실패한 접근

- `b.dependency("cyber").artifact("cyber")`: cyber가 아티팩트를 내보내지 않는다. build.zig에서 받은 패키지 폴더로 `zig build lib`를 실행해 libcyber.a를 링크한다.
- `@cImport`: Zig 0.17.1에 없다. translate-c 패키지를 썼다.
- 능력이 `Future[!str]`을 돌려주기: cyber 0.4.9가 `!str` 값을 복사하지 못한다(core:2918 컴파일 오류). `Future[!int]` 손잡이와 take(h)로 우회했다.
- 세션 VM에서 바로 validate하기: 실패한 컴파일 뒤 다음 컴파일에서 Segmentation fault가 난다(재현 spike/s1/crash-validate.txt). 검증을 fork한 자식에서 한다.
- 호스트 함수에서 매개변수를 반환 슬롯보다 먼저 읽기: 죽는다. cl_thread_ret이 먼저다.
- 모델이 쓴 명령을 가두지 않고 실행하기: 자동 승인이 막았고, 실제로 모델이 `ls ~`와 `find /`를 돌렸다(결과가 나가기 전에 끊었다). sandbox-exec로 쓰기, 네트워크, 사용자 폴더 읽기를 막고 명령당 20초 상한을 뒀다(spike/s2/src/jail.zig). 스파이크의 도구를 다시 돌릴 때 이 가두기를 풀지 않는다.
- 압축하지 않은 cpio를 tars initrd 뒤에 이어 붙이기: 풀리지 않는다. gzip으로 묶어 붙인다.
- tars 게스트의 시리얼 셸에 LF로 Enter 보내기: fish라 CR이어야 한다.
- 이전 세션들의 버린 대안은 ADR 0004~0016에 있다. 다시 제안하지 않는다.

## 남은 작업

2026-11-13 뒤 세션: cyber dev(master dcedfc48 + 작업 트리)로 스파이크를 다시 돌렸다. 결과는 docs/spikes/2026-11-13-m0-spikes-review-02.md. 결함 둘은 dev에서 우회 없이 통과(릴리스 대기). 안내(prompt/cyber-subset*.md)를 기준 0.4.10-DEV로 고쳤고 컴파일 오류가 크게 줄었다. 사용자가 정할 것 셋:

- [ ] `not`이 `and`, `or`보다 약하게 묶이는 것(review-02 6.2)을 cyber 결함으로 요청할지. 스파이크 결함 규칙에 든다고 봄
- [ ] 안내가 약 6,000토큰으로 커져 TODO의 4,000토큰 목표를 넘는다. 목표를 바꿀지 안내를 줄일지 (review-02 8절)
- [ ] review-02 7절의 cyber 요청 후보 중 어느 것을 요청서로 쓸지


정본은 docs/TODO.md다. 본체 구현은 페어 코딩이다: 사용자와 함께 검토하며 한 단계씩 간다 (CLAUDE.md, ADR 0012).

- [ ] 사용자가 docs/spikes/2026-11-13-m0-spikes-review.md를 읽고 ADR 0017의 추천을 받거나 바꾼다. 그 뒤 spike/를 지운다
- [ ] cyber에 요청서 전달 (docs/requests/cyber-m0-spike-findings.md). 스파이크의 결함은 모두 고치고 진행한다(사용자 지시, feedback-fix-spike-defects-first.md): 수정 릴리스, 고정 버전 올리기, 재현 재실행, 우회 없이 통과 확인이 본체 첫 단계의 선행 조건이다. 우회(fork 검증, 손잡이, zig build lib)는 본체에 넣지 않는다
- [ ] 본체 첫 단계: 저장소 뼈대와 runtime 경계. 단계의 결정, 편집, 기능 표를 먼저 낸다

- [ ] ADR 0015의 "2a 뒤에 정할 것" 넷: 스파이크의 답은 검토 문서 4.2에 있다. 확정은 본체의 메시지 모델 단계에서
- [ ] cyber C1: json 모듈, toon 모듈(json 다음에 요청서), 빌드 내보내기. C2: regex(역추적 없는 엔진), time. C3: 임베딩 옵션(모듈 허용 표, spawn 차단)
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록. 평가 도구가 cl_thread_rc로 누수를 세면 먼저 cl_vm_release_result를 부른다
- [ ] M1~M6
- [ ] 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5), 기본값 매개변수가 #[bind]에서 되는지 (M0)
- [ ] tars-linux devlayer의 cyber는 0.4.7이다(`/Users/dp/Repository/tars-linux/devlayer/manifest.toml:580`). tars-linux는 사용자 지시 없이 고치지 않는다

## 핵심 파일

- `docs/spikes/2026-11-13-m0-spikes-review.md` — 스파이크 검토 결과. 1절 요약, 2절 에이전트가 도는 법, 8절 본체 추천 열다섯
- `docs/decisions/0017-m0-spike-findings.md` — 발견과 추천
- `docs/requests/cyber-m0-spike-findings.md` — cyber 요청 (결함 둘, 빌드 내보내기, spawn 차단)
- `spike/s2/src/main.zig` — 최소 에이전트 루프, `spike/s2/src/provider.zig` — 메시지 모델과 어댑터, `spike/s2/src/vm.zig` — 검증, 실행, 승인
- `spike/s1/src/main.zig` — 호스트 경계 검사 31개와 죽는 경로 재현

- `docs/spec/08-cyber-implementation.md:23` — CL_AWAIT API와 규칙, `:35` 0.4.9의 변경, `:53` M0 확인 목록, `:62` cyber에서 만들 것
- `docs/decisions/0016-concurrent-approvals-and-fibers-in-v1.md:13` — 결정 셋, `:35` 되살리는 조건
- `docs/decisions/0011-approval-wait-outside-vm.md:5` — 결정, `:53` 바인딩 층 설계, `:59` cyber가 고른 동작(0.4.9 주석 포함)
- `docs/decisions/0015-provider-message-model-and-adapters.md:16` — 메시지 모델과 어댑터의 방향, `:26` 2a 뒤에 정할 것
- `docs/spec/02-agent-loop.md:30` — 실행 단계(CL_AWAIT, 요청이 여럿일 때)
- `docs/requests/cyber-0.4.9-report.md` — cyber의 0.4.9 안내 원문. `docs/requests/cyber-cl-await.md`와 `-report.md` — CL_AWAIT 요청과 보고
- `prompt/cyber-subset.md:5` — 기준 버전, `:79` 예약어와 fiber 금지 줄. 영문판 `prompt/cyber-subset.en.md`는 같은 구조
- `docs/TODO.md:21` — M0, `:40` — C 줄기
- `/Users/dp/Repository/cyberscript/src/include/cyber.h:441` — "Suspended evals and host futures" 절
- `/Users/dp/Repository/cyberscript/examples/libcyber/host_await.c` — tars-agent 방식 그대로의 호스트 예제(래퍼, 승인, 거부, 취소)
- `/Users/dp/Repository/cyberscript/docs/releases/0.4.9.md` — 0.4.9 호환성과 알려진 문제

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg와 fd. 문서 코드 펜스는 ~~~. 결정은 docs/decisions에 파일로 남기고 MEMORY.md에 한 줄. 용어 옆에 원어를 괄호로 붙이는 표기(연료(fuel), 벽시계(wall-clock))를 쓴다.
2. 본체 구현은 페어 코딩이다 (CLAUDE.md, ADR 0012). 스파이크만 Claude에게 위임됐었고 그것은 끝났다. 단계마다 결정, 편집, 기능을 나눠 공유하고, 구조에 관한 결정은 사용자가 정한다. 추천안과 근거를 내면 사용자가 받거나 바꾼다. 이전 확정을 바꾸면 눈에 띄게 보고한다.
3. cyber 쪽 작업은 요청서를 써서 사용자가 cyber 저장소에 전달하는 흐름이다. 보고가 오면 원문을 docs/requests에 두고 08, ADR, TODO에 반영한다. cyber 저장소와 tars-linux는 사용자 지시 없이 직접 편집하지 않는다. cyber 저장소에서는 다른 세션이 동시에 작업할 수 있다(이번에 커밋되지 않은 변경이 보였다).
4. cyber 릴리스가 나오면: origin의 태그와 GitHub 릴리스부터 확인(`git ls-remote --tags origin`, `gh release list`), 앞서 본 커밋 이후의 diff와 cyber.h 변경 확인, `cyber version`이 태그와 맞는지 확인, 안내 예제 20개 재실행, deps.md 고정 버전과 08, 안내 기준 버전 갱신. 예제는 안내의 cy 코드 펜스를 파일로 뽑아 하나씩 실행한다.
5. 로컬 `/usr/local/bin/cyber`는 사용자가 릴리스마다 올린다(지금 0.4.9 build-833). cyberscript의 `zig-out/bin/cyber`는 버전 표시가 DEV인 작업 중 빌드라 릴리스 확인에 쓰지 않는다.
6. 스파이크를 다시 돌리려면: spike/s1에서 `zig build && ./zig-out/bin/s1`, spike/s2에서 `./compare.sh ds-anth`. 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. tars 게스트는 spike/s3/guest.py와 검토 문서 6절. 키를 게스트에 넣었으면 끝나고 그 cpio를 지운다.
7. 구현을 시작하라는 지시가 오면 본체 첫 단계부터. 먼저 cyber.h, host_await.c, cyber의 docs/decisions/project_embedding_agent_loop.md를 읽는다. 제공자 API 세부는 구현할 때 최신 문서로 다시 확인한다.
