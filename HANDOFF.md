# HANDOFF: cyber 0.4.12로 스파이크 다시 돌림 (2026-11-16)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 본체 코드는 아직 없다. 버릴 스파이크 코드가 spike/에 있다.

이번 세션(2026-11-16): cyber가 0.4.12를 릴리스했다(태그 0.4.12 = 67a2735c, 설치된 CLI `Cyber 0.4.12 build-919-67a2735`). 스파이크 고정을 옮기고 s1, 안내, 문구 여섯을 CLI와 세션에서 확인하고 CodeAct 비교를 0.4.12로 모두 다시 돌렸다. 결함 둘을 찾아 요청서를 냈다. 둘 다 본체 첫 단계의 선행 조건이다(ADR 0019).

앞선 세션: 2026-11-14 0.4.11로 스파이크 판을 만들었다. 2026-11-15 pi 하네스를 검토해 ADR 0021과 명세에 반영했다.

## 현재 브랜치

`main`. 커밋과 push는 Claude에게 위임돼 있다 (ADR 0018).

## 완료된 작업

- [x] 고정: spike/s1, s2의 build.zig.zon `.url = git+https://github.com/soomtong/cyber?ref=0.4.12#67a2735c...`, `.hash = cyber-0.4.12-AW3fkAqEngAhLopP1tr-x8mnWp10OqG14QiB9PLuNEUp`. build.zig 의존 인자 `.build = "919", .commit = "67a2735"`. s1 검사 0은 문자열 전체를 비교
- [x] s1 40개 통과, s2 빌드, 교차 빌드 x86_64-linux-gnu(s1, s2). libcyber.a arm64 3.01 MB, x86_64 3.54 MB, 공개 `cl_` 140개(`cl_mod_bind_json/toon/regex/peg/time`이 늘었다)
- [x] 0.4.11 요청서(문구 여섯): 0.4.12의 CLI와 세션(`s1 replay`)에서 모두 요청한 꼴. 요청서를 지웠다
- [x] 새 표준 모듈: 0.4.12의 기본 로더가 json, toon, regex, peg, time을 싣는다. 안내가 가르치지 않으므로 s1 replay와 s2의 호스트 로더에서 막았다(`isNewStd`). time은 시계와 zoneinfo 파일을 능력 없이 읽는다
- [x] 안내 두 판: 기준 줄, 모듈 줄 둘, 오류 목록의 `let` 우회 한 줄(영문판 19,807바이트). 코드 블록 11개와 목록 항목 탐침이 CLI와 세션에서 통과
- [x] 비교 회차(out/0.4.12/): 0.4.11과 같은 구성. CodeAct 36개 중 33 통과, direct 6개 모두. 실패: DS 사고 없음 1회차 T2(코드 뒤 주석을 놓침), qwen3.8-flash 1회차 T1(`web` 대 `web.log`), DS effort high 2회차 T3(VM이 s2 프로세스째 죽음, 결함 (a)). 과제당 컴파일 오류 DS 0.33, DS high 0.33, flash 2.80, max 1.00. 51건 중 20건이 `print(!str)`. 옛 out/0.4.11은 지웠다(tsv는 git 이력에)
- [x] 결함 (a): `[]T`의 `remove`, `clear`, `insert`는 버퍼를 함께 쓰는 변수가 없으면 제자리에서 고친 버퍼를 돌려주고, 받는 변수는 옛 길이로 본다. `_ = out.remove(i)` 뒤 옛 `out`을 쓰면 str 원소에서 해제된 메모리를 읽는다. Debug libcyber에서 `retain dangling ptr`(vm.c COPY_STR). 0.4.11도 같다. 최소 재현은 요청서
- [x] 결함 (b): 0.4.12의 타입 선언 문구가 `let x = 1`에 `var let x = 1`을 권한다(`mut`, `val`, `auto`도). 안내가 한 줄로 우회
- [x] 요청서 docs/requests/cyber-0.4.12-spike-defects.md
- [x] 문서: 검토 문서(머리, 1, 2, 3.1, 3.4, 3.6, 5, 6, 7, 8, 9의 5와 17, 10, 11), 08, 00, deps, ADR 0017, 0019, TODO(C0, C1, C2), MEMORY, 참고 문서 한 줄
- [x] pi 하네스 검토 (ADR 0021, 2026-11-15)

## 시도했으나 실패한 접근

- 회차 도중에 안내를 고치기: s2가 실행마다 안내를 읽어 회차가 섞인다. 이번에 안내의 기준 줄을 고치지 않은 채 회차를 시작했다가 멈추고 다시 돌렸다. 회차 전에 안내를 먼저 확정한다.
- 릴리스 CLI를 태그에서 스크래치로 빌드하기: 사용자가 설치한 `/usr/local/bin/cyber`를 쓴다(`cyber version`으로 먼저 확인).
- `zig fetch --save=cyber <url>`로 기존 `.path` 의존을 덮기: `.path`에 URL을 넣고 해시를 빼 zon이 깨진다. `zig fetch <url>`로 해시만 받고 zon을 손으로 고친다.
- zsh에서 맞는 것이 없는 glob(`rm out/cmp-*`): 명령 전체가 멈춘다. 따로 지운다.
- `rg`로 spike/s2/out/<회차>/의 trace 찾기: .gitignore에 걸린다. `rg --no-ignore`를 쓴다.
- `s2 --help`, `s2 --version`: 인자가 아니라 질문으로 모델에 보낸다.
- 안내의 오류 문구를 CLI로만 확인하기: 모듈 로더가 달라 `use json`처럼 세션과 다른 문구가 있다. `s1 replay`로도 본다.
- macOS의 `ls -t`: eza 별칭이라 `/bin/ls`를 쓴다.
- 스파이크의 VM 충돌을 ReleaseFast 빌드의 기호로 읽기: 가까운 공개 기호(`_cl_mod_bind_regex` 등)가 찍혀 믿을 수 없다. s1 사본의 build.zig에서 `OptimizeMode.ReleaseFast`를 `Debug`로 바꿔 빌드하면 cyber 소스의 줄이 나온다(scratch에서, spike/는 건드리지 않음).
- 기본 로더를 차단 목록으로 두기: 0.4.12에서 모듈 다섯이 조용히 열렸다. 기준 빌드를 올릴 때 `use <모듈>`을 세션에서 확인한다.
- 이전 세션들의 버린 대안은 ADR 0004~0016에 있다. 다시 제안하지 않는다.

