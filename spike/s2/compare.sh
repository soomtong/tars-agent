#!/bin/sh
# 스파이크 2: 과제 셋을 direct와 codeact로 돌려 한 줄씩 기록한다. 버리는 코드다.
# 모델이 쓴 명령은 jail.zig의 샌드박스 안에서만 돈다 (쓰기는 /tmp/tars-agent-s2, 네트워크 차단).
# 사용: ./compare.sh <provider> [model] [modes] [tasks]
cd "$(dirname "$0")"
P=$1; M=${2:-}
W=/tmp/tars-agent-s2
fixture() {
  rm -rf $W; mkdir -p $W/logs $W/project/src
  python3 - <<'PY'
import random
random.seed(7)
W='/tmp/tars-agent-s2'
for name,n in (('app.log',120),('db.log',80),('web.log',200)):
    with open(f'{W}/logs/{name}','w') as f:
        for i in range(n):
            lvl=random.choices(['INFO','WARN','ERROR'],[8,2,1])[0]
            f.write(f"2026-11-13T10:{i//60:02d}:{i%60:02d} {lvl} {name.split('.')[0]} event {i}\n")
open(f'{W}/project/config.ini','w').write("[server]\nhost = 0.0.0.0\nport = 8080\n\n[client]\nport = 8080\ntimeout = 30\n")
open(f'{W}/project/src/a.py','w').write("import os\n# TODO: remove os\ndef f():\n    pass  # TODO handle errors\n")
open(f'{W}/project/src/b.py','w').write("def g():\n    return 1\n")
open(f'{W}/project/src/c.py','w').write("# TODO: write tests\n# todo lower case is not counted\nx = 1\n# TODO: rename x\n# TODO: docs\n")
PY
}
T1="The folder logs/ has app.log, db.log and web.log. Count the ERROR lines in each file and write the counts to report.txt as 'name: count' lines (file names without the folder), sorted by count descending. Then answer with the total."
T2="In project/src/ find every upper-case TODO comment in the .py files. Write todo.txt with one line per file that has any, as 'file.py count', sorted by file name. Then answer with the overall count."
T3="In project/config.ini change the port under [server] from 8080 to 9090 (leave [client] alone) and add the line 'debug = true' at the end of the [server] section. Then show me the final file."
check() {
  case $1 in
    1) [ "$(cat $W/report.txt 2>/dev/null | tr -d ' ')" = "$(printf 'web.log:23\ndb.log:8\napp.log:7')" ] ;;
    2) [ "$(cat $W/todo.txt 2>/dev/null)" = "$(printf 'a.py 2\nc.py 3')" ] ;;
    3) python3 - <<'PY'
import configparser,sys
c=configparser.ConfigParser(); c.read('/tmp/tars-agent-s2/project/config.ini')
ok=c['server'].get('port')=='9090' and c['client'].get('port')=='8080' and c['server'].get('debug')=='true' and 'debug' not in c['client']
sys.exit(0 if ok else 1)
PY
    ;;
  esac
}
mkdir -p out
for mode in ${3:-direct codeact}; do
  for t in ${4:-1 2 3}; do
    fixture
    eval "Q=\$T$t"
    line=$(./zig-out/bin/s2 --provider $P ${M:+--model $M} --mode $mode --log out/cmp-$P-$mode-t$t.log "$Q" 2> out/cmp-$P-$mode-t$t.trace)
    if check $t; then ok=PASS; else ok=FAIL; fi
    crashes=$(grep -c "컴파일러가 자식" out/cmp-$P-$mode-t$t.trace)
    cerr=$(grep -c "종류=compile error" out/cmp-$P-$mode-t$t.trace)
    printf 'T%s\t%s\t%s\tcompile_errors=%s\tcompiler_crash=%s\n' "$t" "$ok" "$line" "$cerr" "$crashes"
  done
done
