# Writing Cyber (guide for agents who know Python)

Cyber has a syntax structure very close to Python. Blocks are made by indentation, statements end at a newline, and you use `for`, `while`, `if`, `fn`, `use` and `print` with almost the same feel. But Cyber is statically typed, has value ownership, and has no exceptions. These parts differ, so consult this document when you compose code. Do not guess an unfamiliar construct from Python; check the tables below first.

The reference version is Cyber 0.4.7. Old Cyber syntax in your training data (0.3: `my`, `dyn`, `func`, `throw`, `catch`, `'$(x)'`) is all wrong. The forms `#[generator] fn f()` and the symbol literal `@name` from 0.4.6 and earlier are also wrong. Write `generator fn f()` and `symbol.name`.

Cyber is still gaining features. This document matches one point-in-time build and can fall behind the latest build. Before you use or edit this document, check the following.

- Run `cyber version` and compare the real build with the reference version above.
- Re-run the 10 examples in this document on the latest build. If one fails, the document is stale.
- Test the "Missing features" list and the "Differences from Python" table against the latest build, one item at a time. If a feature now exists, remove it from the document or fix the entry (for example the json, regex and time modules, or `xs.map`).
- If the document and the build disagree, the build is right. Fix the document and update the reference version.

If you want a feature that this document does not list, do not assume it exists. Run a small piece of code to check.

## Principles

- Write simple code where the types are visible. int, float, bool, str, []T, Map, ?T, !T and types with plain fields are enough.
- Use heap references `^T`, borrows `&T`, `move`, traits, templates, generators and `spawn` only when you must.
- If you are not sure a method exists, do not call it blindly. Run a small piece first. Compile errors appear before execution and carry a line number. Fix the code as the message says.

## Same as Python

- Indented blocks, the colon, `pass`, `break`, `continue`, `return`
- `and`, `or`, `not`, `==`, `!=`, `<`, `+=`, `-=`, `*=`, `/=`
- Function calls `f(x)`, method calls `s.upper()`, indexing `xs[0]`, the idea of slicing `s[1..3]`
- Single and double quotes are the same for strings. Strings are immutable UTF-8.
- `[]T`, which you use like a list, shares its buffer on assignment (the same aliasing as a Python list)

## Differences from Python

Syntax:

| Python | Cyber |
|---|---|
| `# comment` | `-- comment` |
| `x = 1` (declare and assign are the same) | `x := 1` declares, `x = 2` reassigns. `:=` again in the same block is an error |
| `def f(a, b):` | `fn f(a, b int) -> int:` Parameter types and return type are required. Group equal types as `a, b int` |
| `elif c:` | `else c:` (not `else if`) |
| `for x in xs:` | `for xs \|x\|:` or `for xs \|i, x\|:` |
| `for i in range(n):` | `for 0..n \|i\|:` (end excluded), `0..=n` (end included), `n..>0` (descending) |
| `f"{x}"` | `'%{x}'` interpolation. Expressions work: `'%{a + b}'` |
| `x if c else y` | `if (c) x else y` The parentheses around the condition are required |
| `a // b` | `a / b` Integer division truncates toward zero. `//` is an error. Power `**` is the same |
| `import math` | `use math`. For a file: `use g 'geo.cy'` |
| `class P:` | `type P:` with fields such as `name str` below it. A method is `fn (&P) m():` and uses `self` inside |
| `print(a, b)` | `print(x)` takes exactly one argument. Join values with interpolation |
| `len(xs)` | `xs.len()` is a method. `xs.len` is an error |
| `xs.append(1)` | `xs += 1` or `xs = xs.append(1)`. Methods that change the size return a new value, so you must take it |
| `xs.sort(key=...)` | `xs.sort(\|a, b\| a < b)` |
| `x in xs` | `xs.contains(x)`, and for a Map `m.contains(k)` |
| `[1, 2, 3]` | `[]int{1, 2, 3}` The element type is required |
| `{"a": 1}` | `Map[str, int]{}`, then `m['a'] = 1`. There is no literal |
| `(1, 2)` tuple | `type Pt(x, y float)` for a named tuple, or a struct |
| `None` | `none`. Only inside a `?T` type |
| `assert` | `use test`, then `test.eq(expected, actual)` |
| `if __name__ ...` | Top-level statements are the program. Or declare `fn main()` (mixing the two is an error) |

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
- Strings have no `<` or `>`. Use `a.less(b)`. `==` works.
- String `trim` takes the characters to cut: `s.trim(' ')`. There is no `strip`.
- Map iteration follows hash order, not insertion order. If you need an order, collect the keys and sort them.
- A negative index `xs[-1]` panics. Use `xs[xs.len() - 1]` or `xs.last()` for the last element.
- `xs[5]` out of range panics, and `m[k]` on a missing key panics. `m.get(k)` returns `?V`.
- Integer overflow wraps around. Division by zero panics.
- A number can contain the digit separator `_`: `1_000_000`, `0xff_ff`.
- `fiber` and `suspend` are reserved words. Do not use them as variable or function names.

