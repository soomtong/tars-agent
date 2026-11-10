# 내장 호스트 함수

호스트 함수 계약은 호스트 구현 방식 A, B에서 같게 유지한다. 아래는 초안이며 시그니처는 프로토타입에서 확정한다. 사양 주석은 영어로 쓴다 (모델이 읽는 사양, 짧은 문장).

원칙: 전용 함수 소수 + 셸 하나. 역할이 겹치는 함수는 만들지 않고 사양에 이웃과의 경계를 적는다.

## 파일

- read(path, offset = 0, limit = 2000) -> !str : 줄 번호를 붙여 반환, 초과 시 절단 표시. 읽기 전용
- glob(pattern, path = '.') -> ![]str : 수정 시각 최신순. 읽기 전용
- search(pattern, glob = '', path = '.', max = 200) -> !str : path:line: text 형식. 내용 검색은 이것을 쓰고 셸 grep을 쓰지 않는다. 읽기 전용
- edit(path, old, new, replace_all = false) -> !str : old가 유일하지 않으면 실패하고 일치 개수를 알린다. 전제: 같은 세션에서 read 선행. 파괴적
- write(path, content) -> !str : 신규 또는 전체 교체. 기존 파일 덮어쓰기는 read 선행. 파괴적

## 셸과 작업

- shell(cmd, timeout_ms = 120000) -> !ShellResult : stdout, stderr, exit code. stdin은 닫는다. 명령 문자열을 파싱해 위험도를 2차 분류한다 (05)
- shell_start(cmd) -> !int : 작업 ID 반환
- task_output(id) -> !str : 새 출력 조회
- task_kill(id) -> !str : 하네스가 시작한 작업만 종료

## 데이터 유틸 (표준 라이브러리 공백 보충)

- json_parse(text) -> !JsonValue, json_str(value) -> str
- regex_find(pattern, text) -> ![]Match
- now() -> int

## 상태

- note(key, value), recall(key) : panic으로 main 변수가 사라져도 남는 작업 메모. 호스트가 보관한다
- todo 목록 함수 (후속)

## 사양 조회 (지연 로딩)

- help(name = '') -> str : 이름이 없으면 함수 목록 한 줄씩, 있으면 전체 사양. 시스템 프롬프트에는 핵심 함수만 싣는다.

## tars 특화 (후속, 읽기 전용부터)

- service_status(name) : tars 서비스 제어의 상태 조회
- journal(unit, lines) : 로그 조회
- 구체 목록은 tars-linux의 service-control, daemon-supervision 설계 문서를 읽고 정한다.
