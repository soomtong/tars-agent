# Writing Cyber (guide for agents who know Python)

Cyber has a syntax structure very close to Python. Blocks are made by indentation, statements end at a newline, and you use `for`, `while`, `if`, `fn`, `use` and `print` with almost the same feel. But Cyber is statically typed, has value ownership, and has no exceptions. These parts differ, so consult this document when you compose code. Do not guess an unfamiliar construct from Python; check the lists below first.

The reference version is Cyber 0.4.10-DEV (master after the 0.4.10 release, commit 6ed1b6c4 and the changes that follow it). Old Cyber syntax in your training data (0.3: `my`, `dyn`, `func`, `throw`, `catch`, `'$(x)'`) is all wrong. The forms `#[generator] fn f()` and the symbol literal `@name` from 0.4.6 and earlier are also wrong. Write `generator fn f()` and `symbol.name`.

Cyber is still gaining features. This document matches one point-in-time build and can fall behind the latest build. Before you use or edit this document, check the following.

- Run `cyber version` and compare the real build with the reference version above.
- Re-run the 10 examples in this document on the latest build. If one fails, the document is stale.
- Test the "Missing features" list, the "Differences from Python" list and the "Methods that exist" lists against the latest build, one item at a time. If a feature now exists, remove it from the document or fix the entry (for example the json, regex and time modules, or `xs.map`).
- If the document and the build disagree, the build is right. Fix the document and update the reference version.

If you want a feature that this document does not list, do not assume it exists. Run a small piece of code to check.

## Principles

- Write simple code where the types are visible. int, float, bool, str, []T, Map, ?T, !T and types with plain fields are enough.
- Use heap references `^T`, borrows `&T`, `move`, traits, templates, generators and `spawn` only when you must.
- A call that returns `!T` needs `!` before you print or use the value: `print(f()!)`, not `print(f())`.
- Declare every new variable with `:=` the first time, also inside loops and `if` blocks. `x = ...` only changes a variable that already exists.
- Call only the methods listed in "Methods that exist". If you are not sure a method exists, run a small piece first. Compile errors appear before execution and carry a line number. Fix the code as the message says.

## Same as Python

- Indented blocks, the colon, `pass`, `break`, `continue`, `return`
- `and`, `or`, `not`, `==`, `!=`, `<`, `+=`, `-=`, `*=`, `/=`
- Function calls `f(x)`, method calls `s.upper()`, indexing `xs[0]`, the idea of slicing `s[1..3]`
- Single and double quotes are the same for strings. Strings are immutable UTF-8.
- `[]T`, which you use like a list, shares its buffer on assignment (the same aliasing as a Python list)
- `max(a, b)` and `min(a, b)` for two values of the same type

## Differences from Python

Syntax. Each line is Python, then the Cyber form.

- `# comment` becomes `-- comment`
- `x = 1` (declare and assign are the same) becomes `x := 1` to declare and `x = 2` to reassign. `:=` again in the same block is an error. `x = 1` without an earlier `x :=` is an error.
- `def f(a, b):` becomes `fn f(a, b int) -> int:`. Parameter types and the return type are required. Group equal types as `a, b int`.
- `elif c:` becomes `else c:` (not `else if`)
- `for x in xs:` becomes `for xs |x|:`. With the index: `for xs |i, x|:`
- `for x in 'a', 'b':` or `for x in ['a', 'b']:` becomes `for {'a', 'b'} |x|:`
- `for i in range(n):` becomes `for 0..n |i|:` (end excluded). `0..=n` includes the end. `n..>0` counts down.
- `f"{x}"` becomes `'%{x}'` interpolation. Expressions work: `'%{a + b}'`
- `x if c else y` becomes `if (c) x else y`. The parentheses around the condition are required.
- `a // b` becomes `a / b`. Integer division truncates toward zero. `//` is an error. Power `**` is the same.
- `import math` becomes `use math`. For a file: `use g 'geo.cy'`
- `class P:` becomes `type P:` with fields such as `name str` below it. A method is `fn (&P) m():` and uses `self` inside.
- `P(name='a', n=1)` becomes `P{name='a', n=1}`. A field is set with `=`, not `:`.
- `print(a, b)` becomes `print(x)`. It takes exactly one argument. Join values with interpolation.
- `len(xs)` becomes `xs.len()`. It is a method. `xs.len` is an error.
- `xs.append(1)` becomes `xs += 1` or `xs = xs.append(1)`. Methods that change the size return a new value, so you must take it.
- `xs.sort()` sorts in ascending order. `xs.sort(key=...)` or `reverse=True` becomes `xs.sort(|a, b| a > b)`: the function returns true when `a` goes first. To use an outer variable in it, see "Sorting".
- `x in xs` becomes `xs.contains(x)`, and for a Map `m.contains(k)`
- `[1, 2, 3]` becomes `{1, 2, 3}`. The element type comes from the first element. `[]int{1, 2, 3}` names it. An empty list needs the type: `[]int{}`.
- `{"a": 1, "b": 2}` becomes `Map[str, int]{a=1, b=2}`. A bare name is a string key. For a key computed from an expression, use parentheses: `Map[str, int]{(k)=1}`. An empty Map is `Map[str, int]{}`.
- `(1, 2)` tuple becomes `type Pt(x, y float)` for a named tuple, or a struct
- `None` becomes `none`. Only inside a `?T` type.
- `assert` becomes `use test`, then `test.eq(expected, actual)`
- `if __name__ ...`: top-level statements are the program. Or declare `fn main()` (mixing the two is an error).

