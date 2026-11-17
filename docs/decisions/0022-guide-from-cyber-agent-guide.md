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

- 지금은 같은 안내를 두 저장소가 손으로 따로 고친다(tars-agent의 prompt/cyber-subset.en.md, cyber의 docs/agent-guide.md). 기준 빌드를 올릴 때마다 두 사본을 줄 단위로 맞춰야 한다.
- 언어 설명은 cyber의 릴리스와 함께 cyber 쪽에서 검증된다. 기준 빌드를 올리면 안내도 함께 올라간다.
- 두 문서의 차이는 호스트에 관한 줄뿐이다. 오류 목록, 메서드 목록, 예제 1~10이 같다.

## 선행 조건

- cyber 패키지가 `docs/agent-guide.md`를 담고 있어야 한다. 기준 빌드의 패키지에 들어 있다. 모듈 API `docs/api.json`도 들어 있다(0.4.14부터). 둘 다 s1 검사 0b가 빌드 때 읽는다.

아래 "열린 것"을 정하기 전까지 스파이크는 prompt/cyber-subset.en.md와 prompt/cyber-subset.md를 쓴다.

## 열린 것

agent-guide.md가 정본이고 tars-agent의 문서는 정본이 아니다. 덧붙임은 가이드를 바로잡지 않는다. 지금은 제약을 늘리기보다 열어 두고 살펴보는 단계다(2026-11-16 사용자 지시). cyber와 tars-agent가 함께 바뀌는 중이므로 맞추는 일은 천천히 한다.

가이드와 스파이크 세션이 다른 곳은 아래와 같다. 대부분은 가이드의 문제가 아니라 tars-agent의 선택이거나 실행 환경의 차이다.

- `## Modules`의 `test`와 예제 11(`use test`): 스파이크 로더가 막는다. `json`, `toon`, `regex`, `peg`, `time`은 연다(ADR 0024, 0025).
- Principles의 "fibers ... only when you must": 스파이크 안내는 fiber를 쓰지 않게 했다. 근거가 없으면 본체에서 뺀다.
- `os` 모듈(오류 절의 `os.write_file` 예 포함): 이 호스트에서는 `fs`, `proc` 능력과 가두기를 거쳐야 바깥에 닿는다. 실행 환경의 사실이다.
- `## Running and checking code`(`cyber main.cy`, `cyber fmt`, `cyber doc`): 세션에서는 run 도구로 코드를 돌린다. 실행 환경의 사실이다.

가이드는 머리말에서 임베딩 호스트의 지시가 실행 방법과 모듈에 대해 가이드보다 앞선다고 말하고, `## Modules`에서 거부된 모듈의 문구(`Failed to load module: name` 등)와 "다시 시도하지 말라"를 말한다(cyber def798e9, 2026-11-17 요청). 그래서 위 네 곳은 덧붙임이 이 호스트의 사실을 말하면 되고 가이드와 다투지 않는다. 모듈 API는 가이드가 `cyber doc --api <module>`을 가리키고 "호스트가 다른 길로 줄 수 있다"고 말한다.

## 버린 대안

- prompt/cyber-subset을 따로 두고 손으로 맞춘다. 지금의 방식이다. 사본이 어긋나고 기준 빌드마다 다시 맞춰야 한다.
