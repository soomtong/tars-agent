# TODO

표기: [ ] 미착수, [~] 진행 중, [x] 완료.

단계(M)마다 끝에 게이트가 있다. 게이트는 눈으로 확인할 수 있는 동작 하나다. 게이트를 통과한 뒤 다음 단계로 간다. 단계를 시작할 때 짧은 계획을 쓰고, 끝나면 배운 것을 docs/decisions에 남긴다.

## 끝난 것

- [x] tars-linux, cyber fork 현황 확인
- [x] 라이선스 BSD 3-Clause (ADR 0003)
- [x] 실행 모델 CodeAct + Cyber (ADR 0001), 호스트는 Zig + libcyber (ADR 0002)
- [x] 초기 요구사항 대조 (09 문서)
- [x] 명세 재검토와 열린 질문 결정 (ADR 0004~0009, 2026-11-10)
- [x] cyber 0.4.7 반영: 08 문서, 프롬프트 안내 기준 버전과 예제 20개 재실행 (2026-11-12)
- [x] cyber 0.4.8 반영: 고정 버전, 08 문서, 프롬프트 안내(슬라이스 생략, 최상위 오류, trim), 예제 20개 재실행 (2026-11-12)
- [x] cyber 0.4.9 반영 (태그 0.4.9 → 03d24f4e, build-833. 안내 docs/requests/cyber-0.4.9-report.md)
  - [x] 08 문서, ADR 0011과 05의 fiber 서술, 안내의 예약어 scope, 예제 20개를 로컬 빌드(82877718)로 실행해 0.4.8과 출력이 같음을 확인 (2026-11-12)
  - [x] 태그와 GitHub 릴리스 확인, 82877718 이후 두 커밋(06b0cd7b, 03d24f4e) 확인, deps.md 고정 버전과 안내 기준 버전, 릴리스 바이너리(build-833)로 예제 20개 재실행 (2026-11-12)
  - [x] 결정 (ADR 0016): 동시 승인은 요청 번호 순으로 하나씩, v1 안내는 fiber와 scope를 가르치지 않고 금지 한 줄, 취소된 요청은 eval 끝의 요청 표 비우기로 (2026-11-12)

## M0 증명과 판정

코드를 쓰기 전에 세 가지를 증명하고 한 가지를 판정한다. 산출물은 버려도 되는 스파이크와 남기는 평가 도구(eval/)다.

스파이크는 Claude가 혼자 검토, 구현하고 결정도 위임받았다 (ADR 0012의 덧붙임, 2026-11-13). 코드는 spike/에, 상세한 검토 결과는 docs/spikes/에 둔다. 사용자는 검토 결과로 아키텍처의 감을 잡고, 본체 구현은 페어로 한다.

- [x] 스파이크 1, 호스트 경계: build.zig.zon으로 cyber를 받아 Zig에서 링크. 능력 2개(fs.read, proc.exec), 호스트 로더(c 거부), deny_raw_ptrs, 연료(fuel), 벽시계(wall-clock) interrupt, 스택과 메모리 상한, persist_main 반복 eval, validate, 능력 안에서 블록 후 반환
- [x] 스파이크 1의 확인 목록 (08 문서 "M0에서 확인할 것" 여섯 항목)
- [x] 스파이크 1에서 동시 승인 확인 (ADR 0016): scope 블록으로 요청 둘을 걸고 번호 순으로 하나씩 완료, 중첩 블록에서 그룹 밖 요청 먼저 완료(cyber F-111), 하나를 거부하면 나머지가 버려지고 요청 표가 비는지
- [x] 스파이크 2, 제공자: 전송 형식 둘(Anthropic Messages, OpenAI Chat Completions)을 DeepSeek으로 확인 (ADR 0014). Zig std.http로 스트리밍 요청, SSE 해석, run 도구 한 번 왕복. TLS와 CA 묶음이 macOS와 tars 게스트에서 되는지. 안 되면 대안(curl 프로세스)을 정한다
- [x] 스파이크 검토 결과: docs/spikes/2026-11-13-m0-spikes-review.md, 발견과 추천은 ADR 0017 (2026-11-13). 스파이크 코드(spike/)는 사용자가 검토한 뒤 지운다
- [ ] cyber C1 (json 모듈)이 끝난 뒤 평가를 돌린다. 스파이크 셋은 C1과 나란히 한다
- [x] 스파이크 3, 교차 빌드: x86_64-linux-gnu 산출물이 tars 게스트(QEMU)에서 실행되는지
- [ ] Cyber 부분집합 안내 초안 (prompt/cyber-subset.md, 4,000 토큰 이하, 예제 10개). 2026-11-13 dev 기준으로 갱신: 모델이 실제로 틀린 패턴, 있는 메서드 목록, 정렬, `!T` 처리, 표의 `\|` 이스케이프 제거 (review-02 8절). 기준 버전은 0.4.10-DEV라 고정 버전을 올릴 때 다시 확인한다
- [ ] eval/: 과제 20개와 채점기. 과제는 실제 쓰임에서 고른다 (파일 찾아 고치기, 여러 파일 집계, 명령 실행 후 출력 가공, 오류 처리, JSON 꺼내기 등). 과제마다 3회 실행
- [ ] 평가 실행: CodeAct 대 direct(같은 능력을 JSON 도구로), 모델은 DeepSeek과 OpenRouter의 Qwen 계열 (ADR 0014, 목록은 평가 설계 때 정한다). 기록: 첫 시도 validate 통과율, 과제 성공률, 스텝 수, 토큰, 실패 유형
- [ ] 판정 (ADR 0006): 기본 모델에서 첫 시도 validate 통과 70% 이상이고 과제 성공률이 direct보다 5%p 넘게 낮지 않으면 CodeAct를 기본으로 간다. 못 미치면 안내를 고쳐 한 번 더 재고, 그래도 못 미치면 direct를 기본으로 하고 CodeAct는 선택 모드로 둔다

