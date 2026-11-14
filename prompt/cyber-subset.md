# Cyber 작성 안내 (Python을 아는 에이전트용)

Cyber는 Python과 아주 비슷한 문법 구조를 가진다. 들여쓰기로 블록을 만들고, 줄바꿈으로 문장을 끝내고, `for`, `while`, `if`, `fn`, `use`, `print`를 거의 같은 감각으로 쓴다. 하지만 정적 타입이고 값 소유권이 있고 예외가 없다. 이런 부분들이 다르니까 코드를 구성할 때 본 문서를 참고한다. 모르는 문법은 Python 문법으로 추측하지 말고 아래 목록을 먼저 본다.

기준 버전은 soomtong/cyber의 커밋 6a155275인 Cyber 0.4.10-DEV다 (그 커밋을 빌드하면 `cyber version`이 `Cyber 0.4.10-DEV build-0-6a155275`를 찍는다). 학습 데이터에 있는 옛 Cyber 문법(`my`, `dyn`, `func`, `throw`, `catch`, `'$(x)'`, `#[generator] fn f()`, symbol 리터럴 `@name`)은 틀렸다. `generator fn f()`와 `symbol.name`으로 쓴다.

Cyber는 지금도 기능이 계속 추가되고 있다. 이 문서는 한 빌드에 맞춘 것이므로 더 새 빌드와 어긋날 수 있다. 문서를 사용하거나 고치기 전에 아래를 확인한다.

- `cyber version`으로 실제 빌드를 확인하고 위의 기준 버전과 비교한다.
- 이 문서의 예제 10개를 그 빌드로 다시 실행한다. CLI로 한 번, 에이전트 세션(같은 VM, persist_main, 검증 뒤 실행)으로 한 번. 하나라도 실패하면 문서가 낡은 것이다.
- "없는 것" 목록, "Python과 다른 것" 목록, "있는 메서드" 목록을 그 빌드에서 하나씩 시험한다. 기능이 새로 생겼으면 문서에서 지우거나 고친다 (예: json, regex, time 모듈, `xs.map`).
- 문서와 빌드가 다르면 빌드가 맞다. 문서를 고치고 기준 버전을 갱신한다.

이 문서에 없는 기능을 쓰고 싶으면 있다고 가정하지 말고 작은 조각으로 실행해 확인한다.

## 쓰는 법의 원칙

- 타입이 보이는 단순한 코드를 쓴다. int, float, bool, str, []T, Map, ?T, !T, 필드가 단순한 type으로 충분하다.
- 힙 참조 `^T`, 빌림 `&T`, `move`, trait, 템플릿, 제너레이터, `spawn`은 꼭 필요할 때만 쓴다.
- `!T`를 돌려주는 호출은 출력하거나 쓰기 전에 `!`를 붙인다: `print(f())`가 아니라 `print(f()!)`.
- 새 변수는 처음에 반드시 `:=`로 선언한다. 반복문과 `if` 블록 안에서도 그렇다. `x = ...`는 이미 있는 변수를 바꿀 때만 쓴다.
- "있는 메서드"에 적힌 메서드만 부른다. 확신이 없으면 먼저 작은 조각으로 실행해 본다.
- 컴파일 오류는 실행 전에 나오고 줄 번호가 있다. 대부분의 문구가 고치는 법을 말한다. 문구대로 고친다.

## Python과 같은 것

- 들여쓰기 블록, 콜론, `pass`, `break`, `continue`, `return`
- `and`, `or`, `not`과 그 우선순위: `not a and b`는 `(not a) and b`, `not a == b`는 `not (a == b)`
- 숫자와 문자열의 `==`, `!=`, `<`, `<=`, `>`, `>=` (문자열은 바이트 순), `+=`, `-=`, `*=`, `/=`
- 함수 호출 `f(x)`, 메서드 호출 `s.upper()`, 인덱스 `xs[0]`, 슬라이스 `s[1..3]`의 개념
- 문자열은 작은따옴표와 큰따옴표가 같고, 불변이며 UTF-8이다
- 리스트처럼 쓰는 `[]T`는 대입하면 버퍼를 공유한다 (Python 리스트와 같은 별칭 동작)
- 같은 타입 두 값의 `max(a, b)`, `min(a, b)`

## Python과 다른 것

문법. 줄마다 Python, 그다음 Cyber 형태다.

