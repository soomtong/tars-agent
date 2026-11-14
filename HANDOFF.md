# HANDOFF: cyber 회신을 6a155275에서 확인하고 기준 빌드를 올림 (2026-11-14)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 본체 코드는 아직 없다. 버릴 스파이크 코드가 spike/에 있다.

이번 세션: 사용자가 요청서(cd7b218)에 대한 cyber 회신(docs/requests/cyber-m0-spike-response.md, 사용자가 둔 추적되지 않은 파일)을 받았다. 회신의 각 절을 cyber 로컬 master 6a155275에서 직접 확인했고 모두 회신대로였다. 기준 빌드를 6a155275로 올리고 스파이크, 안내, 문서를 고쳤다. 남은 요청은 커밋을 원격에 올리는 것 하나다.

## 현재 브랜치

`main`. 커밋과 push는 Claude에게 위임돼 있다 (ADR 0018).

## 완료된 작업

- [x] 회신 1절(호출 경로별 매개변수 읽기): 고쳐졌다. `s1 order`(재현 도구)를 지우고 보통 검사 6m으로 바꿨다(ADR 0019). s1 검사 40개 모두 통과
- [x] 회신 3~6절 문구: CLI와 세션(`s1 replay`) 양쪽에서 회신에 적힌 그대로 나온다. 인자 없는 `trimLeft()`, `trimRight()` 동작 확인
- [x] 스파이크: build.zig의 commit 인자를 6a155275로(버전 문자열은 이 인자를 찍을 뿐 소스에서 읽지 않는다). s1의 누수 둘(errorSummary 복사본, replay와 order의 g_out) 고침. s2 빌드, 교차 빌드 x86_64-linux-gnu(s1, s2) 확인
- [x] 안내 두 판: 기준 줄, `trimLeft()`/`trimRight()`와 `lstrip`/`rstrip` 대응 추가, 오류 목록에서 이제 고치는 법을 말하는 두 줄(목록 리터럴 타입, `s.len`) 삭제. 영문판 19,814바이트. 코드 블록 11개 CLI와 세션 통과, 오류 목록 21줄 첫 줄 확인
- [x] 문서: 요청서(남은 것 push 하나와 확인을 마친 것), 검토 문서(7절 축소, 5절에 회차의 빌드 명시), 08, 00, deps, ADR 0017, 0019, TODO, MEMORY
- [x] 결정(스파이크 안, 위임): 능력이 반환 슬롯을 먼저 받는 규칙을 본체 추천에서 뺐다. `elif`, 보간 안의 보간, `and` 안의 풀기는 안내에 새로 넣지 않는다(컴파일러 문구가 말한다)

## 시도했으나 실패한 접근

- `rg`로 spike/s2/out/dev/<회차>/의 trace 찾기: .gitignore에 걸린다. `rg --no-ignore`를 쓴다.
- 비교를 시작한 뒤 s2나 안내를 고치기: 회차가 섞인다.
- `/usr/local/bin/cyber`로 안내 확인: 기준 빌드가 아니다. cyber 저장소에서 `zig build cli -Doptimize=ReleaseFast -Dcommit=<커밋> --prefix <스크래치>`로 만든다(저장소의 zig-out은 건드리지 않는다).
- 버전 문자열로 기준 빌드 확인하기: build.zig의 commit 인자가 찍힐 뿐이다. 실제 소스는 `git -C ../cyberscript log -1`과 `status`로 본다.
- macOS의 `ls -t`: eza 별칭이라 `/bin/ls`를 쓴다.
- 이전 세션들의 버린 대안은 ADR 0004~0016에 있다. 다시 제안하지 않는다.

## 남은 작업

정본은 docs/TODO.md다. 본체 구현은 페어 코딩이다 (CLAUDE.md, ADR 0012).

사용자가 정할 것:

- [ ] 요청서(push 하나)를 cyber에 전달. 이것이 본체 첫 단계의 선행 조건이다
- [ ] 회신 파일(docs/requests/cyber-m0-spike-response.md)을 지울지. 반영은 끝났다 (추적되지 않은 파일이라 두었다)
- [ ] CodeAct 비교를 6a155275와 새 안내로 다시 돌릴지(API 비용). 검토 문서 5절의 숫자는 5de6c83a로 잰 것이다. 다시 돌리면 고쳐진 문구가 작은 모델의 컴파일 오류(과제당 2.4)를 줄이는지 본다
- [ ] 안내가 4,000토큰 목표를 넘는다(약 6,600~6,800토큰). 목표를 바꿀지 안내를 줄일지 (검토 문서 8절)
- [ ] 검토 문서를 읽고 ADR 0017의 추천을 받거나 바꾼다. 그 뒤 spike/를 지운다

그 밖:

- [ ] push가 들어오면: deps와 스파이크를 URL과 해시로 고정, s1, 안내 탐침과 코드 블록을 다시, 문서를 새 빌드의 사실로 (검토 문서 11절)
- [ ] tars 게스트에서 기준 빌드로 스파이크 실행 (tars-linux 산출물 필요)
- [ ] 본체 첫 단계: 저장소 뼈대와 runtime 경계. 단계의 결정, 편집, 기능 표를 먼저 낸다
- [ ] cyber C1: json, toon. C2: regex, time. C3: 모듈 허용 표
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록
- [ ] M1~M6. 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5)

## 핵심 파일

- `docs/requests/cyber-m0-spike-requests.md` — 남은 것(push)과 6a155275에서 확인을 마친 것
- `docs/spikes/2026-11-14-m0-spikes-review.md` — 1절 요약, 3절 호스트 경계, 5절 비교(5de6c83a), 7절 cyber에 남은 것, 11절 다시 돌리는 법
- `docs/decisions/0017-m0-spike-findings.md`, `0019-fix-spike-defects-first.md`, `0020-docs-current-state-only.md`
- `docs/spec/08-cyber-implementation.md` — 기준 빌드의 사실
- `spike/s1/src/main.zig` — 검사 40개, `replay`, `spawn`. `spike/s1/src/inc_check.c`
- `spike/s2/src/vm.zig` — 검증, 실행, 승인, reset 알림

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg와 fd. 문서 코드 펜스는 ~~~. 결정은 docs/decisions에 `NNNN-slug.md`로 남기고 MEMORY.md에 한 줄.
2. 본체 구현은 페어 코딩이다. 구조에 관한 결정은 사용자가 정한다.
3. 문서는 지금 참인 것만 적는다 (ADR 0020).
4. 스파이크는 cyber 로컬 저장소를 경로로 받고, 경로 의존은 작업 트리를 그대로 빌드한다. 이번 확인 때 cyber 작업 트리는 6a155275에 깨끗했다(추적되지 않은 HANDOFF.md뿐). 돌리기 전에 `git -C /Users/dp/Repository/cyberscript status`와 `log -1`을 확인하고, 깨끗하지 않으면 `git archive <커밋>`으로 스크래치에 풀어 쓴다. cyber 저장소는 읽고 빌드만 한다. 편집은 사용자가 지시할 때다 (ADR 0013).
5. 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. 모델이 쓴 명령은 jail.zig의 샌드박스 안에서만 돈다.
