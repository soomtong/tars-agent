# 검증

이 문서는 요구(12)를 무엇으로 확인하는지 정한다. 테스트의 종류, 재료, 놓는 곳, 실행하는 곳, 이름 붙인 테스트 목록, CI, 비기능 예산을 재는 방법을 담는다. 평가(모델의 Cyber 정확도와 CodeAct 판정)는 13이 정본이고 여기서는 가리키기만 한다. 구조에 관한 선택은 끝의 "열린 것"에 있고 사용자가 정한다.

본체 코드는 아직 없다. 아래 테스트는 이름과 모양만 정한 것이고 만든 것은 없다.

## 원칙

- 테스트와 게이트는 다르다. 테스트는 기계가 판정하고 매번 돈다. 게이트는 단계 끝에 사람이 눈으로 보는 동작 하나다(TODO). 게이트가 지나가는 동작도 따로 테스트를 둔다.
- 매 커밋에 도는 테스트는 API 키 없이 돌고, 네트워크는 localhost만 쓰고, 결정적이다. 시계, 난수, 세션 ID, 잠자기를 테스트가 정한다(열린 것 2).
- 실제 제공자가 필요한 것(live 탐침, 평가)과 사람의 눈이 필요한 것(게이트, QEMU 체인의 픽셀)은 손으로 돌린다.
- 테스트 이름은 `종류.대상.사례` 꼴이다. 12의 확인 칸이 이 이름을 쓴다. `종류.대상.*`는 그 대상의 테스트 전부다.
- 테스트를 더하면 이 문서의 목록과 12의 확인 칸을 함께 고친다.

## 테스트 종류

| 종류 | 접두 | 무엇을 보나 | 재료 | 놓는 곳 | 실행 |
|---|---|---|---|---|---|
| 단위 | unit | 함수와 모듈 하나. 누수 검사 allocator(`std.testing.allocator`)가 기본이다 | 테스트 코드 | 소스 옆의 test 블록 | zig build test |
| 할당 실패 훑기 | oom | 할당이 실패하는 모든 지점에서 오류로 돌아오고 새지 않는지 | resize를 거부하는 감싸개(deps.md) | 소스 옆 | zig build test |
| 탈출 시도 | esc | 스크립트가 1층 경계를 넘지 못하고 결과로 끝나는지. 끝난 뒤 VM을 계속 쓸 수 있는지 | Cyber 스크립트와 기대 결과 | test/esc/ | zig build test |
| 시나리오 재생 | scn | 루프의 분기, 기록, 알림. 모의 provider와 각본 프런트엔드로 한 턴 이상을 돌린다 | 모의 provider가 돌려줄 줄, 프런트엔드 명령 | test/scn/ | zig build test |
| 녹화 SSE 재생 | sse | 어댑터의 스트림 풀기. 원문 바이트를 임의의 조각으로 잘라 넣어도 같은 결과인지 | 녹화하거나 손으로 쓴 SSE 원문과 기대 | test/sse/ | zig build test |
| 가짜 서버 | fake | HTTP 수준의 동작(스트림 중단, 재시도할 상태 코드, net.fetch) | localhost 가짜 HTTP 서버 | test/support/ | zig build test |
| 골든 | gold | 만들어진 바이트(시스템 프롬프트, 요청 본문, 생성된 능력 선언과 사양, json 결과) | 기대 파일 | test/gold/ | zig build test |
| fuzz | fuzz | 바깥 바이트를 읽는 디코더가 어떤 입력에도 오류로 끝나는지 (ADR 0030 결정 8 B5) | 씨앗과 말뭉치 | test/fuzz/ | 말뭉치 재생은 zig build test, 찾기는 손으로 |
| 안내 예제 | guide | Cyber 안내의 예제가 링크된 libcyber에서 도는지 (06) | 안내 문서의 코드 블록 | 안내 문서 | zig build test |
| 정적 검사 | check | 모듈 경계, 링크된 심볼, 의존 목록 (ADR 0030 결정 8 B4) | 검사 도구 | tools/check/ | zig build check |
| 종단 헤드리스 | e2e | 만든 실행 파일을 프로세스로 부른다. stdout, stderr, 종료 코드, json, 세션 파일 | 작업 폴더 fixture, 설정, 가짜 서버 | test/e2e/ | zig build e2e |
| 가상 터미널 | pty | 대화형 REPL을 의사 터미널로 몬다. 키 바이트열을 넣고 화면 바이트를 본다 | 키 각본 | test/e2e/ | zig build e2e |
| Linux 전용 | linux | Landlock 샌드박스, termios | e2e와 같다 | test/e2e/ | Linux에서 zig build e2e |
| 측정 | measure | 실행 파일 크기, 시작 시간, 메모리 | 측정 도구 | tools/measure/ | zig build measure |
| CI 작업 | ci | 두 대상의 빌드, 릴리스 산출물 | 워크플로 | .github/workflows/ | CI |
| QEMU 게이트 체인 | chain | tars 게스트에서 헤드리스 로그와 대화형 픽셀 | tars-linux의 체인 | tars-linux 저장소 | 손으로 |
| live 탐침 | live | 실제 제공자 왕복, 녹화, 토큰 실측 | API 키 | tools/live/ | 손으로 |
| 평가 | (13) | 모델의 Cyber 정확도, CodeAct 대 direct, 죽은 run의 비율(json이 없는 회차는 세션 파일로 센다) | eval/ | eval/ | 손으로 (13) |

## 재료

모의 provider

- 07 "리플레이"의 모의 provider다. 세션 파일 형식의 줄(assistant 줄과 error 줄)을 차례로 돌려준다. assistant 줄은 어댑터를 지난 뒤의 메시지(10의 블록 넷, 끝난 이유, 사용량)이고, error 줄은 그 자리에서 제공자 오류(재시도할 오류, 요청 오류, 컨텍스트 초과, retry-after)를 낸다.
- 녹화한 세션 파일의 줄을 그대로 쓸 수 있다. 죽은 세션의 재현(07)과 같은 길이다.
- 스트림을 흉내 낼 때는 assistant 줄을 내부 이벤트(10 "스트림 풀기와 내부 이벤트")로 쪼개 흘린다. 인터럽트 시나리오가 스트림 중간에 끊을 자리를 준다.
- 루프에 끼우는 자리는 열린 것 1이다.

각본 프런트엔드

- 코어-프런트엔드 명령을 각본대로 낸다: 입력, 승인 답(다섯 선택지), 질문 답, 인터럽트, steering 입력. 받은 이벤트를 기록해 단언에 쓴다.
- 이벤트와 명령 타입은 사용자가 편집한다(ADR 0012). 각본의 모양은 그 타입을 따른다.

가짜 HTTP 서버