- `# 주석`은 `-- 주석`
- `x = 1`(선언과 대입이 같음)은 선언 `x := 1`, 재대입 `x = 2`. 같은 블록에서 다시 `:=`는 오류다.
- `def f(a, b):`는 `fn f(a, b int) -> int:`. 매개변수 타입과 반환 타입이 필수다. 같은 타입은 `a, b int`로 묶는다.
- `elif c:`는 `else c:` (`else if`가 아니다)
- `for x in xs:`는 `for xs |x|:`. 인덱스까지: `for xs |i, x|:` (인덱스가 앞)
- `for x in ['a', 'b']:`는 `for {'a', 'b'} |x|:`
- `for i in range(n):`는 `for 0..n |i|:` (끝 제외). `0..=n`은 끝 포함, `n..>0`은 거꾸로 센다.
- `f"{x}"`는 `'%{x}'` 보간. 식도 된다: `'%{a + b}'`
- `x if c else y`는 `if (c) x else y`. 조건의 괄호가 필수다.
- `a // b`는 `a / b`. 정수 나눗셈은 0 쪽으로 버린다. `//`는 오류다. 거듭제곱 `**`는 같다.
- `import math`는 `use math`. 파일은 `use g 'geo.cy'`
- 함수는 최상위에서만 선언한다. `if`, `for`, 다른 함수 안에서는 선언하지 못한다.
- `class P:`는 `type P:`이고 아래에 `name str` 같은 필드를 둔다. 메서드는 `fn (&P) m():`이고 안에서 `self`를 쓴다.
- `P(name='a', n=1)`은 `P{name='a', n=1}`. 필드는 `:`가 아니라 `=`로 준다.
- `print(a, b)`는 `print(x)`. 인자는 정확히 하나다. 여러 값은 보간으로 합친다.
- `len(xs)`는 `xs.len()`. 메서드다. `xs.len`은 오류다.
- `xs.append(1)`은 `xs += 1` 또는 `xs = xs.append(1)`. 크기를 바꾸는 메서드는 새 값을 돌려주므로 받아야 한다.
- `x in xs`는 `xs.contains(x)`, Map은 `m.contains(k)`
- `[1, 2, 3]`은 `{1, 2, 3}`. 목록은 첫 원소의 타입을 따르고(`[]int`) 나머지 원소도 그 타입이어야 한다. 빈 목록은 타입이 필요하다: `[]int{}`. 타입은 언제든 적어도 된다: `[]str{'a', 'b'}`.
- `{"a": 1, "b": 2}`는 `Map[str, int]{a=1, b=2}`. 맨 이름은 문자열 키다. 식으로 계산한 키는 괄호로 감싼다: `Map[str, int]{(k)=1}`. 빈 Map은 `Map[str, int]{}`.
- `(1, 2)` 튜플은 이름 있는 튜플 `type Pt(x, y float)`이나 struct
- `None`은 `none`. `?T` 타입 안에서만 쓴다.
- `assert`는 `use test` 뒤 `test.eq(expected, actual)`
- `if __name__ ...`: 최상위 문장이 곧 프로그램이다. 또는 `fn main()`을 선언한다 (둘을 섞으면 오류).

의미:

- 정적 타입이다. 타입 오류는 한 줄도 실행되기 전에 CompileError로 나온다. 변수의 타입은 바뀌지 않는다.
- truthiness가 없다. `if x:`의 x는 bool이어야 한다. `if xs.len() > 0:`처럼 쓴다. 비트 연산은 `&&`, `||`, `~`. 논리는 `and`, `or`, `not`.
- 정수와 실수는 별개다. `int + float`는 오류이고 오른쪽 피연산자가 왼쪽 타입에 맞춰진다. `float(i) + f`처럼 명시 변환한다. 정수 값의 실수는 `5.0`이 아니라 `5`로 찍힌다.
- 함수는 바깥 스코프의 지역 변수를 읽지 못한다. 매개변수로 넘기거나 `global g int = 0`으로 전역을 선언한다.
- 값을 돌려주는 호출을 문장으로 쓰면 오류다. 버리려면 `_ = f()`.
- 값을 돌려주는 함수는 모든 경로에서 return해야 한다. 아니면 `Missing return statement.`
- 기본값 매개변수와 키워드 인자가 없다. 오버로드로 대신한다.
- 최상위에서 `return`은 쓸 수 없다.
- 타입 없는 목록 리터럴은 첫 원소의 타입을 따르고, 나머지 원소도 그 타입이어야 한다: `{1, 'a'}`와 `{1.5, 2}`는 오류다. 타입을 쓴다: `[]float{1.5, 2}`.
- 정수가 들어갈 자리에 한 글자 문자열 `'s'`는 오류 없이 코드 포인트(115)가 된다: `[]int{1, 'a'}`는 `{1, 97}`이다. 변수 타입이 의심되면 `var n int = ...`로 확인한다.
- 문자열 인덱스와 `len()`은 바이트 단위다. 글자 수는 `s.count()`.
- 문자열의 백슬래시는 `\n`, `\t`, `\r`, `\0`, `\\`, `\'`, `\"`, `\xHH` 중 하나여야 한다. 그 밖의 것(grep이나 정규식 패턴의 `\|`, `\d`, `\.`)은 컴파일 오류다. 백슬래시를 두 번 쓴다: `'a\\|b'`.
- Map 순회는 삽입 순서가 아니라 해시 순서다. 순서가 필요하면 키나 항목을 목록에 옮겨 정렬한다.
- 음수 인덱스 `xs[-1]`은 panic이다. 마지막 원소는 `xs.last()`나 `xs[xs.len() - 1]`.
- 슬라이스는 시작이나 끝을 생략할 수 있다: `s[..3]`, `s[2..]`. `s[1..3]`은 끝을 빼고 `s[1..=3]`은 끝을 넣는다. 음수 경계는 쓸 수 없다. Python의 `s[:-1]`은 `s[..s.len() - 1]`이다 (`s[..-1]`은 panic).
- 범위 밖 `xs[5]`는 panic, 없는 키의 `m[k]`도 panic이다. `m.get(k)`는 `?V`를 돌려준다.
- 정수 오버플로는 감싸 돈다. 0으로 나누면 panic이다.
- 숫자에 자리 구분 `_`를 쓸 수 있다: `1_000_000`, `0xff_ff`.
- `fiber`, `suspend`, `scope`는 예약어다. 변수나 함수 이름으로 쓰지 않는다. 파이버와 `scope` 블록은 쓰지 않는다: 능력은 하나씩 차례로 부른다.

## 있는 메서드

가장 많이 쓰는 세 타입의 메서드 전부다. 여기에 없는 Python 메서드는 그 Python 이름으로는 없다. "Python 이름과 Cyber 이름"에서 Cyber 이름을 찾는다. 메서드 이름은 snake_case다: `startsWith`가 아니라 `starts_with`.

str (문자열은 바뀌지 않고 모든 메서드가 새 값을 돌려준다):

- `s.len()` 바이트, `s.count()` 글자
- `s.contains(sub)`, `s.starts_with(p)`, `s.ends_with(p)`, `s.index(sub)`와 `s.lastIndexOf(sub)`는 `?int`
- `s.split(sep)`은 `[]str`, `s.replace(old, new)`, `s.upper()`, `s.lower()`, `s.repeat(n)`, `s.concat(t)`
- `s.trim()`은 양 끝의 공백, 탭, 줄바꿈을 자른다. `s.trim({'-', '_'})`는 준 문자를 자른다.
- `s.trimLeft()`와 `s.trimRight()`는 같은 규칙으로 앞이나 뒤만 자른다.
- `s.last()` 마지막 바이트

[]T:

- `xs.len()`, `xs.contains(x)`, `xs.index(x)`는 `?int`, `xs.last()`
- `xs.join(sep)`은 `[]str`에서 `str`을 돌려준다
- `xs.append(x)`, `xs.insert(i, x)`, `xs.remove(i)`, `xs.clear()`: 새 목록을 돌려주므로 받는다: `xs = xs.remove(0)`
- `xs.sort()`는 제자리에서 오름차순으로 정렬한다(숫자와 문자열). `xs.sort(|a, b| ...)`는 `a`가 앞에 오면 true를 돌려주는 함수로 정렬한다. 둘 다 아무것도 돌려주지 않는다.

Map[K, V]:

- `m[k]`(없으면 panic), `m.get(k)`는 `?V`, `m[k] = v`, `m.set(k, v)`
- `m.contains(k)`, `m.size()`, `m.keys()`는 `[]K`, `m.remove(k)`, `m.clear()`
- `for m |e|:`는 `e.key`, `e.value`를 가진 항목을 준다

Python 이름과 Cyber 이름:

- `sep.join(xs)`는 `xs.join(sep)` (구분자가 아니라 목록이 합친다)
- `xs.find(x)`는 `xs.index(x)`이고 `?int`를 돌려준다: `xs.index(x) ?else -1`
- `xs.pop()`은 `v := xs.last()` 뒤 `xs = xs.remove(xs.len() - 1)`
- `s.startswith(p)`, `s.endswith(p)`는 `s.starts_with(p)`, `s.ends_with(p)`
- `s.strip()`은 `s.trim()`, `s.lstrip()`은 `s.trimLeft()`, `s.rstrip()`은 `s.trimRight()`
- `s.find(sub)`는 `s.index(sub)`, `s.rfind(sub)`는 `s.lastIndexOf(sub)`. 둘 다 `?int`다. 경로의 마지막 부분은 `p.split('/').last()`
- `len(m)`은 `m.size()`. `m.items()`는 `for m |e|:`. `list(m)`은 `m.keys()`
- `sorted(xs)`는 `xs.sort()`이고 `xs`를 바꾼다. `sorted(xs, reverse=True)`는 `xs.sort(|a, b| a > b)`

## 정렬

`xs.sort()`는 오름차순이다. 다른 순서는 함수를 준다: 내림차순 `|a, b| a > b`, 필드로 `|a, b| a.n > b.n`.

Map의 값으로 정렬하려면 함수가 Map에 닿아야 한다. 람다는 `^`(힙 참조)로 선언한 바깥 변수만 쓸 수 있다. Map을 처음부터 `^`로 선언하고 보통 Map처럼 쓴다:

~~~cy
counts := ^Map[str, int]{}
for {'b', 'a', 'b'} |w|:
    counts[w] = (counts.get(w) ?else 0) + 1
names := counts.keys()
names.sort(|a, b| counts[a] > counts[b] or (counts[a] == counts[b] and a < b))
~~~

람다 앞에서 빌리는 `c := &counts`도 함수 안에서는 되지만, 에이전트 실행의 최상위에서는 안 된다: 최상위 빌림은 다음 실행으로 넘길 수 없다(`Cannot persist local ... of borrow type`). 항목마다 값이 여럿 필요하면 struct 목록에 옮겨 필드로 정렬한다(예제 4).

## 없는 것

리스트 컴프리헨션, `lambda` 키워드(람다는 `|a, b| a + b`이고 타입이 정해진 자리에서만 쓴다), 제너레이터 식, 데코레이터, `with`, `try/except`, `raise`, 상속, `*args`, `**kwargs`, `xs.map`, `xs.filter`, `abs`, `sum`, `sorted`, `enumerate`, `zip`, f-string, 삼항 `?:`, 세미콜론, `i++`.

json, regex, time 모듈은 지금 Cyber 표준 라이브러리에 없고 만드는 중이다 (docs/decisions/0010). 생기면 이 문서를 고친다. 그 전에는 str 메서드나 능력 함수로 푼다.

## 오류와 Option (예외 대신)

- 없을 수 있는 값은 `?T`. 꺼내기: `if x |v|:`, `x ?else 기본값`, `x.?`(없으면 panic).
- `?else`와 `!else`는 식의 나머지 전부를 기본값으로 받는다. 큰 식 안에서는 괄호로 감싼다: `(h() ?else '') == 'server'`, `(f() !else 0) + 1`.
- 실패할 수 있는 연산은 `!T`를 돌려준다. 실패는 `return error.Name`. 호출 쪽은 `f()!`(실패를 위로 넘김, 감싼 함수가 `!U`를 돌려줘야 한다), `f() !else 기본값`, `f() !else |e|:` 블록(블록은 `return`이나 `panic`으로 끝나야 한다).
- `s.index(x)`는 `?int`다. `if s.index(x) |i|:`(`i` 자리에 있다)와 `else:`, 또는 `if idx == none:`으로 확인한다. `not idx`, `idx >= 0`, `idx!`는 오류다.
- `!`와 `!else`는 `!T` 값에만 쓴다. `?T`(예: `s.index(x)`)에는 `?else`, `.?`, `if x |v|:`를 쓴다.
- 여러 호출을 한꺼번에 처리하려면 `try:` 블록 안에서 `!`를 쓰고 `else |e|:`에서 실패를 받는다.
- `panic('msg')`는 잡을 수 없다. 프로그램 버그에만 쓰고, 보통 실패는 `!T`로 돌려준다.
- 최상위의 `f()!`나 `fn main() -> !T`가 돌려준 오류는 잡히지 않은 오류가 되어 panic으로 끝난다. 실패를 출력하고 계속하려면 최상위 코드를 `try:` 블록으로 감싸고 `else |e|:`에서 출력한다 (최상위의 `!else` 블록은 `return`으로 끝낼 수 없다).
- `!T`를 돌려주는 호출은 `!void`라도 처리해야 한다. 맨 `fs.write(p, s)`는 오류다. `try:` 안에서 `fs.write(p, s)!`나 `fs.write(p, s) !else |e|:`로 쓴다.
- `!T`는 쓰기 전에 푼다: `x := r()!` 뒤 `x.len()`. `print(r())`와 `r().len()`은 오류다.
- `int('abc')`는 오류 없이 0이다. 검증이 필요하면 `int.parse(s) !else ...`.

