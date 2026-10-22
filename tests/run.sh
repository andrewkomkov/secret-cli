#!/bin/bash
# Тесты на временном keychain: рабочий keychain и список Keychain Access не трогаются.
# Диалоги (ask, unlock без терминала) не проверяются: им нужен человек.
set -uo pipefail
export SECRET_NO_DIALOG=1
unset SECRET_RUN_MASK CLAUDECODE

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRET="$ROOT/bin/secret"
TMP="$(mktemp -d)"
export SECRET_KEYCHAIN="$TMP/test.keychain-db"
export SECRET_LOG="$TMP/access.log"
export SECRET_NAMES_CACHE="$TMP/names"
trap 'security delete-keychain "$SECRET_KEYCHAIN" 2>/dev/null; rm -rf "$TMP"' EXIT
printf 'create-keychain -p "test" "%s"\n' "$SECRET_KEYCHAIN" | security -i >/dev/null

pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok    $1"; }
bad() { fail=$((fail + 1)); echo "FAIL  $1"; }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }
s() { "$SECRET" "$@"; }

TRICKY='p@ss "q" \y $z `w` '\''s'\'''

printf '%s' "$TRICKY" | s set T_A 2>/dev/null
check "set from stdin keeps special characters" test "$(s get T_A)" = "$TRICKY"
check "set with VALUE argument" s set T_B second
check "has: existing" s has T_A
check "has: missing" bash -c "! '$SECRET' has T_NOPE"
check "ls lists names" bash -c "'$SECRET' ls | grep -qx T_A"
echo new | s set T_A 2>/dev/null
check "set updates the value" test "$(s get T_A)" = new
check "bad name rejected" bash -c "! echo v | '$SECRET' set 'bad name'"
check "empty value rejected" bash -c "! printf '' | '$SECRET' set T_E"
check "multi-line value rejected" bash -c "! printf 'a\nb' | '$SECRET' set T_M"

echo v | s set -c 'Пароль базы, «main»' T_C 2>/dev/null
check "set -c stores a non-ASCII comment" test "$(s note T_C)" = 'Пароль базы, «main»'
echo v2 | s set T_C 2>/dev/null
check "set without -c keeps the comment" test "$(s note T_C)" = 'Пароль базы, «main»'
s note T_C 'plain comment' 2>/dev/null
check "note changes the comment" test "$(s note T_C)" = 'plain comment'
check "note keeps the value" test "$(s get T_C)" = v2
check "ls -l shows the comment" bash -c "'$SECRET' ls -l | grep -q 'T_C *plain comment'"

check "run NAME" test "$(s run T_B -- sh -c 'printf %s "$T_B"')" = second
check "run VAR=NAME" test "$(s run X=T_B -- sh -c 'printf %s "$X"')" = second
check "run with missing secret fails" bash -c "! '$SECRET' run T_NOPE -- true"

cd "$TMP"
cat > .env <<'EOF'
# comment
export API_TOKEN="tok \"quoted\" here"
DB_PASS='single # not comment'
PLAIN=abc   # inline comment
EMPTY=
PORT=8080
EOF
s import -k -p IMP_ .env 2>/dev/null
check "import -k does not change the file" grep -q '^PORT=8080$' .env
check "import -k stores values" test "$(s get IMP_DB_PASS)" = 'single # not comment'
s import -p IMP_ .env 2>/dev/null
check "import rewrites values to references" grep -q '^export API_TOKEN=secret:IMP_API_TOKEN$' .env
check "import keeps comments and empty values" bash -c "grep -q '^# comment$' .env && grep -q '^EMPTY=$' .env"
check "import parses double quotes" test "$(s get IMP_API_TOKEN)" = 'tok "quoted" here'
check "import strips inline comments" test "$(s get IMP_PLAIN)" = abc
check "check: all references ok" s check .env
echo old | s set -c 'kept comment' -x 2033-03-03 IMP_KEEP 2>/dev/null
printf 'KEEP=new-value\n' > keep.env
s import -p IMP_ keep.env 2>/dev/null
check "import: new value for an existing item" test "$(s get IMP_KEEP)" = new-value
check "import: comment and date of an existing item kept" bash -c "'$SECRET' ls -l | grep -q '^IMP_KEEP  *2033-03-03 kept comment\$'"
check "run reads ./.env" test "$(s run -- sh -c 'printf "%s|%s|%s" "$API_TOKEN" "$DB_PASS" "$PORT"')" = 'tok "quoted" here|single # not comment|8080'
printf 'X=secret:IMP_PORT\nY=lit\n' > other.env
check "run -e FILE with SPEC" test "$(s run -e other.env Z=T_B -- sh -c 'printf "%s %s %s" "$X" "$Y" "$Z"')" = '8080 lit second'
printf 'A=secret:T_NOPE\n' > bad.env
check "check: missing reference fails" bash -c "! '$SECRET' check bad.env"
check "run: missing reference fails" bash -c "! '$SECRET' run -e bad.env -- true"
check "check prints no values" bash -c "! '$SECRET' check .env | grep -q quoted"
# --- 013: выборочный import и ошибки без текста строки
printf 'SEL_A=alpha-value\nSEL_B=beta-value\nSEL_PORT=8080\nSEL_DUP=second\n' > sel.env
s import -p SEL_ --keys SEL_A,SEL_B --ref SEL_DUP=T_B sel.env 2>/dev/null
check "013: --keys stores only these keys" bash -c "'$SECRET' has SEL_SEL_A && '$SECRET' has SEL_SEL_B && ! '$SECRET' has SEL_SEL_PORT"
check "013: --keys rewrites only these lines" bash -c "grep -qx 'SEL_A=secret:SEL_SEL_A' sel.env && grep -qx 'SEL_PORT=8080' sel.env"
check "013: --ref points to an existing secret" grep -qx 'SEL_DUP=secret:T_B' sel.env
check "013: --ref stores nothing" bash -c "! '$SECRET' has SEL_SEL_DUP"
printf 'ONLY_REF=second\nOTHER_KEY=plain-other\n' > onlyref.env
s import --ref ONLY_REF=T_B onlyref.env 2>/dev/null
check "013: --ref without --keys moves no other key" bash -c "grep -qx 'OTHER_KEY=plain-other' onlyref.env && grep -qx 'ONLY_REF=secret:T_B' onlyref.env && ! '$SECRET' has OTHER_KEY"
printf 'X_ONE=1\n' > miss.env
check "013: a missing key changes nothing" bash -c "! '$SECRET' import --keys X_TWO miss.env 2>/dev/null && grep -qx 'X_ONE=1' miss.env"
printf 'GOOD=1\nsupersecretline\n' > bad1.env
check "013: bad line error hides the text" bash -c "out=\$('$SECRET' check bad1.env 2>&1); [[ \$out == *'bad line 2'* ]] && [[ \$out != *supersecretline* ]]"
printf '9c2VjcmV0LXZhbHVl=\n' > bad2.env
check "013: bad name error hides the text" bash -c "out=\$('$SECRET' check bad2.env 2>&1); [[ \$out == *'bad env var name in line 1'* ]] && [[ \$out != *c2VjcmV0* ]]"

s rm T_A 2>/dev/null
check "rm deletes" bash -c "! '$SECRET' has T_A"
check "rm missing fails" bash -c "! '$SECRET' rm T_A"

# Заблокированный keychain здесь не проверяется: на нём macOS сама открывает окно пароля.
check "ask without a dialog fails" bash -c "! '$SECRET' ask T_X </dev/null"
check "missing keychain fails" env SECRET_KEYCHAIN="$TMP/none.keychain-db" bash -c "! '$SECRET' ls"

# --- 001: gen
s gen G_A 2>/dev/null
check "gen: default 32 alnum" bash -c "v=\$('$SECRET' get G_A); [ \${#v} -eq 32 ] && [[ \$v =~ ^[A-Za-z0-9]+\$ ]]"
s gen -l 24 -s hex G_H 2>/dev/null
check "gen: hex of length 24" bash -c "[[ \$('$SECRET' get G_H) =~ ^[0-9a-f]{24}\$ ]]"
s gen -s symbols G_S 2>/dev/null
check "gen: symbols has a symbol and no unsafe characters" bash -c "v=\$('$SECRET' get G_S); [[ \$v == *[^A-Za-z0-9]* ]] && [[ \$v =~ ^[A-Za-z0-9!#%+.=@^_~-]+\$ ]]"
old="$(s get G_A)"
check "gen: refuses an existing name" bash -c "! '$SECRET' gen G_A"
check "gen: existing value kept" test "$(s get G_A)" = "$old"
s gen -f -c 'generated' G_A 2>/dev/null
check "gen -f replaces the value" bash -c "[ \"\$('$SECRET' get G_A)\" != '$old' ]"
check "gen -c sets the comment" test "$(s note G_A)" = generated
check "gen: output has no value" bash -c "out=\$('$SECRET' gen -f G_A 2>&1); v=\$('$SECRET' get G_A); [[ \$out != *\$v* ]] && [[ \$out == 'generated: G_A (32 chars)' ]]"
check "gen: bad length rejected" bash -c "! '$SECRET' gen -l 4 G_X"

