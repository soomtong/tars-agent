# cyber 요청: `use c` 없는 `#[extern]` 함수가 프로세스를 죽인다

보내는 곳: soomtong/cyber. 기준: 릴리스 `Cyber 0.4.13 build-945-1dee651` (태그 0.4.13, 커밋 1dee6514). 확인일 2026-11-17.

tars-agent는 libcyber를 정적 링크(-Dffi=false)해 모델이 쓴 스크립트를 세션 VM(persist_main, deny_raw_ptrs, deny_spawn, 검증 뒤 실행)에서 돌린다. 재현은 설치된 CLI(`cyber <파일>`)와 tars-agent의 `spike/s1`(`s1 replay <파일>`)로 했다.

## 재현

~~~cy
#[extern='abs']
fn c_abs(a int) -> int
print(c_abs(-3))
~~~

| 실행 | 결과 |
|---|---|
| CLI | `panic: attempt to use null value`로 프로세스가 끝난다 |
| 세션, ReleaseFast | `cl_vm_validate` 안에서 `Segmentation fault at address 0x3c8`. 호스트 프로세스가 끝난다 |
| 세션, Debug | `panic: attempt to use null value` |

Debug의 위치는 `src/compiler.zig:1035`, `emit_program_init_func`다.

~~~zig
const init_bind_lib = (try c.get_chunk_by_uri("c")).?.sym.getMod().getSym("@initBindLib").?.cast(.func).first;
~~~

스크립트에 `#[extern]` 함수가 있으면 `c` 모듈의 chunk가 있다고 가정한다. 스크립트가 `use c`를 쓰지 않았거나 호스트 로더가 `c`를 거부하면 null이다. `#[extern='getpid']`도 같다.

`c`가 실려 있으면(스크립트의 `use c`, 또는 `use math`가 `c`를 가져온 뒤) 같은 스크립트는 검증을 지나고 eval이 ``panic: Calling an extern function requires FFI, which this build disables (-Dffi=false).``라는 panic 결과로 끝난다. 프로세스는 남는다.

## 요청

`c`가 실려 있지 않을 때 `#[extern]` 함수가 있는 스크립트는 프로세스를 끝내지 않고 컴파일 오류가 된다. 문구와 방법은 cyber가 정한다. 모델은 다른 언어의 FFI 선언을 흉내 내 이 꼴을 쓸 수 있다.

## 참고: 호스트 로더의 허용 목록

같은 조사에서 본 것이다. 요청은 아니다.

- 로더와 resolver는 스크립트의 `use`와 모듈 안의 `use`를 구별하지 못한다. `core`와 `json`은 `meta`를, `math`는 `c`와 `meta`를, `toon`은 `json`을 쓴다. `math`의 `#c.include` 지시는 `curUri`가 스크립트(`main`)인 채로 `c`를 resolve한다.
- 그래서 tars-agent의 허용 목록은 의존 모듈 `meta`와 `c`를 넣는다(core, meta, c, math, json, toon, regex, peg, time). `c`는 deny_raw_ptrs와 -Dffi=false 아래에서 포인터 함수가 컴파일 오류이고 extern 호출이 panic 결과라 무력하다.
