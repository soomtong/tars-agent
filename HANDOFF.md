# HANDOFF: cyber 0.4.11로 스파이크 마지막 판 (2026-11-14)

## 목표

tars-linux용 내장 AI 코딩 에이전트 tars-agent. 본보기는 Claude Code이고, 다른 점은 모델이 JSON 도구 호출 대신 Cyber 스크립트를 써서 실행하는 CodeAct 방식이라는 것이다. 호스트는 Zig 0.17.1, 런타임은 libcyber(soomtong/cyber) 정적 링크. 본체 코드는 아직 없다. 버릴 스파이크 코드가 spike/에 있다.

이번 세션: cyber가 0.4.11을 릴리스했다(태그 0.4.11 = 097b831f, 설치된 CLI `Cyber 0.4.11 build-883-097b831`). 스파이크를 태그 URL과 해시로 고정하고, s1, 안내, 회신 문구를 설치된 CLI와 세션에서 확인하고, 옛 회차 폴더(out/dev, out/dev-5de6c83a)를 지운 뒤 CodeAct 비교를 0.4.11로 모두 다시 돌렸다. 문서를 스파이크의 마지막 판(0.4.11)으로 고쳤다. 회차에서 문구가 고치는 법을 말하지 않은 여섯을 새 요청서로 냈다(선행 조건 아님).

## 현재 브랜치

`main`. 커밋과 push는 Claude에게 위임돼 있다 (ADR 0018).

## 완료된 작업

- [x] 고정: spike/s1, s2의 build.zig.zon `.url = git+https://github.com/soomtong/cyber?ref=0.4.11#097b831f...`, `.hash = cyber-0.4.11-AW3fkEXwjQClbWIfwyRDrnTCj0k7VNbfWrg4S4Bzkzea`. build.zig 의존 인자 `.dev = false, .build = "883", .commit = "097b831"`로 릴리스와 같은 버전 문자열. s1 검사 0은 문자열 전체를 비교
- [x] s1 40개 통과, s2 빌드, 교차 빌드 x86_64-linux-gnu(s1, s2). libcyber.a arm64 2.55 MB, x86_64 3.09 MB, 공개 `cl_` 135개
- [x] 스파이크 결함 수정: `s1 spawn`이 출력 버퍼와 요청 목록을 해제하지 않아 SafeAllocator가 누수를 보고했다. spawnProbe에 `g_out`, `g_reqs`, `g_asked`의 deinit과 VM 둘의 `cl_vm_deinit`을 넣었다(검사 모드는 `process.exit`로 끝나 누수 검사를 거치지 않는다)
- [x] 안내 두 판: 기준 줄 `Cyber 0.4.11 build-883-097b831`(영문판 19,777바이트). 코드 블록 11개 CLI와 세션 통과
- [x] 비교 회차(out/0.4.11/): direct 2(DS 사고 없음, qwen3.8-flash), CodeAct 12(DS 사고 없음 3, DS effort high 3, qwen3.8-flash 5, qwen3.8-max 1). CodeAct 36개 중 35 통과(DS 사고 없음 3회차 T2는 모델의 판정 논리 실수), direct 6개 모두. 과제당 컴파일 오류 DS 0.78, DS high 0.22, flash 1.67, max 0. 컴파일 오류 34건 중 13건이 `print(!str)`. OpenRouter 캐시가 입력의 절반 안팎만 덮었다
- [x] 요청서 docs/requests/cyber-0.4.11-codeact-messages.md: `for p |s| in`, `q: byte = 0`, `in_s str = ''`, 옵션 아닌 값과 `none`, 옵션 아닌 값의 `?else`, `str > int`. 권장 코드는 0.4.11에서 돈다
- [x] 문서: 검토 문서(기준 줄, 1, 2의 예시, 3절 실측, 5절 전체, 7, 8, 11절), 08, 00, deps, ADR 0017, 0019, TODO, MEMORY
- [x] 모델 이름: s2는 `deepseek-flash`(기본 effort high로 사고), OpenRouter는 `deepseek/deepseek-v4.1-flash-1017`. 옛 별칭 `deepseek-chat`은 사고하지 않는다. `output_config.effort`가 받아들여지는지는 미확인
- [x] 결정(스파이크 안, 위임): 능력이 반환 슬롯을 먼저 받는 규칙은 본체 추천에서 뺐다. 컴파일러 문구가 고치는 법을 말하는 실수는 안내에 넣지 않는다

## 시도했으나 실패한 접근