## 값, 참조, 빌림

- struct 대입은 복사다. Python 객체처럼 공유되지 않는다. `q := p; q.age = 9`는 p를 바꾸지 않는다.
- 공유하려면 `^`로 힙에 올린다: `p := ^P{name='a', age=3}`. 필드는 `p.age`로 읽고 쓰고, 값 전체는 `p.*`.
- 참조에 연산자를 쓰면 `.*`를 거쳐서만 가리키는 값에 닿는다: `n.* += 2`, `out := ^[]str{}`이면 `out.* += 'x'`.
- 함수가 인자를 고치게 하려면 `fn inc(p &int)`로 선언하고 `inc(&a)`로 부른다.
- `Array[T]`는 복사할 수 없다. `move a`로 넘기거나 옮긴다. move한 원본을 쓰면 오류다. 보통 리스트는 `[]T`를 쓴다.
- 클로저는 `^T`나 `&T` 타입의 변수만 캡처할 수 있다. 단순한 코드에서는 클로저 대신 보통 함수나 반복문을 쓴다.
- 최상위 변수는 실행 사이에 이어지지만 최상위 빌림(`c := &x`)은 이어지지 않는다. 함수 안에서 빌리거나 `^T`를 쓴다.

## 예제

1. 선언, 보간, 제어 흐름

~~~cy
total := 0
for 1..=10 |i|:
    if i % 2 == 0:
        total += i
    else i == 7:
        total += 100
print('total=%{total}')
~~~

2. 함수와 타입 변환

~~~cy
fn mean(xs []int) -> float:
    sum := 0
    for xs |x|:
        sum += x
    return float(sum) / float(xs.len())

print(mean({1, 2, 3, 4}))
~~~

3. 목록 만들기와 정렬 (append가 돌려준 값을 받는다)

~~~cy
names := {'bob', 'alice'}
names += 'carol'
names = names.append('dave')
names.sort()
print(names.join(','))
~~~

4. Map으로 세고, 단어를 개수 순으로 정렬하기 (해시 순서에 기대지 않는다)

~~~cy
type WordCount:
    word str
    n int

counts := Map[str, int]{}
for 'the cat and the hat'.split(' ') |w|:
    counts[w] = (counts.get(w) ?else 0) + 1

rows := []WordCount{}
for counts |e|:
    rows += WordCount{word=e.key, n=e.value}
rows.sort(|a, b| a.n > b.n or (a.n == b.n and a.word < b.word))
for rows |r|:
    print('%{r.word}: %{r.n}')
~~~

5. struct, 메서드, 복사 의미

~~~cy
type Account:
    name str
    balance int = 0

fn (&&Account) deposit(n int):
    self.balance += n

fn (&Account) summary() -> str:
    return '%{self.name}: %{self.balance}'

a := Account{name='kim'}
a.deposit(50)
b := a
b.deposit(1)
print(a.summary())
print(b.summary())
~~~

6. Option

~~~cy
fn first_even(xs []int) -> ?int:
    for xs |x|:
        if x % 2 == 0:
            return x
    return none

if first_even({1, 4, 5}) |v|:
    print('found %{v}')
print(first_even({1, 3}) ?else -1)
~~~

7. 오류 반환과 처리

~~~cy
fn safe_div(a, b int) -> !int:
    if b == 0:
        return error.DivByZero
    return a / b

fn describe(a, b int) -> str:
    q := safe_div(a, b) !else |e|:
        return 'failed: %{e}'
    return 'ok: %{q}'

