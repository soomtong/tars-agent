# Cyber 작성 안내 (Python을 아는 에이전트용)

Cyber는 Python과 아주 비슷한 문법 구조를 가진다. 들여쓰기로 블록을 만들고, 줄바꿈으로 문장을 끝내고, `for`, `while`, `if`, `fn`, `use`, `print`를 거의 같은 감각으로 쓴다. 하지만 정적 타입이고 값 소유권이 있고 예외가 없다. 이런 부분들이 다르니까 코드를 구성할 때 본 문서를 참고한다. 모르는 문법은 Python 문법으로 추측하지 말고 아래 목록을 먼저 본다.

기준 버전은 Cyber 0.4.10-DEV이다 (0.4.10 릴리스 뒤의 master, 커밋 6ed1b6c4와 그 뒤의 변경). 학습 데이터에 있는 옛 Cyber 문법(0.3의 `my`, `dyn`, `func`, `throw`, `catch`, `'$(x)'`)은 모두 틀렸다. 0.4.6까지의 `#[generator] fn f()`와 symbol 리터럴 `@name`도 틀렸다. 지금은 `generator fn f()`와 `symbol.name`이다.

Cyber는 지금도 기능이 계속 추가되고 있다. 이 문서는 특정 시점의 빌드에 맞춘 것이므로 최신 빌드와 어긋날 수 있다. 문서를 사용하거나 고치기 전에 아래를 확인한다.

- `cyber version`으로 실제 빌드를 확인하고 위의 기준 버전과 비교한다.
- 이 문서의 예제 10개를 최신 빌드로 다시 실행한다. 하나라도 실패하면 문서가 낡은 것이다.
- "없는 것" 목록, "Python과 다른 것" 목록, "있는 메서드" 목록을 최신 빌드에서 하나씩 시험한다. 기능이 새로 생겼으면 문서에서 지우거나 고친다 (예: json, regex, time 모듈, `xs.map`).
- 문서와 빌드가 다르면 빌드가 맞다. 문서를 고치고 기준 버전을 갱신한다.

이 문서에 없는 기능을 쓰고 싶으면 있다고 가정하지 말고 작은 조각으로 실행해 확인한다.

## 쓰는 법의 원칙

- 타입이 보이는 단순한 코드를 쓴다. int, float, bool, str, []T, Map, ?T, !T, 필드가 단순한 type으로 충분하다.
- 힙 참조 `^T`, 빌림 `&T`, `move`, trait, 템플릿, 제너레이터, `spawn`은 꼭 필요할 때만 쓴다.
- `!T`를 돌려주는 호출은 출력하거나 쓰기 전에 `!`를 붙인다: `print(f())`가 아니라 `print(f()!)`.
- 새 변수는 처음에 반드시 `:=`로 선언한다. 반복문과 `if` 블록 안에서도 그렇다. `x = ...`는 이미 있는 변수를 바꿀 때만 쓴다.
- "있는 메서드"에 적힌 메서드만 부른다. 확신이 없으면 먼저 작은 조각으로 실행해 본다. 컴파일 오류는 실행 전에 나오고 줄 번호가 있다. 오류 문구대로 고친다.

## Python과 같은 것

- 들여쓰기 블록, 콜론, `pass`, `break`, `continue`, `return`
- `and`, `or`, `not`, `==`, `!=`, `<`, `+=`, `-=`, `*=`, `/=`
- 함수 호출 `f(x)`, 메서드 호출 `s.upper()`, 인덱스 `xs[0]`, 슬라이스 `s[1..3]`의 개념
- 문자열은 작은따옴표와 큰따옴표가 같고, 불변이며 UTF-8이다
- 리스트처럼 쓰는 `[]T`는 대입하면 같은 버퍼를 공유한다 (Python list와 같은 별칭 동작)
- 같은 타입 두 값의 `max(a, b)`, `min(a, b)`

## Python과 다른 것

문법 차이. 각 줄은 Python, 그다음 Cyber의 모양이다.