- 테스트 안에서 localhost에 띄우는 작은 서버다. 녹화 SSE를 정한 조각 크기와 간격으로 보내고, 정한 자리에서 연결을 끊거나 멈추고, 429(retry-after 포함), 5xx, 400, 컨텍스트 초과 본문을 낸다.
- 제공자 항목의 url이 전체 주소라(10) e2e는 settings.json의 providers 항목 하나를 `http://127.0.0.1:<포트>/...`로 덮어 이 서버를 가리킨다. 실행 파일에 테스트용 길을 두지 않는다.
- net.fetch의 리다이렉트, 본문 상한, 스킴 테스트도 이 서버를 쓴다.

녹화 SSE

- 형식마다 디렉터리 하나(test/sse/anthropic/, test/sse/openai/)에 원문(`.sse`)과 기대(`.json`: 조립된 블록, 다시 계산한 끝난 이유, 제공자가 준 값, 맞춘 사용량)를 둔다.
- 출처는 live 탐침의 녹화(열린 것 5)다. 키, 메시지 id, 서명처럼 계정이나 요청에 묶인 값은 넣기 전에 가린다. 스파이크가 보지 못한 경우(10 "확인하지 않은 것")를 손으로 쓴 원문은 메타 줄에 그 사실을 적는다.

골든 파일

- test/gold/<이름>에 둔다. 바이트로 비교한다. 시각, 세션 ID, 경로, 걸린 시간은 테스트가 주입한 값이라 가리지 않는다(열린 것 2).
- 갱신 방법은 열린 것 4다. CI는 골든을 고치지 않는다.

탈출 스크립트

- test/esc/<이름>.cy 하나가 시도 하나다. 기대는 실패 종류(02)와 오류의 첫 줄이다. 시도 뒤에 같은 VM에서 `1 + 1`을 돌려 세션이 남았는지 본다.
- 스파이크 1의 검사 목록(08 "M0에서 확인한 것", s1 49개)은 runtime 단위 테스트와 탈출 시도의 출발점이다. 스파이크 코드는 버리고 검사는 본체의 테스트로 다시 쓴다.

할당 실패 감싸개

- `std.testing.checkAllAllocationFailures`에 resize를 거부하는 allocator 감싸개를 끼운다. resize가 성공하면 할당 순서가 실행마다 달라진다(deps.md, fx 검토 B2).
- VM 쪽: cl_vm_init_mem으로 VM의 메모리를 테스트 allocator로 돌리면 VM의 누수와 할당 실패도 볼 수 있다. 이 방법으로 누수를 센 적은 없다(확인하지 않았다). cl_thread_rc로 세는 호스트는 cl_vm_release_result를 먼저 부른다(08).

## 디렉터리

01의 디렉터리 표에서 test/는 "모의 provider 시나리오"다. 이 절이 그것을 넓힌다.

~~~text
src/**/*.zig            단위와 할당 실패 테스트는 소스 옆의 test 블록
test/
  support/              모의 provider, 각본 프런트엔드, 가짜 HTTP 서버, 주입할 시계와 ID, allocator 감싸개
  scn/<이름>/           model.jsonl(모의 provider의 줄), front.jsonl(각본, 선택). 단언은 test/scn.zig
  esc/<이름>.cy         탈출 시도. 기대 결과는 test/esc.zig의 표
  sse/anthropic/        <이름>.sse(원문), <이름>.json(기대)
  sse/openai/
  gold/                 골든 파일
  fuzz/<대상>/          씨앗과 말뭉치
  e2e/<이름>/           작업 폴더 fixture, settings.json, 기대. pty 각본도 여기
tools/
  check/                경계, 링크, 의존 검사
  measure/              크기, 시작 시간, 메모리
  live/                 실제 제공자 탐침과 녹화
.github/workflows/      CI (열린 것 6)
~~~

zig build 단계

| 단계 | 담는 것 | 언제 |
|---|---|---|
| zig build test | unit, oom, esc, scn, sse, fake, gold, guide, fuzz 말뭉치 재생 | 매 커밋 |
| zig build check | check.* | 매 커밋 |
| zig build e2e | e2e.*, pty.*, Linux에서는 linux.* | 매 커밋 |
| zig build measure | measure.* | 매 커밋 (기록) |
| zig build test --fuzz | fuzz 찾기 | 손으로 (열린 것 9) |
| zig build live | live.* | 손으로, 키 필요 |

단계 이름은 추천이다. 단계의 경계(키가 필요한 것과 필요 없는 것, 실행 파일이 필요한 것과 필요 없는 것)는 지킨다.

## 이름 붙인 테스트

요구 칸은 12의 요구 ID다. "B3"처럼 적은 것은 ADR 0030 결정 8과 fx 검토 3.2의 항목이다.

### 단위 (unit), 할당 실패 (oom)

