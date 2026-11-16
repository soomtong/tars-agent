# HANDOFF: cyber latest dev 0.4.13-DEV로 고정을 옮김 (2026-11-16)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 본체 코드는 아직 없다. 버릴 스파이크 코드가 spike/에 있다.

이번 세션(2026-11-16):
- cyber가 0.4.12 요청서의 네 건을 고쳤다.
- 0.4.13 릴리스는 빌드가 실패했다(macOS arm64 러너). 그래서 사용자 지시로 latest dev 프리릴리스 `Cyber 0.4.13-DEV build-941-8a89231`(커밋 8a892310, 태그 0.4.13과 같은 커밋)에 고정했다. 내용은 0.4.13과 같다.
- s1, 안내, 네 건을 CLI와 세션에서 확인했다. 새로 찾은 둘로 요청서를 냈다.
- CodeAct 비교는 다시 돌리지 않았다(비교 수치는 0.4.12 회차).
- 안내의 정본을 cyber의 docs/agent-guide.md로 정했다(ADR 0022). 진행은 천천히, 제약보다 열어 두고 본다(사용자 지시).

앞선 세션: 2026-11-14 0.4.11로 스파이크 판을 만들었다. 2026-11-15 pi 하네스를 검토해 ADR 0021과 명세에 반영했다. 2026-11-16 앞부분에 0.4.12로 비교 회차를 돌렸다.

## 현재 브랜치

`main`. 커밋과 push는 Claude에게 위임돼 있다 (ADR 0018).

## 완료된 작업

- [x] 고정: spike/s1, s2의 build.zig.zon.
  - `.url = git+https://github.com/soomtong/cyber#8a892310554bba26061a5613784a20e930971275`
  - `.hash = cyber-0.4.13-AW3fkAQQowDHsJ54gaXZmRQLy97LTg3pDL1NKWoRadp0`
  - build.zig 의존 인자는 `.dev = true, .build = "941", .commit = "8a89231"`이다. s1 검사 0이 `Cyber 0.4.13-DEV build-941-8a89231` 전체를 비교한다.
- [x] s1 40개 통과, s2 빌드, 교차 빌드 x86_64-linux-gnu(s1, s2 각 23초). libcyber.a는 arm64 2.99 MB, x86_64 3.55 MB이고 공개 `cl_`는 140개다.
- [x] 0.4.12 요청서의 네 건이 CLI와 세션에서 회신대로다.
  - `Slice` 크기 바꾸기는 받는 변수를 그대로 두고, 결과를 버리면 컴파일 오류다.
  - `let`, `mut`, `val`, `auto` 문구가 고쳐졌다.
  - `os.read_file`이 str을 돌려준다.
  - 패키지에 docs/agent-guide.md가 들어 있다.

  0.4.12 회차에서 s2를 죽인 스크립트는 고치는 법을 말하는 컴파일 오류로 멈춘다. 요청서는 지웠다.
- [x] 안내 두 판: 기준 줄을 고쳤다. `[]T`의 크기 바꾸기 줄을 가이드에 맞췄다. `let` 우회 줄은 지웠다(영문판 19,726바이트). 코드 블록 22개와 오류 목록의 첫 줄이 dev CLI와 세션에서 맞다.
- [x] 새 요청서 docs/requests/cyber-0.4.13-dev-findings.md:
  - (a) `let x := 1`에 `var x := 1 = value`를 권한다.
  - (b) 세션에서 스크립트 마지막 줄의 `out.remove(i)`는 마지막 표현식 값이라 오류가 없고 `out`은 그대로다.

  둘 다 본체 첫 단계 전에 닫는다(ADR 0019).
- [x] ADR 0022: 안내의 정본은 cyber docs/agent-guide.md, tars-agent는 호스트 덧붙임만. 가이드와 스파이크 세션이 다른 곳을 "열린 것"에 적었다.
- [x] 문서: 검토 문서, 08, 00, deps, ADR 0017, 0019, 0022, TODO, MEMORY, 참고 문서 한 줄

## 시도했으나 실패한 접근

- 회차 도중에 안내를 고치기: s2가 실행마다 안내를 읽어 회차가 섞인다. 회차 전에 안내를 먼저 확정한다.
- 릴리스 CLI를 태그에서 스크래치로 빌드하기: 릴리스면 사용자가 설치한 `/usr/local/bin/cyber`를 쓴다. latest dev면 프리릴리스의 CLI를 받는다(`gh release download latest -R soomtong/cyber -p cyber-macos-arm64.tar.gz`, 스크래치에). 설치된 CLI는 지금 0.4.12다.
- `zig fetch --save=cyber <url>`로 기존 `.path` 의존을 덮기: `.path`에 URL을 넣고 해시를 빼 zon이 깨진다. `zig fetch <url>`로 해시만 받고 zon을 손으로 고친다.
- s1 사본의 zon을 정규식으로 `.path`로 바꾸기: `translate_c` 의존까지 바뀐다. cyber 항목만 고친다.
- zsh에서 맞는 것이 없는 glob(`rm out/cmp-*`): 명령 전체가 멈춘다. 따로 지운다.
- `rg`로 spike/s2/out/<회차>/의 trace 찾기: .gitignore에 걸린다. `rg --no-ignore`를 쓴다.
- `s2 --help`, `s2 --version`: 인자가 아니라 질문으로 모델에 보낸다.
- `s1 replay`의 종료 코드로 판정하기: 컴파일 오류에도 0이다. 출력의 `validate=COMPILE`을 본다. 여러 run은 한 파일 안에서 `=====` 줄로 나눈다.
- 안내의 오류 문구를 CLI로만 확인하기: 모듈 로더와 마지막 표현식 값 처리가 달라 세션과 다른 결과가 있다. `s1 replay`로도 본다.
- macOS의 `ls -t`: eza 별칭이라 `/bin/ls`를 쓴다.
- 스파이크의 VM 충돌을 ReleaseFast 빌드의 기호로 읽기: 가까운 공개 기호가 찍혀 믿을 수 없다. s1 사본에서 Debug로 빌드한다(scratch에서, spike/는 건드리지 않음).
- 이전 세션들의 버린 대안은 ADR 0004~0016에 있다. 다시 제안하지 않는다.