print(safe_div(9, 3) !else -1)
print(describe(9, 3))
print(describe(1, 0))
~~~

8. 오류 전파와 try 블록

~~~cy
fn parse_sum(a, b str) -> !int:
    x := int.parse(a)!
    y := int.parse(b)!
    return x + y

try:
    n := parse_sum('4', '5')!
    print(n)
    m := parse_sum('4', 'x')!
    print(m)
else |e|:
    print('bad input: %{e}')
~~~

9. enum과 switch (모든 경우를 다루면 else가 필요 없다)

~~~cy
type Level enum:
    case low
    case high

fn label(l Level) -> str:
    switch l:
        case .low: return 'L'
        case .high: return 'H'

print(label(Level.high))
~~~

10. 공유 참조와 빌림

~~~cy
fn bump(n &int):
    n.* += 1

x := 1
bump(&x)

shared := ^x
alias := shared
alias.* = 10
print('%{x} %{shared.*}')
~~~

## 문구가 고치는 법을 말하지 않는 오류

대부분의 컴파일 오류는 고치는 법을 말한다. 예: `Did you mean starts_with?`, `Write else cond:, not else if cond:`, `Unwrap it with ! first`. 그대로 따른다. 아래 오류는 그렇지 않아서 원인과 고치는 법을 여기 적는다. 줄마다 오류의 첫 줄이다.

- `Expected end of line or file. Got ...`: `let`, `def`, `class`, `lambda x:`, 세미콜론. Cyber 문법으로 다시 쓴다.
- `Expected right operand.`: `i++`, `10 // 3`, `//` 주석. `i += 1`, `/`, `--`로 쓴다.
- `Expected `]`.`: 리스트 컴프리헨션. 덧붙이는 `for` 반복문으로 쓴다.
- 함수 선언의 `Expected `,`.`: 기본값 매개변수. 빼고 오버로드를 더한다.
- 호출의 `Expected closing parenthesis.`: 키워드 인자 `f(a=1)`. 위치로 넘긴다.
- `Expected a target type or at least one element.`: 빈 `{}`. `[]int{}`나 `Map[str, int]{}`로 쓴다.
- `Expected type `bool`, got `int`.`: truthy 조건. 비교식으로 쓴다.
- `Expected `int`, found `float`.`: int와 float를 섞었다. `float(i)`로 맞춘다.
- `Variable `x` is already declared in the block.`: `:=`를 되풀이했다. `x = ...`로 쓴다.
- 함수 안의 `Undeclared variable `x`.`: 바깥 지역 변수. 매개변수로 넘기거나 `global`을 쓴다.
- `Undeclared variable `abs`.`(`sum`, `sorted`, `enumerate`, `zip`도 같다): Python 내장 함수. "없는 것"을 보고 반복문으로 쓴다.
- `Can not find the symbol `map` in `[]int`.`(`filter`도 같다): 반복문으로 쓴다.
- `Expected `1` arguments, found `2`, when calling the function `fn print(...)``: `print('%{a} %{b}')`로 쓴다.
- `Can not find the symbol `&&` for `bool`.`: 논리 AND. `and`로 쓴다.
- `Expected assignment to a variable or placeholder ...`: 값을 버린 호출. `_ = f()`로 쓰거나 변수에 받는다.
- `Cannot persist local ... of borrow type ... across evals.`: 최상위 `c := &x`. `^T`를 쓰거나 함수 안에서 빌린다.
- `Cannot copy ..., type implements `NoCopy`.`: Array를 복사했다. `[]T`를 쓰거나 `move`.
- `Return statement is not allowed in the main block.`: 최상위 return. 코드를 `fn main():`으로 감싼다.
- `Missing return statement.`: return이 없는 경로가 있다. 끝에 return을 더한다.
- ``fn` declarations are not allowed here.`: 블록 안의 함수. 최상위에서 선언한다.
- `Import path does not exist`: `use json`, `use regex`, `use time`. 없는 모듈이다.

실행 중 panic: `Out of bounds index: -1`은 음수 인덱스(`xs.last()`를 쓴다), 슬라이스의 `OutOfBounds`는 음수이거나 너무 큰 경계, `MissingKey`는 없는 키의 `m[k]`다(`m.get(k)`를 쓴다).

템플릿 안에서 난 오류는 내 코드 대신 표준 모듈의 줄(모듈 이름과 줄, 예: `core:196:5`)을 가리킬 수 있다. 호출식을 직접 확인한다.
