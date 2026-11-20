# 설정과 명령행

이 문서는 다른 문서에 흩어진 설정 키, 명령행 인자, 환경 변수, 파일 위치, 종료 코드를 한곳에 모은 색인이다. 뜻의 정본은 각 행이 가리키는 문서다. 제공자 항목의 칸과 키 읽기는 10 "제공자 설정"과 "키"를 본다.

## 파일 위치

사용자 설정 디렉터리는 $XDG_CONFIG_HOME/tars-agent 하나다($XDG_CONFIG_HOME이 없으면 ~/.config). settings.json, credentials, AGENTS.md가 모두 이 디렉터리를 따르고, 05의 보호 규칙과 기본 deny 규칙도 같은 디렉터리를 가리킨다.

| 위치 | 내용 | 정의 |
|---|---|---|
| $XDG_CONFIG_HOME/tars-agent/settings.json | 사용자 설정 | 05 |
| $XDG_CONFIG_HOME/tars-agent/credentials | API 키 파일. `KEY_ENV이름=값` 줄의 모음. 권한 0600이 아니면 읽지 않는다 | 05 비밀, 10 |
| $XDG_CONFIG_HOME/tars-agent/AGENTS.md | 사용자 지시 파일 | 06 |
| <프로젝트>/.tars-agent/settings.json | 프로젝트 설정. 저장소에 커밋한다 | 05 |
| <프로젝트>/.tars-agent/settings.local.json | 개인 설정. 승인 선택지 3의 규칙이 쌓인다 | 05 |
| <프로젝트>/.tars-agent/commands/*.md | 사용자 슬래시 명령 (후속) | 06 |
| 작업 디렉터리에서 저장소 루트까지의 AGENTS.md | 프로젝트 지시 파일. 바깥에서 안쪽 순서로 읽는다 | 06 |
| $XDG_STATE_HOME/tars-agent/trust.json (기본 ~/.local/state) | 프로젝트 설정 수락. 프로젝트 경로마다 수락한 내용의 해시 | 05 2층 |
| $XDG_STATE_HOME/tars-agent/sessions/<작업 디렉터리 해시>/<세션 ID>.jsonl | 세션 파일. 권한 0600 | 07 |
| 위 디렉터리의 <세션 ID>/out/, files/, crash/ | 넘침 파일, 쓰기 전 보관본, 죽기 직전의 스크립트 | 03, 07 |
| 위 디렉터리의 <세션 ID>/lock | 세션 쓰기 잠금 (flock, pid) | 07 |
| $TMPDIR/tars-agent-<세션 ID> ($TMPDIR가 없으면 /tmp) | 세션 임시 디렉터리. 샌드박스가 작업 디렉터리 밖에서 쓰기를 허용하는 곳. 권한 0700, 세션이 끝나면 지운다 | 05 3층 |

<프로젝트>는 작업 디렉터리에서 위로 올라가며 처음 만나는 .tars-agent/ 디렉터리를 가진 곳이다. 올라가는 끝은 저장소 루트(그것도 본다)이고, 저장소 밖이면 작업 디렉터리만 본다. 찾지 못하면 <프로젝트>는 저장소 루트, 저장소 밖이면 작업 디렉터리다(승인 선택지 3이 여기에 settings.local.json을 만든다). 세션 디렉터리의 해시는 작업 디렉터리 기준이다(07).

## 환경 변수

하네스가 읽는 것

| 변수 | 쓰임 | 정의 |
|---|---|---|
| XDG_CONFIG_HOME | 사용자 설정 디렉터리의 바탕. 없으면 ~/.config | 05 |
| XDG_STATE_HOME | 세션 디렉터리와 수락 기록의 바탕. 없으면 ~/.local/state | 07 |
| TMPDIR | 세션 임시 디렉터리의 바탕. 없으면 /tmp | 05 3층 |
| HOME | ~ 풀이 (설정 파일 위치, 규칙의 ~/) | 05 |
| 제공자 항목의 key_env가 가리키는 변수 | API 키. 지금은 DEEPSEEK_API_KEY, OPENROUTER_API_KEY. 변수를 먼저 보고 없으면 credentials 파일을 본다. 모든 항목의 변수를 자식 환경에서 지운다 | 05 비밀, 10 |

스크립트가 간접으로 읽는 것

| 변수 | 쓰임 | 정의 |
|---|---|---|
| TZ | 표준 모듈 time의 time.local()이 /etc/localtime 대신 읽는다 | 08 |

하네스가 자식 프로세스(proc.*)에 거는 것: 작업 디렉터리 고정, stdin 닫기, TERM=dumb, 페이저와 색 끄기, 하네스의 비밀 변수 지우기 (03).

## 설정 파일

형식은 JSON이다 (ADR 0007). 세 층이고 아래일수록 우선한다. 정본은 05 2층이다.

~~~text
$XDG_CONFIG_HOME/tars-agent/settings.json  사용자 (기본 ~/.config)
<프로젝트>/.tars-agent/settings.json        프로젝트 (저장소에 커밋)
<프로젝트>/.tars-agent/settings.local.json  개인 (승인 기억이 여기에 쌓인다)
~~~

- 값 하나짜리 키는 아래 층이 이긴다. 객체 키(permissions, limits, profiles)는 필드마다 합치고, 각 필드는 값 하나짜리 키처럼 아래 층이 이긴다. permissions의 allow, ask, deny 목록은 층을 이어 붙인다. providers는 name마다 합치고 같은 name이면 항목을 통째로 덮는다(10).
- 판정은 합친 목록에서 deny 규칙을 먼저 보므로 어느 층의 deny든 다른 층의 allow보다 먼저 걸린다 (05).
- 명령행 인자는 모든 층보다 우선한다. --allow는 합친 allow 목록에 더하므로 설정의 deny를 풀지 못한다.
- 프로젝트 파일(settings.json)이 넓히는 값(allow 규칙, profiles와 profile, permissions.default_mode, providers와 provider)은 그 디렉터리를 처음 열 때 사용자에게 보이고 수락을 받는다. 수락은 trust.json에 프로젝트 경로와 수락한 내용의 해시로 기억하고, 내용이 바뀌면 다시 묻는다. 헤드리스는 묻지 못하므로 수락되지 않은 값을 빼고 시작한다 (05).
- bypass 모드는 설정 파일로 켤 수 없다. 명령행의 --dangerously-bypass로만 켠다 (05).
- 해석할 수 없는 파일(JSON 문법, 해석할 수 없는 규칙, 모르는 모드 이름, permissions.default_mode의 bypass)은 시작을 거부하고 파일과 위치(줄, 열)를 stderr에 말한다. 권한 규칙이 든 파일을 건너뛰면 deny가 빠진 채 돌기 때문이다.
- 모르는 키는 stderr에 경고 한 줄을 쓰고 넘어간다. 새 판의 설정을 옛 판이 읽을 수 있다.
- tars의 설정 파일 tars.conf에는 에이전트의 키를 두지 않는다. 에이전트 설정은 위 세 층이다. tars.conf에는 필요가 생길 때만 키를 둔다 (09). 후보는 아래 열린 것 1.

## 설정 키

| 키 | 형식 | 기본값 | 정의 |
|---|---|---|---|
| provider | 문자열 (providers 항목의 name) | ds-anth | 10 |
| providers | 제공자 항목 배열. 칸은 name, format, url(전체 주소), auth, key_env, model | 내장 ds-anth, ds-oai, or-anth, or-oai | 10 "제공자 설정" |
| model | 문자열 (모델 ID). 고른 항목의 model을 덮는다 | 고른 항목의 model. 평가의 기본 모델은 13 | 02, 10, 13 |
| effort | 문자열 (사고 강도 힌트) | 보내지 않는다 | 02, 10 |
| max_tokens | 정수 | 4096 | 10 |
| profile | 문자열 (프로파일 이름) | 대화형 full, 헤드리스 readonly | 05 |
| profiles | 객체. 프로파일 이름마다 능력 이름 배열 | 내장 full, readonly | 05 |
| permissions.allow | 규칙 문자열 배열 | 빈 배열 | 05 |
| permissions.ask | 규칙 문자열 배열 | 빈 배열 | 05 |
| permissions.deny | 규칙 문자열 배열 | 빈 배열. 05 비밀의 기본 deny 규칙이 함께 걸린다 | 05 |
| permissions.default_mode | 모드 이름 (plan, default, accept-edits, auto). bypass는 받지 않는다 | default | 05 |
| limits.max_steps | 정수. 턴당 스텝 수 | 50 | 02 한도 |
| limits.step_wall_seconds | 정수. 스텝당 벽시계 (VM 안의 시간만) | 120 | 02 한도 |
| limits.session_tokens | 정수. 세션 토큰 예산 | 없음 | 02 한도 |
| limits.max_budget_usd | 수. 세션 비용 상한. 넘으면 stop이 budget이다 | 없음 | 02 한도, 06 |

- 시작 모드를 설정에 두는 것은 plan이나 accept-edits로 늘 시작하는 사용자를 위해서다. auto는 샌드박스가 없으면 accept-edits로 내려간다 (05).
- providers의 내장 항목과 키 읽기는 10 "제공자 설정"과 "키"에 있다.

이름이 정해지지 않은 설정

| 값 | 형식 | 기본값 | 정의 |
|---|---|---|---|
| 모델별 가격표 | 모델 ID마다 토큰 종류별 단가 | 정하지 않음 | 07 |

설정 키로 열지 않는 값 (상수)

아래 값은 모델과 하네스의 계약(사양 문구, 넘침 규칙)에 묶여 있거나 사용자가 바꿀 일이 없어 상수로 둔다.

| 값 | 기본값 | 정의 |
|---|---|---|
| 스텝당 연료(fuel) | M1 runtime 단계에서 재서 정한다 | 02 한도, 05 1층 |
| 같은 코드의 같은 오류: 경고, 턴 끝 | 3회, 5회 | 02 한도 |
| 제공자 오류 재시도 | 5회 (retry-after 존중) | 02 |
| 컴팩션 임계치 | 컨텍스트 창의 80% | 02 |
| 스크립트 결과 상한 | 20,000자. 넘치면 앞 200줄, 뒤 50줄 | 03 |
| 능력 반환값 상한 | 1 MiB. 넘치면 앞뒤 512 KiB | 03 |
| VM 스택 상한 | 8 MiB | 05 1층 |
| VM 메모리 상한 | 256 MiB | 05 1층 |
| net.fetch 본문 상한 | 100,000자 | 04 |
| memo 값 상한 | 10,000자 | 04 |
| AGENTS.md 합계 상한 | 40,000자 | 06 |

## 명령행

대화형

~~~text
tars-agent [공통 인자]               새 세션
tars-agent --continue               이 디렉터리의 마지막 세션을 잇는다
tars-agent --resume ID              세션 ID로 잇는다
tars-agent --dangerously-bypass     bypass 모드로 시작한다
~~~

첫 프롬프트를 위치 인자로 받지 않는다. -p와 헷갈린다.

공통 인자 (대화형과 헤드리스가 함께 받는다)

| 인자 | 뜻 | 정의 |
|---|---|---|
| --continue | 작업 디렉터리의 마지막 세션을 잇는다. 잠금을 잡지 못하면 거부한다 | 02, 07 |
| --resume ID | 세션 ID로 잇는다. 대화형 안에서는 /resume이 고르기를 보인다 | 02, 06 |
| --dangerously-bypass | bypass 모드. 설정 파일과 --permission-mode로는 켤 수 없다 | 05 |
| --permission-mode M | 시작 모드. 값은 plan, default, accept-edits, auto. bypass는 받지 않는다. permissions.default_mode를 덮는다 | 05 |
| --allow 규칙 | allow 규칙을 합친 allow 목록에 더한다. 여러 번 준다 | 05 |
| --profile P | 프로파일. full, readonly, profiles로 정의한 이름. 프로파일은 세션 시작에만 정해지므로 대화형에서도 고르는 길이 이것이다 | 05 |
| --provider NAME | provider 키와 같은 값 | 10 |
| --model ID | model 키와 같은 값 | 02, 10 |
| --max-steps N | limits.max_steps와 같은 값 | 02 |
| --tool-mode M | codeact(기본) 또는 direct. direct는 같은 능력 표를 API 도구 여럿으로 노출하고 VM을 쓰지 않는다. 평가가 둘을 대조한다 | 01, 13, ADR 0006 |
| --help, --version | 사용법, 판 번호를 stdout에 쓰고 0으로 끝난다 | |

헤드리스

~~~text
tars-agent -p "프롬프트" [--output-format text|json|stream-json]
           [--permission-mode M] [--allow 규칙]... [--profile P]
           [--continue | --resume ID] [--max-steps N] [--max-budget-usd X]
           [--provider NAME] [--model ID] [--tool-mode codeact|direct]
           [--dangerously-bypass]
~~~

헤드리스만 받는 인자

| 인자 | 뜻 | 정의 |
|---|---|---|
| -p 프롬프트 | 헤드리스로 한 번 실행한다. stdin이 파이프면 프롬프트에 덧붙인다 | 06 |
| --output-format | text(마지막 답, 기본값), json(결과 객체 하나), stream-json(코어 이벤트를 줄마다) | 06 |
| --max-budget-usd X | limits.max_budget_usd와 같은 값 | 02, 06 |

- 결과는 stdout, 진행과 진단은 stderr에 쓴다 (06).
- 헤드리스에서 ask는 deny로 처리한다. 설정의 profile 키도 --profile도 없으면 프로파일은 readonly다. 권한 판정의 헤드리스 규칙은 05 헤드리스.

하위 명령

~~~text
tars-agent stats [세션 ID] [--all] [--json]
~~~

| 명령 | 뜻 | 정의 |
|---|---|---|
| tars-agent stats | 세션 파일들을 읽어 능력별 호출 수, 오류율, 평균과 최대 결과 크기, 실패 종류별 스텝 비율을 낸다. 잠그지 않는다. 깨진 줄은 건너뛰고 그 수를 보인다 | 07 |

- 기본 대상은 작업 디렉터리의 세션들이다(세션 디렉터리가 작업 디렉터리 해시로 나뉜다, 07). --all은 모든 디렉터리의 세션, 세션 ID를 주면 그 세션 하나다.
- 출력은 표이고 --json은 평가 도구가 읽는 기계 형식이다.

## 슬래시 명령

정본은 06 대화형 프런트엔드다. 여기에는 이름만 둔다.

| 명령 | 동작 |
|---|---|
| /help | 명령과 키 |
| /clear | 새 세션 (VM도 새로) |
| /compact [지시] | 컴팩션 (02) |
| /resume | 세션 고르기 |
| /mode [이름] | 권한 모드 (05) |
| /model [이름] | 모델 (다음 세션부터) |
| /cost | 토큰과 비용 (07) |
| /permissions | 현재 규칙 보기 |
| /quit | 종료 |

입력 접두: ! 는 셸 명령을 사용자 권한으로 바로 실행하고 출력을 대화에 넣는다. @경로 는 파일 첨부 (후속). 후속 명령: /rewind, /init, 사용자 슬래시 명령 (06).

## 종료 코드

헤드리스의 종료 코드다. json 결과의 exit_code가 이 코드이고, stop은 오른쪽 열의 값이다 (06, ADR 0030).

| 코드 | 뜻 | stop |
|---|---|---|
| 0 | 성공 | end_turn |
| 1 | 실행 오류, 시작하기 전의 실패 | error, refusal |
| 2 | 한도 초과 | max_steps, budget, repeated_error |
| 3 | 권한 거부로 중단 | permission_denied |
| 130 | 사용자 인터럽트 (SIGINT, 셸 관례 128+2) | interrupted |

- repeated_error는 같은 코드가 같은 오류로 5회 실패해 끝난 턴이다 (02 한도).
- permission_denied는 ask를 deny로 바꾼 호출이 나와 그 스크립트 뒤에 턴을 끝낸 것이다 (05 헤드리스). deny 규칙과 모드의 deny는 턴을 끝내지 않는다.
- 시작하기 전의 실패(인자 오류, 설정 해석 실패, 세션 잠금 실패, 키 없음)는 대화형과 헤드리스 모두 1이다. json을 쓰지 않고 stderr의 문구로 가른다. 사용법 오류에 2를 쓰는 관례는 따르지 않는다. 2는 이미 한도 초과라 평가와 tars 게이트 스크립트가 가르지 못한다.
- 대화형은 /quit와 Ctrl+C 두 번으로 끝나면 0이다.

## 사용자 문서

tars-agent를 쓰는 사람이 읽는 문서다 (TODO M5). 다루는 것은 넷이다.

| 주제 | 정본 |
|---|---|
| 설치: tars devlayer로 들어오는 실행 파일, macOS 개발 빌드 | 01 저장소와 배포, ADR 0005 |
| 키 설정: 제공자 항목의 key_env, credentials 파일과 권한 0600 | 10 키, 이 문서의 환경 변수와 파일 위치 |
| 권한 규칙: 설정 파일 세 층, 규칙 문법, 보호 규칙, 프로젝트 설정 수락 | 05 2층, 이 문서의 설정 파일 |
| 모드: 다섯 모드와 바꾸는 법(Shift+Tab, /mode, --permission-mode, --dangerously-bypass) | 05 2층, 06 |

- 사용자 문서는 명세에서 옮겨 쓴 판이다. 어긋나면 명세가 맞고 사용자 문서를 고친다.
- 명세처럼 지금 참인 것만 적는다 (ADR 0020).
- 자리와 모양은 아래 열린 것 2.

## 열린 것

구조에 닿으므로 사용자가 정한다 (ADR 0012). 추천은 Claude의 것이다.

1. tars.conf에 둘 키 (TODO M5)
   - 사실: 09는 "설정은 tars.conf"였던 지시서 요구를 "에이전트 설정은 settings.json 세 층, tars.conf에는 필요가 생길 때만"으로 바꿨다. 승인 키는 숫자 키로 고정이고(05) 대화형은 패널 하나에서 돌아 패널 API가 필요 없다(09). tars.conf가 지금 무엇을 담는지는 이 세션에서 확인하지 않았다.
   - 선택지: (a) 두지 않는다. (b) tars 쪽에서 에이전트를 띄우는 데 필요한 값만 둔다(예: 에이전트 패널을 여는 키, 실행 파일 경로). 이것은 tars가 읽는 키이고 tars-agent는 읽지 않는다. (c) 에이전트 설정 일부를 tars.conf에서도 읽는다.
   - 추천: tars-agent 쪽은 (a). (b)가 필요하면 tars-linux의 결정이고 요청서(docs/requests/)로 낸다(ADR 0013). 근거: 설정 원천이 하나 더 생기면 위 세 층에 합치는 규칙이 하나 더 생기고, 수락 절차(05)와 해석 실패 규칙도 그 파일에 걸어야 한다.

2. 사용자 문서의 자리와 모양 (TODO M5)
   - 선택지: (a) README.md 한 파일에 모은다. (b) docs/user/ 아래 주제마다 한 파일, README가 가리킨다. (c) --help와 man 페이지만 둔다.
   - 추천: (b)와 --help. 근거: 저장소의 docs/는 지금 에이전트와 개발자가 읽는 자료(명세, 결정, 검토)라 사용자 문서를 따로 둬야 섞이지 않는다. tars 게스트에서 저장소 문서를 읽을 수 있는지는 확인하지 않았다. 게스트에서 읽을 길은 실행 파일의 --help다.