- `# 주석`은 `-- 주석`
- `x = 1` (선언과 대입 같음)은 선언 `x := 1`, 재대입 `x = 2`. 같은 블록에서 `:=`를 다시 쓰면 오류. 앞에 `x :=` 없이 `x = 1`만 쓰면 오류.
- `def f(a, b):`는 `fn f(a, b int) -> int:`. 매개변수와 반환 타입이 필수. 같은 타입은 `a, b int`로 묶는다.
- `elif c:`는 `else c:` (`else if` 아님)
- `for x in xs:`는 `for xs |x|:`. 인덱스와 함께: `for xs |i, x|:`
- `for x in 'a', 'b':`나 `for x in ['a', 'b']:`는 `for {'a', 'b'} |x|:`
- `for i in range(n):`는 `for 0..n |i|:` (끝 제외). `0..=n`은 끝 포함. `n..>0`은 내림.
- `f"{x}"`는 `'%{x}'` 보간. 식도 들어간다 `'%{a + b}'`
- `x if c else y`는 `if (c) x else y`. 조건에 괄호 필수.
- `a // b`는 `a / b`. 정수끼리 나누면 0 쪽으로 버린다. `//`는 오류. 거듭제곱 `**`은 같다.
- `import math`는 `use math`. 파일은 `use g 'geo.cy'`
- `class P:`는 `type P:` 아래에 `name str` 처럼 `필드 타입`. 메서드는 `fn (&P) m():` 안에서 `self`.
- `P(name='a', n=1)`은 `P{name='a', n=1}`. 필드는 `:`가 아니라 `=`로 준다.
- `print(a, b)`는 `print(x)`. 인자는 정확히 하나. 합치려면 보간.
- `len(xs)`는 `xs.len()` 메서드. `xs.len`은 오류.
- `xs.append(1)`은 `xs += 1` 또는 `xs = xs.append(1)`. 크기를 바꾸는 메서드는 새 값을 돌려주므로 받아야 한다.
- `xs.sort()`는 오름차순 정렬. `xs.sort(key=...)`나 `reverse=True`는 `xs.sort(|a, b| a > b)`: `a`가 앞이면 true를 돌려준다. 바깥 변수를 쓰려면 "정렬"을 본다.
- `x in xs`는 `xs.contains(x)`, Map은 `m.contains(k)`
- `[1, 2, 3]`은 `{1, 2, 3}`. 요소 타입은 첫 요소에서 정해진다. `[]int{1, 2, 3}`로 이름을 붙여도 된다. 빈 목록은 타입이 필요하다: `[]int{}`.
- `{"a": 1, "b": 2}`는 `Map[str, int]{a=1, b=2}`. 맨 이름은 문자열 키다. 식으로 계산한 키는 괄호로 감싼다: `Map[str, int]{(k)=1}`. 빈 Map은 `Map[str, int]{}`.
- `(1, 2)` 튜플은 `type Pt(x, y float)` 이름 있는 튜플, 또는 struct
- `None`은 `none`. `?T` 타입 안에서만.
- `assert`는 `use test` 후 `test.eq(기대, 실제)`
- `if __name__ ...`: 최상위 문장이 곧 프로그램. 또는 `fn main()` (둘을 섞으면 오류).

의미 차이:

