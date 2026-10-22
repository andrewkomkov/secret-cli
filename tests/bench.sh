#!/bin/bash
# Замер secret на временном keychain: N записей (по умолчанию 40), run с 5 ссылками, check, import.
#   N=300 tests/bench.sh
#   DP=1 N=300 tests/bench.sh   хранилище data protection на тестовой сборке helper (build/test, 009)
S="$(cd "$(dirname "$0")/.." && pwd)/bin/secret"
T=$(mktemp -d)
export SECRET_KEYCHAIN=$T/b.keychain-db SECRET_LOG=$T/log SECRET_NAMES_CACHE=$T/names SECRET_NO_DIALOG=1
unset CLAUDECODE
printf 'create-keychain -p "t" "%s"\n' "$SECRET_KEYCHAIN" | security -i
if [ -n "${DP:-}" ]; then
  TS="$(dirname "$S")/../build/test/SecretStoreTest.app/Contents/MacOS/SecretStoreTest"
  [ -x "$TS" ] || { echo "no test build: run tests/run.sh first" >&2; exit 1; }
  echo dp > $T/mode; echo 9999999999 > $T/exp; echo allow > $T/auth
  export SECRET_STORE_HELPER="$TS" SECRET_STORE_MODE=$T/mode SECRET_STORE_EXPIRES=$T/exp SECRET_NO_DIALOG=
  export SECRET_TEST_STORE="bench$$" SECRET_TEST_STATE=$T/state SECRET_TEST_AUTH=$T/auth
fi
for i in $(seq 1 ${N:-40}); do printf 'KEY_%03d=value-%03d-xxxxxxxx\n' $i $i; done > $T/src.env
cp $T/src.env $T/imp.env
export LC_NUMERIC=C
t() { local s e; s=$(perl -MTime::HiRes=time -e 'printf "%.3f", time'); "$@" >/dev/null 2>&1; e=$(perl -MTime::HiRes=time -e 'printf "%.3f", time'); perl -e 'printf("%-8s %6.2f s\n", $ARGV[0], $ARGV[2] - $ARGV[1])' "$2" "$s" "$e"; }
cd $T
t "$S" import -p B_ imp.env
printf 'A=secret:B_KEY_001\nB=secret:B_KEY_002\nC=secret:B_KEY_003\nD=secret:B_KEY_004\nE=secret:B_KEY_005\nPORT=1\n' > five.env
t "$S" ls -l
t "$S" run -e five.env -- true
t "$S" check imp.env
t "$S" set B_ONE one
t "$S" get B_KEY_010
[ -z "${DP:-}" ] || "$TS" wipe
security delete-keychain "$SECRET_KEYCHAIN"; rm -rf $T
