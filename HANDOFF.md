# HANDOFF: cyber 5de6c83a로 다시 점검하고 요청서를 다시 씀 (2026-11-14)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 본체 코드는 아직 없다. 버릴 스파이크 코드가 spike/에 있다.

이번 세션: (1) docs/decisions의 `feedback-*.md` 셋을 ADR 0018~0020으로 번호를 매겼다. (2) 사용자가 "cyber lang 저장소의 5de6c83a 커밋 기준으로 다시 점검. 요청서 다시 작성"을 지시했다. cyber가 이전 요청서 1~7절을 bf5967db, 5de6c83a에서 고쳤다는 회신(docs/requests/cyber-m0-spike-response.md, 사용자가 둔 추적되지 않은 파일)을 받아, 기준 빌드를 5de6c83a로 옮기고 스파이크와 문서를 그 빌드의 사실로 고쳐 썼다.

## 현재 브랜치

`main`. 커밋과 push는 Claude에게 위임돼 있다 (ADR 0018).

## 완료된 작업

- [x] 결정 파일 이름 규칙: `NNNN-slug.md`. 사용자 지시 규칙도 번호를 받는다 (MEMORY 머리말)
- [x] 스파이크 의존: cyber 로컬 저장소 경로(`.path = "../../../cyberscript"`)와 `artifact("cyber")`. `zig build lib` 우회를 걷어 냈다. C 파일의 `#include "cyber.h"` 확인(s1 검사 0)
- [x] s1 검사 39개 모두 통과. 새 검사: 이스케이프 오류 뒤 세션(6i), `'\0'`(6j), panic 뒤(6k), `cl_vm_reset_pending`(6l), deny_spawn(7f). `s1 order [n]`은 호출 경로 넷과 대조군 셋
- [x] 새 결함: 직접 호출이 아닌 경로에서 매개변수를 먼저 읽으면 틀린 값 (요청서 1절)
- [x] s2: deny_spawn, 실패 뒤 `cl_vm_reset_pending`이면 머리말 재실행과 알림. 비교 다시 돌림(27개 모두 통과, 컴파일 오류는 qwen3.8-flash 과제당 2.4). 원자료 spike/s2/out/dev/*.tsv
- [x] 안내 두 판: 기준 줄, 목록 리터럴, 이스케이프 줄, 오류 목록(고치는 법을 말하게 된 넷을 빼고 `s.len` 추가). 코드 블록 11개 CLI와 세션 통과
- [x] 교차 빌드 x86_64-linux-gnu (s1 46초, s2 71초)
- [x] 요청서 다시 씀(6절), 검토 문서, ADR 0017, 0019, 08, 00, 02, 05, deps, TODO, MEMORY

## 시도했으나 실패한 접근

- `rg`로 spike/s2/out/dev/<회차>/의 trace 찾기: .gitignore에 걸려 아무것도 안 나온다. `rg --no-ignore`를 쓴다.
- 비교를 시작한 뒤 s2를 고치기: 회차가 섞인다. 고친 뒤 처음부터 다시 돌렸다.
- 회차에서 본 실수(`and`로 묶은 옵션 풀기, 보간 안의 보간)를 바로 안내로 막기: 회차 뒤에 안내를 고치면 측정과 안내가 어긋난다. cyber의 문구(요청서 6절)를 본 뒤 정하고 다시 돌린다.
- `/usr/local/bin/cyber`로 안내 확인하기: 기준 빌드가 아니다. 기준 빌드의 CLI는 cyber 저장소에서 `zig build cli -Doptimize=ReleaseFast -Dcommit=5de6c83a --prefix <스크래치>`로 만든다(저장소의 zig-out은 건드리지 않는다).
- cyber 저장소의 작업 트리를 경로 의존으로 그대로 빌드하기: 다른 작업의 변경이 섞인다. 첫 비교 회차와 교차 빌드가 그렇게 섞여서 버리고 다시 쟀다.
- `s2 --help`: 질문으로 모델에 보낸다. 인자 설명은 main.zig 3행.
- 이전 세션들의 버린 대안은 ADR 0004~0016에 있다. 다시 제안하지 않는다.

## 남은 작업

정본은 docs/TODO.md다. 본체 구현은 페어 코딩이다 (CLAUDE.md, ADR 0012).

사용자가 정할 것:

- [ ] 요청서 docs/requests/cyber-m0-spike-requests.md를 cyber에 전달 (1, 2절이 본체 선행 조건)
- [ ] cyber 회신 파일(docs/requests/cyber-m0-spike-response.md)을 지울지. 반영은 끝났다 (ADR 0020은 반영된 보고서를 지운다. 추적되지 않은 파일이라 지우지 않고 두었다)
- [ ] 안내가 약 6,600~6,800토큰(영문 19.9KB)으로 TODO의 4,000토큰 목표를 넘는다. 목표를 바꿀지 안내를 줄일지 (검토 문서 8절)
- [ ] docs/spikes/2026-11-14-m0-spikes-review.md를 읽고 ADR 0017의 추천을 받거나 바꾼다. 그 뒤 spike/를 지운다

그 밖:

- [ ] cyber 수정과 push가 들어오면: deps와 스파이크를 URL과 해시로 고정, `s1`과 `s1 order 0~6`, 안내 탐침과 코드 블록, s2 비교를 다시, 문서를 새 빌드의 사실로 고쳐 쓰기 (검토 문서 11절)
- [ ] tars 게스트에서 기준 빌드로 스파이크 실행 (tars-linux 산출물 필요)
- [ ] 본체 첫 단계: 저장소 뼈대와 runtime 경계. 단계의 결정, 편집, 기능 표를 먼저 낸다
- [ ] cyber C1: json, toon. C2: regex, time. C3: 모듈 허용 표
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록
- [ ] M1~M6. 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5)

## 핵심 파일

- `docs/requests/cyber-m0-spike-requests.md` — 5de6c83a에서 남은 것 여섯 절과 확인을 마친 것
- `docs/spikes/2026-11-14-m0-spikes-review.md` — 1절 요약, 3절 호스트 경계, 5절 비교, 7절 cyber에 남은 것, 11절 다시 돌리는 법
- `docs/decisions/0017-m0-spike-findings.md`, `0019-fix-spike-defects-first.md` (선행 조건 목록), `0020-docs-current-state-only.md`
- `docs/spec/08-cyber-implementation.md` — 기준 빌드의 사실
- `spike/s1/src/main.zig` — 검사 39개, `replay`, `order`, `spawn`. `spike/s1/src/inc_check.c`
- `spike/s2/src/vm.zig` — 검증, 실행, 승인, reset 알림

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg와 fd. 문서 코드 펜스는 ~~~. 결정은 docs/decisions에 `NNNN-slug.md`로 남기고 MEMORY.md에 한 줄.
2. 본체 구현은 페어 코딩이다. 구조에 관한 결정은 사용자가 정한다.
3. 문서는 지금 참인 것만 적는다 (ADR 0020).
4. 스파이크는 cyber 로컬 저장소를 경로로 받고, 경로 의존은 작업 트리를 그대로 빌드한다. 이번 세션 중에 cyber 저장소에 커밋하지 않은 변경(클로저 고정 관련, src/thread.zig 등)이 생겨, 숫자는 `git archive 5de6c83a`로 스크래치에 푼 깨끗한 소스로 다시 쟀다. 돌리기 전에 `git -C /Users/dp/Repository/cyberscript status`와 `log -1`을 확인한다. cyber 저장소는 읽고 빌드만 한다. 편집은 사용자가 지시할 때다 (ADR 0013).
5. 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. 모델이 쓴 명령은 jail.zig의 샌드박스 안에서만 돈다.
