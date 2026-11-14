# HANDOFF: cyber 9bf8a8e4를 URL과 해시로 고정함, M0 요청 모두 닫힘 (2026-11-14)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 본체 코드는 아직 없다. 버릴 스파이크 코드가 spike/에 있다.

이번 세션: cyber가 M0 요청을 모두 닫고 9bf8a8e4까지 원격 master에 push했다. 회신을 CLI와 세션(`s1 replay`)에서 확인했고 모두 회신대로였다. 스파이크의 cyber 의존을 URL과 해시로 고정하고(본체 첫 단계의 선행 조건, ADR 0019), 문서를 9bf8a8e4로 고쳤다. 반영이 끝난 요청서와 회신 파일은 지웠다(ADR 0020). docs/requests/는 비었다.

## 현재 브랜치

`main`. 커밋과 push는 Claude에게 위임돼 있다 (ADR 0018).

## 완료된 작업

- [x] 9bf8a8e4 확인: `a[i] = v`의 값 불일치가 ``An element of `[]int` must be `int`, got `str`.``(`Map`, `?int`, `!int` 포함). 앞 회신의 문구 다섯(`#` 주석, `for f |{...}|:`, 튜플 반환, 홑따옴표 줄바꿈, 인덱스와 경계의 `?int`)도 그대로. CLI와 세션 같다. `xs[0] = 'a'`는 오류가 아니라 97(언어 규칙)
- [x] 고정: spike/s1, s2의 build.zig.zon `.url = git+https://github.com/soomtong/cyber#9bf8a8e4...`, `.hash = cyber-0.4.10-AW3fkJeBjQCO2jLuKlxiR4KZ2398YcbH8N7ETi0cl_4z`. build.zig commit 인자와 s1 검사 0도 9bf8a8e4. s1 40개 통과, s2 빌드, 교차 빌드 x86_64-linux-gnu(s1, s2). libcyber.a arm64 2.54 MB, 공개 `cl_` 135개
- [x] 안내: 기준 줄 9bf8a8e4, 오류 목록의 `use json` 줄은 세션 문구(`Failed to load module: json`). 코드 블록 11개 CLI와 세션 통과
- [x] 문서: 검토 문서(기준 줄, 1, 3.1, 5.1 표는 지금 문구 기준, 7절 "없다", 8, 11절), 08(C0 줄 삭제), 00, deps, ADR 0017, 0019, TODO(C0 닫힘), MEMORY. 요청서와 회신 파일 삭제
- [x] CodeAct 비교(6a155275 회차, 다시 돌리지 않음): DeepSeek-V4.1-Flash 사고 없음 3회와 effort high 3회, qwen3.8-flash 5회, qwen3.8-max 1회, 과제 36개 모두 통과. 컴파일 오류 34건 중 18건이 `print(!str)`. 원자료 spike/s2/out/dev/, 앞 빌드는 out/dev-5de6c83a/. 검토 문서 5절
- [x] 모델 이름: s2는 `deepseek-flash`(기본 effort high로 사고), OpenRouter는 `deepseek/deepseek-v4.1-flash-1017`. 옛 별칭 `deepseek-chat`은 사고하지 않는다. `output_config.effort`가 받아들여지는지는 미확인
- [x] 결정(스파이크 안, 위임): 능력이 반환 슬롯을 먼저 받는 규칙은 본체 추천에서 뺐다. 컴파일러 문구가 고치는 법을 말하는 실수는 안내에 넣지 않는다

## 시도했으나 실패한 접근