Semantics:

- Typing is static. A type error appears as a CompileError before a single line runs. A variable cannot change its type.
- There is no truthiness. The `x` in `if x:` must be a bool. Write `if xs.len() > 0:`. Bitwise operators are `&&`, `||` and `~`. Logic is `and`, `or` and `not`.
- Integers and floats are separate. `int + float` is an error, and the right operand is fitted to the type of the left one. Convert explicitly: `float(i) + f`. A float with an integer value prints as `5`, not `5.0`.
- A function cannot read a local variable of the outer scope. Declare a global with `global g int = 0`.
- Using a call that returns a value as a statement is an error. To discard the value, write `_ = f()`.
- A function that returns a value must return on every path. Otherwise: `Missing return statement.`
- There are no default parameter values and no keyword arguments. Use overloading.
- `return` is not allowed at top level.
- A one-character string `'s'` becomes a code point (115) where an integer is expected. If you doubt a variable's type, check it with `var n int = ...`.
- String indexing and `len()` count bytes. Use `s.count()` for the number of characters.
- Strings compare with `==`, `<`, `<=`, `>`, `>=` (byte order).
- Map iteration follows hash order, not insertion order. If you need an order, take `m.keys()` and sort them.
- A negative index `xs[-1]` panics. Use `xs.last()` or `xs[xs.len() - 1]` for the last element.
- A slice can omit its start or end: `s[..3]`, `s[2..]`. The end is excluded; `s[1..=2]` includes it. Negative bounds are not allowed. Python's `s[:-1]` is `s[..s.len() - 1]` (`s[..-1]` panics).
- `xs[5]` out of range panics, and `m[k]` on a missing key panics. `m.get(k)` returns `?V`.
- Integer overflow wraps around. Division by zero panics.
- A number can contain the digit separator `_`: `1_000_000`, `0xff_ff`.
- `fiber`, `suspend` and `scope` are reserved words. Do not use them as variable or function names. Do not use fibers or `scope` blocks: call capabilities one at a time, in sequence.

## Methods that exist

These are all the methods of the three types you use most. A Python method that is not here does not exist under its Python name. Look for the Cyber name under "Python name to Cyber name". Method names are snake_case: `starts_with`, not `startsWith`.

str (strings do not change; every method returns a new value):

- `s.len()` bytes, `s.count()` characters
- `s.contains(sub)`, `s.starts_with(p)`, `s.ends_with(p)`, `s.index(sub)` gives `?int`
- `s.split(sep)` gives `[]str`, `s.replace(old, new)`, `s.trim(chars)` (the argument is required), `s.upper()`, `s.lower()`, `s.repeat(n)`, `s.concat(t)`
- `a < b` or `s.less(t)` for ordering, `s.last()` the last byte

[]T:

- `xs.len()`, `xs.contains(x)`, `xs.index(x)` gives `?int`, `xs.last()`
- `xs.join(sep)` for `[]str`, gives `str`
- `xs.append(x)`, `xs.insert(i, x)`, `xs.remove(i)`, `xs.clear()`: each returns the new list; take it: `xs = xs.remove(0)`
- `xs.sort()` (ascending) and `xs.sort(|a, b| ...)` sort in place and return nothing

Map[K, V]:

- `m[k]` (panics when missing), `m.get(k)` gives `?V`, `m[k] = v`, `m.set(k, v)`
- `m.contains(k)`, `m.size()`, `m.keys()` gives `[]K`, `m.remove(k)`, `m.clear()`
- `for m |e|:` gives entries with `e.key` and `e.value`

Python name to Cyber name:

- `sep.join(xs)` is `xs.join(sep)` (the list joins, not the separator)
- `xs.index(x)` and `xs.find(x)` are `xs.index(x)`, which gives `?int`: `xs.index(x) ?else -1`
- `xs.pop()` is `v := xs.last()` then `xs = xs.remove(xs.len() - 1)`
- `s.startswith(p)` and `s.endswith(p)` are `s.starts_with(p)` and `s.ends_with(p)`
- `s.strip()` is `s.trim({' ', '\n', '\t'})`
- `s.find(sub)` is `s.index(sub)`, which gives `?int`. There is no `rfind`. For the last part of a path use `p.split('/').last()`
- `len(m)` is `m.size()`. `m.items()` is `for m |e|:`. `list(m)` is `m.keys()`
- `sorted(xs)` is `xs.sort()`, which changes `xs`. `sorted(xs, reverse=True)` is `xs.sort(|a, b| a > b)`

## Sorting

The function given to `sort` can use an outer variable only if its type is `^T` or `&T`. To sort keys by the values of a Map, declare the Map on the heap: `counts := ^Map[str, int]{}`. Then `names.sort(|a, b| counts[a] > counts[b])` works, and `counts` still persists between runs. With a plain `Map[str, int]` the lambda is an error. Put `^` on the Map only. Keep lists as plain `[]T`: do not write `^[]str`. Do not borrow at top level (`c := &counts`): a top-level borrow cannot persist between runs and is an error. A list of structs sorts by a field: `rows.sort(|a, b| a.n > b.n)`. Example 4 sorts Map keys by their counts.

## Missing features

list comprehensions, the `lambda` keyword (a lambda is written `|a, b| a + b` and only where the type is known), generator expressions, decorators, `with`, `try/except`, `raise`, inheritance, `*args`, `**kwargs`, `xs.map`, `xs.filter`, `abs`, `sum`, `sorted`, `enumerate`, `zip`, f-strings, the ternary `?:`, semicolons, `i++`.

The json, regex and time modules are not in the Cyber standard library now and are under construction (docs/decisions/0010). Update this document when they land. Until then, solve the task with str methods or a capability function.

## Errors and Option (instead of exceptions)

- A value that may be absent has type `?T`. To unwrap: `if x |v|:`, `x ?else default`, `x.?` (panics when absent).
- `?else` and `!else` bind weaker than `==` and `+`. Put them in parentheses inside a larger expression: `(h() ?else '') == 'server'`, `(f() !else 0) + 1`.
- An operation that may fail returns `!T`. A failure is `return error.Name`. The caller uses `f()!` (pass the failure to the caller; the enclosing function must return `!U`), `f() !else default`, or a `f() !else |e|:` block (the block must end with `return` or `panic`).
- To handle several calls together, use a `try:` block with `!` inside and receive the failure in `else |e|:`.
- `panic('msg')` cannot be caught. Use it for program bugs only. Return normal failures as `!T`.
- An error from `f()!` at the top level, or returned by `fn main() -> !T`, is an uncaught error and ends in a panic. To print a failure and go on, wrap the top-level code in a `try:` block and print it in `else |e|:` (a top-level `!else` block cannot end with `return`).
- A call that returns `!T` must be handled, even `!void`. A bare `fs.write(p, s)` is an error. Write `fs.write(p, s)!` inside `try:`, or `fs.write(p, s) !else |e|:`.
- Unwrap a `!T` before you use the value: `x := r()!`, then `x.len()`. `r().len()` and `r().ok` are errors. `print(r())` is an error too: write `print(r()!)`.
- `int('abc')` gives 0 without an error. When you need validation, use `int.parse(s) !else ...`.

## Values, references, borrows

- Struct assignment copies. It is not shared like a Python object. `q := p; q.age = 9` does not change p.
- To share, lift the value to the heap with `^`: `p := ^P{name='a', age=3}`. Read and write fields as `p.age`, and use `p.*` for the whole value.
- To let a function modify an argument, declare `fn inc(p &int)` and call `inc(&a)`.
- `Array[T]` cannot be copied. Use `move a` to pass or relocate it. Using the original after a move is an error. For an ordinary list use `[]T`.
- A closure can only capture variables of type `^T` or `&T`. Declare a variable the lambda needs with `^`: `counts := ^Map[str, int]{}`. In simple code use a plain function or a loop instead of a closure.
- Top-level variables persist between runs, but a top-level borrow (`c := &x`) cannot: `Cannot persist local ... of borrow type`. Borrow inside a function, or use `^T`.

## Examples

1. Declarations, interpolation, control flow

```cy
total := 0
for 1..=10 |i|:
    if i % 2 == 0:
        total += i
    else i == 7:
        total += 100
print('total=%{total}')
```

