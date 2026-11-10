# 내장 능력

원칙: 전용 능력 소수와 프로세스 실행. 역할이 겹치는 능력은 만들지 않고 사양에 이웃과의 경계를 적는다. 시그니처는 M0 스파이크와 평가에서 확정한다.

## v1 목록

| 능력 | 등급 | 요약 |
|---|---|---|
| fs.read(path, offset = 0, limit = 2000) -> !str | read | 줄 번호를 붙여 반환 |
| fs.list(path = '.') -> ![]str | read | 디렉터리 한 층. 디렉터리는 끝에 / |
| fs.glob(pattern, path = '.') -> ![]str | read | 수정 시각 최신순, 상한 200 |
| fs.stat(path) -> !Stat | read | 종류, 크기, mtime |
| fs.search(pattern, path = '.', glob = '', max = 200) -> !str | read | 내용 검색. path:line: text |
| fs.edit(path, old, new, replace_all = false) -> !str | write | 문자열 정확 치환 |
| fs.write(path, content) -> !str | write | 신규 생성 또는 전체 교체 |
| proc.exec(argv, timeout_ms = 120000) -> !ExecResult | exec | 셸 없이 실행. stdout, stderr, code |
| proc.sh(cmd, timeout_ms = 120000) -> !ExecResult | exec | /bin/sh -c. 파이프와 리다이렉션이 필요할 때만 |
| proc.start(argv) -> !int | exec | 백그라운드 작업 ID |
| proc.output(id) -> !str | read | 새 출력과 상태 |
| proc.kill(id) -> !str | exec | 하네스가 시작한 작업만 |
| net.fetch(url, method = 'GET', body = '') -> !HttpResult | net | 상태, 본문(상한) |
| ui.ask(question, options) -> !str | ui | 사용자에게 선택지를 묻는다 |
| ui.todo(items) -> !str | ui | 할 일 목록 전체를 교체한다 |
| memo.set(key, value) -> !str, memo.get(key) -> !str | pure | 변수 초기화와 재개에도 남는 메모 |
| clock.now() -> int | pure | 유닉스 밀리초. 시계 읽기만 능력이고 계산은 표준 모듈 time |
| help(name = '') -> str | pure | 능력 목록 또는 한 능력의 전체 사양 |

## 능력별 메모

fs.read
- 줄 번호는 항상 붙인다. 2,000줄이나 상한을 넘으면 절단 사실과 다음 offset을 알린다.
- 읽은 파일을 세션의 파일 상태에 기록한다 (03).

fs.search
- 구현은 ripgrep 프로세스다. tars devlayer에 있다. 없으면 시작할 때 알리고 능력을 싣지 않는다.
- pattern은 ripgrep 정규식이다. 사양에 적는다.
- .gitignore를 따른다. 결과 상한을 넘으면 파일별 건수로 요약한다.

fs.edit
- old가 없으면 실패. 여러 곳이면 실패하고 일치 개수를 알린다 (replace_all = true 제외).
- 전제: 같은 세션에서 fs.read 선행, 읽은 뒤 파일이 바뀌지 않았을 것.
- 결과로 바뀐 줄 범위와 앞뒤 몇 줄을 돌려준다. 다시 읽지 않아도 된다.
- 승인 프롬프트는 diff를 보인다.

fs.write
- 기존 파일을 덮어쓰려면 fs.read가 선행해야 한다. 부모 디렉터리는 만든다.

proc.exec, proc.sh
- 둘로 나눈 이유는 권한이다. proc.exec는 인자 배열이 그대로 실행되므로 규칙을 인자 앞부분에 정확히 맞출 수 있다 (git status 허용 등). proc.sh는 문자열을 셸이 해석하므로 하네스가 뜻을 판정하지 않는다. 문자열 전체가 허용 규칙과 일치하거나 샌드박스 안일 때만 자동 허용한다 (05).
- CodeAct에서는 파이프의 대부분이 필요 없다. 출력 가공은 스크립트가 한다. 사양에 proc.exec를 먼저 쓰라고 적는다.
- 출력은 stdout과 stderr를 따로 모으고 각각 상한을 둔다.

net.fetch
- http, https만. 본문 상한 기본 100,000자. HTML은 텍스트로 줄이지 않고 그대로 준다 (v1).
- 이 능력이 한 번이라도 불리면 세션에 외부 입력 표시가 선다 (05 프롬프트 인젝션).

ui.ask
- 승인과 별개의 질문 채널이다. 선택지 2~4개와 직접 입력. 헤드리스에서는 오류 값을 돌려준다.

ui.todo
- 목록 전체를 받는다. 항목은 내용과 상태(pending, doing, done). 프런트엔드가 그리고, 컴팩션 요약과 재개에 실린다.

memo
- 호스트가 보관하고 세션 파일에 기록한다. 값 상한 10,000자.
- 변수는 panic과 인터럽트에 초기화되므로, 여러 스텝에 걸쳐 남길 값은 여기에 둔다.

## 능력이 아닌 것: Cyber 표준 모듈 (ADR 0010)

세계에 닿지 않는 순수 계산은 능력이 아니라 cyber 표준 모듈이다. 게이트와 감사 기록을 지나지 않는다. 없는 것은 soomtong/cyber에 만든다 (08 문서의 목록).

| 모듈 | 내용 | 상태 |
|---|---|---|
| core, math | 문자열, Array, Map, 수학 | 있음 |
| json | parse, stringify, 값 트리 타입과 접근 함수 | 만든다 |
| regex | 컴파일, 찾기, 모두 찾기, 치환, 나누기. 역추적 없는 엔진 | 만든다 |
| time | 유닉스 시각과 달력 날짜 변환, ISO 8601 형식과 해석, 기간 계산 | 만든다 |

- 시그니처는 cyber 쪽 설계에서 정한다. 기준은 모델이 다른 언어에서 익힌 모양에 가깝게 하는 것이다.
- 시계 읽기는 세계에 닿으므로 능력 clock.now다. time 모듈은 받은 값을 계산만 한다.
- fs.search의 pattern은 ripgrep 정규식이고 regex 모듈과 문법이 다를 수 있다. 차이를 사양에 적고, 가능하면 regex 모듈의 문법을 ripgrep 기본 문법의 부분집합으로 잡는다.

## 후속 능력

| 능력 | 등급 | 조건 |
|---|---|---|
| agent.run(prompt) -> !str | exec | 서브에이전트. 별도 VM과 히스토리, 요약만 반환 |
| mcp.서버.도구 | 서버 설정, 없으면 exec | MCP 클라이언트 (06) |
| tars.window.list, tars.window.focus | read, ui | tars 터미널에 제어 채널이 생긴 뒤 |
| tars.terminal.read, tars.terminal.send | read, exec | 위와 같음 |
| tars.notify | ui | 위와 같음 |
| tars.service.status(name) | read | tars-service 조회 |

tars.* 능력은 모의 구현을 만들지 않는다. 실제 상대가 없는 모의는 검증하는 것이 없다. tars-linux 쪽 서브프로젝트로 제어 채널을 설계한 뒤 함께 만든다.
