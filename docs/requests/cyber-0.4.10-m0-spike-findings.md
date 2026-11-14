# cyber에 보내는 요청: M0 스파이크를 0.4.10으로 돌린 결과 (2026-11-14)

보내는 쪽: tars-agent. 대상: soomtong/cyber 0.4.10 릴리스. 배경과 전체 결과는 tars-agent의 docs/spikes/2026-11-14-m0-spikes-review.md.

확인한 빌드는 둘이다.

- 라이브러리: build.zig.zon으로 받은 태그 `0.4.10`. `zig fetch`는 이것을 커밋 `9490ddaf`로 풀었다(릴리스 노트는 태그가 `3e6b02eb`라고 적는다. 아래 5.3). 받은 패키지에서 `zig build lib -Doptimize=ReleaseFast -Dffi=false -Dstatic=true`로 만들었고 `cl_full_version`은 `Cyber 0.4.10-DEV build-0-local`이다.
- CLI: 릴리스 바이너리 `Cyber 0.4.10 build-856-3e6b02e`.

호스트는 Zig 0.17.1, macOS arm64. eval 설정은 persist_main과 deny_raw_ptrs를 켰다.

우선순위 순이다. tars-agent는 스파이크의 결함을 모두 고친 릴리스가 나온 뒤에 본체로 간다(사용자 지시). 1~3이 호스트 프로세스를 죽이거나 호스트 설계를 막는 결함이고, 4~5와 함께 본체 첫 단계의 선행 조건이다.

## 1. 실패한 컴파일 뒤 다음 컴파일에서 프로세스가 죽는다

재현 A. 한 VM에서 차례로 cl_vm_validate(또는 cl_vm_evalx)한다.

첫 스크립트:

~~~cy
names := []str{'a', 'b'}
counts := Map[str, int]{}
names.sort(|a, b| counts[a] > counts[b])
~~~

결과는 CL_ERROR_COMPILE(Can only capture variables declared with the reference types `^T` or `&T`.)이다. 여기까지는 맞다.

둘째 스크립트:

~~~cy
counts := Map[str, int]{}
counts['a'] = 1
print(counts['a'])
~~~

결과는 `Segmentation fault at address 0x0`이다. 스택의 맨 위는 `cl_vm_validate` 안이다(릴리스 빌드라 심볼은 그 근처로만 찍힌다).

재현 B. 호스트 로더가 돌려주는 모듈 소스가 컴파일에 실패하는 경우다. 모듈 소스:

~~~cy
fn read(path str) -> !str:
    return undefined_thing
~~~

한 VM에서 `use fs`가 든 스크립트와 `print('plain')`을 번갈아 eval하면 결과는 COMPILE, SUCCESS, COMPILE, SUCCESS, 그리고 다음 `use fs`에서 `Segmentation fault at address 0x0`이다. persist_main을 꺼도 같다. 모듈 소스가 `Future[!str]`을 선언해서 실패하는 경우(2절)도 같다.

요청: 실패한 컴파일이 남긴 상태를 다음 컴파일이 밟지 않게 한다. 컴파일 실패 뒤의 VM이 실패 전과 같은 상태라는 것을 테스트로 고정한다(실패하는 스크립트 여러 종류 뒤에 성공하는 스크립트를 컴파일).

왜 급한가: 에이전트에서 컴파일 실패는 정상 경로다. 0.4.10에 맞춘 안내로도 작은 모델(qwen3.8-flash)은 과제마다 0~4번, 9과제에 11번 컴파일에 실패했다(검토 문서 5절). 같은 VM에서 검증하면 이 결함을 피할 길이 없다.

tars-agent의 임시 대응(스파이크에만): 검증을 fork한 자식에서 하고 부모는 통과한 코드만 컴파일한다.

## 2. `!T`의 T가 관리되는 타입이면 값을 복사하지 못한다

~~~cy
fn g() -> !str:
    return 'a'
x := g()
y := x
print(y!)
~~~

CompileError: Expected type instance of `Result`, found `Ptr[!str]`. 위치는 core:2918:49 (`return meta.access_result_error(src)`). `!int`는 된다.

결과:

- `Future[!str]`의 await가 컴파일되지 않는다(await가 값을 복사한다). 호스트가 문자열을 돌려주는 능력을 `Future[!str]`로 선언할 수 없다. tars-agent의 능력 모양(ADR 0011: 능력은 `Future[!T]`를 돌려주고 래퍼가 await한다)이 문자열 결과에서 막힌다.
- 모델이 `!`를 빠뜨리고 `print(proc.exec('ls'))`를 쓰면 같은 오류가 core의 위치로 나와 원인을 알 수 없다. 모델이 첫 둘러보기로 자주 쓰는 모양이다.

요청: 수정, 그리고 임베딩 테스트에 `Future[!str]`과 `Future[![]int]` 경우를 더한다.

tars-agent의 임시 대응(스파이크에만): `Future[!int]`로 손잡이를 돌려주고 래퍼가 동기 함수 take(h)로 문자열을 꺼낸다.

