# 0028 test 모듈을 연다

상태: 사용자 결정 (2026-11-18). "허용한다."

## 결정

cyber의 표준 모듈 `test`(`assert`, `eq`, `eq_type`, `eq_slice`, `eq_span`, `eq_near`, `fail`)를 스크립트에 연다. 허용 목록은 core, meta, c, math, json, toon, regex, peg, time, path, test와 호스트 능력 모듈이다(ADR 0026).

## 근거

- `test`는 순수 Cyber 모듈이다. 네이티브 바인딩이 없고(cyber `src/std/test.zig`의 함수 표가 비어 있다) 세계에 닿지 않는다. 의존 모듈은 이미 허용된 `meta` 하나다. json, toon, regex, peg, path와 같은 부류다(ADR 0025, 0027).
- ADR 0026은 `test`를 "가르치지 않고 필요가 없다. 위험해서가 아니다"로 막았다. 그 전제가 바뀌었다. 안내의 정본인 cyber의 agent-guide.md(ADR 0022)가 첫머리에서 "For tests, write `use test`"를, Python 대응에서 "`assert` becomes `use test`"를 가르치고 예제 11이 `use test`다. tars-agent의 안내 두 판도 같은 줄을 담고 있다. 막아 두면 안내를 따른 모델이 `Failed to load module: test`로 스텝을 버린다.
- 코딩 에이전트는 고친 코드를 스스로 확인한다. `test.eq(expected, actual)`은 그 확인을 한 줄로 쓰게 한다.

## 확인한 것 (0.4.15, 세션)

- s1 검사 7a4: `use test` 뒤 `test.eq(3, 1 + 2)`, `test.eq_slice(...)`가 통과하고 출력이 이어진다. `test.eq(3, 1 + 1)`은 CL_ERROR_PANIC이고 문구는 ``panic: Expected `3`, found `2`.``다.
- 안내 두 판과 agent-guide.md의 코드 블록 34개가 세션(`s1 replay`)에서 모두 통과한다. 전에는 예제 11 하나가 로더에 막혔다.

## 비용과 적용

- 실패한 검사는 panic이다. panic 뒤에는 함수와 `use`는 남지만 앞선 eval의 최상위 지역이 사라진다(s1 검사 6k). 다른 panic과 같은 동작이고, 본체는 panic 뒤 최상위 변수가 사라졌다고 모델에게 알린다(검토 문서 9절 4).
- spike/s1, s2의 호스트 로더 허용 목록에 `test`를 넣었다. 모듈 API 거름(s1 `isAllowedApi`)에는 넣지 않았다. 안내가 이미 `test.eq`를 가르치고, 모듈 API를 프롬프트에 둘지는 따로 정한다.
- ADR 0022 "열린 것"의 `test` 줄이 닫혔다.
