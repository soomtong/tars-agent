# 0027 path 모듈을 연다

상태: 사용자 결정 (2026-11-17). "path 모듈 허용합시다."

## 결정

cyber 0.4.14에 새로 생긴 표준 모듈 `path`(`join`, `base`, `dir`, `ext`, `stem`, `normalize`, `is_absolute`)를 스크립트에 연다. 허용 목록은 core, meta, c, math, json, toon, regex, peg, time, path와 호스트 능력 모듈이다(ADR 0026).

## 근거

- `path`는 경로 문자열만 다룬다. 구분자는 `/` 하나이고 파일 시스템을 보지 않는다(Go의 `path` 패키지와 같은 방식). 세계에 닿지 않으므로 능력 층을 거칠 이유가 없다. json, toon, regex, peg와 같은 부류다(ADR 0025).
- 코딩 에이전트의 스크립트는 경로를 자주 나누고 붙인다. 없으면 모델이 `split('/')`로 손으로 하거나, 학습 데이터의 `os.path.join`, `os.dirname`을 찾다가 컴파일 오류를 낸다. 0.4.14는 `os.baseName`, `os.dirname`을 빼고 `path.base`, `path.dir`로 옮겼다.
- 모듈에 `use`가 없어 의존 모듈이 늘지 않는다.

## 확인한 것 (0.4.14, 세션)

- s1 검사 7a3: `use path`가 실리고 `path.join('a', 'b/c.txt')`는 `a/b/c.txt`, `path.dir('a')`는 `.`다.
- 모듈 API에 함수 9개가 더해진다(s1 검사 0b, 여섯 모듈 함수 76개). 시그니처는 약 0.2 KB다.

## 적용

- spike/s1, s2의 호스트 로더 허용 목록과 s1의 모듈 API 거름에 `path`를 넣었다.
- 연다는 것과 가르친다는 것은 다르다(ADR 0025). 안내에 넣을지는 다른 모듈과 함께 정한다.
- `path.dir`은 `?str`이 아니라 `str`이다(`'a'`는 `'.'`이고 결과를 정규화한다). 옛 `os.dirname`과 다르다.
