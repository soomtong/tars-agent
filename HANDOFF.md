# HANDOFF: M0 스파이크를 cyber 0.4.10으로 다시 돌리고 문서를 0.4.10 기준으로 정리함 (2026-11-14)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 본체 코드는 아직 없다. 버릴 스파이크 코드가 spike/에 있다.

이번 세션: 사용자가 "cyber는 0.4.10이다. 구버전 테스트 기록과 결과, 구버전 dev에서 생긴 내용은 무시하고 현재 버전에 맞는 문서로 다시 쓰라"고 지시했다. 스파이크 의존을 0.4.10으로 올려 다시 돌리고, 검토 문서 셋(01~03)과 요청서 둘을 0.4.10 기준 한 편씩으로 바꿨다. 지난 세션들이 "고쳐졌다"고 본 cyber 수정은 모두 0.4.10 태그 뒤의 dev 커밋이었고, 0.4.10에서는 결함이 그대로다.

## 현재 브랜치

`main`. 이 세션의 변경을 커밋하고 push했다. 커밋과 push는 Claude에게 위임돼 있다 (docs/decisions/feedback-commit-delegation.md).

## 완료된 작업

- [x] spike/s1, s2의 cyber 의존을 `ref=0.4.10`(→ 9490ddaf)으로 올림. s1 검사 31개 통과(우회 모양)
- [x] 0.4.10에서 결함 재현: 실패한 컴파일 뒤 검증에서 Segmentation fault(재현 둘), `!str` 복사 오류(core:2918), `^[]str +=`로 세션 VM이 실행 중에 죽음
- [x] 안내(prompt/cyber-subset*.md)를 0.4.10 기준으로 다시 씀. 항목을 0.4.10 CLI로 하나씩 확인, 예제 10개를 CLI와 세션(replay) 양쪽에서 통과
- [x] s2 비교 재실행(0.4.10, 새 안내): CodeAct 21과제 모두 통과, 컴파일 오류는 qwen3.8-flash만 과제당 1.4. direct 실패 둘은 과제 해석. 원자료 spike/s2/out/v0410/*.tsv
- [x] x86_64-linux-gnu 교차 빌드 확인 (s1 45초, s2 72초)
- [x] 문서: docs/spikes/2026-11-14-m0-spikes-review.md, docs/requests/cyber-0.4.10-m0-spike-findings.md, ADR 0017, feedback-fix-spike-defects-first.md, 08, 00, 09, deps.md, TODO, MEMORY
- [x] s1의 `replay`가 출력과 오류 첫 줄을 찍게 함 (안내 예제를 세션 조건에서 확인하는 데 씀)

## 시도했으나 실패한 접근

- `b.dependency("cyber").artifact("cyber")`: cyber가 아티팩트를 내보내지 않는다. build.zig에서 받은 패키지 폴더로 `zig build lib`를 실행해 libcyber.a를 링크한다.
- `@cImport`: Zig 0.17.1에 없다. translate-c 패키지를 썼다.
- 능력이 `Future[!str]`을 돌려주기: 0.4.10이 `!str` 값을 복사하지 못한다. `Future[!int]` 손잡이와 take(h)로 우회했다(스파이크에만).
- 세션 VM에서 바로 validate하기: 실패한 컴파일 뒤 다음 컴파일에서 죽는다. 검증을 fork한 자식에서 한다(스파이크에만).
- 호스트 함수에서 매개변수를 반환 슬롯보다 먼저 읽기: 죽는다. cl_thread_ret이 먼저다.
- 모델이 쓴 명령을 가두지 않고 실행하기: 모델이 `ls ~`, `find /`를 돌린 적이 있다. sandbox-exec로 가둔다(spike/s2/src/jail.zig). 풀지 않는다.
- 안내의 조언을 CLI로만 확인하기: 최상위 빌림 오류처럼 세션(persist_main)에서만 나는 것이 있다. 세션에서도 확인한다.
- `zig build`의 산출물 경로를 묻느라 `s2 --help`를 실행하기: s2는 그것을 질문으로 모델에 보낸다. 인자 설명은 main.zig 3행.
- 이전 세션들의 버린 대안은 ADR 0004~0016에 있다. 다시 제안하지 않는다.

## 남은 작업

정본은 docs/TODO.md다. 본체 구현은 페어 코딩이다: 사용자와 함께 검토하며 한 단계씩 간다 (CLAUDE.md, ADR 0012).

사용자가 정할 것:

- [ ] 요청서 docs/requests/cyber-0.4.10-m0-spike-findings.md를 cyber에 전달 (1~3절의 결함이 먼저)
- [ ] 안내가 약 6,900토큰(영문 20.8KB)으로 TODO의 4,000토큰 목표를 넘는다. 목표를 바꿀지 안내를 줄일지 (검토 문서 8절)
- [ ] 스크립트 실행이 호스트를 죽일 수 있으니(`^[]str +=`) runtime 경계에서 VM을 별도 프로세스로 둘지 (검토 문서 9절 4, 본체 첫 단계에서)
- [ ] docs/spikes/2026-11-14-m0-spikes-review.md를 읽고 ADR 0017의 추천을 받거나 바꾼다. 그 뒤 spike/를 지운다

그 밖:

- [ ] cyber의 수정 릴리스가 나오면: 고정 버전 올리기, 7절의 재현 재실행, 우회를 걷어 낸 모양(`Future[!str]`, 세션 VM 검증)으로 통과 확인, 안내의 0.4.10 함정 줄 다시 보기. 이것이 본체 첫 단계의 선행 조건이다 (feedback-fix-spike-defects-first.md)
- [ ] tars 게스트에서 0.4.10 스파이크 실행 (tars-linux 산출물 필요, 이번 세션은 하지 않음)
- [ ] 본체 첫 단계: 저장소 뼈대와 runtime 경계. 단계의 결정, 편집, 기능 표를 먼저 낸다
- [ ] ADR 0015의 "2a 뒤에 정할 것" 넷: 스파이크의 답은 검토 문서 4.2. 확정은 본체의 메시지 모델 단계에서
- [ ] cyber C1: json 모듈, toon 모듈, 빌드 내보내기. C2: regex, time. C3: 임베딩 옵션(모듈 허용 표, spawn 차단)
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록
- [ ] M1~M6
- [ ] 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5)

## 핵심 파일

- `docs/spikes/2026-11-14-m0-spikes-review.md` — 0.4.10 검토. 1절 요약, 5절 CodeAct 비교, 7절 결함, 8절 안내, 9절 본체 추천 열여섯, 11절 다시 돌리는 법
- `docs/requests/cyber-0.4.10-m0-spike-findings.md` — cyber 요청 (결함 셋, 조용히 다른 값, 빌드와 임베딩, 오류 문구, 정렬)
- `docs/decisions/0017-m0-spike-findings.md` — 발견과 추천
- `prompt/cyber-subset.en.md`, `prompt/cyber-subset.md` — 0.4.10 안내. 같은 구조, 같은 예제
- `docs/spec/08-cyber-implementation.md` — 3행 기준 버전, "0.4.10의 변경", "M0에서 확인한 것", "cyber에서 만들 것"
- `docs/deps.md` — cyber 0.4.10 고정(해시 포함)
- `spike/s2/src/main.zig` — 최소 에이전트 루프, `spike/s2/src/provider.zig` — 메시지 모델과 어댑터, `spike/s2/src/vm.zig` — 검증, 실행, 승인
- `spike/s1/src/main.zig` — 검사 31개, 죽는 경로 재현, `replay`
- `spike/s2/out/v0410/*.tsv` — 0.4.10 비교 원자료 (trace와 로그는 같은 폴더의 하위 폴더, git에서 뺌)

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg와 fd. 문서 코드 펜스는 ~~~. 결정은 docs/decisions에 파일로 남기고 MEMORY.md에 한 줄. 용어 옆에 원어를 괄호로 붙이는 표기(연료(fuel), 벽시계(wall-clock))를 쓴다.
2. 본체 구현은 페어 코딩이다 (CLAUDE.md, ADR 0012). 단계마다 결정, 편집, 기능을 나눠 공유하고, 구조에 관한 결정은 사용자가 정한다.
3. 2026-11-14 사용자 지시: "다른 저장소는 확인하지 마". 이번 세션에서 cyberscript와 tars-linux 저장소를 읽지 않고 진행했다. cyber는 build.zig.zon으로 받은 패키지와 로컬 CLI(`/usr/local/bin/cyber`, 지금 `Cyber 0.4.10 build-856-3e6b02e`)로만 확인했다. 이웃 저장소를 다시 볼 때는 사용자에게 먼저 묻는다.
4. cyber 쪽 작업은 요청서를 써서 사용자가 cyber 저장소에 전달하는 흐름이다. 보고가 오면 원문을 docs/requests에 두고 08, ADR, TODO에 반영한다.
5. 기준은 릴리스다. dev 빌드의 결과를 문서의 사실로 쓰지 않는다(이번 세션이 그것을 걷어 냈다). 새 릴리스가 오면: `cyber version` 확인, build.zig.zon의 `ref`를 올리고 커밋을 확인, 스파이크 재실행, 안내 항목과 예제를 CLI와 세션에서 재확인, deps와 08과 안내 기준 버전 갱신.
6. 스파이크를 다시 돌리려면 검토 문서 11절. 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY.