- 회차 도중에 안내를 고치기: s2가 실행마다 안내를 읽어 회차가 섞인다. 이번에 안내의 기준 줄을 고치지 않은 채 회차를 시작했다가 멈추고 다시 돌렸다. 회차 전에 안내를 먼저 확정한다.
- 릴리스 CLI를 태그에서 스크래치로 빌드하기: 사용자가 설치한 `/usr/local/bin/cyber`를 쓴다(`cyber version`으로 먼저 확인).
- `zig fetch --save=cyber <url>`로 기존 `.path` 의존을 덮기: `.path`에 URL을 넣고 해시를 빼 zon이 깨진다. `zig fetch <url>`로 해시만 받고 zon을 손으로 고친다.
- zsh에서 맞는 것이 없는 glob(`rm out/cmp-*`): 명령 전체가 멈춘다. 따로 지운다.
- `rg`로 spike/s2/out/<회차>/의 trace 찾기: .gitignore에 걸린다. `rg --no-ignore`를 쓴다.
- `s2 --help`, `s2 --version`: 인자가 아니라 질문으로 모델에 보낸다.
- 안내의 오류 문구를 CLI로만 확인하기: 모듈 로더가 달라 `use json`처럼 세션과 다른 문구가 있다. `s1 replay`로도 본다.
- macOS의 `ls -t`: eza 별칭이라 `/bin/ls`를 쓴다.
- 이전 세션들의 버린 대안은 ADR 0004~0016에 있다. 다시 제안하지 않는다.

## 남은 작업

정본은 docs/TODO.md다. 본체 구현은 페어 코딩이다 (CLAUDE.md, ADR 0012).

사용자가 정할 것:

- [x] 요청서(문구 여섯)를 cyber에 전달. cyber e25e7d76에 반영됐고 CLI에서 여섯 모두 확인. 세션 확인은 0.4.12로 고정을 옮길 때 한 번에 한다(사용자 결정)
- [ ] `print(!str)`가 작은 모델의 가장 흔한 오류다. 능력의 모양이나 안내로 줄일지 (본체의 능력 설계 때)
- [ ] 안내가 4,000토큰 목표를 넘는다(첫 요청 입력 약 6,500토큰). 목표를 바꿀지 안내를 줄일지 (검토 문서 8절)
- [ ] 검토 문서를 읽고 ADR 0017의 추천을 받거나 바꾼다. 그 뒤 spike/를 지운다

그 밖:

- [ ] 본체 첫 단계: 저장소 뼈대와 runtime 경계. 선행 조건은 닫혔다. 단계의 결정, 편집, 기능 표를 먼저 낸다
- [ ] tars 게스트에서 기준 빌드로 스파이크 실행 (tars-linux 산출물 필요)
- [ ] cyber C1: json, toon. C2: regex, time. C3: 모듈 허용 표
- [ ] 평가: eval/ 과제 20개, CodeAct 대 direct, 판정을 docs/decisions에 기록
- [ ] M1~M6. 미확인: tars 커널의 CONFIG_SECURITY_LANDLOCK (M5)

## 핵심 파일

- `docs/spikes/2026-11-14-m0-spikes-review.md` — 스파이크의 마지막 판(0.4.11). 1절 요약, 3절 호스트 경계, 5절 비교, 7절 cyber에 남은 것, 11절 다시 돌리는 법
- `docs/requests/cyber-0.4.11-codeact-messages.md` — 열린 요청(문구 여섯)
- `docs/decisions/0017-m0-spike-findings.md`, `0019-fix-spike-defects-first.md`, `0020-docs-current-state-only.md`
- `docs/spec/08-cyber-implementation.md` — 기준 빌드의 사실
- `spike/s1/build.zig.zon`, `spike/s2/build.zig.zon` — cyber 고정(태그 URL과 해시)
- `spike/s2/out/0.4.11/` — 비교 회차 원자료
- `spike/s1/src/main.zig` — 검사 40개, `replay`, `spawn`. `spike/s2/src/vm.zig` — 검증, 실행, 승인, reset 알림

## 다음 에이전트에게

1. 사용자 규칙(~/.claude/CLAUDE.md): 응답은 한국어, 문서와 주석에 ** 강조 금지, 커밋은 접두사 없이 첫 글자 대문자 80자 이내, 검색은 rg와 fd. 문서 코드 펜스는 ~~~. 결정은 docs/decisions에 `NNNN-slug.md`로 남기고 MEMORY.md에 한 줄.
2. 본체 구현은 페어 코딩이다. 구조에 관한 결정은 사용자가 정한다.
3. 문서는 지금 참인 것만 적는다 (ADR 0020).
4. 스파이크는 cyber를 URL과 해시로 고정해 받는다(build.zig.zon). 로컬 cyber 저장소의 상태와 상관없다. 문구를 CLI로 볼 때만 cyber 저장소에서 같은 커밋을 스크래치로 빌드한다. cyber 저장소는 읽고 빌드만 한다. 편집은 사용자가 지시할 때다 (ADR 0013).
5. 키는 환경 변수 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. 모델이 쓴 명령은 jail.zig의 샌드박스 안에서만 돈다.