## 남은 작업

정본은 docs/TODO.md다. 본체 구현은 페어 코딩이다 (CLAUDE.md, ADR 0012).

사용자가 정할 것:

- [x] 요청서 docs/requests/cyber-0.4.12-spike-defects.md의 네 건을 cyber가 master에서 고쳤다(`85c95b1d` (c), `526146a9` (d), `4cf57841` (b), `40ae5b5a` (a), 기록 `54e61f48`, push 전). 회신과 tars-agent 확인은 요청서 끝. HEAD를 스크래치로 빌드해 CLI와 세션(s1 40/40, 크래시 스크립트, 안내 블록 12개)에서 확인했다
- [ ] cyber가 push하고 릴리스하면 스파이크 고정(URL, 해시, build.zig의 build와 commit, s1 검사 0)을 올리고 요청서를 지운다. 안내의 `let` 오류 줄을 지운다
- [ ] 안내를 cyber의 agent-guide.md와 호스트 덧붙임으로 만든다(ADR 0022). agent-guide.md의 호스트와 부딪히는 부분(CLI 절, 모듈 절, `os.write_file` 예, 예제 11)을 어떻게 다룰지 사용자가 정한다
- [ ] 새 표준 모듈: 안내에 json, regex(그리고 toon, peg)를 가르칠지, 안내 크기 결정과 함께. `time`을 허용할지와 능력 clock.now와의 관계 (08 문서, TODO C2)
- [ ] 본체가 VM 충돌로 프로세스가 끝나는 경우를 어떻게 다룰지 (검토 문서 9절 17: 세션 기록 먼저 쓰기와 재개, 또는 실행을 별도 프로세스로)
- [ ] `print(!str)`가 작은 모델의 가장 흔한 오류다. 능력의 모양이나 안내로 줄일지 (본체의 능력 설계 때)
- [ ] 안내가 4,000토큰 목표를 넘는다(첫 요청 입력 약 6,500토큰). 목표를 바꿀지 안내를 줄일지 (검토 문서 8절)
- [ ] 검토 문서를 읽고 ADR 0017의 추천을 받거나 바꾼다. 그 뒤 spike/를 지운다

그 밖:

- [ ] 본체 첫 단계: 저장소 뼈대와 runtime 경계. 선행 조건 둘(요청서 (a), (b))은 cyber master에서 고쳐졌고 릴리스를 기다린다. 릴리스되면 고정을 올리고 (a)의 스크립트(요청서의 재현)를 세션에서 돌려 확인하고 안내의 `let` 줄을 지운다. 단계의 결정, 편집, 기능 표를 먼저 낸다
- [ ] tars 게스트에서 기준 빌드로 스파이크 실행 (tars-linux 산출물 필요)
- [ ] cyber C1(json, toon), C2(regex, time)는 0.4.12에 있다. tars-agent 쪽 게이트(안내의 예제)가 남았다. C3: 모듈 허용 표
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록
- [ ] M1~M6. 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5)

## 핵심 파일

- `docs/spikes/2026-11-14-m0-spikes-review.md` — 스파이크 검토(0.4.12). 1절 요약, 3절 호스트 경계, 5절 비교, 7절 cyber에 남은 것, 11절 다시 돌리는 법
- `docs/requests/cyber-0.4.12-spike-defects.md` — 열린 요청(네 건, cyber master에서 고쳐졌고 릴리스 대기)
- `docs/decisions/0017-m0-spike-findings.md`, `0019-fix-spike-defects-first.md`, `0020-docs-current-state-only.md`
- `docs/decisions/0021-borrow-from-pi-harness.md` — pi에서 가져온 것과 버린 것
- `docs/spec/08-cyber-implementation.md` — 기준 빌드의 사실
- `spike/s1/build.zig.zon`, `spike/s2/build.zig.zon` — cyber 고정(태그 URL과 해시)
- `spike/s2/out/0.4.12/` — 비교 회차 원자료. 프로세스가 죽은 과제는 `dsflash-codeact-r2/cmp-ds-anth-codeact-t3.*`
- `spike/s1/src/main.zig` — 검사 40개, `replay`, `spawn`. `spike/s2/src/vm.zig` — 검증, 실행, 승인, reset 알림

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg와 fd. 문서 코드 펜스는 ~~~. 결정은 docs/decisions에 `NNNN-slug.md`로 남기고 MEMORY.md에 한 줄.
2. 본체 구현은 페어 코딩이다. 구조에 관한 결정은 사용자가 정한다.
3. 문서는 지금 참인 것만 적는다 (ADR 0020).
4. 스파이크는 cyber를 URL과 해시로 고정해 받는다(build.zig.zon). 로컬 cyber 저장소의 상태와 상관없다. 문구를 CLI로 볼 때만 cyber 저장소에서 같은 커밋을 스크래치로 빌드한다. cyber 저장소는 읽고 빌드만 한다. 편집은 사용자가 지시할 때다 (ADR 0013).
5. 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. 모델이 쓴 명령은 jail.zig의 샌드박스 안에서만 돈다.