- 정적 타입이다. 타입 오류는 한 줄도 실행되기 전에 CompileError로 나온다. 변수 타입은 바꿀 수 없다.
- truthy가 없다. `if x:`의 x는 반드시 bool이다. `if xs.len() > 0:`처럼 쓴다. 비트 연산은 `&&`, `||`, `~`이고 논리는 `and`, `or`, `not`이다.
- 정수와 실수가 분리된다. `int + float`는 오류이고 왼쪽 피연산자 타입에 오른쪽이 맞춰진다. `float(i) + f`처럼 명시한다. 정수 값 실수는 `5.0`이 아니라 `5`로 출력된다.
- 함수는 바깥 지역 변수를 읽지 못한다. 전역은 `global g int = 0`으로 선언한다.
- 값을 돌려주는 호출을 문장으로 쓰면 오류다. 버리려면 `_ = f()`.
- 값 반환 함수는 모든 경로가 return해야 한다. 안 그러면 `Missing return statement.`
- 기본값 매개변수와 키워드 인자가 없다. 오버로딩을 쓴다.
- 최상위에서 `return`을 못 쓴다.
- 단일 문자 문자열 `'s'`는 정수 자리에서 코드포인트(115)로 바뀐다. 문자열 변수 타입이 의심스러우면 `var n int = ...`로 확인한다.
- 문자열 인덱스와 `len()`은 바이트 기준이다. 문자 수는 `s.count()`.
- 문자열은 `==`, `<`, `<=`, `>`, `>=`로 비교한다 (바이트 순).
- Map 순회는 삽입 순서가 아니라 해시 순서다. 순서가 필요하면 `m.keys()`를 받아 정렬한다.
- `xs[-1]` 음수 인덱스는 panic이다. 마지막은 `xs.last()` 또는 `xs[xs.len() - 1]`.
- 슬라이스는 시작이나 끝을 생략할 수 있다: `s[..3]`, `s[2..]`. 끝은 제외되고 `s[1..=2]`는 끝을 포함한다. 음수는 안 된다. Python의 `s[:-1]`은 `s[..s.len() - 1]`이다 (`s[..-1]`은 panic).
- `xs[5]`가 범위 밖이면 panic, `m[k]`가 없는 키여도 panic이다. `m.get(k)`는 `?V`를 돌려준다.
- 정수 오버플로는 랩어라운드한다. 0으로 나누면 panic.
- 숫자에 자릿수 구분자 `_`를 쓸 수 있다: `1_000_000`, `0xff_ff`.
- `fiber`, `suspend`, `scope`는 예약어다. 변수나 함수 이름으로 쓰지 않는다. fiber와 `scope` 블록은 쓰지 않는다: 능력 호출은 한 번에 하나씩 차례로 한다.

## 있는 메서드

가장 많이 쓰는 세 타입의 메서드 전부다. 여기 없는 Python 메서드는 Python 이름으로는 없다. "Python 이름에서 Cyber 이름으로"에서 찾는다. 메서드 이름은 snake_case다: `startsWith`가 아니라 `starts_with`.

str (문자열은 바뀌지 않는다. 모든 메서드가 새 값을 돌려준다):

- `s.len()` 바이트 수, `s.count()` 문자 수
- `s.contains(sub)`, `s.starts_with(p)`, `s.ends_with(p)`, `s.index(sub)`는 `?int`
- `s.split(sep)`는 `[]str`, `s.replace(old, new)`, `s.trim(chars)` (인자 필수), `s.upper()`, `s.lower()`, `s.repeat(n)`, `s.concat(t)`
- 순서 비교 `a < b`나 `s.less(t)`, 마지막 바이트 `s.last()`

[]T:

- `xs.len()`, `xs.contains(x)`, `xs.index(x)`는 `?int`, `xs.last()`
- `[]str`의 `xs.join(sep)`는 `str`
- `xs.append(x)`, `xs.insert(i, x)`, `xs.remove(i)`, `xs.clear()`: 새 목록을 돌려준다. 받는다: `xs = xs.remove(0)`
- `xs.sort()` (오름차순)와 `xs.sort(|a, b| ...)`는 제자리에서 정렬하고 아무것도 돌려주지 않는다

Map[K, V]:

- `m[k]` (없으면 panic), `m.get(k)`는 `?V`, `m[k] = v`, `m.set(k, v)`
- `m.contains(k)`, `m.size()`, `m.keys()`는 `[]K`, `m.remove(k)`, `m.clear()`
- `for m |e|:`는 `e.key`, `e.value`를 가진 항목을 준다

Python 이름에서 Cyber 이름으로:

