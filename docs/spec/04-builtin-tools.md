# 내장 도구

초기에는 전용 도구 소수와 셸 하나로 시작한다. 역할이 겹치는 도구는 만들지 않고, 설명에 이웃 도구와의 경계를 적는다.

설명은 영어로 쓴다 (모델이 읽는 사양, 짧은 문장). 아래는 초안이다.

## read

- 요약: 파일 내용을 줄 번호와 함께 반환
- 인자: path (필수), offset, limit
- 상한: 기본 2000줄. 초과 시 절단 표시
- 읽기 전용
- 사용 안 함: 파일 이름 검색(glob 사용), 내용 검색(search 사용)

## search

- 요약: 정규식으로 파일 내용 검색. path:line: text 반환
- 인자: pattern (필수), glob, path, max_results (기본 200)
- 읽기 전용
- bash + grep 대신 사용. 이름으로 찾으려면 glob

## glob

- 요약: 패턴으로 파일 이름 검색. 수정 시각 최신순
- 인자: pattern (필수), path
- 읽기 전용

## edit

- 요약: 파일에서 old_string을 new_string으로 정확히 치환
- 인자: path, old_string, new_string, replace_all
- 전제: 같은 세션에서 read 선행. 없으면 오류로 알린다
- old_string이 유일하지 않으면 실패하고 일치 개수를 알려준다
- 파괴적: ask 기본

## write

- 요약: 파일 전체를 새로 쓴다 (신규 생성 또는 전체 교체)
- 기존 파일 덮어쓰기는 read 선행 필요
- 파괴적: ask 기본

## bash

- 요약: 셸 명령 실행. stdout/stderr/exit code 반환
- 인자: command (필수), timeout_ms, run_in_background
- 비대화형 강제 (stdin 닫기). TTY 요구 프로그램은 실패 메시지로 알린다
- 백그라운드 실행 시 작업 ID 반환
- 명령 문자열을 파싱해 위험도 2차 분류 (05 문서)

## bash_output / bash_kill

- 백그라운드 작업의 새 출력 조회 / 종료
- 종료 대상은 하네스가 시작한 작업 ID로 한정 (다른 프로세스 종료 금지)

## 후속 후보

- fetch (URL 읽기), journal (systemd 로그 조회), service (서비스 상태 조회, 읽기 전용), todo (작업 목록)
- tars-linux 특화 도구는 배포판 확인 후 결정