| 이름 | 무엇 | 요구 | 단계 |
|---|---|---|---|
| unit.runtime.loader | 허용 목록 열한 모듈과 능력 모듈만 싣고 io, cy, 모르는 이름은 로드 실패 | R-RUN-02, R-NF-SEC-02 | M1 |
| unit.runtime.prelude | 머리말을 한 번 eval한 뒤에 검증한다. 첫 eval 전 검증은 설정이 꺼져 있다(08) | R-RUN-04 | M1 |
| unit.runtime.future | `Future[!ExecResult]` 같은 구조체 완료와 `Future[![]str]`, 호스트 모듈 소스의 오버로드와 옵션 구조체(03) | R-CAP-03 | M1 |
| unit.runtime.wall-excludes-cap | 스텝 벽시계보다 오래 막히는 능력 호출 뒤에도 스크립트가 끊기지 않는다. 바인딩 층이 타이머를 멈춘다 | R-LOOP-06 | M1 |
| unit.caps.* (누수) | 모든 능력 본체를 누수 검사 allocator로 부른다. 본체는 VM 없이 Zig 값만 받는다 | R-CAP-02 | M1~M3 |
| unit.caps.nonempty | 능력 표의 모든 능력이 성공에서 빈 결과를 돌려주지 않는다(표에서 생성) | R-CAP-12 | M1~M3 |
| unit.caps.fs-read | 줄 번호, 2,000줄과 상한에서의 절단 사실과 다음 offset, 파일 상태 기록 | R-TOOL-02 | M1 |
| unit.caps.path | 상대 경로 입출력, 심볼릭 링크를 따라간 정규화, 작업 디렉터리 안팎 | R-CAP-08 | M2 |
| unit.caps.overflow | 스크립트 결과 20,000자(앞 200줄, 뒤 50줄, 생략 수, 넘침 파일), 능력 반환 1 MiB(앞뒤 512 KiB), 바이너리 | R-CAP-09 | M2 |
| unit.caps.file-state | 읽지 않은 파일과 읽은 뒤 바뀐 파일의 편집, 덮어쓰기 거부. 턴마다 파일당 한 번 보관 | R-CAP-10 | M2 |
| unit.caps.fs-search | rg 결과 모양, .gitignore, 결과 상한의 파일별 요약. PATH에 rg가 없으면 싣지 않고 시작 알림 | R-TOOL-03 | M2 |
| unit.caps.fs-edit | 정확 일치, 정규화 일치(04의 정규화 표), 여러 곳이면 실패와 개수, replace_all, LF와 CRLF 보존, 바뀐 범위 | R-TOOL-04 | M2 |
| unit.caps.proc | 셸 없는 인자 배열, /bin/sh -c, stdin 닫힘, TERM=dumb, 키 변수 지움, 시간 제한에 프로세스 그룹째 종료, 세션 끝 정리 | R-TOOL-05 | M2 |
| unit.caps.proc-jobs | proc.output, proc.kill은 하네스가 시작한 작업 ID만 받는다 | R-TOOL-06 | M2 |
| unit.caps.cancel | 취소 플래그를 세운 뒤 막힌 능력(proc.exec의 오래 자는 명령)이 정한 시간 안에 돌아온다 | R-CAP-07 | M2, M3 |
| unit.caps.ui-ask | 선택지 2~4개 검사, 헤드리스에서 오류 값 | R-TOOL-08 | M3 |
| unit.caps.memo | 값 10,000자 상한, 세션 파일 기록 | R-TOOL-10 | M3 |
| unit.perm.order | 판정 순서 아홉 단계(05)를 단계마다 이기는 사례로 | R-PERM-01 | M2 |
| unit.perm.rules | 규칙 맞춤 표: fs glob(`*`, `**`, `~/`, `**/`, 상대 패턴의 기준), proc.exec 인자 앞부분, proc.sh 정확 일치와 `*`, domain:과 하위 도메인, 해석할 수 없는 규칙 | R-PERM-01, R-PERM-05 | M2 |
| unit.perm.modes | 모드 다섯과 등급 여섯의 판정 표 전체, 작업 디렉터리 안팎 | R-PERM-03 | M2 |
| unit.perm.profile | 프로파일에 없는 능력은 주입되지 않는다(부르면 컴파일 오류, 프롬프트에 없음). 짝 없는 proc.output이 빠진다 | R-PERM-02 | M2 |
| unit.perm.auto-fallback | 샌드박스가 없으면 auto가 accept-edits로 내려가고 알린다 | R-PERM-04, R-NF-PORT-02 | M2, M5 |
| unit.perm.protect | 보호 규칙: 작업 디렉터리 밖 쓰기, 시스템 경로, 자기 설정과 세션 디렉터리, 남의 프로세스. 선택지 2와 3을 보이지 않음 | R-PERM-08 | M2 |
| unit.perm.default-deny | 기본 deny 규칙 셋이 모든 모드와 bypass에서 걸린다 | R-SEC-03 | M2 |
| unit.perm.sandbox-false | sandbox = false는 bypass가 아니면 모든 모드에서 ask이고 allow 규칙으로 풀리지 않는다 | R-SBX-03 | M5 |
| unit.perm.external-input | 표시가 선 뒤 net.fetch allow 규칙과 auto의 샌드박스 안 exec가 ask로 내려간다. 재개와 컴팩션 뒤에도 | R-PERM-09 | M3 |
| unit.perm.approval-options | 선택지 2와 3은 그 규칙이 실제로 allow를 낼 때만 보인다. 능력마다 뽑는 규칙 문자열 | R-PERM-07 | M3 |
| unit.config.layers | 설정 세 층 합치기, 명령행 우선, --allow가 deny를 풀지 못함, 해석할 수 없는 파일은 시작 거부(줄, 열), 모르는 키는 경고 | R-PERM-06 | M2 |
| unit.config.trust | 프로젝트 설정의 넓히는 값은 처음 열 때 수락, 해시가 바뀌면 다시 묻기, 헤드리스는 빼고 시작 | R-PERM-06 | M3 |
| unit.secret.credentials | 환경 변수 먼저, 없으면 credentials 파일. 0600이 아니면 거부. 빈 줄과 # 줄 | R-SEC-01 | M2 |
| unit.secret.child-env | 모든 제공자 항목의 key_env가 자식 환경에서 빠진다 | R-SEC-02 | M2 |
| unit.secret.redact | 기록 전에 읽은 키 값과 흔한 키 꼴(sk-, sk-ant-, sk-or-, ghp_)을 가린다 | R-SEC-02 | M2 |
| unit.sandbox.fallback | Landlock ABI를 0, 4 미만, 4, 6으로 주입해 샌드박스 없음 알림, TCP 제한, 신호 범위 제한의 선택을 본다 | R-SBX-02, R-NF-PORT-02 | M5 |
| unit.session.layout | 세션 파일 위치, 0600, 곁 디렉터리 out/, files/, crash/ | R-SESS-01 | M1 |
| unit.session.header | 줄 머리 순서(v, seq, ts, type), crc 계산, 4 MiB 상한과 out/ | R-SESS-03 | M1 |
| unit.session.torn-tail | 줄바꿈 없는 꼬리와 crc 불일치 꼬리를 잘라 내고 error 줄을 남긴다 | R-SESS-04 | M1 |
| unit.session.corrupt | 깨진 줄 뒤에 온전한 줄, seq 끊김은 재개 거부와 줄 번호. 읽기 도구는 건너뛰고 센다 | R-SESS-04 | M1 |
| unit.session.fsync | fsync 호출을 세는 감싸개로, 턴을 닫는 줄 뒤에만 fsync하는지. 새 세션의 임시 이름 뒤 rename | R-SESS-04 | M1 |
| unit.session.version | 더 새 v는 재개 거부, 읽기 도구는 모르는 type을 건너뛴다 | R-SESS-06 | M1 |
| unit.session.crash-fill | 결과 없는 run 줄로 끝난 파일에 crashed 결과, 나머지 run에 interrupted, 그 뒤 cap 줄의 목록 | R-SESS-08 | M4 |
| unit.prompt.spec-budget | 생성된 능력 사양의 크기를 대리 상한(바이트)과 비교한다. 토큰 실측은 live.prompt-tokens | R-CAP-04 | M1, M4 |
| unit.prompt.agents-md | 읽는 곳과 바깥에서 안쪽 순서, 합계 40,000자 초과 알림, 첫 user 메시지 앞 | R-CTX-04 | M3 |
| unit.fe.terminal-safe | 제어 문자, DEL, 잘못된 UTF-8을 보이는 꼴로 바꾸고 줄바꿈과 탭은 둔다. 나뉜 UTF-8 조각을 이어 받는 증분판. 모양은 01 열린 것 2 | B3 | M1 |
| unit.fe.line-editor | 키 바이트열에서 편집 버퍼 상태: 여러 줄, 히스토리, 한글(조합된 UTF-8) | R-FE-01 | M3 |
| unit.fe.slash | 슬래시 명령 v1 아홉의 해석과 코어 명령으로 가는지 | R-FE-04 | M3, M4 |
| unit.fe.bang | ! 접두: 게이트를 지나지 않음, 환경 정리와 시간 제한, 결과 상한, user 줄 | R-FE-05 | M3 |
| unit.obs.cost | 녹화한 세션에서 토큰 넷, 지연, 가격표로 비용. null 캐시 필드는 모름 | R-OBS-01 | M4 |
| oom.session, oom.sse, oom.message, oom.config, oom.prompt, oom.caps | 할당 실패 훑기. 모든 지점에서 오류 반환, 누수 없음, 프로세스가 죽지 않음 | R-CAP-06 | M1~M3 |