- `sep.join(xs)`는 `xs.join(sep)` (구분자가 아니라 목록이 잇는다)
- `xs.index(x)`, `xs.find(x)`는 `xs.index(x)`이고 `?int`다: `xs.index(x) ?else -1`
- `xs.pop()`은 `v := xs.last()` 뒤에 `xs = xs.remove(xs.len() - 1)`
- `s.startswith(p)`, `s.endswith(p)`는 `s.starts_with(p)`, `s.ends_with(p)`
- `s.strip()`은 `s.trim({' ', '\n', '\t'})`
- `s.find(sub)`는 `s.index(sub)`이고 `?int`다. `rfind`는 없다. 경로의 마지막 부분은 `p.split('/').last()`
- `len(m)`은 `m.size()`. `m.items()`는 `for m |e|:`. `list(m)`은 `m.keys()`
- `sorted(xs)`는 `xs.sort()`이고 `xs`를 바꾼다. `sorted(xs, reverse=True)`는 `xs.sort(|a, b| a > b)`

## 정렬

`sort`에 주는 함수는 타입이 `^T`나 `&T`인 바깥 변수만 쓸 수 있다. Map의 값으로 키를 정렬하려면 Map을 힙에 선언한다: `counts := ^Map[str, int]{}`. 그러면 `names.sort(|a, b| counts[a] > counts[b])`가 되고, `counts`는 다음 run에도 남는다. 그냥 `Map[str, int]`이면 람다가 오류다. `^`는 Map에만 붙인다. 목록은 그냥 `[]T`로 둔다: `^[]str`로 쓰지 않는다. 최상위에서 빌리지 않는다(`c := &counts`): 최상위 빌림은 다음 run으로 이어질 수 없어 오류다. struct 목록은 필드로 정렬한다: `rows.sort(|a, b| a.n > b.n)`. 예제 4는 Map의 키를 개수로 정렬한다.

## 없는 것

list comprehension, `lambda` 키워드 (람다는 `|a, b| a + b` 형태로 타입이 정해진 자리에서만), 제너레이터 표현식, 데코레이터, `with`, `try/except`, `raise`, 상속, `*args`, `**kwargs`, `xs.map`, `xs.filter`, `abs`, `sum`, `sorted`, `enumerate`, `zip`, f-string, 삼항 `?:`, 세미콜론, `i++`.

json, regex, time 모듈은 지금 Cyber 표준에 없고 만드는 중이다 (docs/decisions/0010). 모듈이 들어오면 이 문서를 갱신한다. 그 전에는 str 메서드로 해결하거나 능력 함수를 쓴다.

## 에러와 Option (예외 대신)

- 값이 없을 수 있으면 `?T`. 풀 때는 `if x |v|:`, `x ?else 기본값`, `x.?` (없으면 panic).
- `?else`와 `!else`는 `==`, `+`보다 약하게 묶인다. 더 큰 식 안에서는 괄호로 감싼다: `(h() ?else '') == 'server'`, `(f() !else 0) + 1`.
- 실패할 수 있으면 `!T`. 실패는 `return error.Name`. 부르는 쪽에서 `f()!` (실패를 호출자에게 넘김, 함수 반환 타입이 `!U`여야 함), `f() !else 기본값`, `f() !else |e|:` 블록 (블록은 `return`이나 `panic`으로 끝나야 함).
- 여러 호출을 묶어 처리하려면 `try:` 블록 아래 `!`를 쓰고 `else |e|:`로 받는다.
- `panic('msg')`는 잡을 수 없다. 프로그램 오류에만 쓰고 정상적인 실패는 `!T`로 돌려준다.
- 최상위에서 쓴 `f()!`나 `fn main() -> !T`가 돌려준 오류는 잡히지 않은 오류라 panic으로 끝난다. 실패를 출력하고 계속하려면 최상위에서는 `try:` 블록으로 감싸고 `else |e|:`에서 출력한다 (최상위 `!else` 블록은 `return`으로 끝낼 수 없다).
- `!T`를 돌려주는 호출은 `!void`라도 반드시 처리한다. `fs.write(p, s)`만 쓰면 오류다. `try:` 안에서 `fs.write(p, s)!`, 또는 `fs.write(p, s) !else |e|:`.
- `!T` 값은 풀고 나서 쓴다: `x := r()!` 뒤에 `x.len()`. `r().len()`, `r().ok`는 오류다. `print(r())`도 오류다: `print(r()!)`로 쓴다.
- `int('abc')`는 오류 없이 0이다. 검증이 필요하면 `int.parse(s) !else ...`를 쓴다.

