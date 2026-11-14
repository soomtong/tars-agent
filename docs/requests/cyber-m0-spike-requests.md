# cyber 요청: M0 스파이크에서 남은 것

보내는 곳: soomtong/cyber. 기준: 로컬 master b450f535 (`Cyber 0.4.10-DEV build-0-b450f535`). 확인일 2026-11-14.

tars-agent는 libcyber를 정적 링크해 모델이 쓴 Cyber 스크립트를 세션 VM(persist_main, deny_raw_ptrs, deny_spawn, 검증 뒤 실행)에서 돌린다. 앞 요청서(tars-agent 44aa24a, 기준 6a155275)에 대한 회신을 이 커밋에서 확인했다. 2절의 다섯 문구는 모두 회신대로 고쳐졌다. 남은 것은 1절이고, 1절이 tars-agent 본체 첫 단계의 선행 조건이다.

재현에 쓴 것: tars-agent의 spike/s1(`zig build && ./zig-out/bin/s1`. `s1 replay <파일>`은 `=====` 줄로 나눈 스크립트를 한 세션에서 검증 뒤 실행한다)과 이 커밋의 CLI(`zig build cli -Doptimize=ReleaseFast -Dcommit=b450f535`).

## 1. 커밋을 원격에 올린다

b450f535와 그 앞의 커밋 일곱(bf5967db, 5de6c83a, a80b07ee, 35d2857f, c4c49933, 118f0c62, 6a155275)이 soomtong/cyber 원격에 없다. 원격 master는 63e35e88이다(`git ls-remote`로 확인). tars-agent 스파이크는 지금 로컬 경로 의존(`.path = "../../../cyberscript"`)으로 받는다. 본체와 docs/deps.md는 URL과 해시로 고정한다.

요청: push한다. 릴리스(0.4.11 등)나 태그가 정해지면 tars-agent는 그것으로 고정한다.

## 2. 값 쪽 불일치에 보이는 내부 이름 (선행 조건 아님)

회신대로 `a[i]`, `a[i..j]`, `a[i] = v`의 인덱스와 경계 쪽 불일치는 내부 이름을 보이지 않는다. `a[i] = v`의 값 쪽은 회신에 적힌 대로 전과 같다.

~~~cy
xs := {1, 2}
xs[0] = 'ab'
~~~

``CompileError: Expected argument `int`, found `str`, when calling `fn @set_index(&[]int, int, int) -> void`.`` 비교 회차에서는 나오지 않았다. 모델이 모르는 이름(`@set_index`)이 보이는 마지막 자리라서 적는다. 요청: ``An element of `[]int` must be `int`, got `str`.``처럼 원소 타입으로 말한다. 급하지 않다.

## 확인을 마친 것

b450f535에서 다음이 통과했다.

- 2절 (a) ~ (e): 앞 요청서의 재현 코드와 회신에 적힌 경우가 CLI와 세션(`s1 replay`, 검증 뒤 실행) 양쪽에서 회신에 적힌 첫 줄 그대로 나온다.
  - (a) `#` 주석: 블록 안, 최상위, 줄 끝, `#` 뒤에 탭이나 줄 끝이 오는 경우 모두 ``A comment starts with `--`, not `#`.``. 한계로 적힌 `#note`는 ``Could not find the symbol `note`.``다.
  - (b) `for f |{'a', 'b'}|:`와 `for i |0..2|:`가 자리를 말한다. 한계로 적힌 `for f |names|:`는 ``Undeclared variable `f`.``다. `for {'a', 'b'} |x|:`는 그대로 돈다.
  - (c) 튜플 반환 타입과 `return 1, 2` 두 문구. 안내대로 쓴 `type Pair(a int, b int)` 코드는 3을 찍고, `fn f() -> (int):`는 그대로 된다.
  - (d) 홑따옴표와 큰따옴표 각각 `'''...'''`, `"""..."""`를 말한다. 문구 속의 `\n`은 글자 그대로 찍힌다.
  - (e) 슬라이스 경계와 인덱스(`xs[h]`, `xs[h] = 3`)의 `?int`, `!int`, `str`이 회신의 문구다.
- s1 검사 40개 모두 통과(버전 문자열의 커밋과 `#include "cyber.h"`의 구조체 크기를 보는 검사 0 포함).
- 안내 문서의 코드 블록 11개가 CLI와 세션에서 통과하고, 출력이 6a155275와 같다. 오류 목록의 문구 21개는 6a155275와 첫 줄이 같다. 바뀐 다섯 문구를 줄 전체로 맞추는 항목은 안내에 없었다.
- macOS arm64(libcyber.a 2.54 MB, 공개 `cl_` 함수 135개)와 x86_64-linux-gnu 교차 빌드(s1, s2).

이 확인 중에 tars-agent 쪽 결함 하나를 찾아 고쳤다. cyber에 요청할 것은 아니다. 안내의 오류 목록이 `use json`의 첫 줄을 CLI의 `Import path does not exist`로 적었는데, 세션(라이브러리의 기본 로더)에서는 ``Failed to load module: json``이 나온다. 안내를 세션 쪽 문구로 고쳤다.

CodeAct 비교는 b450f535로 다시 돌리지 않았다. 지금 있는 숫자는 6a155275 회차의 것이다(과제 36개 모두 통과, 컴파일 오류 34건, 가장 흔한 것은 ``Can not print `!str`.`` 18건으로 tars-agent 쪽에서 다룬다).