### 탈출 시도 (esc)

모두 M1이다. 기대는 결과 종류이고 시도 뒤에 VM을 계속 쓴다.

| 이름 | 시도 | 기대 | 요구 |
|---|---|---|---|
| esc.raw-ptr | use c 없이 `as[Ptr[int]]`로 주소 읽기 | 컴파일 오류 (deny_raw_ptrs) | R-RUN-03 |
| esc.c-ptr | `use c` 뒤 to_strz, memcpy | 컴파일 오류 | R-RUN-02, R-RUN-03 |
| esc.extern | `#[extern]` 함수 선언과 호출 | c가 없으면 선언 위치의 컴파일 오류, 있으면 panic 결과 (-Dffi=false) | R-RUN-02 |
| esc.modules | use io, use cy, use os, 모르는 이름 | 로드 실패 컴파일 오류 | R-RUN-02, R-NF-SEC-02 |
| esc.intrinsic | @memcpy, @bitCast, #[unsafe] | 컴파일 오류 | R-NF-SEC-02 |
| esc.spawn | spawn 호출 | 컴파일 오류 (deny_spawn) | R-RUN-03 |
| esc.fuel | 끝나지 않는 루프 | interrupted | R-LOOP-06, R-NF-SEC-04 |
| esc.wall-clock | 연료를 크게 준 바쁜 루프 | 벽시계 상한에서 interrupted | R-LOOP-06, R-NF-SEC-04 |
| esc.recursion | 폭주 재귀 | panic (Stack overflow), 스택 기본 8 MiB | R-LOOP-06, R-NF-SEC-04 |
| esc.memory | 메모리 폭주 | panic (OutOfMemory), 메모리 기본 256 MiB | R-LOOP-06, R-NF-SEC-04 |
| esc.fiber-cap | fiber와 scope 안의 능력 호출 둘 | 요청 번호가 작은 것부터 하나씩 묻는다 (ADR 0016) | R-LOOP-12 |
| esc.future-resolver | 스크립트가 만든 미완료 Future를 await | 태그 0이라 abandon, interrupted | R-LOOP-12 |

### 시나리오 재생 (scn)

모의 provider와 각본 프런트엔드로 돈다. 단언은 결과 본문, 세션 파일의 줄, 낸 이벤트를 본다.

| 이름 | 각본 | 기대 | 요구 | 단계 |
|---|---|---|---|---|
| scn.run-input-invalid | run의 args_json이 { code: string }이 아님 | 실행하지 않고 오류 결과 | R-LOOP-01 | M1 |
| scn.stop-branches | 끝난 이유 여섯을 한 턴씩 | end_turn 끝, tool_use 실행, refusal 범주 보이고 끝, pause_turn 이어 요청, other 원값 보이고 끝 | R-LOOP-02 | M1 |
| scn.truncated | max_tokens로 잘린 tool_call | 실행하지 않고 잘렸다는 오류 결과 | R-LOOP-03 | M1 |
| scn.two-runs | 한 응답에 run 둘 | 차례로 실행, 결과는 user 메시지 하나 | R-LOOP-04 | M1 |
| scn.compile-error | 컴파일 오류 스크립트 | is_error, 모델에는 요약 문자열, run 줄에 구조화 필드(1을 더한 줄과 열) | R-LOOP-05 | M1 |
| scn.failure-kinds | 실패 종류마다 스크립트 하나 | 결과 종류와 문구가 서로 다르고 루프가 이어진다 | R-LOOP-07 | M1 |
| scn.failed-result-caps | 능력 둘을 부른 뒤 panic | 그때까지의 출력과 능력 목록(ok, error, denied, cancelled) | R-LOOP-08 | M1 |
| scn.panic-reset-notice | panic, interrupted 뒤 | 최상위 변수 초기화 알림 | R-LOOP-09 | M1 |
| scn.vm-reset-pending | VM의 첫 컴파일 실패 | cl_vm_reset_pending이 참, 머리말 다시 eval, 세션 reset 알림 | R-LOOP-09 | M1 |
| scn.step-limit | 끝나지 않는 tool_use | 턴당 스텝 상한에서 끝, stop max_steps | R-LOOP-10 | M1 |
| scn.repeated-error | 같은 코드 같은 오류 다섯 번 | 3회에 경고, 5회에 턴 끝, stop repeated_error. crashed도 센다 | R-LOOP-10 | M1 |
| scn.provider-retry | error 줄(429, retry-after), 5xx, 스트림 중간 끊김 | 백오프 재시도(주입한 잠자기로 시간 확인), 기본 5회 넘으면 오류로 턴 끝, error 줄 기록 | R-LOOP-11 | M1 |
| scn.provider-request-error | 400, 401, 403 | 재시도 없음, 401과 403에 key_env, 히스토리는 요청 전 상태 | R-LOOP-11 | M1 |
| scn.context-overflow | 컨텍스트 초과 오류 | 컴팩션 한 번 뒤 다시 보냄. 두 번째 초과는 오류 | R-LOOP-11 | M4 |
| scn.record-order | 능력 둘을 부르는 run | run 줄, cap 줄 둘, result 줄 순서 | R-LOOP-15 | M1 |
| scn.cap-audit | 능력 호출마다 | cap 줄의 칸(능력, 인자 요약, 결정과 근거, 외부 입력 표시, 시간, 결과 크기, 오류) | R-CAP-11 | M1 |
| scn.replay | 녹화한 세션 파일 하나를 모의 provider로 | 같은 cap 줄과 result 줄 (대조만 하는 모드 포함) | R-SESS-09 | M1 |
| scn.append-only | 여러 턴, 컴팩션, 재개 | 앞선 파일 내용이 뒤 파일의 앞부분과 바이트로 같다 | R-SESS-02 | M1, M4 |
| scn.prompt-stable | 모드 변경, 할 일 변경이 있는 여러 턴 | 매 요청의 시스템 프롬프트가 바이트로 같다 | R-CTX-01, R-NF-CACHE-01 | M1, M3 |
| scn.harness-notice | 모드 변경, 할 일 알림, 재개 | `<harness-notice>` text 블록의 자리(사용자 입력 앞, tool_result 뒤, steering 앞), notice 줄 | R-PROV-05, R-PERM-11 | M3 |
| scn.approval-await | ask 판정 능력, 프런트엔드가 허용, 거부, 취소 | 허용은 resume, 거부는 error.Denied이고 부작용 없음, 취소는 abandon | R-LOOP-12, R-CAP-03 | M3 |
| scn.approval-concurrent | scope 블록의 요청 둘, 하나 거부 | 번호 순으로 하나씩, 거부 뒤 나머지 버림, 요청 표가 빔 | R-LOOP-12 | M3 |
| scn.ui-ask | ui.ask 대기와 답, 취소 | 승인과 같은 CL_AWAIT 경로, 벽시계는 대기를 세지 않는다 | R-TOOL-08 | M3 |
| scn.interrupt | 스트림 중간, 스크립트 실행 중 인터럽트 | 스트림 끊기, cl_vm_interrupt와 취소 플래그, 실행하지 못한 tool_call에 interrupted | R-LOOP-13 | M3 |
| scn.steering | 실행 중 입력 셋, 턴 끝, 인터럽트 | 스텝마다 하나씩 tool_result 뒤, 남은 것은 다음 턴, 인터럽트 때 입력 줄로 | R-LOOP-14 | M3 |
| scn.todo | ui.todo 두 번, 컴팩션, 재개 | 목록 전체 교체, 요약과 재개에 실린다 | R-TOOL-09 | M3, M4 |
| scn.compact | 임계치 넘는 사용량, /compact | 요약으로 새 히스토리, VM은 산다, compact 줄 | R-COMP-01 | M4 |
| scn.cache-warning | cache_read 0이 이어지는 사용량, 캐시 필드 없는 사용량 | 앞은 경고, 뒤는 경고 없음 | R-OBS-02, R-NF-CACHE-01 | M4 |