## 값, 참조, 빌림

- struct 대입은 복사다. Python 객체처럼 공유되지 않는다. `q := p; q.age = 9`는 p를 바꾸지 않는다.
- 공유가 필요하면 `^`로 힙에 올린다. `p := ^P{name='a', age=3}`, 읽고 쓰기는 `p.age`, 값 전체는 `p.*`.
- 함수가 인자를 수정하게 하려면 `fn inc(p &int)` 로 선언하고 `inc(&a)`로 부른다.
- `Array[T]`는 복사가 금지된다. 넘기거나 옮길 때 `move a`. 이동 뒤 원본을 쓰면 오류다. 일반 목록은 `[]T`를 쓴다.
- 클로저가 캡처하는 변수는 `^T`나 `&T`여야 한다. 람다가 쓸 변수는 `^`로 선언한다: `counts := ^Map[str, int]{}`. 단순한 코드에서는 클로저 대신 일반 함수나 반복문을 쓴다.
- 최상위 변수는 다음 run에도 남지만 최상위 빌림(`c := &x`)은 남을 수 없다: `Cannot persist local ... of borrow type`. 함수 안에서 빌리거나 `^T`를 쓴다.

## 예제

1. 선언, 보간, 제어 흐름

```cy
total := 0
for 1..=10 |i|:
    if i % 2 == 0:
        total += i
    else i == 7:
        total += 100
print('total=%{total}')
```

2. 함수와 타입 변환

```cy
fn mean(xs []int) -> float:
    sum := 0
    for xs |x|:
        sum += x
    return float(sum) / float(xs.len())

print(mean({1, 2, 3, 4}))
```

3. 목록 만들기와 정렬 (append는 값을 받는다)

```cy
names := {'bob', 'alice'}
names += 'carol'
names = names.append('dave')
names.sort()
print(names.join(','))
```

4. Map으로 세고 단어를 개수로 정렬하기 (해시 순서에 기대지 않는다)

```cy
counts := ^Map[str, int]{}
for 'the cat and the hat'.split(' ') |w|:
    counts[w] = (counts.get(w) ?else 0) + 1

words := counts.keys()
words.sort(|a, b| counts[a] > counts[b] or (counts[a] == counts[b] and a < b))
for words |w|:
    print('%{w}: %{counts[w]}')
```

5. struct, 메서드, 복사 의미

```cy
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
```

6. Option

```cy
fn first_even(xs []int) -> ?int:
    for xs |x|:
        if x % 2 == 0:
            return x
    return none

if first_even({1, 4, 5}) |v|:
    print('found %{v}')
print(first_even({1, 3}) ?else -1)
```

7. 에러 반환과 처리

```cy
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
```

8. 에러 전파와 try 블록

```cy
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
```

9. enum과 switch (모든 case를 다루면 else 불필요)

```cy
type Level enum:
    case low
    case high

fn label(l Level) -> str:
    switch l:
        case .low: return 'L'
        case .high: return 'H'

print(label(Level.high))
```

10. 참조 공유와 빌림

```cy
fn bump(n &int):
    n.* += 1

x := 1
bump(&x)

shared := ^x
alias := shared
alias.* = 10
print('%{x} %{shared.*}')
```

## 자주 나는 오류와 고치는 법

각 줄은 오류의 첫 줄, 그다음 원인과 고침이다.

