# 0025 표준 모듈 json, toon, regex, peg를 연다

상태: 사용자 결정 (2026-11-17). "json, toon, regex, peg 추가해주세요. tars-agent를 사용하기 위해 우선적으로 만들어진 모듈입니다."

## 결정

표준 모듈 `json`, `toon`, `regex`, `peg`를 스크립트에 연다. `time`(ADR 0024)과 함께 다섯 모듈이 열린다. 호스트 로더는 허용 목록이다(ADR 0026): core, meta, c, math, json, toon, regex, peg, time, path(ADR 0027), test(ADR 0028)와 호스트 능력 모듈. 기본 로더가 아는 것 가운데 싣지 않는 것은 `io`, `cy`다.

## 근거

- 다섯은 cyber가 tars-agent를 위해 먼저 만든 모듈이다(ADR 0010, 08 문서 "cyber에서 만들 것"의 C1, C2). 필요의 증거는 08 문서에 있다. JSON 설정과 API 응답, 모델에게 돌려줄 결과의 토큰 절약(toon), 로그와 명령 출력에서 값 뽑기(regex), 그보다 큰 문법(peg)이다.
- json, toon, regex, peg는 순수 계산이다. 세계에 닿지 않으므로 능력 층을 거칠 이유가 없다.
- 스파이크에서 막았던 것은 0.4.12 비교 회차를 같은 조건으로 돌리기 위해서였다. 그 이유는 끝났다.

## 적용

- spike/s1, s2의 호스트 로더가 다섯 모듈을 싣는다(허용 목록, ADR 0026).
- 연다는 것과 가르친다는 것은 다르다. 모듈의 쓰는 법은 cyber의 agent-guide.md(ADR 0022)와 API 문서가 정본이다. tars-agent 안내에 예제를 넣을지와 크기는 안내를 모을 때(ADR 0022 "열린 것", 8절의 크기 결정) 정한다.
- 본체의 로더는 허용 목록으로 쓴다(core, meta, c, math, json, toon, regex, peg, time, path, test, 그리고 우리 능력 모듈. ADR 0026, 0027, 0028). meta와 c는 다른 모듈의 의존이다. 기본 로더가 주는 그 밖의 모듈(`io`, `cy`)은 싣지 않고, `os`, `libc`, `cli`는 라이브러리의 기본 로더에 없다(08).
