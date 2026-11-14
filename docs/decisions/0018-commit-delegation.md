# 0018 커밋과 push는 Claude가 알아서 한다

상태: 사용자 지시 (2026-11-10). "commit; remember, commit job is up to you. If there are meaningful changes exist, you can make commit easily.", "push it; push is up to you too"

## 결정

의미 있는 변경이 생기면 묻지 않고 커밋하고 push한다. 시점과 묶는 단위는 Claude가 정한다.

## 적용

- 작업 한 덩어리(문서 재검토, 결정 하나, 단계 하나)가 끝나면 커밋하고 push한다. 깨진 중간 상태는 커밋하지 않는다.
- 메시지 규칙은 그대로다: 접두사 없음, 첫 글자 대문자, 80자 이내.
- 이 저장소는 main에 직접 커밋해 왔다. 그대로 따른다.
- 위임은 보통의 push까지다. force push, 히스토리 재작성, 태그와 릴리스는 지시를 받고 한다 (Claude의 해석).
- 이 저장소(tars-agent)에 대한 지시다. cyber와 tars-linux는 각 저장소의 규칙을 따른다.
