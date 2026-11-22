# 요청: `[]Array[T]`로 실패한 검증 뒤 다음 검증이 세그폴트 (cyber 0.4.17, 02c3c425)

상태: 열림 (2026-11-22). cyber가 셋 다 고쳤다(회신은 맨 아래, 아직 릴리스 전). 고친 빌드에서 확인하고 닫는다. 1은 결함이다. 호스트 프로세스가 끝나므로 tars-agent는 본체 첫 단계 전에 닫는다(ADR 0019). 2와 3은 문구와 동작에 관한 질문이다.

## 배경

tars-agent가 0.4.17로 옮기며 안내(prompt/cyber-subset*.md)의 새 `Array` 문장을 세션(`s1 replay`: 한 VM, `persist_main`, 스크립트마다 `cl_vm_validate` 뒤 eval)에서 확인하다 찾았다. 0.4.16 의존으로 빌드한 s1에서도 같다. 회귀가 아니다.

재현은 설치된 `/usr/local/bin/cyber`(`Cyber 0.4.17 build-1031-02c3c42`)와, 태그 `0.4.17` 의존으로 빌드한 tars-agent spike/s1(macOS arm64, ReleaseFast)에서 했다.

## 1. 실패한 검증 뒤의 `cl_vm_validate`가 세그폴트

세션의 한 VM에서 차례로 검증한다(호스트는 첫 스크립트의 `CL_ERROR_COMPILE`을 받고 다음으로 간다).

~~~cy
xs := []Array[int]{}
~~~

~~~cy
print(1)
~~~

~~~
script 0: validate=COMPILE | CompileError: Cannot copy `Array[int]`, type implements `NoCopy`.
script 1: Segmentation fault at address 0x0
???:?:?: 0x100b52d90 in _cl_vm_validate (s1)
...
spike/s1/src/main.zig:377:39: in replay
            const v = c.cl_vm_validate(vm, B(src));
~~~

- 첫 스크립트가 `[]Array[int]`를 쓰기만 하면 같다: `[]Array[int]{}`, `[]Array[int]{Array[int]{7}}`, `[]Array[int]{move a}`, `xs.append(Array[int]{7})`, 함수 본문 안이어도 같다.
- 둘째 스크립트는 무엇이든 죽는다(`print(1)`, `xs2 := 1`). 첫 스크립트를 검증 없이 eval해도(`s1 replay <파일> nv`) 다음 검증에서 죽는다.
- 한 갈래는 죽지 않고 앞 오류가 다시 나온다. 함수 본문의 `a := []Array[int]{Array[int]{7}}` 뒤에 `x := a[0]`이 있으면, 다음 스크립트 `print(1)`의 검증이 같은 'Cannot copy `Array[int]`, ...'로 실패한다. 같은 뿌리로 보인다(실패한 타입 인스턴스화가 VM에 남는 것).
- `[2]Array[int]{...}`, `Array[Array[int]]{...}`의 실패(`x := a[0]`)는 다음 검증에 해가 없다.
- `cl_vm_reset_pending`은 호스트가 묻지 않았다. 헤더의 설명대로 그 값과 상관없이 다음 검증이 돌아야 한다고 본다.
- 바라는 것: 실패한 검증과 eval 뒤에도 VM이 다음 검증과 eval을 받는다. tars-agent는 고친 빌드에서 s1 검사로 이 순서를 넣는다.

## 2. `[]Array[T]`는 왜 안 되는가 (질문)

~~~cy
xs := []Array[int]{}
print(xs.len())
~~~

~~~
CompileError: Cannot copy `Array[int]`, type implements `NoCopy`.
~~~

- 빈 리터럴에도 복사가 없어 보이는데 복사 오류다. `[]T`가 원소를 복사할 수 있어야 한다는 규칙이면, 그 이유를 문구가 말하고 고칠 꼴(`Array[Array[T]]`)을 보이면 좋겠다. 예: ``A slice `[]T` copies its elements, so `T` can not be `NoCopy`. Use `Array[Array[int]]`.``
- 위치는 core 안이다: `core:4797:37`(`@ptr_init(self.ptr + i, o[i])`)에서 시작해 'While specializing `PtrSpan[Array[int]]`', '`Ptr[Array[int]]`', '`[]Array[int]` here'를 거쳐 사용자의 `nc.cy:1:7`에 닿는다. 모델은 첫 위치(core)를 먼저 읽는다. 사용자 줄을 첫 위치로 둘 수 있으면 좋겠다. 1의 결함이 이 특수화 실패 뒤에 남는 상태에서 오는 것으로 짐작한다.