## 3. `^[]str`에 `+=`하면 메모리가 깨진다

~~~cy
out := ^[]str{}
out += 'x'
out += 'y'
print('done')
~~~

CLI와 세션 VM 모두 `Segmentation fault at address 0xc4`. 세션 VM에서는 cl_vm_validate가 통과하고 실행 중에 죽는다(스택 `_cl_mod_bind_core`, `_execBytecode`). 한 번만 붙이면 `print(out.len())`이 `0`을 찍은 뒤 끝에서 같은 자리에서 죽는다.

대조:

| 스크립트 | 결과 |
|---|---|
| `out := []str{}` 뒤 `out += 'x'` 두 번 | 맞다 |
| `out := ^[]int{}` 뒤 `out += 1` | 맞다 |
| `out := ^[]str{}` 뒤 `out.* += 'x'` | 맞다 |

모델이 쓸 법한 한 줄이 호스트 프로세스를 죽인다. 기대하는 것은 둘 중 하나다: `out.* += x`와 같은 뜻으로 동작하거나, 컴파일 오류로 막는다.

tars-agent의 대응: 안내에 "목록에 `^`를 붙이지 않는다"고 적었다. 모델이 그대로 따른다는 보장은 없다.

## 4. 조용히 다른 값을 내는 것

컴파일 오류도 panic도 없이 다른 값이 나온다. 에이전트는 이것을 알아챌 길이 없다.

| 스크립트 | 0.4.10 | 기대 |
|---|---|---|
| `a := []int{1, 2, 3, 4}` 뒤 `print(a[1..=2])` | `{2}` | `{2, 3}`. `for 1..=3 \|i\|:`는 끝을 포함하는데 슬라이스의 `..=`는 `..`와 같다 |
| `a := false`, `b := false` 뒤 `print(not a and b)` | `true` (`not (a and b)`) | Python처럼 `(not a) and b`, 아니면 문서에 우선순위를 적는다. `!a and b`는 `false`다 |
| `fn r() -> !int` 뒤 `print(r())`, `'%{r()}'` | `!int`, `n=!int` | 성공 값을 찍거나 컴파일 오류로 "먼저 `!`로 풀라"를 말한다 |

## 5. 임베딩과 빌드

### 5.1 빌드 내보내기

`b.dependency("cyber", .{}).artifact("cyber")`가 panic한다(unable to find artifact "cyber"). 라이브러리가 `lib` 스텝 아래에서만 설치되기 때문이다.

요청: 의존으로 쓰는 쪽이 정적 라이브러리와 헤더를 얻는 길을 낸다. 예: 옵션(target, optimize, ffi=false)을 받아 `b.installArtifact`로 라이브러리를 내보내고 `installHeader`로 cyber.h를 싣는다. 의존으로 빌드할 때 버전 문자열이 `0.4.10-DEV build-0-local`이 되지 않게 한다.

tars-agent의 임시 대응(스파이크에만): build.zig에서 받은 패키지 폴더를 작업 폴더로 `zig build lib`를 실행하고 산출물을 링크한다.

### 5.2 spawn 차단 옵션

`spawn(work, {x})`가 임베딩에서 그대로 되고, 스레드 안에서 호스트 함수가 불린다. cyber.h는 cl_future_new를 메인 스레드에서 부르라고 적는다. 호스트의 요청 표가 스레드에 안전하지 않다.

요청: 스크립트의 spawn을 컴파일 오류로 만드는 eval 설정(deny_raw_ptrs와 같은 자리).

### 5.3 태그가 가리키는 커밋

릴리스 노트(docs/releases/0.4.10.md)는 태그 `0.4.10` → `3e6b02eb`, 빌드 `build-856-3e6b02e`라고 적는데, `zig fetch "git+https://github.com/soomtong/cyber?ref=0.4.10"`은 `9490ddaf`로 풀었다. 그 사이의 커밋은 릴리스 노트를 고친 것 하나로 보여 동작 차이는 없을 것이다. 의존으로 고정하는 쪽은 태그와 노트의 커밋이 같기를 바란다. 어느 쪽이 맞는지 알려 주기를 바란다.

### 5.4 작은 것

- 호스트 함수에서 cl_thread_ret보다 cl_thread_str을 먼저 부르면 Segmentation fault다. cyber.h에 "반환 슬롯 먼저, 매개변수는 선언 순서"를 적어 주기를 요청한다.

## 6. 모델이 실제로 틀린 코드와 오류 문구

모델이 틀린 코드에 대해 0.4.10의 문구는 원인을 맞게 말하지만, 고칠 방법을 말하지 않거나 엉뚱한 곳을 가리키는 것이 있다. 아래는 모델이 Python과 JavaScript 습관으로 쓰는 코드를 0.4.10 CLI에 넣어 받은 문구다. tars-agent는 지금 안내 문서로 이것들을 미리 가르치고 있고(그래서 안내가 시스템 프롬프트의 대부분이다), 문구가 고칠 방법을 말해 주면 안내를 줄일 수 있다. 문구 끝에 고칠 방법을 한 문장으로 붙여 주기를 바란다.