### 녹화 SSE (sse), 가짜 서버 (fake)

| 이름 | 무엇 | 요구 | 단계 |
|---|---|---|---|
| sse.anthropic.* | 글, 사고와 signature_delta, tool_use와 partial_json, 사용량(message_start와 message_delta), OpenRouter의 0 사용량 | R-PROV-01 | M1 |
| sse.openai.* | delta.content, reasoning_content와 reasoning, tool_calls의 index 이어 붙이기, 두 번 오는 finish_reason, include_usage | R-PROV-01 | M1 |
| sse.stop-reason | 10의 끝난 이유 표 여섯 줄. tool_use 블록이 있는데 end_turn인 응답, 잘림과 도구 호출이 함께인 응답 | R-LOOP-02 | M1 |
| sse.chunking | 모든 원문을 1바이트부터 임의 크기의 조각으로 잘라 넣어도 결과가 같다. 1 MiB를 넘는 줄 | R-PROV-01 | M1 |
| fake.stream-abort | 서버가 SSE를 연 채 멈춤. 끊기 요청 뒤 정한 시간 안에 돌아오고 연결이 정리된다 | R-PROV-03, R-LOOP-13 | M1 |
| fake.retry-http | 429와 retry-after, 529, 연결 끊김, 스트림 중간 끊김을 HTTP로 | R-LOOP-11 | M1 |
| fake.net-fetch | http, https만, 본문 100,000자 상한, 리다이렉트 hop마다 판정, 외부 입력 표시 | R-TOOL-07 | M3 |

### 골든 (gold)

| 이름 | 무엇 | 요구 | 단계 |
|---|---|---|---|
| gold.prompt.system | 시스템 프롬프트: 프로파일 둘(full, readonly)과 모드 둘(codeact, direct). 규칙(외부 내용은 자료, 하네스 알림의 뜻), 안내와 fiber 한 줄, 사양, 환경 줄. 날짜 없음 | R-CTX-01, R-CTX-03, R-CTX-05, R-SEC-04 | M1 |
| gold.caps | 능력 표에서 생성한 Cyber 선언과 래퍼, 사양, JSON Schema, 등급 표. 04의 v1 목록과 맞는지 | R-CAP-01, R-TOOL-01 | M1 |
| gold.caps.help | help()와 help(name)의 출력 | R-TOOL-11 | M1 |
| gold.caps.errors | 능력 오류 문구 모음. 사람이 "무엇이 틀렸고 다음에 할 일"을 읽고 검토한다 | R-CAP-05 | M1~M3 |
| gold.request | 정한 히스토리에서 두 형식의 요청 본문과 헤더 | R-PROV-01 | M1 |
| gold.request.thinking | 같은 형식으로 되돌린 사고(signature, reasoning_content), 다른 형식으로 보낼 때 빠진 사고 | R-PROV-02 | M1 |
| gold.request.hints | max_tokens, effort, 캐시 지점 둘의 자리(시스템 끝, 마지막 블록), Claude 모델의 adaptive thinking | R-PROV-04 | M1 |
| gold.compact | 첫 요약 요청과 두 번째 요약 요청 본문, 호스트 덧붙임, 2,000자 절단 | R-COMP-02 | M4 |
| gold.headless.json | stop 값마다 json 결과. 없는 값은 필드가 없다. 평가(13)가 읽는 필드를 지킨다 | R-HL-02 | M1, M2 |
| gold.headless.stream-json | 한 턴의 stream-json 줄 | R-HL-04 | M1 |
| gold.stats | fixture 세션 묶음에서 stats 표와 --json. 죽은 run의 셈(01 "죽는 비율을 재는 법": 결과 없는 run 줄, crashed 결과, run 줄 없는 tool_call, 같은 tool_use_id는 한 번)을 포함한다 | R-OBS-03, R-RUN-06 | M4 |

### fuzz

ADR 0030 결정 8 B5다. 대상마다 test/fuzz/<대상>/에 씨앗을 둔다. 기대는 모든 입력에서 오류 값이나 정상 결과로 끝나고, 누수와 panic이 없는 것이다.

| 이름 | 디코더 | 요구 | 단계 |
|---|---|---|---|
| fuzz.sse | SSE 줄 해석과 두 형식의 누적기 | R-CAP-06 | M1 |
| fuzz.provider-json | 응답 조각과 오류 본문의 JSON | R-CAP-06 | M1 |
| fuzz.session | 세션 JSONL 읽기, crc, 복구 | R-SESS-03 | M1 |
| fuzz.run-args | run의 args_json | R-CAP-06 | M1 |
| fuzz.config | settings.json, credentials | R-CAP-06 | M2 |
| fuzz.rule | 권한 규칙 문자열과 glob | R-PERM-05 | M2 |
| fuzz.edit-normalize | fs.edit의 정규화 일치 | R-TOOL-04 | M2 |
| fuzz.terminal-safe | terminalSafe의 증분 UTF-8 | B3 | M1 |
| fuzz.cli | 명령행 인자 | R-CAP-06 | M1 |

- 말뭉치 재생은 zig build test가 매번 한다. 찾기(`zig build test --fuzz`)는 손으로 돌린다(열린 것 9). Zig 0.17.1의 fuzz가 macOS aarch64에서 도는지는 확인하지 않았다. fx 검토(2절 3)는 `--fuzz`가 찾은 실패도 종료 코드 0이라 출력을 읽어야 한다고 적었다. 우리 빌드에서는 확인하지 않았다.
- 찾은 실패 입력은 말뭉치에 더해 회귀가 된다.

### 정적 검사 (check), 안내 예제 (guide)

