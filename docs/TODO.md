# TODO

표기: [ ] 미착수, [~] 진행 중, [x] 완료.

단계(M)마다 끝에 게이트가 있다. 게이트는 눈으로 확인할 수 있는 동작 하나다. 게이트를 통과한 뒤 다음 단계로 간다. 단계를 시작할 때 짧은 계획을 쓰고, 끝나면 배운 것을 docs/decisions에 남긴다.

## 끝난 것

- [x] tars-linux, cyber fork 현황 확인
- [x] 라이선스 BSD 3-Clause (ADR 0003)
- [x] 실행 모델 CodeAct + Cyber (ADR 0001), 호스트는 Zig + libcyber (ADR 0002)
- [x] 초기 요구사항 대조 (09 문서)
- [x] 명세 재검토와 열린 질문 결정 (ADR 0004~0009, 2026-11-10)
- [x] cyber 기준 빌드 반영: 0.4.15. 스파이크 의존은 가장 새 빌드를 따르고(ADR 0023), s1, 안내의 코드 블록과 오류 문구를 설치된 CLI와 세션에서 확인했다. CodeAct 비교를 0.4.15로 다시 돌렸다(검토 문서 5.3). 스파이크의 호스트 로더는 허용 목록이다(ADR 0026) (2026-11-18)

## M0 증명과 판정

코드를 쓰기 전에 세 가지를 증명하고 한 가지를 판정한다. 산출물은 버려도 되는 스파이크와 남기는 평가 도구(eval/)다.

스파이크는 Claude가 혼자 검토, 구현하고 결정도 위임받았다 (ADR 0012의 덧붙임, 2026-11-13). 코드는 spike/에, 상세한 검토 결과는 docs/spikes/에 둔다. 사용자는 검토 결과로 아키텍처의 감을 잡고, 본체 구현은 페어로 한다.

