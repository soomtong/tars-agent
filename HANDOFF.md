# HANDOFF: fx 검토와 ADR 0030 반영 (2026-11-20)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 본체 코드는 아직 없다. 버릴 스파이크 코드가 spike/에 있다.

이번 세션(2026-11-20):
- vercel-labs/fx(`5960bc93d`, 로컬 `~/Repository/_study/fx-agent`, Zig 0.17.1, Apache-2.0)를 검토했다. "minimal"이지만 Zig 약 87만 줄이다. 도구는 JSON 도구 호출이고 auto 모드는 모델 검토자에 기댄다. 검토 문서: docs/references/2026-11-20-fx-agent-review.md (참고할 곳 표, 배울 방법 9개, 차용 후보 A1~A13과 B1~B7, 가져오지 않을 것, 라이선스, 추천 순서).
- 사용자가 추천 순서를 받았다. ADR 0030에 기록했다.
  - 지금 받은 것: 세션 줄 머리(`v`, `seq`, `ts`, `type` 순서 고정, 끝에 `crc` CRC32C, 줄 4 MiB), 쓰기와 복구(write 한 번에 줄 하나, 턴을 닫는 줄 뒤에만 fsync, 임시 이름 뒤 rename, 찢긴 꼬리 자르기, 중간 손상은 재개 거부), 잠금(`<세션 ID>/lock` flock, 2초 재시도 뒤 pid를 말하고 거부), 헤드리스 json 객체(spec 06), Zig 0.17.1 지뢰(deps.md).
  - 사용자 인터럽트의 종료 코드는 130이다(사용자가 Claude에게 맡김).
  - 정할 때 함께 볼 것: 이벤트 타입의 도구 카드 수명과 결과 종류, 열린 카드 닫기, 승인 요청의 출처(A9). 능력 표의 reads_only, irreversible 술어(A10). 둘 다 사용자 편집 대상이다.
  - 단계에서 다시 볼 것: A11 복구 순수 모듈(M1 provider), A8 steering 경계(M3), A6, A7 컴팩션 원문 유지와 접은 기록 다시 열기(M4), A5 크래시 뒤 스스로 이어 가기, B3 terminalSafe, B4 경계 검사 스크립트(M1 뼈대), B5~B7 fuzz, 크기와 시작 시간 예산, TLA+.
- 고친 문서: ADR 0030(새), spec 06, 07, deps.md, TODO(M1 caps, provider, session, headless와 M3 steering 줄), ADR 0008 결과 한 줄, MEMORY 두 줄.
- deps.md의 Zig 지뢰는 fx 메모에서 옮긴 것이고 우리 빌드에서 재현하지 않았다. 해당 코드를 쓸 때 재현하고 고친다.