- `Expected end of line or file. Got ...`: `let`, `function`, `class`, `print "x"`, 세미콜론. Cyber 문법으로 다시 쓴다.
- `Expected `(`.`: `else if`. `else 조건:`으로 쓴다.
- `Expected `:` or `|x|:`. ...`: `for i in xs:`나 `for 'a', 'b' |x|:`. `for xs |i|:`나 `for {'a', 'b'} |x|:`로 쓴다.
- `A list literal uses braces: ...`: `['a', 'b']`. `{'a', 'b'}`로 쓴다.
- `Expected `=` between a key and a value. ...`: `{'a': 1}`나 `P{name: 'x'}`. `Map[str, int]{a=1}`나 `P{name='x'}`로 쓴다.
- `Expected a target type or at least one element.`: 빈 `{}`. `[]int{}`나 `Map[str, int]{}`로 쓴다.
- `Unknown token: slash`: `//` 주석. `--`로 쓴다.
- `Expected right operand.`: `i++`, `10 // 3`. `i += 1`, `/`로 쓴다.
- `Expected type `bool`, got `int`.`: truthy 조건. 비교식으로 쓴다.
- `Expected `int`, found `float`.`: int와 float 혼합. `float(i)`로 맞춘다.
- `Variable `x` is already declared in the block.`: `:=` 반복. `x = ...`로 쓴다.
- `Undeclared variable `x`.`: 앞에 `x := ...` 없이 쓴 `x = ...`, 또는 함수 안에서 쓴 바깥 지역 변수. `:=`로 선언하거나, 매개변수로 넘기거나, `global`을 쓴다.
- `Can not find the symbol `join` in `str`.`: `sep.join(xs)`. `xs.join(sep)`로 쓴다.
- `Can not find the symbol `m` in ...`: 없는 메서드. "있는 메서드"를 본다.
- `Field `len` does not exist`: `xs.len`. `xs.len()`로 쓴다.
- `Expected to handle the error case for `!void`.`: `!T` 호출을 문장으로 씀. `try:` 안에서 `!`를 붙이거나 `!else`.
- `Can not find the symbol `len` in `!str`.`나 `Field `ok` does not exist in `!str`.`: 풀지 않은 `!T` 값을 씀. 먼저 `x := f()!`.
- `Expected `2` arguments, found `1`, when calling the function `fn trim(...)``: `s.trim()`. `s.trim(' ')`나 `s.trim({' ', '\n'})`로 쓴다.
- `Can not find the symbol ... for `?int`.`: Option을 풀지 않음. `?else`나 `if x |v|:`를 쓴다.
- `Expected assignment to a variable ...`: 값을 버리는 호출. `_ = f()`나 변수에 받는다.
- `Can not find the symbol `&&` for `bool`.`: 논리 AND. `and`로 쓴다.
- `Can only capture variables declared with the reference types ...`: 람다가 바깥 지역 변수를 씀. 그 변수를 `^`로 선언한다: `counts := ^Map[str, int]{}` ("정렬" 참고).
- `Cannot persist local ... of borrow type ... across evals.`: 최상위의 `c := &x`. `^T`를 쓰거나 함수 안에서 빌린다.
- `Cannot copy ..., type implements `NoCopy`.`: Array 복사. `[]T`를 쓰거나 `move`.
- `Return statement is not allowed in the main block.`: 최상위 return. `fn main():`으로 감싼다.
- `Missing return statement.`: 일부 경로에 return이 없음. 마지막에 return을 더한다.
- `Undeclared `@x`. A symbol literal is written `symbol.x`.`: 옛 symbol 리터럴. `symbol.x`로 쓴다.
- `The `#[generator]` attribute was replaced by `generator fn`.`: 옛 제너레이터 선언. `generator fn f() -> T:`로 쓴다.

템플릿 안에서 난 오류는 사용자 코드가 아니라 표준 모듈의 줄(`core:196:5`처럼 모듈 이름과 줄)을 가리킬 수 있다. 호출한 식을 직접 확인한다.