- [x] 스파이크 1, 호스트 경계: build.zig.zon으로 cyber를 받아 Zig에서 링크. 능력 2개(fs.read, proc.exec), 호스트 로더(허용 목록), deny_raw_ptrs, 연료(fuel), 벽시계(wall-clock) interrupt, 스택과 메모리 상한, persist_main 반복 eval, validate, 능력 안에서 블록 후 반환
- [x] 스파이크 1의 확인 목록 (08 문서 "M0에서 확인한 것"). 검사 44개 모두 통과
- [x] 스파이크 1에서 동시 승인 확인 (ADR 0016): scope 블록으로 요청 둘을 걸고 번호 순으로 하나씩 완료, 중첩 블록, 하나를 거부하면 나머지가 버려지고 요청 표가 비는지
- [x] 스파이크 2, 제공자: 전송 형식 둘(Anthropic Messages, OpenAI Chat Completions)을 DeepSeek으로 확인 (ADR 0014). Zig std.http로 스트리밍 요청, SSE 해석, run 도구 한 번 왕복. TLS와 CA 묶음은 macOS에서 된다
- [x] 스파이크 검토 결과: docs/spikes/2026-11-14-m0-spikes-review.md, 발견과 추천은 ADR 0017. 스파이크 코드(spike/)는 사용자가 검토한 뒤 지운다
- [ ] 평가는 json 모듈을 안내에 넣은 뒤 돌린다(json은 기준 빌드에 있다). 안내에 가르칠 모듈과 크기는 사용자가 정한다
- [~] 스파이크 3, 교차 빌드: x86_64-linux-gnu 교차 빌드는 확인. tars 게스트(QEMU)에서의 실행은 기준 빌드로 확인할 것 (tars-linux 산출물 필요)
- [x] cyber 0.4.15로 옮기기 (2026-11-18): 두 스파이크의 의존을 태그 `0.4.15`(`93a9ca4f`)로 올렸다. s1 47개 통과(새 검사 7i: `cl_vm_symbol_hints`, 7a4: `use test`, 6n: 오류 복구), s2 빌드, x86_64 교차 빌드. 안내 두 판과 agent-guide.md의 코드 블록 34개가 CLI와 세션에서 모두 통과한다(`test`를 연 뒤, ADR 0028). 제자리 `Slice`의 문구(`xs = xs.append(3)`, `ys := xs.append(3)`, 전역 `g.append(g.len())`)를 CLI와 세션에서, `os` 옛 꼴의 문구를 CLI에서 탐침으로 확인했다(세션은 `os`를 싣지 않는다). 세션의 마지막 줄 `xs.append(4)`는 결과 없는 문장, `xs.appended(3)`은 eval 결과다. `cyber-lsp`를 stdio로 붙여 unused 경고, quick fix, inlay hint, `scope` 출구 알림, 문서 주석 hover를 확인했다. 검토 문서 3.5, 7, 8절, 9절 18
- [x] CodeAct 비교를 0.4.15로 다시 돌림 (2026-11-18): 0.4.12와 같은 표(회차 14개, 과제 42개). 41개 통과, 실패 하나는 과제 해석, 죽은 실행 없음, 컴파일 오류 51건에서 41건. 원자료 spike/s2/out/0.4.15/, 검토 문서 5.3
- [ ] cyber 요청: 0.4.15 회차에서 고치는 법을 말하지 않은 문구 셋(`!T`가 아닌 함수의 `!`, `.!`, `^[]T`의 제자리 메서드). docs/requests/cyber-0.4.15-messages-from-codeact-round.md. 회신을 받으면 새 빌드에서 세 스크립트를 CLI와 세션으로 확인한다
- [ ] cyber 0.4.15 다음 빌드에서 안내 고치기: 전역의 제자리 메서드가 인자를 먼저 평가한다(cyberscript `docs/releases/unreleased.md` "0.4.14..0.4.15 코드 리뷰에서 나온 수정"). `g.append(g.len())`가 컴파일되고, 오류는 같은 전역의 빌림(`g.append(g.span())`)뿐이며 문구가 'so this argument can not read'로 바뀐다. `g += f()!`가 error일 때 전역이 비던 결함과 `g += h`(목록)가 컴파일되지 않던 회귀도 고쳐졌다. 의존을 올릴 때 prompt/cyber-subset.md · cyber-subset.en.md 105행의 '인자가 같은 전역을 읽으면 컴파일 오류' 문장을 고친다. 0.4.15에서는 지금 문장이 맞으므로 그 전에는 두지 않는다
- [ ] 검증 뒤 `cl_vm_symbol_hints`의 쓰지 않는 함수 안 지역을 모델에게 넘길지 (검토 문서 9절 18, 세션의 최상위 지역은 거른다). 평가 때 정한다
- [ ] Cyber 부분집합 안내 (prompt/cyber-subset*.md, 예제 10개). 기준 빌드로 다시 썼고 예제와 조언을 CLI와 세션(persist_main) 양쪽에서 확인했다 (검토 문서 8절). 남은 것: 크기가 4,000토큰 목표를 넘는다(검토 문서 8절의 수치). 목표를 바꿀지 안내를 줄일지 사용자가 정한다
- [ ] eval/: 과제 20개와 채점기. 과제는 실제 쓰임에서 고른다 (파일 찾아 고치기, 여러 파일 집계, 명령 실행 후 출력 가공, 오류 처리, JSON 꺼내기 등). 과제마다 3회 실행
- [ ] 평가 실행: CodeAct 대 direct(같은 능력을 JSON 도구로), 모델은 DeepSeek과 OpenRouter의 Qwen 계열 (ADR 0014, 목록은 평가 설계 때 정한다). 기록: 첫 시도 validate 통과율, 과제 성공률, 스텝 수, 토큰, 실패 유형
- [ ] 판정 (ADR 0006): 기본 모델에서 첫 시도 validate 통과 70% 이상이고 과제 성공률이 direct보다 5%p 넘게 낮지 않으면 CodeAct를 기본으로 간다. 못 미치면 안내를 고쳐 한 번 더 재고, 그래도 못 미치면 direct를 기본으로 하고 CodeAct는 선택 모드로 둔다

게이트: 평가 표와 판정을 docs/decisions에 기록하고 사용자에게 보고한다.

## C cyber 쪽 작업 줄기 (ADR 0010)

필요한 것은 cyber에 만든다. 작업 장소는 soomtong/cyber이고 그 저장소의 절차를 따른다. 목록과 필요의 증거는 08 문서 "cyber에서 만들 것"이 정본이다. M 단계와 나란히 간다.

- [x] C0 `use c` 없는 `#[extern]` 함수가 검증 중에 프로세스를 죽이던 것. cyber 0.4.14에서 컴파일 오류가 됐다. s1 검사 7h (2026-11-17)
- [~] C1 json 모듈 (parse, stringify, 값 트리). 기준 빌드에 있고 로더가 싣는다(ADR 0025). 남은 게이트: 안내 문서의 예제가 이 모듈을 써서 통과
- [~] C1 toon 모듈 (encode, decode). 기준 빌드에 있고 로더가 싣는다. 남은 게이트는 json과 같다
- [~] C2 regex 모듈 (역추적 없는 엔진), peg 모듈. 기준 빌드에 있고 로더가 싣는다. 남은 게이트는 json과 같다
- [x] C2 time 모듈. 기준 빌드에 있다. 허용하고 clock.now는 두지 않는다. 스파이크 로더에서 열었다 (ADR 0024, 2026-11-17)
- [x] 표준 모듈 API: 패키지에 `docs/api.json`이 들어 있고 `cyber doc --api <module>`이 찍는다. s1 검사 0b가 빌드 때 읽어 모듈로 거른다 (cyber 0.4.14, 2026-11-17)
- [x] `test` 모듈을 연다. 순수 Cyber 검사 함수이고 정본 안내가 가르친다. s1 검사 7a4 (ADR 0028, 사용자 결정, 2026-11-18)
- [x] `path` 모듈(0.4.14, join, base, dir, ext, stem, normalize, is_absolute). 파일 시스템을 보지 않는 문자열 함수라 연다. 스파이크 로더에서 열었다. s1 검사 7a3 (ADR 0027, 2026-11-17)
- [ ] C3 임베딩 옵션: `os`를 호스트 콜백으로 받기(ADR 0026의 방향 D). 모듈 허용 표는 호스트 로더로 되므로 올리지 않는다
- [ ] 수시: 프로세스를 죽이는 경로 수정
- [ ] cyber의 새 빌드를 받을 때마다 s1, 안내의 예제와 항목, 평가를 다시 돌린다. 문서는 새 빌드의 사실로 고쳐 쓴다 (ADR 0020)