앞선 세션(2026-11-18): cyber 0.4.15로 옮김.
- cyber 0.4.15(태그 `93a9ca4f`, 설치된 `/usr/local/bin/cyber`는 `Cyber 0.4.15 build-969-93a9ca4`)로 두 스파이크의 의존을 올렸다. 깨지는 변경은 `[]T`의 크기 바꾸기가 제자리가 된 것(`xs.append(v)`, 새 목록은 `appended`, `+`)이고, 안내 두 판은 전 세션에 먼저 고쳐 두었다.
- `test` 모듈을 연다(ADR 0028, 사용자 결정). 순수 Cyber 검사 함수이고 정본 안내가 `use test`를 가르친다. s1 검사 7a4, 로더 두 곳.
- 0.4.15 태그가 다시 릴리스됐다(`c13a207f` → `93a9ca4f`, cyber-lsp가 구문 오류를 모두 진단). 같은 태그를 다시 받았다(zig fetch가 새 커밋과 해시를 적는다). 새 검사 6n: 세션 검증에서 `cl_vm_set_error_recovery`가 구문 오류를 모두, 본문마다 하나씩 돌려주고 세션이 남는다(검토 문서 9절 13).
- s1 47개 통과. 새 검사 7i가 `cl_vm_symbol_hints`(0.4.15에 더해진 C API)를 본다: 검증 뒤 쓰지 않는 지역과 `use`, 추론 타입을 받는다. 실패한 검증 뒤에는 unused가 없다. 세션의 최상위 지역도 unused로 나오므로 호스트가 걸러야 한다.
- 안내 두 판과 agent-guide.md의 코드 블록 34개: CLI와 세션 모두 통과(`test`를 연 뒤). 제자리 `Slice` 문구, 전역 take-and-restore 문구, `os` 옛 꼴 문구(CLI)를 탐침으로 확인했다.
- `cyber-lsp`를 stdio(JSON-RPC)로 붙여 unused Warning, quick fix(`_` 붙이기, `use` 지우기, `file_exists`, `out.append(3)`), inlay hint(추론 타입, `waits for fibers`), `scope` 출구 Information, `--|` 문서 주석 hover를 확인했다. 구문 오류는 전부 진단하고, 구문 오류가 없으면 본문(main 블록, 함수)마다 첫 오류 하나를 낸다.
- s2 빌드, x86_64-linux-gnu 교차 빌드(s1, s2). libcyber.a arm64 3,058,056바이트, x86_64 3,620,340바이트, 공개 `cl_` 함수 142개. 새 표준 모듈은 없다.
- 문서: 검토 문서(3.1, 3.5, 3.6, 6, 7, 8절, 9절 추천 5, 13, 18), 03, 05, 08, deps, ADR 0017, 0019, 0022, 0023, 0025, 0026, 0028, 안내 기준 줄, TODO.
- CodeAct 비교를 0.4.15로 다시 돌렸다(0.4.12와 같은 표, 회차 14개, 과제 42개). 41개 통과(실패 하나는 `project/src/a.py`로 쓴 과제 해석), 죽은 실행 없음, 컴파일 오류 51건에서 41건. 제자리 `append`는 run 206개 중 29개가 썼고 그 꼴의 오류는 `^[]str`에 쓴 하나뿐이다. 새로 연 모듈은 한 번도 쓰이지 않았다. 집계 스크립트는 0.4.12 원자료로 5절의 표가 그대로 나오는 것을 먼저 확인했다. 검토 문서 5.3, 원자료 spike/s2/out/0.4.15/.
- 고치는 법을 말하지 않는 문구 셋으로 cyber에 요청서를 냈다: docs/requests/cyber-0.4.15-messages-from-codeact-round.md(`!T`가 아닌 함수의 `!`가 `Result`를 말함, `idx.!`가 `Expected ident.`, `^[]str`의 `append`가 `&>[]str`를 드러냄).

앞선 세션(2026-11-16~17):
- cyber가 0.4.12 요청서의 네 건을 고쳤다.
- cyber 의존은 커밋에 묶지 않고 가장 새 빌드를 따른다(사용자 지시, ADR 0023). 그때는 릴리스 0.4.14(a2b33655)였다. extern 수정, resolver 수정, 패키지의 `docs/api.json`, x86_64 AVX2 `str.index` 수정, 표준 라이브러리 이름의 snake_case 통일, 새 `path` 모듈이 들어 있다.
- 0.4.13-DEV에서 찾은 두 건(`let x := 1`의 문구, 세션 마지막 줄의 버린 `Slice` 결과)이 0.4.13에서 고쳐졌다. CLI와 세션에서 확인하고 요청서를 지웠다.
- 모듈: time(ADR 0024, clock.now는 뺐다), json, toon, regex, peg(ADR 0025), path(ADR 0027)를 연다. 세계에 닿는 일은 능력으로만 하고 os는 열지 않는다(ADR 0026, 사용자 결정 A). 로더는 허용 목록 core, meta, c, math, json, toon, regex, peg, time, path이다(meta와 c는 의존). 2026-11-18에 test를 더했다(ADR 0028).
- 0.4.13에서 찾은 결함(c가 실리기 전의 `#[extern]` 함수가 검증 중에 프로세스를 죽인다)을 cyber가 0.4.14에서 컴파일 오류로 고쳤다. s1 검사 7h로 확인하고 요청서를 지웠다. 본체 첫 단계 전에 닫을 결함은 없다(ADR 0019).
- cyber 회신: 0.4.14부터 호스트 resolver가 소스의 use만 받는다. 스크립트의 `use c`, `use meta`만 막는 길이다. 쓸지는 본체 runtime 단계에서 정한다(ADR 0026, 05 1층).
- s1, 안내, 네 건을 CLI와 세션에서 확인했다. 새로 찾은 둘로 요청서를 냈다.
- CodeAct 비교는 다시 돌리지 않았다(비교 수치는 0.4.12 회차).
- 안내의 정본을 cyber의 docs/agent-guide.md로 정했다(ADR 0022). 진행은 천천히, 제약보다 열어 두고 본다(사용자 지시).