# --- 001: run --mask
printf '%s' 'mask-me-1' | s set M_A 2>/dev/null
printf '%s' 'mask-me-1-longer' | s set M_B 2>/dev/null
check "mask: stdout" test "$(s run --mask M_A -- sh -c 'echo "x $M_A y"')" = 'x *** y'
check "mask: stderr" test "$(s run --mask M_A -- sh -c 'echo "e $M_A" >&2' 2>&1 >/dev/null)" = 'e ***'
check "mask: exit code kept" bash -c "'$SECRET' run --mask M_A -- sh -c 'exit 7'; [ \$? -eq 7 ]"
check "mask: longer value first" test "$(s run --mask M_A M_B -- sh -c 'echo "$M_B"')" = '***'
check "mask: SECRET_RUN_MASK=1" test "$(SECRET_RUN_MASK=1 s run M_A -- sh -c 'echo "$M_A"')" = '***'
check "run without mask unchanged" test "$(s run M_A -- sh -c 'echo "$M_A"')" = mask-me-1
printf 'P=secret:M_A\nPORT=8080\n' > mask.env
check "mask: plain .env values not masked" test "$(s run --mask -e mask.env -- sh -c 'echo "$P $PORT"')" = '*** 8080'
check "mask: stdin passes to the command" test "$(echo in | s run --mask M_A -- cat)" = in

# --- 001: log
: > "$SECRET_LOG"
s get M_A >/dev/null
s run M_A M_B -- true
CLAUDECODE=1 s get M_B >/dev/null
check "log: get and run written" test "$(wc -l < "$SECRET_LOG" | tr -d ' ')" = 3
check "log: run line has names and command" bash -c "grep -q \$'\\trun\\thuman\\tM_A M_B\\ttrue\$' '$SECRET_LOG'"
check "log: CLAUDECODE marks agent" bash -c "tail -1 '$SECRET_LOG' | grep -q \$'\\tget\\tagent\\tM_B'"
check "log: no values in the file" bash -c "! grep -q mask-me '$SECRET_LOG'"
check "log: file mode 600" test "$(stat -f %Lp "$SECRET_LOG")" = 600
check "log NAME filters" test "$(s log M_B | wc -l | tr -d ' ')" = 2
check "log -n" test "$(s log -n 1 | wc -l | tr -d ' ')" = 1
SECRET_LOG=off s get M_A >/dev/null
check "SECRET_LOG=off writes nothing" test "$(wc -l < "$SECRET_LOG" | tr -d ' ')" = 3

# --- 001: Claude Code hook
HOOK="$ROOT/hooks/claude-pretooluse.sh"
hook() { perl -MJSON::PP -e 'print encode_json({tool_name => "Bash", tool_input => {command => $ARGV[0]}})' "$1" | "$HOOK" 2>/dev/null; }
for c in 'secret get GITHUB_TOKEN' \
         'security find-generic-password -a secret-cli -s X -w ~/Library/Keychains/secrets.keychain-db' \
         'security find-generic-password -g -s X' \
         'security dump-keychain -d login.keychain' \
         'cd proj && cat .env' \
         'secret run -e .env -- env' \
         'secret run X -- printenv X' \
         'secret run X -- set' \
         'FOO=1 secret get X' \
         'v=$(secret get X)' \
         'true && secret get X' \
         'sudo security find-generic-password -s X -w' \
         'SECRET_CONFIRM=yes secret gh X -R o/r' \
         'SECRET_GH=./fake secret gh X'; do
  check "hook blocks: $c" bash -c "$(declare -f hook); HOOK='$HOOK'; hook '$c'; [ \$? -eq 2 ]"
done
for c in 'secret run --mask X -- psql' \
         'secret ls -l' \
         'secret gh X -R o/r' \
         'security find-generic-password -a secret-cli -s X' \
         'cat .env.example' \
         'secret run X -- env FOO=1 make' \
         'echo "use secret get with care"' \
         'git commit -m "docs: block secret get in the hook"' \
         'grep -n "cat .env" README.md'; do
  check "hook passes: $c" bash -c "$(declare -f hook); HOOK='$HOOK'; hook '$c'"
done
check "hook passes input without a command" bash -c "echo '{}' | '$HOOK'"
# --- 002: copy (буфер обмена подменён файлом)
export SECRET_PBCOPY="cat > '$TMP/clip'" SECRET_PBPASTE="cat '$TMP/clip'"
printf '%s' 'clip-value-1' | s set C_A 2>/dev/null
out="$(s copy C_A 1 2>&1)"
check "copy: value in the clipboard" test "$(cat "$TMP/clip")" = clip-value-1
check "copy: output has no value" test "$out" = 'copied: C_A (clears in 1s)'
sleep 2
check "copy: clipboard cleared" test "$(cat "$TMP/clip")" = ''
s copy C_A 1 2>/dev/null
printf 'other text' > "$TMP/clip"
sleep 2
check "copy: other text kept" test "$(cat "$TMP/clip")" = 'other text'
check "copy: logged" bash -c "tail -1 '$SECRET_LOG' | grep -q \$'\\tcopy\\thuman\\tC_A'"
check "copy: bad seconds rejected" bash -c "! '$SECRET' copy C_A 0"

# --- 021: gh (gh подменён скриптом, окно подтверждения — ответ из переменной)
cat > "$TMP/gh" <<EOF
#!/bin/bash
printf '%s\n' "\$*" > '$TMP/gh-args'
cat > '$TMP/gh-in'
EOF
chmod +x "$TMP/gh"
printf '%s' 'gh-value-1' | s set G_A 2>/dev/null
out="$(SECRET_GH="$TMP/gh" SECRET_CONFIRM=yes s gh G_A DEPLOY_KEY -R o/r -e prod 2>&1)"
check "021: gh: value on stdin of gh" test "$(cat "$TMP/gh-in")" = gh-value-1
check "021: gh: GH_NAME and flags to gh" test "$(cat "$TMP/gh-args")" = 'secret set DEPLOY_KEY -R o/r -e prod'
check "021: gh: output has no value" test "$out" = 'sent: G_A -> DEPLOY_KEY (-R o/r -e prod)'
check "021: gh: logged" bash -c "tail -1 '$SECRET_LOG' | grep -q \$'\\tgh\\thuman\\tG_A\\tDEPLOY_KEY (-R o/r -e prod)'"
SECRET_GH="$TMP/gh" SECRET_CONFIRM=yes s gh G_A -R o/r 2>/dev/null
check "021: gh: GH_NAME defaults to NAME" test "$(cat "$TMP/gh-args")" = 'secret set G_A -R o/r'
rm -f "$TMP/gh-in"
check "021: gh: no confirm, no push" bash -c "! SECRET_GH='$TMP/gh' SECRET_CONFIRM=no '$SECRET' gh G_A -R o/r 2>/dev/null && [ ! -e '$TMP/gh-in' ]"
check "021: gh: SECRET_NO_DIALOG, no push" bash -c "! SECRET_GH='$TMP/gh' '$SECRET' gh G_A -R o/r 2>/dev/null && [ ! -e '$TMP/gh-in' ]"
check "021: gh: --body rejected" bash -c "! SECRET_GH='$TMP/gh' SECRET_CONFIRM=yes '$SECRET' gh G_A -R o/r --body x 2>/dev/null && [ ! -e '$TMP/gh-in' ]"
check "021: gh: -f rejected" bash -c "! SECRET_GH='$TMP/gh' SECRET_CONFIRM=yes '$SECRET' gh G_A -f x.env 2>/dev/null"
check "021: gh: bad GH_NAME rejected" bash -c "! SECRET_GH='$TMP/gh' SECRET_CONFIRM=yes '$SECRET' gh G_A bad.name 2>/dev/null"
check "021: gh: missing NAME" bash -c "! SECRET_GH='$TMP/gh' SECRET_CONFIRM=yes '$SECRET' gh G_NOPE 2>/dev/null"
check "021: gh: no gh, clear error" bash -c "SECRET_GH='$TMP/no-gh' SECRET_CONFIRM=yes '$SECRET' gh G_A 2>&1 | grep -q 'gh not found'"

