# 요청: 0.4.16 비교 회차에서 고치는 법을 말하지 않은 문구 넷 (cyber 0.4.16, ca000225)

상태: 열림 (2026-11-21). 결함이 아니라 문구에 관한 요청이다. 모두 컴파일 오류로 멈추고 아무것도 실행되지 않는다. tars-agent 본체의 첫 단계를 막지 않는다.

## 배경

tars-agent의 스파이크 2로 direct 대 CodeAct 비교를 0.4.16으로 다시 돌렸다(과제 셋, 회차 14개, 과제 42개, 2026-11-21). CodeAct는 36개 중 35개를 끝냈고 실패 하나는 모델의 판정 실수다. 모델이 낸 컴파일 오류는 45건이고 대부분은 문구가 고치는 법을 말해 다음 스텝에 고쳐졌다. 0.4.15 요청서의 세 꼴은 이 회차에 나오지 않았다.

기준은 앞 요청서와 같다: 문구가 고치는 법을 말하지 않는 오류가 회차에서 되풀이되면 요청한다. 1은 되풀이됐다. 2는 한 건이지만 위치가 틀려 모델을 엉뚱한 곳으로 보낸다. 3과 4는 한 건이지만 같은 부류의 다른 문구가 이미 고치는 꼴을 말해 맞추기 쉽다.

재현은 모두 설치된 `/usr/local/bin/cyber`(`Cyber 0.4.16 build-1010-ca00022`)에서 했다. tars-agent 세션(`s1 replay`, 검증 뒤 실행)에서도 같은 문구다.

## 1. Python 슬라이스

qwen3.8-flash, 두 회차에서 셋. 0.4.15 회차에도 하나.

~~~cy
s := 'abcdef'
print(s[:3])
~~~

~~~
ParseError: Expected element expression.
~~~

~~~cy
s := 'abcdef'
print(s[2:])
~~~

~~~
ParseError: Expected closing bracket.
~~~

- 무엇이 틀렸는지도 어떻게 쓰는지도 말하지 않는다. 가이드 81행이 `s[..3]`, `s[2..]`를 가르친다.
- 바라는 것: `[` 안의 `:`를 알아보고 꼴을 말한다. 예: ``A slice is written `s[..3]`, `s[2..]` or `s[1..3]`, not `s[:3]`.``

## 2. `for 0..n |_|:`의 위치가 틀린 `Expected ident.`

DeepSeek(deepseek-flash) 하나.

~~~cy
for 0..2 |_|:
    print('x')
print('end')
~~~

~~~
ParseError: Expected ident.

b.cy:2:5:
    print('x')
    ^
~~~

- 위치가 `|_|`가 아니라 다음 줄이다. 회차의 스크립트(37행)에서는 파일 끝의 `print(result)`를 가리켜, 모델이 사고에서 "error points to line 37 print(result)"라며 엉뚱한 곳을 의심했다.
- 고치는 꼴은 `for 0..2:`이고 돈다.
- 바라는 것: 위치를 `_`에 두고 꼴을 말한다. 예: ``A loop that does not use the index is written `for 0..n:`. `|_|` is not allowed.`` `|_|`를 받아들일지는 cyber가 정한다.

## 3. 블록 안의 `xs.pop()` 문장

DeepSeek(deepseek-flash) 하나.

~~~cy
xs := []str{'a', 'b'}
while xs.len() > 1:
    xs.pop()
print(xs.len())
~~~

~~~
CompileError: Expected assignment to a variable or placeholder for `?str`.
~~~

- 무엇을 써야 하는지는 짐작할 수 있지만 꼴이 없다. 같은 부류의 `remove`는 ``Write `xs.remove(2)` as a statement, or ...``처럼 꼴을 말한다.
- 바라는 것: ``... Write `_ = xs.pop()` to drop the value.``
- 참고: 세션의 마지막 줄 `xs.pop()`는 오류가 아니라 eval 결과다(앞서 본 `Slice`와 같다).

## 4. `path.basename`

qwen3.8-flash 하나.

~~~cy
use path
print(path.basename('a/b.py'))
~~~

~~~
CompileError: Can not find the symbol `basename` in `path`.
~~~

- 이름은 `path.base`다. 0.4.14의 snake_case 바꾸기에서는 옛 이름에 ``Did you mean ...?``이 붙었다. 여기에는 없다.
- 바라는 것: 모듈 안의 비슷한 이름을 알려 준다(``Did you mean `base`?``). 다른 언어에서 흔한 이름(`basename`, `dirname`, `extname`)을 맞출지는 cyber가 정한다.

## 덧붙임: `int('Z')`와 `int(z)` (요청 아님, 안내 문구)

스텝 상한에 걸린 CodeAct 실패 하나에서 모델이 아래를 보고 헷갈렸다.

~~~cy
z := 'Z'
print(int(z))
print(int('Z'))
~~~

~~~
0
90
~~~

한 글자 문자열 리터럴은 정수 자리에서 코드 포인트가 되고(가이드 76행), `int(s)`는 파싱해 실패하면 0이다(182행). 둘 다 가이드에 있지만 따로 있어, 같은 글자가 리터럴이냐 변수냐에 따라 값이 다른 것은 읽어 내기 어렵다. 두 줄을 묶어 이 예를 넣을지 보아 주기 바란다.

## 내지 않은 것

- `chr(10)`(``Undeclared variable `chr`.``), 빈 보간 `'%{}'`(``Expected expression.``), `str.bytes()`: 한 건씩이고 무엇이 틀렸는지는 말한다.
- 선언하지 않은 `p`로 시작한 `for p |x|:` 셋(qwen3.8-flash): 모델의 잘못이고 문구는 맞다.

## 확인 방법

tars-agent 쪽에서 새 빌드를 받으면 위 스크립트를 CLI와 세션(`s1 replay`)에서 돌려 문구를 본다. 비교 회차를 다시 돌릴 때 같은 오류가 몇 스텝에 고쳐지는지 본다. 원자료는 tars-agent spike/s2/out/0.4.16/, 집계는 검토 문서 5.4.