| 이름 | 무엇 | 요구 | 단계 |
|---|---|---|---|
| check.boundary | @import 그래프를 읽는다(건너 import 포함). libcyber와 cl_* 선언은 runtime/cy.zig만. caps/ 밖에서는 정문 파일만(이름은 능력 표를 편집할 때 정한다). 능력 본체는 runtime/를 import하지 않는다(바인딩 층만). frontend/는 permission/, runtime/을 import하지 않고 core는 frontend/를 import하지 않는다. std.http와 네트워크는 provider/와 net 능력만 | R-RUN-01, R-CAP-02, R-FE-06, R-NF-SEC-05 (B4) | M1 |
| check.no-panic | caps/, session/, provider/에서 @panic, std.process.exit와 허용 목록 밖의 unreachable | R-CAP-06 | M1 |
| check.link | 산출물의 심볼 표: tcc와 mimalloc 심볼 없음, x86_64-linux-gnu는 glibc 동적 링크(인터프리터가 있다), cyber 의존 인자에 ffi가 꺼져 있음 | R-NF-LIC-01, R-NF-DEP-01 | M1 |
| check.deps | build.zig.zon의 의존이 cyber뿐이고 해시가 고정됨. 새 의존은 deps.md에 줄이 있어야 통과 | R-NF-DEP-01 | M1 |
| guide.examples | 안내(호스트 덧붙임 포함)의 코드 블록을 세션 VM 설정(persist_main, 허용 로더, deny 옵션)으로 실행. 깨지면 빌드 실패 | R-CTX-02 | M1 |

스파이크는 tcc와 mimalloc 없음을 심볼로 확인했다(08). check.link는 그것을 매 빌드에 한다.

### 종단 헤드리스 (e2e), 가상 터미널 (pty), Linux (linux)

e2e는 만든 실행 파일을 임시 작업 폴더에서 부른다. HOME, XDG_CONFIG_HOME, XDG_STATE_HOME, TMPDIR을 임시 디렉터리로 두고 제공자는 가짜 서버를 가리킨다.

| 이름 | 무엇 | 요구 | 단계 |
|---|---|---|---|
| e2e.headless-io | -p와 text, json, stream-json. 결과는 stdout, 진행은 stderr. 파이프 stdin을 프롬프트에 덧붙임 | R-HL-01 | M1 |
| e2e.exit-codes | 0, 1(설정 해석 실패와 위치, 키 없음, 잠금 실패, 실행 오류, refusal), 2(max_steps, budget, repeated_error), 3, 130(SIGINT). 시작 전 실패는 json을 쓰지 않는다 | R-HL-03 | M1, M2 |
| e2e.limits | --max-steps, --max-budget-usd, --permission-mode, --allow, --profile | R-HL-05 | M1, M2 |
| e2e.headless-readonly | 설정 없이 프로파일 readonly. 밖 읽기는 deny | R-PERM-10 | M2 |
| e2e.headless-ask-deny | ask가 deny로, cap 줄 ask_denied와 근거 headless, 그 스크립트 뒤 턴 끝, 종료 코드 3, error.message에 규칙 문자열 | R-PERM-10, R-HL-05 | M2 |
| e2e.bypass-cli | bypass는 --dangerously-bypass로만. 설정과 --permission-mode의 bypass는 시작 거부 | R-PERM-04 | M2 |
| e2e.direct-mode | --tool-mode direct: 도구 여럿, json에 능력 호출 하나짜리 run, validate 없음 | R-EVAL-01 | E |
| e2e.crash-resume | 능력 안에서 막힌 run 중에 SIGKILL 뒤 --continue. crash/ 보관, crashed 결과, 재실행 없음, 찢긴 꼬리 처리 | R-RUN-05, R-LOOP-07, R-SESS-04, R-SESS-08 | M4 |
| e2e.killed-run | 헤드리스를 검증 중과 실행 중에 SIGKILL한다. stdout에 json이 없고, 세션 파일은 run 줄 없는 tool_call(검증 중)과 결과 없는 run 줄(실행 중)로 끝난다. 평가 실행기와 stats가 죽은 run을 세는 재료가 이 모양이다(01 "죽는 비율을 재는 법", 13) | R-RUN-06 | M1 |
| e2e.resume | --continue, --resume. 히스토리, memo, todo, 파일 상태, 외부 입력 표시 복원, VM 새 시작 알림 | R-SESS-07, R-TOOL-10 | M4 |
| e2e.session-lock | 같은 세션을 두 프로세스가 연다. 뒤의 것이 2초 뒤 pid를 말하고 거부, 종료 코드 1 | R-SESS-05 | M1 |
| pty.repl | 의사 터미널에서 입력, 스트리밍 표시, 코드 접기와 Ctrl+O, 상태 줄 | R-FE-01, R-FE-02 | M3 |
| pty.keys | Esc 인터럽트, Shift+Tab 모드 순환, Ctrl+C 두 번 종료 | R-FE-03 | M3 |
| pty.approval | 승인 프롬프트의 내용(diff, 명령 전체, 스크립트 줄)과 숫자 키 다섯 | R-PERM-07 | M3 |
| linux.sandbox | 범위 밖 쓰기와 TCP 연결이 막힌다. ABI 6이면 밖 프로세스에 신호를 못 보낸다 | R-SBX-01, R-NF-SEC-01 | M5 |
| linux.termios | 줄 편집기의 터미널 설정이 Linux libc 링크에서 스택을 넘치지 않는다(deps.md) | R-FE-01 | M3 |

- 한글 입력 상태에서 숫자 키가 눌리는지는 입력기가 터미널 쪽에 있어 pty로 볼 수 없다. G-M3과 chain.agent가 본다.
- linux.*는 Linux 러너의 커널이 Landlock을 주면 CI에서, 아니면 chain.agent에서 돈다. GitHub ubuntu 러너 커널의 Landlock ABI는 확인하지 않았다.

### 측정 (measure), CI 작업 (ci), 체인 (chain), live 탐침 (live)

| 이름 | 무엇 | 요구 | 단계 |
|---|---|---|---|
| measure.size | 아래 "비기능 예산을 재는 법" | R-NF-SIZE-01 (B6) | M1 |
| measure.startup | 같은 절 | R-NF-TIME-01 (B6) | M1 |
| measure.memory | 같은 절 | R-NF-MEM-01 | M1 |
| ci.build | 아래 "CI"의 매 커밋 작업이 초록 | R-DIST-02, R-DIST-03, R-NF-PORT-01 | M1 |
| ci.linux | x86_64 Linux 러너에서 zig build test, e2e (열린 것 7) | R-NF-PORT-03 | M1 |
| ci.release | 태그를 밀면 x86_64-linux-gnu 산출물과 sha256이 릴리스에 오른다 | R-DIST-01, R-DIST-03 | M5 |
| chain.agent | 아래 "QEMU 게이트 체인" | R-DIST-04, R-FE-07, R-NF-PORT-03, R-NF-PORT-04 | M5 |
| live.formats | 내장 제공자 항목 넷의 한 번 왕복 | R-PROV-01 | M1 |
| live.record | test/sse/의 원문을 녹화하고 가린다 | R-PROV-01 | M1 |
| live.probes | 10 "확인하지 않은 것": 도구 호출 여럿, 작은 max_tokens의 잘림, effort 칸, 컨텍스트 초과 문구, 스트림 중간 오류 | R-LOOP-02, R-LOOP-11 | M1 |
| live.prompt-tokens | 시스템 프롬프트를 늘리고 줄인 요청의 사용량 차이로 안내와 능력 사양의 토큰 수를 잰다 | R-CAP-04, R-CTX-02 | M1 |