## 남은 작업

정본은 docs/TODO.md다. 본체 구현은 페어 코딩이다 (CLAUDE.md, ADR 0012).

사용자가 정할 것:

- [ ] 요청서 docs/requests/cyber-0.4.13-dev-findings.md를 cyber에 전달
- [ ] 안내를 cyber의 agent-guide.md와 호스트 덧붙임으로 언제, 어떤 모양으로 모을지(ADR 0022 "열린 것"). 가이드와 스파이크 세션이 다른 곳은 대부분 tars-agent의 선택(모듈 막기, fiber 금지)이거나 실행 환경의 차이(`os`, CLI)다. 임베딩 호스트에 관한 한 줄을 가이드에 요청할지
- [ ] 새 표준 모듈: 막지 않고 열어 둘지, `time`과 능력 clock.now의 관계 (08 문서, TODO C2)
- [ ] CodeAct 비교를 기준 빌드로 다시 돌릴지 (지금 수치는 0.4.12 회차)
- [ ] 본체가 VM 충돌로 프로세스가 끝나는 경우를 어떻게 다룰지 (검토 문서 9절 17)
- [ ] `print(!str)`가 작은 모델의 가장 흔한 오류다. 능력의 모양이나 안내로 줄일지 (본체의 능력 설계 때)
- [ ] 안내가 4,000토큰 목표를 넘는다. 목표를 바꿀지 안내를 줄일지 (검토 문서 8절)
- [ ] 검토 문서를 읽고 ADR 0017의 추천을 받거나 바꾼다. 그 뒤 spike/를 지운다

그 밖:

- [ ] 본체 첫 단계: 저장소 뼈대와 runtime 경계. 선행 조건은 새 요청서의 둘. 단계의 결정, 편집, 기능 표를 먼저 낸다
- [ ] 0.4.13 릴리스가 나오면 고정을 태그로 옮길지 본다(같은 커밋이면 해시도 같다)
- [ ] tars 게스트에서 기준 빌드로 스파이크 실행 (tars-linux 산출물 필요)
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록
- [ ] M1~M6. 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5)

## 핵심 파일

- `docs/spikes/2026-11-14-m0-spikes-review.md` — 스파이크 검토. 1절 요약, 3절 호스트 경계, 5절 비교(0.4.12 회차), 7절 cyber에 남은 것, 11절 다시 돌리는 법
- `docs/requests/cyber-0.4.13-dev-findings.md` — 열린 요청(둘)
- `docs/decisions/0022-guide-from-cyber-agent-guide.md` — 안내의 정본과 열린 것
- `docs/decisions/0017-m0-spike-findings.md`, `0019-fix-spike-defects-first.md`, `0020-docs-current-state-only.md`, `0021-borrow-from-pi-harness.md`
- `docs/spec/08-cyber-implementation.md` — 기준 빌드의 사실
- `spike/s1/build.zig.zon`, `spike/s2/build.zig.zon` — cyber 고정(커밋 URL과 해시)
- `spike/s2/out/0.4.12/` — 비교 회차 원자료
- `spike/s1/src/main.zig` — 검사 40개, `replay`, `spawn`. `spike/s2/src/vm.zig` — 검증, 실행, 승인, reset 알림

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md):
   - 응답은 한국어로 한다.
   - 문서와 주석에 ** 강조를 쓰지 않는다.
   - 커밋은 접두사 없이 첫 글자 대문자, 80자 이내로 쓴다.
   - 검색은 rg와 fd로 한다. 문서 코드 펜스는 ~~~다.
   - 결정은 docs/decisions에 `NNNN-slug.md`로 남기고 MEMORY.md에 한 줄을 더한다.
2. 본체 구현은 페어 코딩이다. 구조에 관한 결정은 사용자가 정한다. 지금은 제약을 늘리기보다 열어 두고 살펴보는 단계다.
3. 문서는 지금 참인 것만 적는다 (ADR 0020).
4. 스파이크는 cyber를 URL과 해시로 고정해 받는다(build.zig.zon). 로컬 cyber 저장소의 상태와 상관없다. cyber 저장소는 읽고 빌드만 한다. 편집은 사용자가 지시할 때다 (ADR 0013).
5. 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. 모델이 쓴 명령은 jail.zig의 샌드박스 안에서만 돈다.
