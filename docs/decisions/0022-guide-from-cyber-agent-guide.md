# 0022 Cyber 안내는 cyber의 agent-guide.md에 호스트 덧붙임을 붙여 만든다

상태: 사용자 결정 (2026-11-16). "둘째 안으로 가자, agents.md에 호스트 덧붙임". cyber는 그 뒤 파일 이름을 docs/agent-guide.md로 바꿨다.

## 결정

모델에게 주는 Cyber 안내의 정본은 cyber 저장소의 `docs/agent-guide.md`다. 이 문서는 `cyber doc --for-agents`가 내보내는 안내와 같다. tars-agent는 빌드할 때 고정한 cyber 의존에서 이 파일을 읽는다. 여기에 호스트 덧붙임(tars-agent 저장소의 파일)을 붙여 시스템 프롬프트의 안내 부분을 만든다. tars-agent는 언어 설명을 따로 고치지 않는다. 언어 설명이 틀리면 cyber에 요청서를 낸다.

덧붙임에는 이 호스트에서만 참인 것을 적는다.

- 능력(`fs`, `proc`과 그 뒤의 것). 미리 import되어 있고, 바깥에 닿는 길은 이것뿐이다.
- 로더가 막는 모듈과 그때 나오는 `Failed to load module` 문구.
- 세션 규칙: 최상위 변수가 run 사이에 남는다. 최상위 빌림 오류 문구(`Cannot persist local ... across evals.`).
- fiber와 `scope` 블록을 쓰지 말고 능력을 하나씩 차례로 부른다.
- CLI 명령(`cyber`, `cyber fmt`, `cyber doc`)이 세션에 없다는 것. 코드는 run 도구로 돌린다.

## 근거

- 0.4.12까지는 같은 안내를 두 저장소가 손으로 따로 고쳤다(tars-agent의 prompt/cyber-subset.en.md, cyber의 docs/agent-guide.md). 기준 빌드를 올릴 때마다 두 사본을 줄 단위로 맞춰야 했다.
- 언어 설명은 cyber의 릴리스와 함께 cyber 쪽에서 검증된다. 기준 빌드를 올리면 안내도 함께 올라간다.
- 두 문서의 차이는 호스트에 관한 줄뿐이다. 오류 목록, 메서드 목록, 예제 1~10이 같다(HEAD `fa72869e`에서 비교).

## 선행 조건

- cyber 패키지가 `docs/agent-guide.md`를 담고 있어야 한다. cyber master `54e61f48`에서 `.paths`에 들어갔고 `zig fetch`로 받은 패키지에 있는 것을 확인했다(요청서 (d)). push와 릴리스 전이다.

그 전까지 스파이크는 prompt/cyber-subset.en.md와 prompt/cyber-subset.md를 쓴다.

## 열린 것

agent-guide.md에는 호스트와 부딪히는 부분이 있다. 덧붙이기만 하면 모델이 서로 어긋난 지시를 함께 읽는다. 어떻게 다룰지는 사용자가 정한다.

- `## Running and checking code`: CLI로 돌리고 `cyber fmt`, `cyber doc`, `use test`를 쓰라고 한다.
- `## Modules`: `os`, `json`, `toon`, `regex`, `peg`, `time`, `test`를 쓸 수 있다고 한다. 스파이크 로더는 이 모듈을 막는다.
- 오류 절의 `os.write_file(p, s)` 예. 이 호스트에서는 `fs.write(p, s)`다.
- 예제 11(`use test`). 세션에서는 실패한다.
- Principles의 "fibers ... only when you must". 이 호스트는 fiber를 쓰지 않게 한다.

## 버린 대안

- prompt/cyber-subset을 따로 두고 손으로 맞춘다. 0.4.12까지의 방식이다. 사본이 어긋나고 기준 빌드마다 다시 맞춰야 한다.