게이트: 모듈마다 cyber의 테스트(누수 검사 포함)와 릴리스, 그리고 tars-agent 안내 문서의 예제가 그 모듈을 써서 통과한다.

## M1 최소 루프 (헤드리스, 읽기 전용)

- [ ] 저장소 뼈대: build.zig, cyber 의존(가장 새 빌드, ADR 0023), macOS와 linux 빌드, CI
- [ ] runtime: cy.zig 래퍼, 로더, 상한, 결과 조립
- [ ] caps: 능력 표와 생성기 (Cyber 선언, 바인딩, 프롬프트 사양, JSON Schema), fs.read, fs.list, fs.glob, fs.stat, help
- [ ] provider: Messages API 스트리밍, 적응형 사고, effort, 캐시 지점, stop_reason 분기(end_turn, tool_use, max_tokens, refusal, pause_turn), 재시도. refusal의 서버 쪽 fallbacks 옵션 적용 여부 결정
- [ ] prompt: 조립기, rules.md
- [ ] loop: validate, eval, 실패 분류, 한도. 벽시계는 VM 안의 시간만 잰다(바인딩 층이 능력 호출 동안 타이머를 멈춘다). 실패 결과에 능력 호출 목록 (ADR 0021)
- [ ] session: JSONL 쓰기 (07의 형식)
- [ ] headless: -p, text와 stream-json 출력
- [ ] 테스트: 모의 provider와 시나리오 재생, 능력 단위 테스트(누수 검사 allocator), 샌드박스 탈출 시도(raw 포인터, use c, 무한 루프, 폭주 재귀, 메모리 폭주)가 모두 결과로 끝나는지

게이트: tars-agent -p "이 저장소의 빌드 방법을 설명해" 가 파일을 읽고 답한다. 탈출 시도 테스트가 모두 통과한다.

## M2 쓰기와 권한

- [ ] fs.search (ripgrep), fs.edit(정규화 일치, 줄바꿈 보존), fs.write, 파일 상태 추적, 쓰기 전 보관
- [ ] proc.exec, proc.sh, proc.start, proc.output, proc.kill, 환경 정리, 프로세스 그룹 종료
- [ ] 결과 상한과 넘침 파일: 스크립트 결과 20,000자, 능력 반환 1 MiB (ADR 0021)
- [ ] permission: 프로파일, 모드 다섯, 규칙 맞춤(경로 glob, 인자 앞부분, 도메인), 설정 파일 세 층, 보호 규칙
- [ ] 비밀: 자격 파일 권한 검사, 자식 환경에서 지우기, 기록 가리기
- [ ] 헤드리스 권한 옵션 (--permission-mode, --allow, --profile), json 출력, 종료 코드
- [ ] 테스트: 규칙 맞춤 표, 경로 정규화와 심볼릭 링크, 보호 규칙, 헤드리스 종단

게이트: 헤드리스가 규칙 파일 아래에서 파일을 고치고 테스트 명령을 돌린다. 규칙 밖의 쓰기는 거부로 기록된다.

## M3 대화형

- [ ] 줄 편집기 (raw 모드, 여러 줄, 히스토리, 한글)
- [ ] 스트리밍 표시, 코드 접기와 펼치기, 상태 줄
- [ ] 승인 프롬프트 (숫자 키, diff 표시, 승인 기억을 settings.local.json에). CL_AWAIT 경로로 루프 바닥에서 묻는다 (ADR 0011)
- [ ] 인터럽트 (Esc, Ctrl-C), 취소 플래그를 능력에 연결
- [ ] 실행 중 입력(steering): 코어의 큐, 스텝마다 하나씩, 턴 끝에 남은 입력은 다음 턴, 인터럽트 때 입력 줄로 돌려주기. 코어-프런트엔드 이벤트와 명령 타입은 사용자가 편집한다 (ADR 0021)
- [ ] 모드 전환 (Shift+Tab, /mode)과 system 메시지
- [ ] AGENTS.md 읽기, 프로젝트 설정 수락 절차
- [ ] 슬래시 명령: /help /clear /mode /model /cost /permissions /quit
- [ ] ui.ask, ui.todo, memo
- [ ] os 대신 능력으로: fs.mkdir, fs.remove, fs.copy, fs.move, env.get 후보를 평가를 보고 정한다 (04, ADR 0026)
- [ ] net.fetch와 외부 입력 표시