# --- 002: names cache
echo v | s set N_A 2>/dev/null
check "names cache: updated by set" grep -qx N_A "$SECRET_NAMES_CACHE"
check "names cache: mode 600" test "$(stat -f %Lp "$SECRET_NAMES_CACHE")" = 600
check "names cache: no values" bash -c "! grep -q clip-value '$SECRET_NAMES_CACHE'"
s rm N_A 2>/dev/null
check "names cache: updated by rm" bash -c "! grep -qx N_A '$SECRET_NAMES_CACHE'"

# --- 002: expiry
echo v | s set -x 2030-01-31 -c 'with expiry' X_A 2>/dev/null
check "set -x stores the date" bash -c "'$SECRET' ls -l | grep -q '^X_A  *2030-01-31 with expiry\$'"
echo v2 | s set X_A 2>/dev/null
check "set without -x keeps the date" bash -c "'$SECRET' ls -l | grep -q '^X_A  *2030-01-31'"
s note X_A 'new comment' 2>/dev/null
check "note keeps the date" bash -c "'$SECRET' ls -l | grep -q '^X_A  *2030-01-31 new comment\$'"
s expire X_A none 2>/dev/null
check "expire none removes the date" bash -c "! '$SECRET' ls -l | grep -q '^X_A  *2030'"
check "bad date rejected" bash -c "! '$SECRET' expire X_A 2026-13-01 && ! '$SECRET' expire X_A 2026-02-30"
past="$(date -v-3d +%Y-%m-%d)"; soon="$(date -v+5d +%Y-%m-%d)"; later="$(date -v+90d +%Y-%m-%d)"
echo v | s set -x "$past" X_OLD 2>/dev/null
echo v | s set -x "$soon" X_SOON 2>/dev/null
echo v | s set -x "$later" X_LATER 2>/dev/null
exp="$(s ls --expiring)"
check "expiring: expired listed" bash -c "grep -q '^EXPIRED  X_OLD ' <<< '$exp'"
check "expiring: soon listed with days" bash -c "grep -q '^soon     X_SOON .*(5 days)' <<< '$exp'"
check "expiring: later not listed" bash -c "! grep -q X_LATER <<< '$exp'"
check "expiring 100: later listed" bash -c "'$SECRET' ls --expiring 100 | grep -q X_LATER"
check "run warns about an expired secret" bash -c "'$SECRET' run X_OLD -- true 2>&1 | grep -q 'warning: X_OLD expired'"
check "run with an expired secret still works" s run X_OLD -- true
printf 'O=secret:X_OLD\n' > old.env
check "check warns about an expired secret" bash -c "'$SECRET' check old.env 2>&1 | grep -q 'warning: X_OLD expired'"

# --- 002: mv
echo mv-value | s set -c 'moved comment' -x 2031-05-05 MV_A 2>/dev/null
out="$(s mv MV_A MV_B 2>&1)"
check "mv: value moved" test "$(s get MV_B)" = mv-value
check "mv: comment and date moved" bash -c "'$SECRET' ls -l | grep -q '^MV_B  *2031-05-05 moved comment\$'"
check "mv: OLD removed" bash -c "! '$SECRET' has MV_A"
check "mv: hint about references" bash -c "grep -q 'update references secret:MV_A' <<< '$out'"
echo other | s set MV_C 2>/dev/null
check "mv: refuses an existing NEW" bash -c "! '$SECRET' mv MV_B MV_C"
check "mv: both kept after refusal" bash -c "[ \"\$('$SECRET' get MV_B)\" = mv-value ] && [ \"\$('$SECRET' get MV_C)\" = other ]"
s mv -f MV_B MV_C 2>/dev/null
check "mv -f replaces NEW" test "$(s get MV_C)" = mv-value

# --- 002: completion
check "completion: zsh syntax" zsh -n "$ROOT/completions/_secret"

# --- 003: export и restore во второй временный keychain
KC2="$TMP/second.keychain-db"
printf 'create-keychain -p "test" "%s"\n' "$KC2" | security -i >/dev/null
trap 'security delete-keychain "$SECRET_KEYCHAIN" 2>/dev/null; security delete-keychain "$KC2" 2>/dev/null; rm -rf "$TMP"' EXIT
PW='correct horse battery'
printf '%s' "$TRICKY" | s set -c 'Комментарий «бэкапа»' -x 2032-02-02 B_TRICKY 2>/dev/null
s2() { SECRET_KEYCHAIN="$KC2" "$SECRET" "$@"; }
n_src="$(s ls | wc -l | tr -d ' ')"
out="$(echo "$PW" | s export --pass-stdin "$TMP/backup.enc" 2>&1)"
check "export: message with count" test "$out" = "exported: $n_src secrets to $TMP/backup.enc"
check "export: file mode 600" test "$(stat -f %Lp "$TMP/backup.enc")" = 600
check "export: no plain names, values or comments" bash -c "! grep -qaE 'B_TRICKY|mask-me|clip-value|correct horse|secret-cli-export' '$TMP/backup.enc' && ! grep -qa \"\$(printf 'Комментарий')\" '$TMP/backup.enc'"
check "export: refuses an existing file" bash -c "! echo '$PW' | '$SECRET' export --pass-stdin '$TMP/backup.enc'"
check "export -f replaces the file" bash -c "echo '$PW' | '$SECRET' export -f --pass-stdin '$TMP/backup.enc'"
check "export: short password rejected" bash -c "! echo short | '$SECRET' export --pass-stdin '$TMP/short.enc' && [ ! -e '$TMP/short.enc' ]"
check "export: logged without names" bash -c "tail -1 '$SECRET_LOG' | grep -q \$'\\texport\\thuman\\t\\*\\t$n_src secrets'"

out="$(echo "$PW" | s2 restore --pass-stdin "$TMP/backup.enc" 2>&1)"
check "restore: message" test "$out" = "restored: $n_src, skipped: 0"
check "restore: same names" test "$(s ls)" = "$(s2 ls)"
check "restore: same values, comments and dates" test "$(s ls -l)" = "$(s2 ls -l)"
check "restore: tricky value intact" test "$(s2 get B_TRICKY)" = "$TRICKY"
bad=0; for n in $(s ls); do [ "$(s get "$n")" = "$(s2 get "$n")" ] || bad=1; done
check "restore: every value equal" test $bad -eq 0

echo changed | s2 set B_TRICKY 2>/dev/null
out="$(echo "$PW" | s2 restore --pass-stdin "$TMP/backup.enc" 2>&1)"
check "restore: existing skipped" bash -c "grep -q 'restored: 0, skipped: $n_src' <<< '$out'"
check "restore: skipped value kept" test "$(s2 get B_TRICKY)" = changed
echo "$PW" | s2 restore -f --pass-stdin "$TMP/backup.enc" 2>/dev/null
check "restore -f replaces" test "$(s2 get B_TRICKY)" = "$TRICKY"

check "restore: wrong password fails" bash -c "! echo 'wrong password 1' | SECRET_KEYCHAIN='$KC2' '$SECRET' restore -f --pass-stdin '$TMP/backup.enc'"
cp "$TMP/backup.enc" "$TMP/damaged.enc"
printf 'X' | dd of="$TMP/damaged.enc" bs=1 seek=100 conv=notrunc 2>/dev/null
echo changed-again | s2 set B_TRICKY 2>/dev/null
check "restore: damaged file fails" bash -c "! echo '$PW' | SECRET_KEYCHAIN='$KC2' '$SECRET' restore -f --pass-stdin '$TMP/damaged.enc'"
check "restore: keychain unchanged after a failure" test "$(s2 get B_TRICKY)" = changed-again
check "restore: not a backup fails" bash -c "printf 'x\n' | openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -salt -pass pass:'$PW' -out '$TMP/other.enc' && ! echo '$PW' | SECRET_KEYCHAIN='$KC2' '$SECRET' restore --pass-stdin '$TMP/other.enc'"

