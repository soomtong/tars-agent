# 커밋은 Claude가 알아서 한다

상태: 사용자 지시 (2026-11-10, "commit; remember, commit job is up to you. If there are meaningful changes exist, you can make commit easily.")

## 규칙

의미 있는 변경이 생기면 묻지 않고 커밋한다. 커밋 시점과 묶는 단위는 Claude가 정한다.

## 적용

- 작업 한 덩어리(문서 재검토, 결정 하나, 단계 하나)가 끝나면 커밋한다. 깨진 중간 상태는 커밋하지 않는다.
- 메시지 규칙은 그대로다: 접두사 없음, 첫 글자 대문자, 80자 이내.
- 이 지시는 커밋에 대한 것이다. push는 지시받지 않았으므로 사용자가 말할 때 한다.
- 이 저장소는 main에 직접 커밋해 왔다. 그대로 따른다.