## CI

모양의 추천이다. 장소와 러너는 열린 것 6, 7이다.

- 매 커밋(main에 push, pull request)에 돈다. 워크플로는 zig build 단계만 부른다. 같은 단계를 개발 기계에서 그대로 돌린다.
- CI에는 API 키가 없다. 네트워크는 Zig 배포본과 build.zig.zon 의존을 받을 때와 localhost뿐이다.
- Zig는 0.17.1 배포본을 받아 sha256을 대조한다. cyber는 build.zig.zon의 해시로 고정된다. 제3자 action은 쓰지 않는다(tars-linux의 checks.yml과 같다).

매 커밋

| 작업 | 러너 | 하는 일 |
|---|---|---|
| macos | aarch64 macOS | zig build test, check, e2e, measure. -Dtarget=x86_64-linux-gnu 교차 빌드와 그 산출물의 check.link |
| linux | x86_64 Linux | 네이티브 빌드, zig build test, e2e(linux.* 포함), check.link (열린 것 7) |

태그

| 작업 | 하는 일 |
|---|---|
| release | x86_64-linux-gnu 릴리스 빌드, sha256, GitHub 릴리스에 올림 (M5, R-DIST-01). 릴리스 빌드의 최적화 모드와 strip은 01 열린 것 4 |

손으로

| 일 | 언제 |
|---|---|
| live.* | provider 단계, 제공자나 모델을 바꿀 때, 녹화를 더할 때 |
| fuzz 찾기 | 디코더를 고친 뒤, 릴리스 전 |
| 평가 (13) | TODO E, 기준 빌드를 올릴 때 |
| chain.agent | M5 게이트, 릴리스 전, tars-linux 쪽이 바뀔 때 |
| 게이트 | 단계 끝 |
| measure.* (개발 기계) | 예산 수치를 정할 때. CI 러너의 값과 함께 적는다 |

cyber의 새 빌드를 받을 때(TODO C의 마지막 줄) 매 커밋 작업이 그 빌드로 돈다. 안내 예제(guide.examples)와 탈출 시도가 런타임의 바뀐 동작을 먼저 잡는다.

## QEMU 게이트 체인

- tars-linux의 `make check CHAIN=<이름>`은 체인 디렉터리의 check.sh를 컨테이너에서 돌린다. agent 체인은 아직 없다. tars-linux 쪽 작업이므로 요청서(docs/requests/)로 낸다 (ADR 0013).
- 판정 둘: 헤드리스 stream-json 로그로 요청, 스크립트, 능력 호출, 파일 생성을 보고, 대화형은 픽셀로 본다 (09, TODO M5).
- 헤드리스에서 ask는 deny다(05). 로그만으로 승인 단계를 판정하려면 stream-json이 승인 명령을 받는 길이 있어야 한다. 이벤트 타입을 편집할 때 함께 본다(12 체크리스트). 그 전에는 승인 단계를 픽셀로 본다.
- 체인이 쓸 산출물을 어디서 받는지(릴리스 url, 로컬 빌드)는 요청서에서 정한다.
- 이 체인이 tars 게스트의 x86_64에서 실행 파일이 도는지(TODO M0 스파이크 3)와 cyber 기준 빌드의 x86_64 동작(R-NF-PORT-03)을 확인하는 곳이다.

## 비기능 예산을 재는 법

수치는 이 문서가 정하지 않는다. 후보와 CI에서의 처리(넘으면 실패할지, 기록만 할지)는 01 열린 것 4이고 12의 비기능 표가 그것을 가리킨다. 정해지기 전에는 재서 기록만 한다. 이 절은 재는 법만 정한다.

실행 파일 크기 (measure.size)

- 대상 둘(x86_64-linux-gnu, aarch64-macos)을 릴리스 작업과 같은 모드로 빌드하고 바이트 수를 적는다. 그 모드와 strip은 01 열린 것 4에서 함께 정한다. 정하기 전에는 strip한 크기와 하지 않은 크기를 함께 적는다.
- 같은 빌드의 libcyber.a 크기를 함께 적어 cyber 몫과 본체 몫을 가른다. 08의 libcyber.a 수치(arm64 3,058,056바이트, x86_64 3,620,340바이트)와 같은 방법이다.
- 앞 커밋 값과의 차이를 적는다.

시작 시간 (measure.startup)

- 01 열린 것 4의 두 값을 잰다. 하나는 `tars-agent --version`의 실행부터 끝까지다(프로세스와 인자 해석). 다른 하나는 새 세션의 첫 요청 직전까지로, `tars-agent -p`의 실행부터 가짜 서버가 첫 요청 바이트를 받을 때까지로 잰다(설정 읽기, AGENTS.md, git 저장소 확인, 프롬프트 조립, VM 생성과 머리말 eval 포함, 네트워크와 TLS 없음).
- 측정 도구가 20회 띄우고 중앙값과 최댓값을 적는다. 첫 1회는 버린다. 러너 이름과 CPU를 함께 적는다.
- 08의 실측(VM 생성과 첫 eval 개당 2~3 ms)이 두 번째 값의 아래쪽 한 부분이다.

메모리 (measure.memory)

- 유휴 메모리: 대화형을 pty로 띄워 세션을 열고 입력을 기다릴 때의 현재 RSS를 읽는다(Linux는 /proc/<pid>/statm, macOS는 proc_pid_rusage). 01 열린 것 4의 유휴 후보가 이 값이다.
- 최대 메모리: 자식 프로세스의 최대 상주 메모리(getrusage의 ru_maxrss)를 --version, 한 턴 시나리오, 같은 세션의 20턴 시나리오(턴이 늘 때 자라는지)에서 잰다. macOS는 바이트, Linux는 KiB 단위라 도구가 맞춘다.
- 08의 VM 하나 약 2.6 MiB는 이 값의 일부다.

기록

- CI는 측정값을 작업 요약에 쓴다. 수치가 정해지면 측정 도구가 그 수치와 비교한다.

## 단계별로 생기는 테스트

TODO의 단계 줄이 정본이다. 요약:

| 단계 | 생기는 것 |
|---|---|
| M1 | test/support(모의 provider, 각본 프런트엔드, 가짜 서버, 주입), unit.runtime.*, unit.session.*, esc.*, scn(M1 줄), sse.*, fake.stream-abort, fake.retry-http, gold(prompt, caps, request, headless), fuzz(M1 줄), check.*, guide.examples, e2e(M1 줄), measure.*, CI, live 탐침 |
| M2 | unit.perm.*, unit.caps(M2 줄), unit.config.layers, unit.secret.*, fuzz(M2 줄), e2e(M2 줄) |
| E | e2e.direct-mode. 평가는 13 |
| M3 | scn(M3 줄), unit.caps(M3 줄), unit.fe.*, unit.config.trust, unit.prompt.agents-md, fake.net-fetch, pty.*, linux.termios |
| M4 | scn.compact, scn.context-overflow, scn.cache-warning, gold.compact, gold.stats, unit.obs.cost, unit.session.crash-fill, e2e.crash-resume, e2e.resume |
| M5 | linux.sandbox, unit.sandbox.fallback, unit.perm.sandbox-false, ci.release, chain.agent |

TLA+ 모델(ADR 0030 결정 8 B7)은 M2의 판단 줄이다(TODO). 둔다면 07 리플레이의 관찰열을 재료로 쓴다.

## 열린 것

사용자가 정한다. 추천은 근거와 함께 적고 정하지 않았다.

1. 모의 provider를 루프에 끼우는 자리
   - 선택지: (a) provider 앞에 응답의 원천을 tagged union(http, replay)으로 두고 루프는 그 union을 받는다. (b) Format enum에 mock을 더한다. (c) 모의 provider를 두지 않고 모든 시나리오를 가짜 HTTP 서버로 돌린다.
   - 추천: (a).
   - 근거: 리플레이는 07에 이미 있는 기능이고(죽은 세션의 재현) 출하하는 실행 파일에도 든다. Format은 전송 형식이라 mock은 뜻이 다르다. (c)는 모든 시나리오가 소켓과 스레드를 지나 느리고, Zig 0.17.1 HTTP의 주의(deps.md)가 루프 테스트에 섞인다. HTTP 수준은 fake.*와 e2e가 따로 본다. tagged union은 ADR 0031 결정 3의 Format switch와 같은 꼴이다.

2. 시계, 난수, 세션 ID, 잠자기를 주입하는 자리
   - 선택지: (a) 코어의 진입점이 io와 함께 환경 값(시계, ID 원천, 잠자기)을 인자로 받는다. (b) 모듈 전역을 테스트에서 바꿔 끼운다. (c) 주입하지 않고 골든과 단언에서 그 값을 가린다.
   - 추천: (a).
   - 근거: 세션 줄의 ts와 세션 ID, 재시도 백오프(02)가 결정적이어야 골든과 시나리오가 바이트로 맞고 백오프 테스트가 잠들지 않는다. ADR 0030은 전역 Io 접근자를 받지 않고 io를 인자로 넘긴다. 같은 방향이다. fx의 복구 모듈도 시계를 호출자가 넘긴다(fx 검토 2절 1).

3. 시나리오의 모양
   - 선택지: (a) 모의 provider의 줄은 데이터(07 형식의 model.jsonl), 단언은 Zig 코드. (b) 모두 Zig 코드. (c) 모두 데이터(기대도 jsonl).
   - 추천: (a).
   - 근거: 녹화한 세션이 손대지 않고 회귀 테스트가 된다(R-SESS-09). 단언은 시나리오마다 보는 것이 달라 코드가 읽기 쉽다. (c)는 기대 파일이 세션 파일 전체가 되어 작은 변경에 모든 기대가 바뀐다.

4. 골든 파일 갱신
   - 선택지: (a) `zig build test -Dupdate-golden`이 기대 파일을 다시 쓰고 git diff로 검토한다. (b) 손으로만 고친다. (c) 골든을 테스트 소스 안의 문자열로 둔다.
   - 추천: (a). CI는 이 옵션 없이 돈다.
   - 근거: 시스템 프롬프트와 요청 본문은 크고 자주 바뀐다. 손으로 맞추면 틀리기 쉽고, diff로 보는 것이 바뀐 뜻을 읽는 길이다. (c)는 큰 기대가 소스를 덮는다.

5. 녹화 SSE의 출처
   - 선택지: (a) live.record가 녹화하고 가린 뒤 넣는다. 녹화로 얻지 못한 경우는 손으로 쓰고 메타 줄에 적는다. (b) 모두 손으로 쓴다. (c) 녹화만 쓴다.
   - 추천: (a).
   - 근거: 상류에 따라 모양이 다르다(10: 두 번 오는 finish_reason, 0인 사용량, null 캐시 필드). 손으로는 모르는 모양을 만들 수 없다. 10 "확인하지 않은 것"(잘린 도구 호출, 스트림 중간 오류)은 녹화가 어려울 수 있어 손으로 쓴 원문이 필요하다. 손으로 쓴 것은 추측이라 표시해 둔다.

6. CI의 장소
   - 선택지: (a) GitHub Actions. 워크플로는 zig build 단계만 부르고 제3자 action을 쓰지 않는다. (b) CI 없이 개발 기계의 스크립트로만. (c) 다른 CI 서비스.
   - 추천: (a).
   - 근거: 원격 저장소와 릴리스가 GitHub이다(R-DIST-01). tars-linux와 cyber가 GitHub Actions를 쓴다. 단계를 zig build에 두면 개발 기계에서 같은 것을 돌리고 CI 서비스에 묶이지 않는다.

7. Linux 러너
   - 선택지: (a) macOS 러너에서 x86_64-linux-gnu 교차 빌드만 한다. (b) x86_64 Linux 러너에서 네이티브 빌드와 테스트도 돌린다.
   - 추천: (b).
   - 근거: 산출물은 x86_64 Linux에서 돈다. x86_64에서만 드러나는 결함이 실제로 있었다(08의 AVX2 문자열 검색). 프로세스 그룹, termios, Landlock은 Linux 경로다. 교차 빌드는 컴파일만 본다. 러너 커널의 Landlock ABI와 CPU의 AVX2 여부는 확인하지 않았다.

8. 경계 검사의 구현
   - 선택지: (a) Zig로 쓴 검사 도구(tools/check/)를 zig build check가 부른다. (b) 셸 스크립트와 git grep(fx의 방식).
   - 추천: (a).
   - 근거: 두 러너와 개발 기계에서 같은 도구가 돌고 외부 프로그램에 기대지 않는다. 건너 import까지 보려면 import 그래프를 만들어야 해서 grep 한 줄로 끝나지 않는다. check.link의 심볼 표 읽기도 같은 도구에 둔다.

9. fuzz 찾기의 실행
    - 선택지: (a) 손으로, 디코더를 고친 뒤와 릴리스 전. (b) CI의 예약 실행.
    - 추천: (a). Zig 0.17.1의 `--fuzz`가 두 러너에서 도는지 확인한 뒤 (b)를 다시 본다.
    - 근거: `--fuzz`의 동작과 실패 보고를 우리 빌드에서 확인하지 않았다. 확인하지 않은 도구를 CI에 걸면 초록이 아무것도 말하지 않는다.