앞선 세션: 2026-11-14 0.4.11로 스파이크 판을 만들었다. 2026-11-15 pi 하네스를 검토해 ADR 0021과 명세에 반영했다. 2026-11-16 앞부분에 0.4.12로 비교 회차를 돌렸다.

## 현재 브랜치

`main`. 커밋과 push는 Claude에게 위임돼 있다 (ADR 0018).

## 완료된 작업

- [x] 의존: spike/s1, s2의 build.zig.zon은 `zig fetch --save=cyber "git+https://github.com/soomtong/cyber#0.4.15"`로 넣는다(`?ref=0.4.15#<커밋>`과 해시가 적힌다).
  - build.zig 의존 인자는 `.dev = false`뿐이다(릴리스). 버전 문자열은 `Cyber 0.4.15 build-0-local`이고 s1 검사 0은 `Cyber `로 시작하는지만 본다.
- [x] s1 47개 통과(0.4.15, `93a9ca4f`), s2 빌드, 교차 빌드 x86_64-linux-gnu(s1, s2).
- [x] 0.4.15로 옮김(2026-11-18): 위 "이번 세션"과 TODO의 해당 줄.
- [x] 0.4.14로 옮김(2026-11-17 저녁): 두 스파이크의 의존을 릴리스 태그로, `dev = false`. s1 43개, 안내 두 판과 agent-guide.md의 코드 블록 34개(CLI 전부, 세션은 `use test` 블록만 로더가 막음), 새 이름(`trim_left`, `trim_right`, `last_index`) 탐침, s2 빌드, x86_64 교차 빌드를 확인했다. 옛 camelCase 이름은 `Did you mean ...?` 컴파일 오류다. 안내와 04, ADR 0026의 이름을 snake_case로 고쳤다
- [x] 0.4.12 요청서의 네 건이 CLI와 세션에서 회신대로다.
  - `Slice` 크기 바꾸기는 받는 변수를 그대로 두고, 결과를 버리면 컴파일 오류다.
  - `let`, `mut`, `val`, `auto` 문구가 고쳐졌다.
  - `os.read_file`이 str을 돌려준다.
  - 패키지에 docs/agent-guide.md가 들어 있다.

  0.4.12 회차에서 s2를 죽인 스크립트는 고치는 법을 말하는 컴파일 오류로 멈춘다. 요청서는 지웠다.
- [x] 안내 두 판: 기준 줄을 고쳤다. `[]T`의 크기 바꾸기 줄을 가이드에 맞췄다. `let` 우회 줄은 지웠다(영문판 19,538바이트). 코드 블록 22개가 0.4.13 CLI와 세션에서 통과한다. agent-guide.md의 12개도 CLI에서 통과하고, 세션에서는 `use test` 블록만 로더가 막는다. `latest` 세션에서 34개를 다시 돌려 같은 결과다.
- [x] 0.4.13-DEV 요청 두 건이 0.4.13에서 닫혔다. `let x := 1`은 ``Declare with `x := 1`.``을 말하고, 세션의 마지막 줄에서도 버린 `Slice` 크기 바꾸기 결과는 컴파일 오류다. 요청서는 지웠다.
- [x] ADR 0022: 안내의 정본은 cyber docs/agent-guide.md, tars-agent는 호스트 덧붙임만. 가이드와 스파이크 세션이 다른 곳을 "열린 것"에 적었다.
- [x] 문서: 검토 문서, 08, 00, deps, ADR 0017, 0019, 0022, TODO, MEMORY, 참고 문서 한 줄