# --- 006: маскировка под Claude Code и закодированные значения
printf '%s' 'p@ss/word+long=1' | s set AM_A 2>/dev/null
printf '%s' 'short' | s set AM_S 2>/dev/null
check "agent: masked without --mask" test "$(CLAUDECODE=1 s run AM_A -- sh -c 'echo "$AM_A"')" = '***'
check "agent: --no-mask ignored with a warning" bash -c "out=\$(CLAUDECODE=1 '$SECRET' run --no-mask AM_A -- sh -c 'echo \"\$AM_A\"' 2>&1); grep -qx '\*\*\*' <<< \"\$out\" && grep -q 'ignored for the agent' <<< \"\$out\""
check "human: no mask without the flag" test "$(s run AM_A -- sh -c 'echo "$AM_A"')" = 'p@ss/word+long=1'
check "human: --no-mask beats SECRET_RUN_MASK" test "$(SECRET_RUN_MASK=1 s run --no-mask AM_A -- sh -c 'echo "$AM_A"')" = 'p@ss/word+long=1'
check "agent: env dump masked" bash -c "! CLAUDECODE=1 '$SECRET' run AM_A -- env | grep -q 'p@ss/word'"
check "agent: python environ dump masked" bash -c "! CLAUDECODE=1 '$SECRET' run AM_A -- python3 -c 'import os; print(os.environ)' | grep -q 'p@ss/word'"
check "mask: base64" test "$(s run --mask AM_A -- sh -c 'printf %s "$AM_A" | base64')" = '***'
check "mask: base64 without padding" test "$(s run --mask AM_A -- sh -c 'printf %s "$AM_A" | base64 | tr -d =')" = '***'
check "mask: URL-safe base64" test "$(s run --mask AM_A -- sh -c 'printf %s "$AM_A" | base64 | tr "+/" "-_"')" = '***'
check "mask: URL encoding" test "$(s run --mask AM_A -- sh -c 'echo "x=p%40ss%2Fword%2Blong%3D1"')" = 'x=***'
check "mask: URL encoding with lower-case hex" test "$(s run --mask AM_A -- sh -c 'echo "p%40ss%2fword%2blong%3d1"')" = '***'
check "mask: short value masked as is" test "$(s run --mask AM_S -- sh -c 'echo "$AM_S"')" = '***'
check "mask: short value not masked in base64" test "$(s run --mask AM_S -- sh -c 'printf %s "$AM_S" | base64')" = 'c2hvcnQ='

