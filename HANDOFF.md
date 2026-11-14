# HANDOFF: 문서를 cyber 기준 빌드(master 63e35e88)의 현재 상태로 다시 세움 (2026-11-14)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 본체 코드는 아직 없다. 버릴 스파이크 코드가 spike/에 있다.

이번 세션: 사용자가 "cyber는 0.4.10+dev(로컬 저장소의 빌드)다. 구버전 테스트 기록과 결과, 구버전 dev에서 생긴 내용은 무시하고 현재 버전에 맞는 문서로 다시 쓰라", "문서를 전체적으로 리빌드해도 된다. 과거 버그나 과거 기록이 LLM 컨텍스트를 오염하지 않도록"이라고 지시했다. 기준 빌드를 cyber master 63e35e88(`0.4.10-DEV`)로 정하고, 스파이크를 우회 없는 모양으로 고쳐 다시 돌리고, 문서를 지금 참인 것만 적도록 다시 썼다. 규칙은 docs/decisions/0020-docs-current-state-only.md.

## 현재 브랜치

`main`. 커밋과 push는 Claude에게 위임돼 있다 (docs/decisions/0018-commit-delegation.md).

## 완료된 작업

- [x] 스파이크 의존을 cyber 63e35e88(커밋과 해시)로 고정. s1, s2는 본래 모양(능력은 `Future[!str]`, 검증은 세션 VM의 `cl_vm_validate`)으로 돈다
- [x] s1 검사 35개: 34 통과, 6i(이스케이프 오류 뒤 세션)는 열린 결함의 문. `s1 order`, `s1 spawn`, `s1 replay <파일> [nv]`
- [x] 안내 두 판을 기준 빌드로 다시 씀. 항목은 탐침으로, 코드 블록 11개는 CLI와 세션 양쪽에서 확인. 회차에서 모델이 틀린 곳(`?int`, 이스케이프, 블록 안 `fn`)을 더함
- [x] s2 비교: direct 6, CodeAct 21 과제 모두 통과. 원자료 spike/s2/out/dev/*.tsv
- [x] 교차 빌드 x86_64-linux-gnu (s1 45초, s2 77초)
- [x] 새 결함 발견과 요청서: 문자열 이스케이프 오류가 세션을 지움, `\0`이 큰따옴표 등 (docs/requests/cyber-m0-spike-requests.md)
- [x] 문서 다시 쓰기: 검토 문서, ADR 0017, 08, deps, TODO, MEMORY, 규칙 둘, ADR 0011과 0016, 명세 00, 01, 02, 05, 09. 반영이 끝난 요청서와 보고서 넷, 옛 회차 원자료, 재현 파일을 지움

## 시도했으나 실패한 접근

- `b.dependency("cyber").artifact("cyber")`: cyber가 아티팩트를 내보내지 않는다. build.zig에서 받은 패키지 폴더로 `zig build lib`를 실행해 libcyber.a를 링크한다(스파이크에만).
- `@cImport`: Zig 0.17.1에 없다. translate-c 패키지를 썼다.
- 호스트 함수에서 매개변수를 반환 슬롯보다 먼저 읽기: 죽는다. cl_thread_ret이 먼저다.
- 모델이 쓴 명령을 가두지 않고 실행하기: 모델이 `ls ~`, `find /`를 돌린 적이 있다. sandbox-exec로 가둔다(spike/s2/src/jail.zig). 풀지 않는다.
- 안내의 조언을 CLI로만 확인하기: 최상위 빌림처럼 세션(persist_main)에서만 다른 것이 있다. `s1 replay`로 세션에서도 확인한다.
- 회차 도중에 안내 고치기: s2는 실행마다 안내를 읽어 표본이 섞인다. 회차가 끝난 뒤 고치고 다시 돌린다.
- `/usr/local/bin/cyber`로 안내 확인하기: 그것은 기준 빌드가 아니다. 기준 빌드의 CLI는 cyber 저장소에서 `zig build cli -Doptimize=ReleaseFast -Dcommit=63e35e88 --prefix <스크래치>`로 만든다(저장소의 zig-out은 건드리지 않는다).
- `zig build`의 산출물 경로를 묻느라 `s2 --help`를 실행하기: s2는 그것을 질문으로 모델에 보낸다. 인자 설명은 main.zig 3행.
- 이전 세션들의 버린 대안은 ADR 0004~0016에 있다. 다시 제안하지 않는다.

## 남은 작업

정본은 docs/TODO.md다. 본체 구현은 페어 코딩이다: 사용자와 함께 검토하며 한 단계씩 간다 (CLAUDE.md, ADR 0012).

사용자가 정할 것:

- [ ] 요청서 docs/requests/cyber-m0-spike-requests.md를 cyber에 전달 (1~5절이 본체 선행 조건, 1절의 세션 소실이 가장 무겁다)
- [ ] 안내가 약 6,800~6,900토큰(영문 20.4KB)으로 TODO의 4,000토큰 목표를 넘는다. 목표를 바꿀지 안내를 줄일지 (검토 문서 8절)
- [ ] docs/spikes/2026-11-14-m0-spikes-review.md를 읽고 ADR 0017의 추천을 받거나 바꾼다. 그 뒤 spike/를 지운다

그 밖:

- [ ] cyber 수정이 들어오면: 고정 커밋 올리기, s1(6i 통과 확인)과 안내 탐침, 코드 블록 11개를 CLI와 `replay`로 다시, 안내의 피하는 법 줄(이스케이프, 최상위 빌림) 다시 보기, 문서를 새 빌드의 사실로 고쳐 쓰기
- [ ] tars 게스트에서 기준 빌드로 스파이크 실행 (tars-linux 산출물 필요)
- [ ] 본체 첫 단계: 저장소 뼈대와 runtime 경계. 단계의 결정, 편집, 기능 표를 먼저 낸다
- [ ] ADR 0015의 "2a 뒤에 정할 것" 넷: 스파이크의 답은 검토 문서 4.2. 확정은 본체의 메시지 모델 단계에서
- [ ] cyber C1: json 모듈, toon 모듈. C2: regex, time. C3: 모듈 허용 표
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록
- [ ] M1~M6
- [ ] 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5)

## 핵심 파일

- `docs/spikes/2026-11-14-m0-spikes-review.md` — 1절 요약, 3절 호스트 경계, 5절 CodeAct 비교와 모델이 틀린 곳, 7절 cyber에 남은 것, 8절 안내, 9절 본체 추천 열여섯, 11절 다시 돌리는 법
- `docs/requests/cyber-m0-spike-requests.md` — cyber 요청 일곱 절
- `docs/decisions/0017-m0-spike-findings.md` — 발견과 추천
- `docs/decisions/0020-docs-current-state-only.md` — 문서는 지금의 상태만
- `prompt/cyber-subset.en.md`, `prompt/cyber-subset.md` — 안내. 같은 구조, 같은 코드 블록
- `docs/spec/08-cyber-implementation.md` — 기준 빌드의 사실, M0에서 확인한 것, cyber에서 만들 것
- `docs/deps.md` — cyber 63e35e88 고정(해시 포함)
- `spike/s1/src/main.zig` — 검사 35개, `replay`, `order`, `spawn`
- `spike/s2/src/main.zig` — 최소 에이전트 루프, `provider.zig` — 메시지 모델과 어댑터, `vm.zig` — 검증, 실행, 승인
- `spike/s2/out/dev/*.tsv` — 비교 원자료 (trace와 로그는 하위 폴더, git에서 뺌)

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg와 fd. 문서 코드 펜스는 ~~~. 결정은 docs/decisions에 파일로 남기고 MEMORY.md에 한 줄. 용어 옆에 원어를 괄호로 붙이는 표기(연료(fuel), 벽시계(wall-clock))를 쓴다.
2. 본체 구현은 페어 코딩이다 (CLAUDE.md, ADR 0012). 단계마다 결정, 편집, 기능을 나눠 공유하고, 구조에 관한 결정은 사용자가 정한다.
3. 문서는 지금 참인 것만 적는다. 고쳐진 결함, 걷어 낸 우회, 버전별 변천을 문서에 남기지 않는다 (ADR 0020).
4. 기준 빌드는 cyber 로컬 저장소(/Users/dp/Repository/cyberscript)의 master다. 이번 세션은 사용자 지시로 그 저장소를 읽고 빌드했다(편집은 하지 않았다). cyber 쪽 작업은 요청서를 써서 사용자가 전달하는 흐름이고, 그 저장소를 편집하는 것은 사용자가 지시할 때다 (ADR 0013).
5. 스파이크를 다시 돌리려면 검토 문서 11절. 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY.