- `zig fetch --save=cyber <url>`로 기존 `.path` 의존을 덮기: `.path`에 URL을 넣고 해시를 빼 zon이 깨진다. `zig fetch <url>`로 해시만 받고 zon을 손으로 고친다.
- `rg`로 spike/s2/out/dev/<회차>/의 trace 찾기: .gitignore에 걸린다. `rg --no-ignore`를 쓴다.
- 비교를 시작한 뒤 s2나 안내를 고치기: 회차가 섞인다.
- `s2 --help`, `s2 --version`: 인자가 아니라 질문으로 모델에 보낸다.
- `/usr/local/bin/cyber`로 안내 확인: 기준 빌드가 아니다. cyber 저장소에서 `zig build cli -Doptimize=ReleaseFast -Dcommit=<커밋> --prefix <스크래치>`로 만든다(저장소의 zig-out은 건드리지 않는다).
- 버전 문자열로 기준 빌드 확인하기: build.zig의 commit 인자가 찍힐 뿐이다. 실제 소스는 zon의 URL이 정한다.
- 안내의 오류 문구를 CLI로만 확인하기: 모듈 로더가 달라 `use json`처럼 세션과 다른 문구가 있다. `s1 replay`로도 본다.
- macOS의 `ls -t`: eza 별칭이라 `/bin/ls`를 쓴다.
- 이전 세션들의 버린 대안은 ADR 0004~0016에 있다. 다시 제안하지 않는다.

## 남은 작업

정본은 docs/TODO.md다. 본체 구현은 페어 코딩이다 (CLAUDE.md, ADR 0012).

사용자가 정할 것:

- [ ] `print(!str)`가 작은 모델의 가장 흔한 오류다. 능력의 모양이나 안내로 줄일지 (본체의 능력 설계 때)
- [ ] 안내가 4,000토큰 목표를 넘는다(약 6,600~6,800토큰). 목표를 바꿀지 안내를 줄일지 (검토 문서 8절)
- [ ] 검토 문서를 읽고 ADR 0017의 추천을 받거나 바꾼다. 그 뒤 spike/를 지운다

그 밖:

- [ ] 본체 첫 단계: 저장소 뼈대와 runtime 경계. 선행 조건은 닫혔다. 단계의 결정, 편집, 기능 표를 먼저 낸다
- [ ] cyber 릴리스(0.4.11 등)나 태그가 정해지면 고정을 옮긴다
- [ ] tars 게스트에서 기준 빌드로 스파이크 실행 (tars-linux 산출물 필요)
- [ ] cyber C1: json, toon. C2: regex, time. C3: 모듈 허용 표
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록
- [ ] M1~M6. 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5)

## 핵심 파일

- `docs/spikes/2026-11-14-m0-spikes-review.md` — 1절 요약, 3절 호스트 경계, 5절 비교(6a155275 회차, 앞 빌드와 견줌), 7절 cyber에 남은 것(없다), 11절 다시 돌리는 법
- `docs/decisions/0017-m0-spike-findings.md`, `0019-fix-spike-defects-first.md`, `0020-docs-current-state-only.md`
- `docs/spec/08-cyber-implementation.md` — 기준 빌드의 사실
- `spike/s1/build.zig.zon`, `spike/s2/build.zig.zon` — cyber 고정(URL과 해시)
- `spike/s1/src/main.zig` — 검사 40개, `replay`, `spawn`. `spike/s1/src/inc_check.c`
- `spike/s2/src/vm.zig` — 검증, 실행, 승인, reset 알림

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg와 fd. 문서 코드 펜스는 ~~~. 결정은 docs/decisions에 `NNNN-slug.md`로 남기고 MEMORY.md에 한 줄.
2. 본체 구현은 페어 코딩이다. 구조에 관한 결정은 사용자가 정한다.
3. 문서는 지금 참인 것만 적는다 (ADR 0020).
4. 스파이크는 cyber를 URL과 해시로 고정해 받는다(build.zig.zon). 로컬 cyber 저장소의 상태와 상관없다. 문구를 CLI로 볼 때만 cyber 저장소에서 같은 커밋을 스크래치로 빌드한다. cyber 저장소는 읽고 빌드만 한다. 편집은 사용자가 지시할 때다 (ADR 0013).
5. 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. 모델이 쓴 명령은 jail.zig의 샌드박스 안에서만 돈다.