# --- 004, 007: защищённый режим на тестовой сборке helper (Touch ID — ответ из файла)
REAL_HELPER="$ROOT/build/secret-auth"
TH="$TMP/th/secret-auth"
mkdir -p "$TMP/th"
if swiftc -swift-version 5 -O -D SECRET_TEST "$ROOT/helper/secret-auth.swift" -o "$TH" 2>/dev/null \
    && codesign -f -s - -o runtime "$TH" 2>/dev/null; then
  KC3="$TMP/third.keychain-db"
  printf 'create-keychain -p "test" "%s"\n' "$KC3" | security -i >/dev/null
  trap 'for k in "$SECRET_KEYCHAIN" "$KC2" "$KC3"; do security delete-keychain "$k" 2>/dev/null; done; rm -rf "$TMP"' EXIT
  export SECRET_TEST_AUTH="$TMP/auth-answer" SECRET_TEST_AUTH_LOG="$TMP/auth-log" SECRET_AUTH_STAMP="$TMP/auth-stamp"
  echo allow > "$SECRET_TEST_AUTH"
  s3() { SECRET_KEYCHAIN="$KC3" SECRET_AUTH_HELPER="$TH" SECRET_NO_DIALOG= "$SECRET" "$@"; }
  calls() { [ -f "$SECRET_TEST_AUTH_LOG" ] && wc -l < "$SECRET_TEST_AUTH_LOG" | tr -d ' ' || echo 0; }
  owner() { "$TH" owner "$KC3" "$@"; }

  printf '%s' "$TRICKY" | s3 set -c 'comment a' -x 2031-01-01 P_A 2>/dev/null
  echo second-value | s3 set P_B 2>/dev/null
  check "touchid: off at the start" bash -c "$(declare -f s3); TH='$TH' KC3='$KC3' SECRET='$SECRET'; s3 touchid status | grep -q '^touchid: off'"
  check "off: items belong to security" test "$(owner P_A P_B | tr '\n' ' ')" = 'foreign foreign '
  out="$(s3 touchid on 2>&1)"
  check "touchid on: 2 secrets moved" bash -c "grep -q 'touchid: on, 2 secrets moved' <<< '$out'"
  check "on: items belong to the helper" test "$(owner P_A P_B | tr '\n' ' ')" = 'mine mine '
  check "on: status with grace" bash -c "$(declare -f s3); TH='$TH' KC3='$KC3' SECRET='$SECRET'; s3 touchid status | grep -q '^touchid: on, 300s grace, helper built: yes'"
  check "on: comment and date kept" bash -c "SECRET_KEYCHAIN='$KC3' '$SECRET' ls -l | grep -q '^P_A  *2031-01-01 comment a\$'"
  check "on: policy hidden in ls" bash -c "! SECRET_KEYCHAIN='$KC3' '$SECRET' ls | grep -q __secret-cli"
  if [ -x "$REAL_HELPER" ]; then
    check "on: another helper build cannot read (no dialog)" bash -c "! '$REAL_HELPER' read '$KC3' r P_A 2>/dev/null; [ \"\$('$REAL_HELPER' owner '$KC3' P_A)\" = foreign ]"
  fi
  rm -f "$SECRET_AUTH_STAMP"
  n="$(calls)"
  check "on: get returns the value" test "$(s3 get P_A)" = "$TRICKY"
  check "on: get asked once with the reason" bash -c "[ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $((n + 1)) ] && tail -1 '$SECRET_TEST_AUTH_LOG' | grep -qx 'read P_A'"
  n="$(calls)"; s3 get P_A >/dev/null
  check "on: no new question in the grace time" test "$(calls)" = "$n"
  s3 touchid grace 0 2>/dev/null
  n="$(calls)"
  check "on: run reads both values" test "$(s3 run P_A X=P_B -- sh -c 'printf "%s|%s" "$P_A" "$X"')" = "$TRICKY|second-value"
  check "on: run asks once for all names" bash -c "[ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $((n + 1)) ] && tail -1 '$SECRET_TEST_AUTH_LOG' | grep -qx 'use P_A P_B for sh'"
  n="$(calls)"; s3 get P_B >/dev/null; s3 get P_B >/dev/null
  check "on: grace 0 asks each time" test "$(calls)" = "$((n + 2))"
  check "on: SECRET_NO_DIALOG=1 stops get" bash -c "! SECRET_KEYCHAIN='$KC3' SECRET_AUTH_HELPER='$TH' SECRET_NO_DIALOG=1 '$SECRET' get P_A"
  echo deny > "$SECRET_TEST_AUTH"
  check "on: refusal stops get without output" bash -c "out=\$(SECRET_KEYCHAIN='$KC3' SECRET_AUTH_HELPER='$TH' SECRET_NO_DIALOG= '$SECRET' get P_A 2>/dev/null); [ -z \"\$out\" ]"
  check "on: refusal stops run" bash -c "! SECRET_KEYCHAIN='$KC3' SECRET_AUTH_HELPER='$TH' SECRET_NO_DIALOG= '$SECRET' run P_A -- echo ran"
  check "on: grace change needs a confirmation" bash -c "! SECRET_KEYCHAIN='$KC3' SECRET_AUTH_HELPER='$TH' SECRET_NO_DIALOG= '$SECRET' touchid grace 600"
  echo allow > "$SECRET_TEST_AUTH"
  s3 touchid grace 300 2>/dev/null

  echo third-value | s3 set P_B 2>/dev/null
  check "on: set updates a helper item" bash -c "[ \"\$('$TH' owner '$KC3' P_B)\" = mine ] && [ \"\$(SECRET_KEYCHAIN='$KC3' SECRET_AUTH_HELPER='$TH' SECRET_NO_DIALOG= '$SECRET' get P_B)\" = third-value ]"
  s3 gen -c generated P_G 2>/dev/null
  check "on: gen creates a helper item" test "$(owner P_G)" = mine
  n="$(calls)"
  s3 note P_A 'new comment' 2>/dev/null; s3 expire P_A 2032-02-02 2>/dev/null
  check "on: note and expire without a question" test "$(calls)" = "$n"
  check "on: note and expire written" bash -c "SECRET_KEYCHAIN='$KC3' '$SECRET' ls -l | grep -q '^P_A  *2032-02-02 new comment\$'"
  s3 mv P_G P_G2 2>/dev/null
  check "on: mv keeps the item with the helper" bash -c "[ \"\$('$TH' owner '$KC3' P_G2 P_G | tr '\n' ' ')\" = 'mine missing ' ]"
  check "on: copy" bash -c "SECRET_KEYCHAIN='$KC3' SECRET_AUTH_HELPER='$TH' SECRET_NO_DIALOG= '$SECRET' copy P_B 1 2>/dev/null && [ \"\$(cat '$TMP/clip')\" = third-value ]"
  out="$(echo "$PW" | s3 export -f --pass-stdin "$TMP/p.enc" 2>&1)"
  check "on: export reads all items" bash -c "grep -q 'exported: 3 secrets' <<< '$out'"
  printf 'A=secret:P_A\nB=secret:P_B\nPORT=1\n' > p.env
  check "on: check works without a question" bash -c "SECRET_KEYCHAIN='$KC3' '$SECRET' check p.env | grep -c '^ok' | grep -qx 2"
  printf 'IMP_X=imported-value\n' > imp.env
  s3 import -p P_ imp.env 2>/dev/null
  check "on: import creates helper items" test "$(owner P_IMP_X)" = mine
  check "on: import rewrites the file" grep -qx 'IMP_X=secret:P_IMP_X' imp.env
  s3 rm P_IMP_X 2>/dev/null
  check "on: rm" test "$(owner P_IMP_X)" = missing
  s3 rm P_G2 2>/dev/null
  echo "$PW" | s3 restore --pass-stdin "$TMP/p.enc" 2>/dev/null
  check "on: restore creates helper items" bash -c "[ \"\$('$TH' owner '$KC3' P_G2)\" = mine ] && [ -n \"\$(SECRET_KEYCHAIN='$KC3' SECRET_AUTH_HELPER='$TH' SECRET_NO_DIALOG= '$SECRET' get P_G2)\" ]"
  printf '%s' 'stale' | "$TH" write "$KC3" 'P_B#new'
  echo fixed-value | s3 set P_B 2>/dev/null
  security delete-generic-password -a secret-cli -s P_B "$KC3" >/dev/null 2>&1
  printf 'add-generic-password -a secret-cli -s P_B -w "foreign" "%s"\n' "$KC3" | security -i >/dev/null
  printf '%s' 'stale' | "$TH" write "$KC3" 'P_B#new'
  echo fixed-value | s3 set P_B 2>/dev/null
  check "on: interrupted move with a stale NAME#new finishes" bash -c "[ \"\$('$TH' owner '$KC3' P_B 'P_B#new' | tr '\n' ' ')\" = 'mine missing ' ] && [ \"\$(SECRET_KEYCHAIN='$KC3' SECRET_AUTH_HELPER='$TH' SECRET_NO_DIALOG= '$SECRET' get P_B)\" = fixed-value ]"

  security delete-generic-password -a secret-cli -s P_B "$KC3" >/dev/null 2>&1
  printf 'add-generic-password -a secret-cli -s P_B -w "attacker" "%s"\n' "$KC3" | security -i >/dev/null
  check "on: a replaced item is refused" bash -c "out=\$(SECRET_KEYCHAIN='$KC3' SECRET_AUTH_HELPER='$TH' SECRET_NO_DIALOG= '$SECRET' get P_B 2>&1); [[ \$out == *'not protected: P_B'* ]] && [[ \$out != *attacker* ]]"
  echo fixed-value | s3 set P_B 2>/dev/null
  check "on: set takes the item back" test "$(owner P_B)" = mine

  s3 touchid grace 300 2>/dev/null
  echo "$(date +%s) 0000" > "$SECRET_AUTH_STAMP"
  n="$(calls)"; s3 get P_A >/dev/null
  check "on: a forged grace stamp is refused" test "$(calls)" = "$((n + 1))"

  out="$(s3 touchid off 2>&1)"
  check "touchid off: secrets moved back" bash -c "grep -q 'touchid: off, 3 secrets moved back' <<< '$out'"
  check "off: items belong to security again" test "$(owner P_A P_B P_G2 | tr '\n' ' ')" = 'foreign foreign foreign '
  check "off: values kept" bash -c "[ \"\$(SECRET_KEYCHAIN='$KC3' '$SECRET' get P_A)\" = '$(printf '%s' "$TRICKY" | sed "s/'/'\\\\''/g")' ] && [ \"\$(SECRET_KEYCHAIN='$KC3' '$SECRET' get P_B)\" = fixed-value ]"
  check "off: comment and date kept" bash -c "SECRET_KEYCHAIN='$KC3' '$SECRET' ls -l | grep -q '^P_A  *2032-02-02 new comment\$'"
  check "off: no temporary items left" bash -c "! security dump-keychain '$KC3' | grep -q -e '#plain' -e '#new'"
  check "off: status" bash -c "$(declare -f s3); TH='$TH' KC3='$KC3' SECRET='$SECRET'; s3 touchid status | grep -q '^touchid: off'"

  # обновление helper: вторая сборка с другим кодом и другим cdhash
  TH2="$TMP/th/secret-auth-2"
  { cat "$ROOT/helper/secret-auth.swift"; echo "// test build 2"; } > "$TMP/th/v2.swift"
  swiftc -swift-version 5 -O -D SECRET_TEST "$TMP/th/v2.swift" -o "$TH2" 2>/dev/null && codesign -f -s - -o runtime "$TH2" 2>/dev/null
  s3 touchid on 2>/dev/null
  out="$(s3 __rehelper "$TH2" 2>&1)"
  check "rehelper: 3 secrets moved" bash -c "grep -q 'rehelper: 3 secrets moved' <<< '$out'"
  check "rehelper: new build owns items and policy" test "$("$TH2" owner "$KC3" P_A P_B P_G2 __secret-cli.policy | tr '\n' ' ')" = 'mine mine mine mine '
  check "rehelper: old build is refused" test "$("$TH" owner "$KC3" P_A)" = foreign
  check "rehelper: values kept" test "$(SECRET_KEYCHAIN="$KC3" SECRET_AUTH_HELPER="$TH2" SECRET_NO_DIALOG= "$SECRET" get P_B)" = fixed-value
  check "rehelper: comment and date kept" bash -c "SECRET_KEYCHAIN='$KC3' '$SECRET' ls -l | grep -q '^P_A  *2032-02-02 new comment\$'"
  check "rehelper: grace kept" bash -c "[ \"\$('$TH2' policy show '$KC3')\" = grace=300 ]"
  check "rehelper: second run moves nothing" bash -c "SECRET_KEYCHAIN='$KC3' SECRET_AUTH_HELPER='$TH' SECRET_NO_DIALOG= '$SECRET' __rehelper '$TH2' 2>&1 | grep -q 'rehelper: 0 secrets moved'"
  SECRET_KEYCHAIN="$KC3" SECRET_AUTH_HELPER="$TH2" SECRET_NO_DIALOG= "$SECRET" touchid off 2>/dev/null
  check "rehelper: off with the new build" test "$("$TH2" owner "$KC3" P_A)" = foreign

  # запись helper без политики (политику удалили): bash всё равно читает через helper, Touch ID каждый раз
  printf '%s' 'no-policy-value' | "$TH" write "$KC3" NP_A
  n="$(calls)"
  check "no policy: get goes through the helper" test "$(s3 get NP_A)" = no-policy-value
  s3 get NP_A >/dev/null
  check "no policy: Touch ID each time" test "$(calls)" = "$((n + 2))"

  # подмена helper не работает для keychain по умолчанию, даже через другой путь к тому же файлу
  if [ -x "$REAL_HELPER" ]; then
    mkdir -p "$TMP/home/Library/Keychains"
    ln -s "$SECRET_KEYCHAIN" "$TMP/home/Library/Keychains/secrets.keychain-db"
    ln -s "$SECRET_KEYCHAIN" "$TMP/alias.keychain-db"
    check "override works with a test keychain" bash -c "SECRET_AUTH_HELPER=/nonexistent '$SECRET' touchid status | grep -q 'helper built: no'"
    check "override ignored for the default keychain via another path" bash -c "HOME='$TMP/home' SECRET_KEYCHAIN='$TMP/alias.keychain-db' SECRET_AUTH_HELPER=/nonexistent '$SECRET' touchid status | grep -q 'helper built: yes'"
  fi
fi

# --- 017, 018: хранилище Secure Enclave на тестовой сборке helper (программный ключ, Touch ID — ответ из файла)
TS_DIR="$ROOT/build/test"
TV="$TS_DIR/secret-vault-test"
if [ ! -x "$TV" ] || [ "$(cat "$TS_DIR/secret-vault-test.src-sha256" 2>/dev/null)" != "$(shasum -a 256 "$ROOT/helper/store/main.swift" | cut -d' ' -f1)" ]; then
  "$ROOT/helper/store/build.sh" Test "$TS_DIR" >/dev/null 2>&1 || rm -f "$TV"