## 3. 빌린 목록을 `for`로 돌기

~~~cy
fn total(a &[]int) -> int:
    s := 0
    for a |x|:
        s += x
    return s
b := []int{1, 2, 3}
print(total(&b))
~~~

~~~
CompileError: Expected argument `&[]int`, found `&&[]int`, when calling `fn iterator(&[]int) -> int`.
~~~

- 적은 것은 `&[]int`인데 문구는 `&&[]int`를 찾았다고 말한다. `Array[int]`도 같다. 0.4.16에서도 같다.
- `for a.* |x|:`는 돈다(6). 받는 쪽이 빌림이면 `for`가 스스로 역참조할지, 문구가 `for a.* |x|:`를 말할지는 cyber가 정한다. 안내는 `&[]T` 매개변수를 가르치지 않아 모델이 만날 일은 드물다. 비교 회차에서는 나오지 않았다.

## 확인 방법

tars-agent 쪽에서 고친 빌드를 받으면 1의 순서를 `s1 replay`로 돌려 둘째 스크립트가 `validate=SUCCESS eval=SUCCESS 출력=1`인지 보고, s1에 같은 검사를 더한다. 2와 3은 CLI와 세션에서 문구를 본다.

## cyber 회신 (2026-11-22)

셋 다 cyber master에서 고쳤다. 0.4.17 뒤의 미릴리스 변경이다(cyber `docs/releases/unreleased.md`). 다음 빌드에서 확인한다.

### 1. 세그폴트: 고쳤다

- 재현 조건은 "앞에 성공한 eval이 있는 세션"이다(`s1 replay`의 prelude eval). 첫 컴파일이 실패하면 VM이 리셋되어 보이지 않는다.
- 원인은 짐작한 대로 실패한 특수화가 VM에 남는 것이다. 실패한 것은 `PtrSpan[Array[int]]`의 본문 하나인데, 그것을 부르는
  `Slice[Array[int]]`의 본문들이 다음 컴파일로 넘어가 코드가 생성됐고, 검사된 적 없는 본문의 IR을 읽었다. `x := a[0]` 갈래에서
  앞 오류가 다시 나온 것도 같은 뿌리다.
- 이제 실패한 본문은 본문 단위로 표시해 넘기지 않고, 그것을 부르는 넘어온 본문도 조용히 버린다. 다음 소스는 그 영향을 받지 않는다.
- 같은 잘못을 다시 적은 소스는 원래 오류를 위치까지 그대로 다시 받는다. 전에는 세션에서 두 번째부터 'The template could not be
  expanded with these arguments because of an earlier error.'만 나올 수 있었다.
- 같이 고친 것: 본문 하나가 실패하면 타입 인스턴스 전체를 버리던 것. `[]Array[int]`가 실패한 세션에서 `Array[Array[int]]`도
  막혔다. 이제 된다.
- `cl_vm_reset_pending`은 묻지 않아도 된다. 헤더 설명대로다.
- cyber 쪽 검사: lib 테스트 둘(검증과 eval 각각, 같은 잘못을 여러 번, 사이에 `print(1)` 검증과 eval).

### 2. `[]Array[T]`: 규칙이고, 문구와 위치를 고쳤다

- `[]T`는 원소를 복사한다(두 슬라이스가 버퍼를 공유하다가 크기가 바뀌면 복제한다). 그래서 `NoCopy` 원소는 쓸 수 없다.
  빈 리터럴도 같은 타입이므로 안 된다.
- 새 문구(첫 위치가 사용자 줄이다. core 위치와 'While specializing ...' 줄은 없다):

~~~
CompileError: A slice `[]Array[int]` copies its elements, so the element type `Array[int]` can not be `NoCopy`. Use `Array[Array[int]]`, which moves them.

main:1:7:
xs := []Array[int]{}
      ^~~~~~~~~~~~
~~~

- 깨지는 변경 하나: 필드나 매개변수 타입으로 `[]Array[int]`를 적기만 해도 이 오류다. 전에는 값을 만들 때만 오류였다.
- 안내의 오류 표에 넣는다면 이 문구의 앞부분 'A slice `[]T` copies its elements, ...'이 고정이다.

### 3. 빌린 목록의 `for`: 스스로 역참조한다

- `fn total(a &[]int)`의 `for a |x|:`가 돈다(`for a.* |x|:`와 같다). `|i, x|`, `|&x|`, `&Array[T]`, `&Map[K, V]`도 같다.
- `&&[]int` 문구는 이 자리에서 더 나오지 않는다.
