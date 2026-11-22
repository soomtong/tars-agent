# 의존

규칙: BSD 3-Clause와 호환되는 것만. GPL 계열은 들이지 않는다. 의존을 더하면 이 표에 이유와 라이선스를 적는다.

## 빌드에 링크되는 것

| 의존 | 버전 | 라이선스 | 이유 | 조건 |
|---|---|---|---|---|
| Zig 표준 라이브러리 | 0.17.1 | MIT | HTTP, TLS, JSON, 프로세스, 파일 | |
| soomtong/cyber (libcyber) | 릴리스 `0.4.17`. 가장 새 빌드를 따른다(ADR 0023): `zig fetch --save=cyber "git+https://github.com/soomtong/cyber#0.4.17"`. 버전 문자열은 `Cyber 0.4.17 build-0-local`이다. 라이브러리는 `b.dependency("cyber", .{ .target, .optimize, .static = true, .dev = false }).artifact("cyber")`로 받고 cyber.h가 따라온다 | MIT | 스크립트 VM과 표준 모듈(json, toon, regex, peg, time, path, test 포함). 패키지에 에이전트 안내 docs/agent-guide.md가 들어 있다 (ADR 0022) | 반드시 -Dffi=false. FFI를 켜면 tcc(LGPL)가 링크된다 |
| translate-c (ziglang) | cyber와 같은 커밋 | MIT | 빌드할 때 cyber.h를 Zig 모듈로 바꾼다 | 스파이크에서만 썼다. 본체는 손으로 쓴 extern을 추천한다 (ADR 0017). 링크되지 않는다 |
| glibc (동적, 대상 시스템의 것) | Debian | LGPL | 대상 환경의 바닥 라이브러리 | 동적 링크만. 정적 링크하지 않는다 |

## Zig 0.17.1에서 피할 것 (ADR 0030)

컴파일 오류 없이 지나가는 것들이다. 출처는 fx의 Zig 메모(`.fx/skills/zig/references/toolchain.md`, `5960bc93d`)이고 우리 빌드에서는 아직 재현하지 않았다. 해당 코드를 쓸 때 재현하고 이 줄을 고친다.

- HTTP 요청 정리: `std.http.Client.Request.deinit`이 본문을 보낸 요청에서 응답을 끝까지 읽어 연결을 재사용하려 한다. 길이가 없는 응답이나 서버가 열어 두는 스트림(SSE)이면 멈춘다. provider 스트림을 중간에 끊을 때(Esc, 재시도) `deinit` 전에 연결을 닫음으로 표시한다(`connection.closing = true`).
- termios: Linux에서 libc와 링크하면 `std.posix.tcgetattr`가 glibc의 60바이트 구조체를 44바이트 자리에 써 스택을 넘친다. `std.os.linux.tcgetattr`(TCGETS ioctl)를 쓴다. 줄 편집기(M3)에 걸린다.
- macOS의 connect panic: `std.Io.Threaded`에서 `std.Io.Select`를 작업이 도는 중에 취소하면 그 신호가 같은 스레드의 다음 connect에 떨어져 `EISCONN`으로 Debug에서 panic한다. 보조 작업은 먼저 멈추라고 알리고 결과를 받은 뒤에 Select를 취소한다.
- `std.Io.Evented`는 컴파일되지 않는다. `std.Io.Threaded`를 쓴다.
- allocator 훑기: 손으로 쓴 `std.testing.FailingAllocator`는 resize를 성공시켜 할당 순서가 실행마다 달라진다. resize를 거부하는 감싸개나 `resize_fail_index = 0`을 쓴다.
- `@hasDecl`은 pub 선언만 본다. 비공개를 찾는 탐침은 조용히 거짓이 된다.

## 실행할 때 찾는 외부 프로그램

| 프로그램 | 쓰는 곳 | 없으면 |
|---|---|---|
| ripgrep (rg) | fs.search | 시작할 때 알리고 fs.search를 싣지 않는다 |
| /bin/sh | proc.sh | proc.sh를 싣지 않는다 |
| git | 환경 정보(저장소 여부) | 정보 없이 진행 |

이들은 링크하지 않고 프로세스로 실행하므로 라이선스 조건이 번지지 않는다. tars devlayer에 ripgrep이 있다.

## 들이지 않기로 한 것

- 정규식 라이브러리: 엔진을 cyber에 직접 쓴다 (ADR 0010).
- TOML 해석기, TUI 라이브러리, linenoise: 필요한 범위를 직접 쓰거나 범위에서 뺐다 (ADR 0009).
- mimalloc: cyber의 FFI를 끈 라이브러리 빌드에는 들어가지 않는다 (스파이크 1에서 심볼로 확인).