fi
if [ ! -x "$TV" ]; then
  echo "skip  017: no test build of the store helper (swiftc is needed)"
else
  export SECRET_TEST_STORE="vrun$$" SECRET_TEST_STATE="$TMP/vs"
  export SECRET_TEST_AUTH="$TMP/v-auth" SECRET_TEST_AUTH_LOG="$TMP/v-auth-log" SECRET_TEST_VALUE_LOG="$TMP/v-value-log"
  trap 'for st in "vrun$$" "mig$$"; do SECRET_TEST_STORE="$st" "$TV" wipe 2>/dev/null; done; security delete-keychain "$SECRET_KEYCHAIN" "$KC5" "$KC6" 2>/dev/null; rm -rf "$TMP"' EXIT
  echo allow > "$SECRET_TEST_AUTH"
  vcalls() { [ -f "$SECRET_TEST_AUTH_LOG" ] && wc -l < "$SECRET_TEST_AUTH_LOG" | tr -d ' ' || echo 0; }

  # переезд из файлового keychain (009 → 018): свой keychain и своё хранилище
  KC6="$TMP/m.keychain-db"
  printf 'create-keychain -p "test" "%s"\n' "$KC6" | security -i >/dev/null
  sm() { SECRET_TEST_STORE="mig$$" SECRET_KEYCHAIN="$KC6" SECRET_VAULT_HELPER="$TV" SECRET_STORE_MODE="$TMP/m-mode" \
    SECRET_NO_DIALOG= "$SECRET" "$@"; }
  SM="$(declare -f sm); TV='$TV' TMP='$TMP' KC6='$KC6' SECRET='$SECRET'"
  printf '%s' "$TRICKY" | sm set -c 'Пароль «main»' D_A 2>/dev/null
  echo second-value | sm set -x 2031-01-01 D_B 2>/dev/null
  echo third-value | sm set D_C 2>/dev/null
  before="$(sm ls -l)"
  check "018: migrate refuses a test keychain without SECRET_STORE_MODE" bash -c \
    "! echo '$PW' | SECRET_TEST_STORE='mig$$' SECRET_KEYCHAIN='$KC6' SECRET_VAULT_HELPER='$TV' '$SECRET' migrate --backup '$TMP/x.bak' --pass-stdin"
  out="$(echo short | sm migrate --backup "$TMP/short.bak" --pass-stdin 2>&1)"
  check "018: migrate with a short backup password changes nothing" bash -c "grep -q 'nothing changed' <<< '$out' && [ ! -e '$TMP/short.bak' ] && [ ! -e '$TMP/m-mode' ]"
  out="$(echo "$PW" | sm migrate --backup "$TMP/m.bak" --pass-stdin 2>&1)"
  check "018: migrate moves 3 secrets" bash -c "grep -q 'migrate: 3 secrets in the secure enclave store' <<< '$out'"
  check "018: migrate writes the backup first" test -s "$TMP/m.bak"
  check "018: migrate removes the old copies" bash -c "grep -q 'secrets are removed from' <<< '$out' && [ -z \"\$(SECRET_KEYCHAIN='$KC6' '$SECRET' ls)\" ]"
  check "018: mode file" test "$(cat "$TMP/m-mode")" = vault
  check "018: ls -l as before" test "$(sm ls -l)" = "$before"
  check "018: values as before" test "$(sm get D_B)" = second-value
  check "018: special characters moved" test "$(sm get D_A)" = "$TRICKY"
  check "018: migrate again is refused" bash -c "$SM; ! echo '$PW' | sm migrate --backup '$TMP/y.bak' --pass-stdin"
  echo dp > "$TMP/m-mode"
  check "018: an old dp mode file is an error" bash -c "$SM; out=\$(sm ls 2>&1); [ \$? -ne 0 ] && [[ \$out == *'data protection store is gone'* ]]"
  echo vault > "$TMP/m-mode"
  out="$(sm migrate --back 2>&1)"
  check "018: migrate --back moves 3 secrets" bash -c "grep -q 'migrate: 3 secrets back' <<< '$out' && [ ! -e '$TMP/m-mode' ]"
  check "018: --back keeps comments, dates and values" bash -c "[ \"\$(SECRET_KEYCHAIN='$KC6' '$SECRET' ls -l)\" = '$before' ] && [ \"\$(SECRET_KEYCHAIN='$KC6' '$SECRET' get D_B)\" = second-value ]"
  check "018: --back empties the store" bash -c "[ -z \"\$(SECRET_TEST_STORE='mig$$' '$TV' list)\" ]"
  SECRET_TEST_STORE="mig$$" "$TV" wipe 2>/dev/null

  # рабочее хранилище прогона
  KC5="$TMP/v.keychain-db"
  printf 'create-keychain -p "test" "%s"\n' "$KC5" | security -i >/dev/null
  echo vault > "$TMP/v-mode"
  sv() { SECRET_KEYCHAIN="$KC5" SECRET_VAULT_HELPER="$TV" SECRET_STORE_MODE="$TMP/v-mode" SECRET_NO_DIALOG= "$SECRET" "$@"; }
  SV="$(declare -f sv); TV='$TV' TMP='$TMP' KC5='$KC5' SECRET='$SECRET'"
  VF="$SECRET_TEST_STATE/vault-$SECRET_TEST_STORE"
  : > "$SECRET_TEST_AUTH_LOG"; rm -f "$SECRET_TEST_VALUE_LOG"

  "$TV" policy init 1800
  printf '%s' "$TRICKY" | sv set -c 'Пароль «vault»' V_A 2>/dev/null
  echo second-value | sv set -x 2031-01-01 V_B 2>/dev/null
  echo third-value | sv set V_C 2>/dev/null
  check "017: set and ls -l" bash -c "$SV; sv ls -l | grep -q '^V_A  *Пароль «vault»\$' && sv ls -l | grep -q '^V_B  *2031-01-01'"
  check "017: the file hides names, comments and values" bash -c "[ -s '$VF' ] && ! grep -qa -e V_A -e second-value -e vault '$VF'"
  check "017: no warning, status names the store" bash -c "$SV; [ -z \"\$(sv ls 2>&1 >/dev/null)\" ] && sv touchid status | grep -q '^touchid: on, 1800s idle, grace .*, store: secure enclave\$'"

  n="$(vcalls)"
  sv ls >/dev/null; sv has V_A; sv ls --expiring 9999 >/dev/null; printf 'A=secret:V_A\nB=secret:V_B\nPORT=1\n' > v.env
  check "017: check" bash -c "$SV; sv check v.env | grep -c '^ok' | grep -qx 2"
  echo temp | sv set V_TMP 2>/dev/null; sv rm V_TMP 2>/dev/null
  sv touchid status >/dev/null; sv note V_C 'meta only' 2>/dev/null; sv expire V_C 2040-01-01 2>/dev/null
  check "017: ls, has, check, set, rm, status, note, expire without a question" test "$(vcalls)" = "$n"
  check "011: no value opened for them" test ! -s "$SECRET_TEST_VALUE_LOG"
  check "017: note and expire written" bash -c "$SV; sv ls -l | grep -q '^V_C  *2040-01-01 meta only\$'"
  check "017: rm removes" bash -c "$SV; ! sv has V_TMP"
  check "017: set keeps the comment" bash -c "$SV; echo new | sv set V_A 2>/dev/null; sv ls -l | grep -q '^V_A  *Пароль «vault»\$'"
  printf '%s' "$TRICKY" | sv set V_A 2>/dev/null

  sv lock 2>/dev/null; n="$(vcalls)"
  check "017: get" test "$(sv get V_C)" = third-value
  check "017: special characters kept" test "$(sv get V_A)" = "$TRICKY"
  check "017: second get in grace asks nothing" test "$(vcalls)" = "$((n + 1))"
  sv lock 2>/dev/null; n="$(vcalls)"
  check "017: run with two names asks once" bash -c "[ \"\$($SV; sv run V_B X=V_C -- sh -c 'printf \"%s %s\" \"\$V_B\" \"\$X\"')\" = 'second-value third-value' ] && [ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $((n + 1)) ] && tail -1 '$SECRET_TEST_AUTH_LOG' | grep -qx 'use V_B V_C for sh'"
  echo changed-value | sv set V_B 2>/dev/null
  check "017: a changed value is read again" test "$(sv get V_B)" = changed-value
  echo second-value | sv set V_B 2>/dev/null
  sv lock 2>/dev/null
  check "017: SECRET_NO_DIALOG=1 stops get" bash -c "out=\$(SECRET_NO_DIALOG=1 SECRET_KEYCHAIN='$KC5' SECRET_VAULT_HELPER='$TV' SECRET_STORE_MODE='$TMP/v-mode' '$SECRET' get V_A 2>/dev/null); [ \$? -ne 0 ] && [ -z \"\$out\" ]"
  echo deny > "$SECRET_TEST_AUTH"
  check "017: refusal stops get without output" bash -c "out=\$($SV; sv get V_A 2>/dev/null); [ \$? -ne 0 ] && [ -z \"\$out\" ]"
  check "017: refusal stops run" bash -c "$SV; ! sv run V_A -- echo ran"
  check "017: note works after a refusal (no Touch ID)" bash -c "$SV; sv note V_A x"
  check "017: grace change needs a confirmation" bash -c "$SV; ! sv touchid grace 0"
  echo allow > "$SECRET_TEST_AUTH"
  sv note V_A 'Пароль «vault»' 2>/dev/null

  sv gen -c generated V_G 2>/dev/null
  check "017: gen" bash -c "[ \$($SV; sv get V_G | wc -c) -eq 33 ]"
  sv mv V_G V_G2 2>/dev/null
  check "017: mv" bash -c "$SV; sv has V_G2 && ! sv has V_G"
  sv rm V_G2 2>/dev/null
  check "017: copy" bash -c "$SV; sv copy V_B 1 2>/dev/null && [ \"\$(cat '$TMP/clip')\" = second-value ]"
  printf 'IMP_X=imported-value\nIMP_Y=other value\n' > vimp.env
  sv import -p V_ vimp.env 2>/dev/null
  check "017: import stores and rewrites" bash -c "grep -qx 'IMP_X=secret:V_IMP_X' vimp.env && [ \"\$($SV; sv get V_IMP_Y)\" = 'other value' ]"
  sv rm V_IMP_X 2>/dev/null; sv rm V_IMP_Y 2>/dev/null
  check "017: touchid off is refused" bash -c "$SV; ! sv touchid off"
  check "017: grace over 3600 is refused" bash -c "$SV; ! sv touchid grace 4000"
  check "017: unlock and init do nothing" bash -c "$SV; sv unlock && sv init"

  sv touchid grace 0 2>/dev/null
  n="$(vcalls)"; sv get V_A >/dev/null; sv get V_A >/dev/null
  check "017: grace 0 asks each time" test "$(vcalls)" = "$((n + 2))"
  sv touchid grace 1800 2>/dev/null

  # --- 014: копирование со скрытым типом (тестовый буфер, не системный), status
  export SECRET_TEST_PASTEBOARD="secretcli.test.$$"
  printf 'clip-check' | "$TV" clip
  check "014: clip marks the value concealed" test "$("$TV" test-paste)" = "concealed clip-check"
  printf '' | "$TV" clip
  check "014: empty clip clears" test "$("$TV" test-paste)" = "plain "
  check "014: status without an agent" bash -c "'$TV' lock; '$TV' status | grep -qE '^ok off grace=[0-9]+\$'"
  sv get V_A >/dev/null
  check "014: status with an active grace" bash -c "'$TV' status | grep -qE '^ok active [0-9]+ [0-9]+ [0-9]+ grace=[0-9]+\$'"
  unset SECRET_TEST_PASTEBOARD

  # --- 010: скользящий grace
  sv touchid grace 2 2>/dev/null
  sv lock 2>/dev/null; n="$(vcalls)"
  for i in 1 2 3 4; do sv get V_A >/dev/null; sleep 1; done
  check "010: requests closer than the idle time ask once" test "$(vcalls)" = "$((n + 1))"
  check "010: status shows the active grace" bash -c "$SV; sv touchid status | grep -q '^touchid: on, 2s idle, grace active: [0-9]*s left'"
  sleep 3; sv get V_A >/dev/null
  check "010: the idle time asks again" test "$(vcalls)" = "$((n + 2))"
  sv lock 2>/dev/null
  check "010: status after lock" bash -c "$SV; sv touchid status | grep -q '^touchid: on, 2s idle, grace off'"
  export SECRET_TEST_MAX_GRACE=3
  n="$(vcalls)"
  for i in 1 2 3 4 5; do sv get V_A >/dev/null; sleep 1; done
  check "010: the limit asks again during requests" test "$(vcalls)" = "$((n + 2))"
  unset SECRET_TEST_MAX_GRACE
  sv lock 2>/dev/null; sv touchid grace 1800 2>/dev/null
  n="$(vcalls)"; sv get V_A >/dev/null
  "$TV" test-lock; sleep 0.5; sv get V_A >/dev/null
  check "010: a screen lock ends the grace" test "$(vcalls)" = "$((n + 2))"
  # контекст стареет: агент отдаёт прочитанные значения из памяти
  export SECRET_TEST_CONTEXT_FRESH=1
  sv lock 2>/dev/null; n="$(vcalls)"
  sv get V_A >/dev/null; sleep 2
  check "010: after the context age a value comes from memory" bash -c "[ \"\$($SV; sv get V_B)\" = second-value ] && [ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $((n + 1)) ]"
  sv note V_A 'memory note' 2>/dev/null
  check "010: note needs no question" test "$(vcalls)" = "$((n + 1))"
  check "010: note keeps the value" test "$(sv get V_A)" = "$TRICKY"
  echo changed-value | sv set V_B 2>/dev/null
  check "010: a changed item is read again after a question" bash -c "[ \"\$($SV; sv get V_B)\" = changed-value ] && [ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $((n + 2)) ]"
  check "010: the new value then comes from memory" bash -c "[ \"\$($SV; sv get V_B)\" = changed-value ] && [ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $((n + 2)) ]"
  unset SECRET_TEST_CONTEXT_FRESH
  sv lock 2>/dev/null
  echo second-value | sv set V_B 2>/dev/null
  sv note V_A 'Пароль «vault»' 2>/dev/null
  check "011: only the agent opens values" bash -c "! grep -v '^agent ' '$SECRET_TEST_VALUE_LOG'"

  out="$(echo "$PW" | sv export -f --pass-stdin "$TMP/v.enc" 2>&1)"
  check "017: export" bash -c "grep -q 'exported: 3 secrets' <<< '$out'"
  sv rm V_C 2>/dev/null
  echo "$PW" | sv restore --pass-stdin "$TMP/v.enc" 2>/dev/null
  check "017: restore" test "$(sv get V_C)" = third-value

  cp "$VF" "$TMP/vf.good"
  perl -e 'open F, "+<", $ARGV[0] or die; seek F, -1, 2; read F, $c, 1; seek F, -1, 2; print F chr(ord($c) ^ 1)' "$VF"
  check "017: a changed file is refused" bash -c "$SV; out=\$(sv ls 2>&1); [ \$? -ne 0 ] && [[ \$out == *'damaged or not ours'* ]]"
  check "017: no write over a changed file" bash -c "$SV; ! echo x | sv set V_D 2>/dev/null"
  cp "$TMP/vf.good" "$VF"
  mv "$SECRET_TEST_STATE/vault-$SECRET_TEST_STORE.key" "$TMP/vkey"
  check "017: a file without its key is an error" bash -c "$SV; out=\$(sv ls 2>&1); [ \$? -ne 0 ] && [[ \$out == *'key item of the store is missing'* ]]"
  check "017: no new key for a file without its key" bash -c "$SV; ! echo x | sv set V_D 2>/dev/null && [ ! -e '$SECRET_TEST_STATE/vault-$SECRET_TEST_STORE.key' ]"
  mv "$TMP/vkey" "$SECRET_TEST_STATE/vault-$SECRET_TEST_STORE.key"
  check "017: the store works again with its key" test "$(sv get V_C)" = third-value
  rm "$SECRET_TEST_STATE/vault-$SECRET_TEST_STORE.key"; sv lock 2>/dev/null
  echo deny > "$SECRET_TEST_AUTH"
  check "017: repair needs a confirmation" bash -c "$SV; ! sv touchid repair 2>/dev/null && [ ! -e '$SECRET_TEST_STATE/vault-$SECRET_TEST_STORE.key' ]"
  echo allow > "$SECRET_TEST_AUTH"
  check "017: repair rebuilds the key from the file" bash -c "$SV; sv touchid repair 2>&1 | grep -q 'repair: a new key item, 3 secrets'"
  check "017: values after repair" test "$(sv get V_C)" = third-value
  check "017: a damaged header is not repaired" bash -c "cp '$VF' '$TMP/vf2'; printf 'SCV2\\0\\0\\0\\2{}x' > '$VF'; $SV; ! sv touchid repair 2>/dev/null; rc=\$?; cp '$TMP/vf2' '$VF'; [ \$rc -eq 0 ]"
  check "017: repair in the file keychain is refused" bash -c "! SECRET_KEYCHAIN='$KC5' '$SECRET' touchid repair 2>/dev/null"
  cp "$VF" "$TMP/vf.old"
  sv touchid grace 60 2>/dev/null
  cp "$TMP/vf.old" "$VF"
  check "017: an old copy of the file keeps the new grace" bash -c "$SV; sv touchid status | grep -q '^touchid: on, 60s idle'"
  sv touchid grace 1800 2>/dev/null

  check "017: a changed key without a file gives a new store" bash -c "S=$SECRET_TEST_STATE/vault-other$$; printf junk > \$S.key; printf '%s %s - -\n' 41 76 | SECRET_TEST_STORE=other$$ '$TV' write && SECRET_TEST_STORE=other$$ '$TV' list | grep -q '^A'; rc=\$?; SECRET_TEST_STORE=other$$ '$TV' wipe; [ \$rc -eq 0 ]"
  check "017: a release helper is never a test helper" bash -c "out=\$(SECRET_KEYCHAIN='$KC5' SECRET_VAULT_HELPER='$ROOT/build/secret-vault' SECRET_STORE_MODE='$TMP/v-mode' SECRET_PBCOPY='cat > $TMP/leak' '$SECRET' touchid status 2>&1); [[ \$out != *'secure enclave'* ]]"
  check "013: a missing test keychain enables no override" bash -c "out=\$(SECRET_KEYCHAIN='$TMP/none.keychain-db' SECRET_VAULT_HELPER='$TV' SECRET_STORE_MODE='$TMP/v-mode' '$SECRET' ls 2>&1); [ \$? -ne 0 ] && [[ \$out == *'keychain not found'* ]]"
  printf '#!/bin/sh\n[ "$1" = kind ] && { echo test; exit 0; }\necho "secret-vault: the store file is damaged or not ours: x" >&2\nexit 1\n' > "$TMP/bad-store"; chmod +x "$TMP/bad-store"
  printf '#!/bin/sh\n[ "$1" = kind ] && { echo test; exit 0; }\nexit 1\n' > "$TMP/dead-store"; chmod +x "$TMP/dead-store"
  check "017: the error of the helper is shown" bash -c "out=\$(SECRET_KEYCHAIN='$KC5' SECRET_VAULT_HELPER='$TMP/bad-store' SECRET_STORE_MODE='$TMP/v-mode' '$SECRET' ls 2>&1); [ \$? -ne 0 ] && [[ \$out == *'helper failed: secret-vault: the store file is damaged'* ]]"
  check "017: a helper that does not start is an error, not the file keychain" bash -c "out=\$(SECRET_KEYCHAIN='$KC5' SECRET_VAULT_HELPER='$TMP/dead-store' SECRET_STORE_MODE='$TMP/v-mode' '$SECRET' ls 2>&1); [ \$? -ne 0 ] && [[ \$out == *'it did not start'* ]]"
  "$TV" wipe 2>/dev/null
  unset SECRET_TEST_STORE SECRET_TEST_STATE SECRET_TEST_AUTH SECRET_TEST_AUTH_LOG SECRET_TEST_VALUE_LOG