## 시도했으나 실패한 접근

- fx를 이름대로 작은 저장소로 보고 한 번에 읽기: 87만 줄이다. 영역(루프와 복구, 권한과 도구, 프로토콜, 시험과 Zig 관행)으로 나눠 읽었다. fx의 파일을 베끼지 않는다(Apache-2.0, ADR 0003). 재구현한다.
- 회차 도중에 안내를 고치기: s2가 실행마다 안내를 읽어 회차가 섞인다. 회차 전에 안내를 먼저 확정한다.
- 릴리스 CLI를 태그에서 스크래치로 빌드하기: 릴리스면 사용자가 설치한 `/usr/local/bin/cyber`를 쓴다. latest dev면 프리릴리스의 CLI를 받는다(`gh release download latest -R soomtong/cyber -p cyber-macos-arm64.tar.gz`, 스크래치에). 설치된 CLI는 지금 0.4.15다.
- `latest` 태그만 따르기: 릴리스 빌드만 돌고 `latest` 프리릴리스가 갱신되지 않는 때가 있다(0.4.13 때). 가장 새 태그를 본다(ADR 0023).
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

- [ ] 안내를 cyber의 agent-guide.md와 호스트 덧붙임으로 언제, 어떤 모양으로 모을지(ADR 0022 "열린 것"). 가이드와 스파이크 세션이 다른 곳은 대부분 tars-agent의 선택(모듈 막기, fiber 금지)이거나 실행 환경의 차이(`os`, CLI)다. 가이드에 임베딩 호스트 줄이 들어갔다(호스트의 지시가 앞선다, 거부된 모듈의 문구). 요청서는 닫았다
- [x] 표준 모듈 다섯을 연다: time(ADR 0024, clock.now는 뺐다), json, toon, regex, peg(ADR 0025). 스파이크 로더는 허용 목록이다(ADR 0026)
- [x] `path` 모듈을 연다(ADR 0027, 사용자 결정). s1 검사 7a3, 44개 통과
- [ ] os 대신 능력으로 넓힐 후보(fs.mkdir, fs.remove, fs.copy, fs.move, env.get)를 언제 정할지 (04, ADR 0026)
- [ ] 여섯 모듈의 예제를 안내에 넣을지 (TODO C1, C2의 남은 게이트)
- [ ] 모듈 API(패키지의 `docs/api.json`, 여섯 모듈 약 7 KB)를 프롬프트에 둘지 help(name)으로 꺼내게 할지 (본체 능력 설계 때)
- [x] CodeAct 비교를 0.4.15로 다시 돌렸다 (검토 문서 5.3)
- [ ] cyber 요청서(docs/requests/cyber-0.4.15-messages-from-codeact-round.md)의 회신 확인
- [ ] 본체가 VM 충돌로 프로세스가 끝나는 경우를 어떻게 다룰지 (검토 문서 9절 17)
- [ ] 검증 뒤 `cl_vm_symbol_hints`의 쓰지 않는 함수 안 지역을 모델에게 넘길지 (검토 문서 9절 18, 평가 때)
- [ ] `print(!str)`가 작은 모델의 가장 흔한 오류다. 능력의 모양이나 안내로 줄일지 (본체의 능력 설계 때)
- [ ] 안내가 4,000토큰 목표를 넘는다. 목표를 바꿀지 안내를 줄일지 (검토 문서 8절)
- [ ] 검토 문서를 읽고 ADR 0017의 추천을 받거나 바꾼다. 그 뒤 spike/를 지운다

그 밖:

- [ ] 이벤트 타입을 편집할 때 ADR 0030의 6(도구 카드 수명, 결과 종류, 열린 카드 닫기, 승인 요청의 출처)을 사용자 결정 거리로 올린다. 비교 자료는 fx 검토 문서 1절 첫 줄
- [ ] 능력 표를 편집할 때 ADR 0030의 7(reads_only, irreversible 술어)을 사용자 결정 거리로 올린다
- [ ] deps.md의 Zig 0.17.1 지뢰를 해당 코드(provider 스트림, 줄 편집기, 테스트 allocator)를 쓸 때 재현하고 고친다
- [ ] 본체 첫 단계: 저장소 뼈대와 runtime 경계. 선행 조건으로 남은 결함은 없다(ADR 0019). 단계의 결정, 편집, 기능 표를 먼저 낸다
- [ ] tars 게스트에서 기준 빌드로 스파이크 실행 (tars-linux 산출물 필요)
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록
- [ ] M1~M6. 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5)

## 핵심 파일

- `docs/references/2026-11-20-fx-agent-review.md` — fx 검토. 1절 참고할 곳(fx 파일:줄), 3절 차용 후보, 6절 추천 순서
- `docs/decisions/0030-borrow-from-fx.md` — 받은 것, 정할 때 볼 것, 가져오지 않을 것
- `docs/spec/07-observability.md` — 세션 파일의 줄 머리, 쓰기와 복구, 잠금
- `docs/spec/06-mcp-and-context.md` — 헤드리스 json 객체와 종료 코드(0, 1, 2, 3, 130)
- `docs/deps.md` — Zig 0.17.1에서 피할 것
- `docs/spikes/2026-11-14-m0-spikes-review.md` — 스파이크 검토. 1절 요약, 3절 호스트 경계, 5절 비교(0.4.12 회차, 5.3에 0.4.15 회차), 7절 cyber에 남은 것, 11절 다시 돌리는 법
- `docs/decisions/0022-guide-from-cyber-agent-guide.md` — 안내의 정본과 열린 것
- `docs/decisions/0017-m0-spike-findings.md`, `0019-fix-spike-defects-first.md`, `0020-docs-current-state-only.md`, `0021-borrow-from-pi-harness.md`
- `docs/spec/08-cyber-implementation.md` — 기준 빌드의 사실
- `spike/s1/build.zig.zon`, `spike/s2/build.zig.zon` — cyber 의존(가장 새 빌드의 태그, ADR 0023)
- `spike/s2/out/0.4.12/` — 비교 회차 원자료
- `spike/s1/src/main.zig` — 검사 44개, `replay`, `spawn`. `spike/s2/src/vm.zig` — 검증, 실행, 승인, reset 알림

## 다음 에이전트에게

0. 직전 세션은 fx 검토(docs/references/2026-11-20-fx-agent-review.md)와 ADR 0030 반영이다. 본체 단계를 시작할 때 그 단계에 걸린 차용 후보(검토 문서 6절의 추천 순서)를 단계 표의 결정 칸에 함께 낸다.
1. 사용자 규칙(~/.claude/CLAUDE.md):
   - 응답은 한국어로 한다.
   - 문서와 주석에 ** 강조를 쓰지 않는다.
   - 커밋은 접두사 없이 첫 글자 대문자, 80자 이내로 쓴다.
   - 검색은 rg와 fd로 한다. 문서 코드 펜스는 ~~~다.
   - 결정은 docs/decisions에 `NNNN-slug.md`로 남기고 MEMORY.md에 한 줄을 더한다.
2. 본체 구현은 페어 코딩이다. 구조에 관한 결정은 사용자가 정한다. 지금은 제약을 늘리기보다 열어 두고 살펴보는 단계다.
3. 문서는 지금 참인 것만 적는다 (ADR 0020).
4. 스파이크는 cyber를 가장 새 빌드의 태그로 받는다(build.zig.zon, ADR 0023). 로컬 cyber 저장소의 상태와 상관없다. 아직 태그에 없는 수정은 `zig build --fork=<cyber 저장소>`로 본다. cyber 저장소는 읽고 빌드만 한다. 편집은 사용자가 지시할 때다 (ADR 0013).
5. 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. 모델이 쓴 명령은 jail.zig의 샌드박스 안에서만 돈다.
