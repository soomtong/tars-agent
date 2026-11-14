# 의존

규칙: BSD 3-Clause와 호환되는 것만. GPL 계열은 들이지 않는다. 의존을 더하면 이 표에 이유와 라이선스를 적는다.

## 빌드에 링크되는 것

| 의존 | 버전 | 라이선스 | 이유 | 조건 |
|---|---|---|---|---|
| Zig 표준 라이브러리 | 0.17.1 | MIT | HTTP, TLS, JSON, 프로세스, 파일 | |
| soomtong/cyber (libcyber) | master 5de6c83a (`0.4.10-DEV`). 원격에 아직 없어 스파이크는 로컬 경로 의존(`.path = "../../../cyberscript"`)으로 받는다. push되면 커밋과 해시로 고정한다 (요청서 2절). 라이브러리는 `b.dependency("cyber", .{ .target, .optimize, .static = true, .commit }).artifact("cyber")`로 받고 cyber.h가 따라온다 | MIT | 스크립트 VM과 표준 모듈(json, regex, time은 만들 것) | 반드시 -Dffi=false. FFI를 켜면 tcc(LGPL)가 링크된다 |
| translate-c (ziglang) | cyber와 같은 커밋 | MIT | 빌드할 때 cyber.h를 Zig 모듈로 바꾼다 | 스파이크에서만 썼다. 본체는 손으로 쓴 extern을 추천한다 (ADR 0017). 링크되지 않는다 |
| glibc (동적, 대상 시스템의 것) | Debian | LGPL | 대상 환경의 바닥 라이브러리 | 동적 링크만. 정적 링크하지 않는다 |

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
