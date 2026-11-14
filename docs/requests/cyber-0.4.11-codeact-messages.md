# cyber 요청: 0.4.11 CodeAct 회차에서 고치는 법을 말하지 않은 문구

보내는 곳: soomtong/cyber. 기준: 릴리스 0.4.11 (`Cyber 0.4.11 build-883-097b831`). 확인일 2026-11-14.

tars-agent는 libcyber를 정적 링크해 모델이 쓴 Cyber 스크립트를 세션 VM(persist_main, deny_raw_ptrs, deny_spawn, 검증 뒤 실행)에서 돌린다. 0.4.11로 CodeAct 비교를 돌렸다(과제 셋, DeepSeek-V4.1-Flash 사고 없음 3회와 effort high 3회, qwen3.8-flash 5회, qwen3.8-max 1회. 과제 36개 중 35개 통과, 실패 하나는 모델의 판정 논리 실수, 컴파일 오류 34건). 아래는 그 회차에서 문구가 고치는 법을 말하지 않은 여섯이다. 모두 한 건씩 나왔고, 모델은 다음 스텝 안팎에 고쳤다. 본체의 선행 조건은 아니다.

재현: 설치된 0.4.11 CLI(`cyber <파일>`)와 tars-agent의 `spike/s1`(`s1 replay <파일>`, 세션에서 검증 뒤 실행). 둘의 첫 줄이 모두 같다.

## (a) Python의 `in`을 붙인 `for`

~~~cy
for p |s| in {'a', 'b'}:
    print(s)
~~~

``ParseError: Expected :.`` 요청: `|x|` 뒤에 `in`이 오면 ``A `for` loop has no `in`: `for {a, b} |x|:`.``처럼 말한다.

## (b) Python의 타입 표기 `name: T = v`

~~~cy
fn f():
    q: byte = 0
    print(q)
f()
~~~

``ParseError: Unsupported block statement.`` 요청: 이름 뒤에 `:`와 타입이 오면 ``Write `var q byte = 0` or `q := byte(0)`.``처럼 선언하는 법을 말한다.

## (c) `var` 없는 타입 선언 `name T = v`

~~~cy
fn f():
    in_s str = ''
    print(in_s)
f()
~~~

``ParseError: Expected end of line or file. Got ident.`` 요청: 이름 뒤에 타입 이름과 `=`가 오면 ``To declare a typed variable, write `var in_s str = ''`.``처럼 말한다.

## (d) 옵션이 아닌 값을 `none`과 비교

~~~cy
out := 'a'
if out == none:
    print(1)
~~~

``CompileError: Expected `?T` to infer `none` value, found `str`.`` 요청: 비교의 상대가 옵션이 아니면 ``A `str` is never `none`. Compare with a value of the same type, for example `out.len() == 0`.``처럼 말한다.

## (e) 옵션이 아닌 값에 `?else`

~~~cy
text := 'a'
print(text.ends_with('a') ?else false)
~~~

``CompileError: Expected type instance of `Option`, found `bool`.`` 요청: 왼쪽이 옵션이 아니면 ``This value is `bool`, not an option. Remove `?else false`.``처럼 말한다. 결과(`!T`)가 아닌 값에 `!`을 쓴 경우의 문구(``... `str` has no error case, so use the value as it is.``)와 같은 꼴이다.

## (f) `str`과 `int`의 비교

~~~cy
i := '3'
if i > 0:
    print(i)
~~~

``CompileError: Expected argument `str`, found `int`, when calling `fn >(str, str) -> bool`.`` 타입은 맞게 말하지만 모델에게는 연산자가 함수 호출로 보인다. 요청: ``Can not compare `str` with `int`. Convert one side: `int(i)` or `'%{n}'`.``처럼 연산자로 말한다.

## 확인을 마친 것

0.4.11에서 다음이 통과했다.

- tars-agent spike/s1 검사 40개(버전 문자열이 `Cyber 0.4.11 build-883-097b831`와 같은지 보는 검사 0 포함). 의존은 `git+https://github.com/soomtong/cyber?ref=0.4.11#097b831f049c030683c52f5cec8e1b5cec1da276`, 해시 `cyber-0.4.11-AW3fkEXwjQClbWIfwyRDrnTCj0k7VNbfWrg4S4Bzkzea`.
- M0 요청의 문구(`#` 주석, `for f |{...}|:`, 튜플 반환, 홑따옴표 안의 줄바꿈, 인덱스와 경계의 `?int`, `a[i] = v`의 원소 타입)가 CLI와 세션에서 같게 나온다.
- 안내 문서의 코드 블록 11개가 CLI와 세션에서 통과한다.
- macOS arm64(libcyber.a 2.55 MB, 공개 `cl_` 함수 135개)와 x86_64-linux-gnu 교차 빌드.
- 비교 회차에서 세션 reset, panic, 상한에 걸린 실행은 없었다.

## 회신 (2026-11-14)

cyber master `e25e7d76`(0.4.11 뒤, 미릴리스)에 반영됐다. 그 커밋을 빌드한 CLI에서 (a)~(f)의 첫 줄이 요청한 꼴로 나오고, behavior-test 510/510이 통과한다. (d)는 변수 이름까지 말한다(``` `out` is `str`, which is never `none`. ...```). 범위 밖으로 남은 것: `=` 없는 `x int`는 여전히 `Expected end of line or file. Got ident.`.

세션(`s1 replay`)에서의 확인은 0.4.12 릴리스로 고정을 옮길 때 한 번에 한다(사용자 결정). 그때 같은 첫 줄이 나오면 이 요청서를 닫는다.