## Missing features

list comprehensions, the `lambda` keyword (a lambda is written `\|a, b\| a + b` and only where the type is known), generator expressions, decorators, `with`, `try/except`, `raise`, inheritance, `*args`, `**kwargs`, `xs.map`, `xs.filter`, built-ins such as `abs`, `max` and `min`, f-strings, the ternary `?:`, semicolons, `i++`.

The json, regex and time modules are not in the Cyber standard library now and are under construction (docs/decisions/0010). Update this document when they land. Until then, solve the task with str methods or a capability function.

## Errors and Option (instead of exceptions)

- A value that may be absent has type `?T`. To unwrap: `if x |v|:`, `x ?else default`, `x.?` (panics when absent).
- An operation that may fail returns `!T`. A failure is `return error.Name`. The caller uses `f()!` (pass the failure to the caller; the enclosing function must return `!U`), `f() !else default`, or a `f() !else |e|:` block (the block must end with `return` or `panic`).
- To handle several calls together, use a `try:` block with `!` inside and receive the failure in `else |e|:`.
- `panic('msg')` cannot be caught. Use it for program bugs only. Return normal failures as `!T`.
- `int('abc')` gives 0 without an error. When you need validation, use `int.parse(s) !else ...`.

## Values, references, borrows

- Struct assignment copies. It is not shared like a Python object. `q := p; q.age = 9` does not change p.
- To share, lift the value to the heap with `^`: `p := ^P{name='a', age=3}`. Read and write fields as `p.age`, and use `p.*` for the whole value.
- To let a function modify an argument, declare `fn inc(p &int)` and call `inc(&a)`.
- `Array[T]` cannot be copied. Use `move a` to pass or relocate it. Using the original after a move is an error. For an ordinary list use `[]T`.
- A closure can only capture variables of type `^T` or `&T`. In simple code use a plain function instead of a closure.

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

print(mean([]int{1, 2, 3, 4}))
```

3. Building and sorting a list (take the value that append returns)

```cy
names := []str{'bob', 'alice'}
names += 'carol'
names = names.append('dave')
names.sort(|a, b| a.less(b))
print(names.join(','))
```

4. Map and a sorted walk (do not rely on hash order)

```cy
counts := Map[str, int]{}
for 'the cat and the hat'.split(' ') |w|:
    counts[w] = (counts.get(w) ?else 0) + 1

keys := []str{}
for counts |e|:
    keys += e.key
keys.sort(|a, b| a.less(b))
for keys |k|:
    print('%{k}: %{counts[k]}')
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

if first_even([]int{1, 4, 5}) |v|:
    print('found %{v}')
print(first_even([]int{1, 3}) ?else -1)
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

| First line of the error | Cause | Fix |
|---|---|---|
| `Expected end of line or file. Got ...` | `let`, `function`, `class`, `print "x"`, a semicolon | Rewrite in Cyber syntax |
| `Expected `(`.` | `else if` | `else condition:` |
| `Expected :.` | `for i in xs:` | `for xs \|i\|:` |
| `Unknown token: slash` | `//` comment | `--` |
| `Expected right operand.` | `i++`, `10 // 3` | `i += 1`, `/` |
| `Expected type `bool`, got `int`.` | truthy condition | Use a comparison |
| `Expected `int`, found `float`.` | int and float mixed | Match them with `float(i)` |
| `Variable `x` is already declared in the block.` | repeated `:=` | `x = ...` |
| `Undeclared variable `x`.` | outer local variable used in a function | Pass it as a parameter, or use `global` |
| `Field `len` does not exist` | `xs.len` | `xs.len()` |
| `Can not find the symbol ... for `?int`.` | Option not unwrapped | `?else`, `if x \|v\|` |
| `Expected assignment to a variable ...` | call whose value is discarded | `_ = f()` or assign it to a variable |
| `Can not find the symbol `&&` for `bool`.` | logical AND | `and` |
| `Cannot copy ..., type implements `NoCopy`.` | copying an Array | Use `[]T`, or `move` |
| `Return statement is not allowed in the main block.` | top-level return | Wrap the code in `fn main():` |
| `Missing return statement.` | some path has no return | Add a return at the end |
| `Undeclared `@x`. A symbol literal is written `symbol.x`.` | old symbol literal | `symbol.x` |
| `The `#[generator]` attribute was replaced by `generator fn`.` | old generator declaration | `generator fn f() -> T:` |

An error raised inside a template can point to a line of a standard module (the module name and line, such as `core:196:5`) instead of your code. Check the call expression yourself.