게이트: 평가 표와 판정을 docs/decisions에 기록하고 사용자에게 보고한다.

## C cyber 쪽 작업 줄기 (ADR 0010)

필요한 것은 cyber에 만든다. 작업 장소는 soomtong/cyber이고 그 저장소의 절차를 따른다. 목록과 필요의 증거는 08 문서 "cyber에서 만들 것"이 정본이다. M 단계와 나란히 간다.

- [ ] C0 스파이크의 결함 (요청서 docs/requests/cyber-m0-spike-findings.md, 2026-11-13). 모두 닫힌 뒤에 본체 첫 단계로 간다 (feedback-fix-spike-defects-first.md)
  - [ ] 실패한 컴파일 뒤 다음 컴파일에서 죽는 것. master dcedfc48에서 고쳐짐, dev 빌드로 재현과 s2 비교 실행을 우회 없이 통과 (2026-11-13, docs/spikes/2026-11-13-m0-spikes-review-02.md). 릴리스 대기
  - [ ] `!str` 값 복사의 컴파일 오류. master aa92e857에서 고쳐짐, `Future[!str]` 모양으로 s1 검사 31개 통과 (같은 날, 같은 문서). 릴리스 대기
  - [ ] 빌드 내보내기
  - [ ] spawn 차단 옵션
  - [ ] 호스트 함수의 인자 읽기 순서 (문서 또는 확인)
  - [ ] 수정 릴리스 뒤: 고정 버전 올리기, 스파이크 재현 재실행, 우회를 걷어 낸 모양으로 통과 확인. 재실행 방법은 review-02 10절
  - [ ] 다음 요청서 후보 (review-02 7절): sort가 캡처하는 클로저나 키 정렬, 없는 메서드 오류에 비슷한 이름, `!T`의 print, `for x in xs`의 문구, 오류 문구의 `Vector`
- [ ] C1 json 모듈 (parse, stringify, 값 트리). M0의 평가 실행보다 먼저
- [ ] C1 toon 모듈 (stringify, parse). 목적은 모델에게 돌려주는 결과의 토큰 절약. 값 트리는 json 모듈과 같이 쓴다. json 다음에 요청서를 쓴다
- [ ] C1 빌드 내보내기: 스파이크 1에서 필요가 확인됐다 (artifact("cyber")가 없다). 요청서에 포함
- [ ] C2 regex 모듈 (역추적 없는 엔진). M2보다 먼저
- [ ] C2 time 모듈. M2보다 먼저
- [ ] C3 임베딩 옵션 (모듈 허용 표, spawn 차단). M1 중. spawn 차단은 요청서에 포함 (스레드 안에서 능력 함수가 불린다)
- [x] C3 CL_AWAIT: 루트 맥락 중단과 재개, 호스트 Future C API (ADR 0011). 2026-11-12 요청, master 8de18b05~94350e31 구현(태그 API 포함)(wait_any 포함), 검토 통과, cyber 0.4.8로 릴리스
- [x] C3 #[bind] 문서: cyber 0.4.5의 docs/docs.md Attributes 절과 #[bind] hooks 절
- [ ] 수시: 프로세스를 죽이는 경로 수정
- [ ] cyber 릴리스를 낼 때마다 tars-agent의 고정 버전을 올리고 예제 테스트와 평가를 다시 돌린다

