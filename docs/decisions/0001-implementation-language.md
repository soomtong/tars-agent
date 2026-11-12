# 0001 구현 언어와 실행 모델

상태: 확정 (방향), 호스트 방식은 0002

## 결정

에이전트는 CodeAct 방식이고 실행 언어는 Cyber(soomtong/cyber fork)다. 모델이 쓴 Cyber 스크립트를 libcyber VM이 실행하고, 도구는 호스트 함수로 연다.

## 근거

- 프로젝트 목표가 Cyber로 만든 tars-linux용 에이전트다.
- cyber fork 쪽 검토에서 이미 이 용도를 상정해 중단/연료(fuel), validate, 호스트 함수 소유 규약, deny_raw_ptrs를 구현했다.
- 작은 런타임(libcyber 2.1 MB, VM당 약 2 MB)과 빠른 시작(두 번째 eval 0.01 ms)이 내장 에이전트에 맞다.

## 위험

08 문서 참고. 가장 큰 위험은 모델의 Cyber 정확도다. 0006이 대조군(direct 모드)과 판정 기준을 정했다. 그 밖에 능력 함수 안 블록, 표준 라이브러리 공백(JSON, 정규식, 날짜).