게이트: macOS 터미널과 tars 패널(QEMU)에서 대화로 파일을 고친다. 승인, 거부, 인터럽트가 한글 입력 상태에서도 동작한다.

## M4 긴 세션

- [ ] 재개: --continue, --resume, /resume. VM 새 시작 알림, memo와 todo 복원
- [ ] 컴팩션: 자동 임계치와 /compact, 요약 요청 형식과 요약의 틀, 파일 목록 누적, 두 번째부터 요약 고치기 (02)
- [ ] 확인: 컴팩션에서 최근 구간을 원문으로 남길 때, 앞부분이 바뀐 대화에 남긴 사고 블록을 제공자가 받는지. 결과로 남길지 정한다 (ADR 0021 열어 둔 것)
- [ ] 캐시 점검: cache_read가 0으로 이어지면 경고
- [ ] 비용 계산과 tars-agent stats
- [ ] 지연 사양 (예산을 넘는 능력은 한 줄 요약과 help)
- [ ] 죽은 세션: crash/ 보관, 재개 때 crashed 결과 채우기, 재개 안내 (02)

게이트: 컨텍스트 창을 넘기는 작업 하나를 컴팩션을 거쳐 끝낸다. 중간에 프로세스를 죽이고 이어서 끝낸다.

## M5 tars-linux 통합

- [ ] 릴리스: 태그를 밀면 CI가 x86_64-linux-gnu 산출물과 sha256을 올린다
- [ ] tars-linux devlayer/manifest.toml 등록 (tars-linux 쪽 작업, 그 저장소의 절차를 따른다)
- [ ] 커널 설정 CONFIG_SECURITY_LANDLOCK 확인과 추가 요청
- [ ] sandbox/landlock.zig: 쓰기 범위, TCP 제한, ABI 버전 확인, 없을 때의 내려가기
- [ ] auto 모드 (샌드박스가 있을 때만)
- [ ] tars 게이트 체인 make check CHAIN=agent: QEMU에서 헤드리스 stream-json으로 요청, 스크립트, 승인, 파일 생성을 로그로 판정하고 대화형은 픽셀로 본다
- [ ] 사용자 문서: 설치, 키 설정, 권한 규칙, 모드
- [ ] tars.conf에 둘 키가 있는지 판단 (없으면 두지 않는다. 에이전트 설정은 settings.json에 있다)

게이트: tars ISO에서 tars-agent가 실행되고 체인이 통과한다. 0.1.0 릴리스.

## M6 확장 (06 문서의 순서)

- [ ] /rewind
- [ ] MCP 클라이언트 (stdio)
- [ ] 서브에이전트
- [ ] 스킬, 훅, 사용자 슬래시 명령, /init
- [ ] agentd와 tars 터미널 제어 채널, tars.* 능력: 자기 조작(명령 실행, 콘솔 입력). tars-linux 쪽 설계와 개선도 이 프로젝트의 일이다 (ADR 0013). 앞당길 자리는 능력 표 설계 때 정한다. agentd의 클라이언트 프로토콜은 AHP를 먼저 검토한다 (ADR 0029)
- [ ] MCP 서버 방향, MCP HTTP 전송
- [ ] ACP 어댑터: 헤드리스 프런트엔드 하나로 얹는다 (ADR 0029)
- [ ] 다른 제공자 어댑터
- [ ] 안내를 cyber의 docs/agent-guide.md와 호스트 덧붙임으로 만든다 (ADR 0022). 기준 빌드의 패키지에 이 파일이 있다. 언제, 어떤 모양으로 모을지는 ADR 0022의 "열린 것"이고 사용자가 정한다
- [ ] fiber 안 Future.await의 양보(cyber에 있다): agentd에서 한 스레드에 여러 세션을 돌릴 때 쓸지 판단

## 뺀 것

이전 TODO에 있었으나 하지 않기로 한 것 (ADR 0009).

- 방식 B(순수 Cyber CLI) 스파이크
- docs/design.md, docs/fork-plan.md: 명세(spec/)와 08 문서가 그 역할을 한다
- 셸 명령 분류기
- tars.* 모의 구현
- OpenTelemetry
- 세션 재개 때 코드 재생으로 VM 복원
- JSON, 정규식을 호스트 능력으로 주기 (ADR 0010: cyber 표준 모듈로 만든다)