게이트: 모듈마다 cyber의 테스트(누수 검사 포함)와 릴리스, 그리고 tars-agent 안내 문서의 예제가 그 모듈을 써서 통과한다.

## M1 최소 루프 (헤드리스, 읽기 전용)

- [ ] 저장소 뼈대: build.zig, cyber 의존 고정, macOS와 linux 빌드, CI
- [ ] runtime: cy.zig 래퍼, 로더, 상한, 결과 조립
- [ ] caps: 능력 표와 생성기 (Cyber 선언, 바인딩, 프롬프트 사양, JSON Schema), fs.read, fs.list, fs.glob, fs.stat, help
- [ ] provider: Messages API 스트리밍, 적응형 사고, effort, 캐시 지점, stop_reason 분기(end_turn, tool_use, max_tokens, refusal, pause_turn), 재시도. refusal의 서버 쪽 fallbacks 옵션 적용 여부 결정
- [ ] prompt: 조립기, rules.md
- [ ] loop: validate, eval, 실패 분류 다섯, 한도
- [ ] session: JSONL 쓰기 (07의 형식)
- [ ] headless: -p, text와 stream-json 출력
- [ ] 테스트: 모의 provider와 시나리오 재생, 능력 단위 테스트(누수 검사 allocator), 샌드박스 탈출 시도(raw 포인터, use c, 무한 루프, 폭주 재귀, 메모리 폭주)가 모두 결과로 끝나는지

게이트: tars-agent -p "이 저장소의 빌드 방법을 설명해" 가 파일을 읽고 답한다. 탈출 시도 테스트가 모두 통과한다.

## M2 쓰기와 권한

- [ ] fs.search (ripgrep), fs.edit, fs.write, 파일 상태 추적, 쓰기 전 보관
- [ ] proc.exec, proc.sh, proc.start, proc.output, proc.kill, 환경 정리, 프로세스 그룹 종료
- [ ] 결과 상한과 넘침 파일
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
- [ ] 모드 전환 (Shift+Tab, /mode)과 system 메시지
- [ ] AGENTS.md 읽기, 프로젝트 설정 수락 절차
- [ ] 슬래시 명령: /help /clear /mode /model /cost /permissions /quit
- [ ] ui.ask, ui.todo, memo, clock.now
- [ ] net.fetch와 외부 입력 표시

게이트: macOS 터미널과 tars 패널(QEMU)에서 대화로 파일을 고친다. 승인, 거부, 인터럽트가 한글 입력 상태에서도 동작한다.

## M4 긴 세션

- [ ] 재개: --continue, --resume, /resume. VM 새 시작 알림, memo와 todo 복원
- [ ] 컴팩션: 자동 임계치와 /compact, 요약에 넣을 항목
- [ ] 캐시 점검: cache_read가 0으로 이어지면 경고
- [ ] 비용 계산과 tars-agent stats
- [ ] 지연 사양 (예산을 넘는 능력은 한 줄 요약과 help)
- [ ] 죽은 세션: crash/ 보관과 재개 안내

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
- [ ] agentd와 tars 터미널 제어 채널, tars.* 능력: 자기 조작(명령 실행, 콘솔 입력). tars-linux 쪽 설계와 개선도 이 프로젝트의 일이다 (ADR 0013). 앞당길 자리는 능력 표 설계 때 정한다
- [ ] MCP 서버 방향, MCP HTTP 전송
- [ ] 다른 제공자 어댑터
- [ ] cyber CLI의 spec --for-agents로 안내 문서 생성
- [ ] fiber 안 Future.await의 양보(cyber 로드맵 단계 3): cyber 0.4.9에 들어왔다. agentd에서 한 스레드에 여러 세션을 돌릴 때 쓸지 판단

## 뺀 것

이전 TODO에 있었으나 하지 않기로 한 것 (ADR 0009).

- 방식 B(순수 Cyber CLI) 스파이크
- docs/design.md, docs/fork-plan.md: 명세(spec/)와 08 문서가 그 역할을 한다
- 셸 명령 분류기
- tars.* 모의 구현
- OpenTelemetry
- 세션 재개 때 코드 재생으로 VM 복원
- JSON, 정규식을 호스트 능력으로 주기 (ADR 0010: cyber 표준 모듈로 만든다)