| 모델이 쓴 것 | 0.4.10 문구 | 바라는 것 (예) |
|---|---|---|
| `xs := {1, 2}`, `for {'a', 'b'} \|x\|:` (타입 없는 목록) | TODO: infer tuple type | 첫 요소에서 `[]T`를 추론하거나, "Write the element type: `[]int{1, 2}`." |
| `['a', 'b']` | Expected `]`. | A list literal is written `[]T{a, b}`. |
| `xs + ['a']` | Expected `Vector` element type. | 내부 이름(`Vector`) 대신 쓰는 표기로 |
| `{'a': 1}`, `P{name: 'x'}` | Expected closing brace. | An initializer uses `key=value`. |
| `for x in xs:`, `for 'a', 'b' \|x\|:` | Expected :. | A `for` loop is written `for xs \|x\|:`. |
| `s.startsWith(p)`, `s.find(x)`, `s.strip()`, `out.pop()`, `'\n'.join(out)`, `m.items()` | Can not find the symbol ... | 비슷한 Cyber 이름 제안(`starts_with`, `index`, `trim`, `last`와 `remove`, `xs.join(sep)`, `for m \|e\|:`) |
| `xs.sort()` | Expected `2` arguments, found `1` ... `fn sort(...)` | 인자 없는 오름차순 정렬, 또는 "Pass a function: `xs.sort(\|a, b\| a < b)`." |
| `names.sort(\|a, b\| counts[a] > counts[b])` | Can only capture variables ... `^T` or `&T`. | 아래 7절 |
| `counts := ^Map[...]` 뒤 같은 정렬 | Expected argument `&OpaqueFunc[...]`, found `Func[...]` | 아래 7절 |
| `'a' < 'b'` | Can not find the symbol `<` in `str`. | 문자열 비교 연산자, 또는 "Use `a.less(b)`." |
| `Map[str, int]{(k)=1}` | Expected record key. | 식 키 |
| `print(proc.exec('ls'))` (풀지 않은 `!str`) | Expected type instance of `Result`, found `Ptr[!str]`. core:2918 | 2절의 수정, 그리고 "Unwrap it with `!` first." |
| `report = ...` (`:=` 없이 처음 대입) | Undeclared variable `report`. | Declare it with `report := ...`. (대입문의 왼쪽일 때만) |
| `else if b:` | Expected `(`. | Write `else b:`. |
| `fs.write(p, s)` (`!void`를 처리하지 않음) | Expected to handle the error case for `!void`. | Add `!` (inside `try:`) or `!else`. |
| `s.index('=')!` (`?int`에 `!`) | Expected type instance of `Result`, found `?int`. | `!` unwraps a `!T`. Use `?else` for `?int`. |
| `s.trim()` | Expected `2` arguments, found `1` ... `fn trim(&str, str) -> str`. | `trim` takes the characters to cut: `s.trim(' ')`. |
| `h() ?else '' == 'x'` | Expected type `str`, got `bool`. | 문서의 연산자 표에 `?else`, `!else`, `not`의 자리를 올린다 |

## 7. 정렬에 바깥 값을 쓰는 길

집계 과제(파일별 개수를 세어 개수로 정렬)마다 모델은 Map으로 세고 Map의 값으로 키를 정렬하려 한다. 0.4.10에는 그 길이 없다.

~~~cy
counts := Map[str, int]{app=7, db=8, web=23}
names := counts.keys()
names.sort(|a, b| counts[a] > counts[b])        -- Can only capture variables ...
c := &counts
names.sort(|a, b| c[a] > c[b])                  -- Expected argument `&OpaqueFunc[...]`, found `OpaqueFunc[...]`
counts2 := ^Map[str, int]{app=7}
names.sort(|a, b| counts2[a] > counts2[b])      -- Expected argument `&OpaqueFunc[...]`, found `Func[...]`
~~~

`sort`는 `&OpaqueFunc[LessFn[T]]`를 받는데 캡처하는 클로저는 그 모양이 되지 않는다. 그래서 캡처 오류 문구가 권하는 `^T`나 `&T`를 따라도 정렬에서는 막힌다. 되는 길은 struct 목록을 필드로 정렬하는 것뿐이고, tars-agent의 안내는 그렇게 가르친다.

요청: `sort`가 `^T`나 `&T`를 캡처한 클로저를 받거나, 키를 뽑는 정렬(`xs.sort_by(|x| key)`처럼)을 둔다. 어렵다면 캡처 오류 문구가 정렬에서는 struct 목록을 권하게 한다.

## 확인된 것 (참고)

승인, 거부, 취소, 버린 Future, 태그 0, scope 블록의 요청 둘, 중첩 scope(F-111), 연료, interrupt, 스택과 메모리 상한, persist_main, validate와 구조화된 오류, deny_raw_ptrs, 호스트 로더, `Cannot persist local ... of borrow type` 문구: 모두 0.4.10에서 문서대로 동작했다. 스파이크 1의 검사 31개가 macOS에서 통과했다.