2. Functions and type conversion

```cy
fn mean(xs []int) -> float:
    sum := 0
    for xs |x|:
        sum += x
    return float(sum) / float(xs.len())

print(mean({1, 2, 3, 4}))
```

3. Building and sorting a list (take the value that append returns)

```cy
names := {'bob', 'alice'}
names += 'carol'
names = names.append('dave')
names.sort()
print(names.join(','))
```

4. Counting with a Map, then sorting the words by count (do not rely on hash order)

```cy
counts := ^Map[str, int]{}
for 'the cat and the hat'.split(' ') |w|:
    counts[w] = (counts.get(w) ?else 0) + 1

words := counts.keys()
words.sort(|a, b| counts[a] > counts[b] or (counts[a] == counts[b] and a < b))
for words |w|:
    print('%{w}: %{counts[w]}')
```

5. Struct, methods, copy semantics

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

7. Returning and handling an error

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

8. Error propagation and the try block

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

9. enum and switch (no else needed when every case is covered)

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

10. Shared reference and borrow

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

## Common errors and fixes

Each line is the first line of the error, then the cause and the fix.

- `Expected end of line or file. Got ...`: `let`, `function`, `class`, `print "x"`, a semicolon. Rewrite in Cyber syntax.
- `Expected `(`.`: `else if`. Write `else condition:`.
- `Expected `:` or `|x|:`. ...`: `for i in xs:` or `for 'a', 'b' |x|:`. Write `for xs |i|:` or `for {'a', 'b'} |x|:`.
- `A list literal uses braces: ...`: `['a', 'b']`. Write `{'a', 'b'}`.
- `Expected `=` between a key and a value. ...`: `{'a': 1}` or `P{name: 'x'}`. Write `Map[str, int]{a=1}` or `P{name='x'}`.
- `Expected a target type or at least one element.`: an empty `{}`. Write `[]int{}` or `Map[str, int]{}`.
- `Unknown token: slash`: a `//` comment. Write `--`.
- `Expected right operand.`: `i++`, `10 // 3`. Write `i += 1`, `/`.
- `Expected type `bool`, got `int`.`: a truthy condition. Use a comparison.
- `Expected `int`, found `float`.`: int and float mixed. Match them with `float(i)`.
- `Variable `x` is already declared in the block.`: repeated `:=`. Write `x = ...`.
- `Undeclared variable `x`.`: `x = ...` without `x := ...` first, or an outer local variable used in a function. Declare it with `:=`, pass it as a parameter, or use `global`.
- `Can not find the symbol `join` in `str`.`: `sep.join(xs)`. Write `xs.join(sep)`.
- `Can not find the symbol `m` in ...`: a method that does not exist. Use "Methods that exist".
- `Field `len` does not exist`: `xs.len`. Write `xs.len()`.
- `Expected to handle the error case for `!void`.`: a `!T` call used as a statement. Add `!` (inside `try:`) or `!else`.
- `Can not find the symbol `len` in `!str`.` or `Field `ok` does not exist in `!str`.`: a `!T` value used before it is unwrapped. Write `x := f()!` first.
- `Expected `2` arguments, found `1`, when calling the function `fn trim(...)``: `s.trim()`. Write `s.trim(' ')` or `s.trim({' ', '\n'})`.
- `Can not find the symbol ... for `?int`.`: an Option not unwrapped. Use `?else` or `if x |v|:`.
- `Expected assignment to a variable ...`: a call whose value is discarded. Write `_ = f()` or assign it to a variable.
- `Can not find the symbol `&&` for `bool`.`: logical AND. Write `and`.
- `Can only capture variables declared with the reference types ...`: a lambda uses an outer local. Declare that variable with `^`: `counts := ^Map[str, int]{}` (see "Sorting").
- `Cannot persist local ... of borrow type ... across evals.`: a top-level `c := &x`. Use `^T`, or borrow inside a function.
- `Cannot copy ..., type implements `NoCopy`.`: copying an Array. Use `[]T`, or `move`.
- `Return statement is not allowed in the main block.`: a top-level return. Wrap the code in `fn main():`.
- `Missing return statement.`: some path has no return. Add a return at the end.
- `Undeclared `@x`. A symbol literal is written `symbol.x`.`: an old symbol literal. Write `symbol.x`.
- `The `#[generator]` attribute was replaced by `generator fn`.`: an old generator declaration. Write `generator fn f() -> T:`.

An error raised inside a template can point to a line of a standard module (the module name and line, such as `core:196:5`) instead of your code. Check the call expression yourself.