fi

# --- 012: SecretBar. Разбор вывода команд (--selftest); бинарник без entitlements и без вызовов keychain
APP_SUM="$(cat "$ROOT"/app/SecretBar/*.swift "$ROOT/app/SecretBar.xcodeproj/project.pbxproj" "$ROOT"/app/SecretBar/Assets.xcassets/AppIcon.appiconset/Contents.json | shasum -a 256 | cut -d' ' -f1)"
if [ ! -x "$ROOT/build/SecretBar.app/Contents/MacOS/SecretBar" ] || [ "$(cat "$ROOT/build/SecretBar.src-sha256" 2>/dev/null)" != "$APP_SUM" ]; then
  "$ROOT/app/build.sh" "$ROOT/build" >/dev/null 2>&1 || true
fi
if [ -x "$ROOT/build/SecretBar.app/Contents/MacOS/SecretBar" ]; then
  check "012: selftest" "$ROOT/build/SecretBar.app/Contents/MacOS/SecretBar" --selftest
  check "012: no entitlements" bash -c "[ -z \"\$(codesign -d --entitlements - --xml '$ROOT/build/SecretBar.app' 2>/dev/null)\" ]"
  check "012: no keychain calls in the binary" bash -c "! nm -u '$ROOT/build/SecretBar.app/Contents/MacOS/SecretBar' | grep -qE 'SecItem|SecKeychain'"
  check "012: hardened runtime" bash -c "codesign -dvv '$ROOT/build/SecretBar.app' 2>&1 | grep -q 'flags=.*runtime'"
else
  echo "skip  012: no build of SecretBar (Xcode needed)"
fi
# 015: the installed app has its items in the Spotlight index (names and comments only)
if [ -x /Applications/SecretBar.app/Contents/MacOS/SecretBar ] && [ "$(defaults read local.secretcli.bar spotlight 2>/dev/null)" != 0 ]; then
  check "015: spotlight index of the installed app" bash -c "/Applications/SecretBar.app/Contents/MacOS/SecretBar --spotlight-check | grep -qE '^spotlight: [1-9][0-9]* items\$'"
else
  echo "skip  015: SecretBar is not installed or Spotlight is off"
fi

# заблокированный keychain: статус через helper, системное окно не открывается
if [ -x "$REAL_HELPER" ]; then
  s lock 2>/dev/null
  check "helper: status locked" test "$("$REAL_HELPER" status "$SECRET_KEYCHAIN")" = locked
  check "locked keychain with SECRET_NO_DIALOG fails" bash -c "! '$SECRET' has T_B </dev/null"
  printf 'unlock-keychain -p "test" "%s"\n' "$SECRET_KEYCHAIN" | security -i >/dev/null
  check "helper: status unlocked" test "$("$REAL_HELPER" status "$SECRET_KEYCHAIN")" = unlocked
fi

for c in 'secret touchid off' 'secret touchid grace 0' \
         'touch ~/.local/state/secret/touchid-ok' 'SECRET_AUTH_HELPER=/usr/bin/true secret get X' \
         'SECRET_STORE_MODE=/tmp/m secret ls' 'SECRET_TEST_AUTH=/tmp/a secret get X' \
         'build/secret-vault read r X' 'cd build && ./secret-vault read r X' \
         'SECRET_VAULT_HELPER=/tmp/v secret ls' 'secret touchid repair' \
         'x=$(secret-vault read r X)' 'true;secret-vault read r X' 'echo `secret-vault read r X`' \
         'cp build/secret-vault /tmp/sv && /tmp/sv read r X' 'build/secret-vault.bak read r X'; do
  check "hook blocks: $c" bash -c "$(declare -f hook); HOOK='$HOOK'; hook '$c'; [ \$? -eq 2 ]"
done
check "hook passes: secret touchid status" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'secret touchid status'"
check "014: copy under Claude Code is refused" bash -c "out=\$(CLAUDECODE=1 '$SECRET' copy T_B 2>&1); [ \$? -ne 0 ] && [[ \$out == *'copy is for the user'* ]]"
check "014: SECRET_VIA names the source in the log" bash -c "SECRET_VIA=shortcuts '$SECRET' get T_B >/dev/null && tail -1 '$SECRET_LOG' | cut -f3 | grep -qx shortcuts"
check "014: SECRET_VIA cannot hide the agent" bash -c "CLAUDECODE=1 SECRET_VIA=secretbar '$SECRET' run T_B -- true && tail -1 '$SECRET_LOG' | cut -f3 | grep -qx agent"
check "hook blocks: secret copy X" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'secret copy X'; [ \$? -eq 2 ]"
check "hook passes: secret migrate --back" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'secret migrate --back'"
check "hook passes: helper/store/build-vault.sh Release build" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'helper/store/build-vault.sh Release build'"
check "hook passes: cat build/secret-vault.src-sha256" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'cat build/secret-vault.src-sha256'"

echo
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
