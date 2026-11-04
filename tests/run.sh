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
         'grep -n "cat .env" README.md' \
         'secret lease --for 6h SHOP_API_KEY SHOP_DB_PASSWORD' \
         'secret lease -e .env' \
         'secret lease status' \
         'secret lease --revoke'; do
  check "hook passes: $c" bash -c "$(declare -f hook); HOOK='$HOOK'; hook '$c'"
done
check "026: lease needs the secure enclave store" bash -c "out=\$('$SECRET' lease T_B 2>&1); [ \$? -eq 1 ] && [[ \$out == *'lease needs the secure enclave store'* ]]"
check "026: lease status and --revoke need the secure enclave store" bash -c "! '$SECRET' lease status 2>/dev/null && ! '$SECRET' lease --revoke 2>/dev/null"
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

  # --- 026: agent lease (a locked screen and a sleep end the grace, not the lease)
  echo x-value | sv set V_X 2>/dev/null
  sv lock 2>/dev/null
  n="$(vcalls)"
  out="$(sv lease --for 6h V_B V_C 2>&1)"
  check "026: lease prints the end and the names" bash -c "[[ '$out' =~ ^leased\ until\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:\ V_B,\ V_C\$ ]]"
  check "026: lease asks Touch ID once and names the names and the term" bash -c "[ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $((n + 1)) ] && tail -1 '$SECRET_TEST_AUTH_LOG' | grep -qx 'lease V_B, V_C for 6h'"
  out="$(sv lease status 2>&1)"
  check "026: lease status shows names and the end, no values" bash -c "[ \$(grep -cE '^V_[BC]	[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}\$' <<< '$out') -eq 2 ] && [[ '$out' != *second-value* ]] && [[ '$out' != *third-value* ]]"
  n="$(vcalls)"
  check "026: a leased name needs no Touch ID with an open screen" bash -c "$SV; [ \"\$(sv run V_B -- sh -c 'printf %s \"\$V_B\"')\" = second-value ] && [ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $n ]"
  "$TV" test-lock
  check "026: SC-001 a leased name is read after a screen lock without Touch ID" bash -c "$SV; [ \"\$(sv run V_C -- sh -c 'printf %s \"\$V_C\"')\" = third-value ] && [ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $n ]"
  t0="$(perl -MTime::HiRes=time -e 'printf "%.3f", time')"
  out="$(sv run V_A -- true 2>&1)"; rc=$?
  t1="$(perl -MTime::HiRes=time -e 'printf "%.3f", time')"
  check "026: SC-001 a name outside the lease fails at once with not leased" bash -c "[ $rc -ne 0 ] && [[ '$out' == *'not leased: V_A'* ]] && [ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $n ] && perl -e 'exit(($t1 - $t0) < 1 ? 0 : 1)'"
  out="$(sv run V_A V_X V_B -- true 2>&1)"
  check "026: not leased names all of them, and only them" bash -c "[[ '$out' == *'not leased: V_A, V_X'* ]] && [[ '$out' != *V_B,* ]]"
  out="$(sv get V_A 2>&1)"
  check "026: get outside the lease on a locked screen" bash -c "[[ '$out' == *'not leased: V_A'* ]] && [[ '$out' != *vault-value* ]]"
  check "026: lease on a locked screen is refused without Touch ID" bash -c "$SV; out=\$(sv lease V_A 2>&1); [ \$? -ne 0 ] && [[ \$out == *'the screen is locked'* ]] && [ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $n ]"
  "$TV" test-sleep
  check "026: SC-001 a sleep keeps the lease" bash -c "$SV; [ \"\$(sv run V_B -- sh -c 'printf %s \"\$V_B\"')\" = second-value ] && [ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $n ]"
  check "026: the status line of the helper has the lease" bash -c "'$TV' status | grep -qE '^ok off grace=[0-9]+ lease=2:[0-9]+\$'"
  "$TV" test-unlock
  check "026: a name outside the lease asks Touch ID again with an open screen" bash -c "$SV; sv get V_A >/dev/null && [ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $((n + 1)) ]"
  # the grace of a name outside the lease still ends at a screen lock
  n="$(vcalls)"
  sv get V_A >/dev/null; sv get V_A >/dev/null
  check "026: the grace serves the second request" test "$(vcalls)" = "$n"
  "$TV" test-lock; "$TV" test-unlock
  sv get V_A >/dev/null
  check "026: a screen lock still ends the grace for a name outside the lease" test "$(vcalls)" = "$((n + 1))"
  "$TV" test-sleep; sv get V_A >/dev/null
  check "026: a sleep still ends the grace for a name outside the lease" test "$(vcalls)" = "$((n + 2))"
  check "026: the leased name is still served after the grace ended" bash -c "$SV; [ \"\$(sv run V_B -- sh -c 'printf %s \"\$V_B\"')\" = second-value ] && [ \$(wc -l < '$SECRET_TEST_AUTH_LOG') -eq $((n + 2)) ]"
  # a new lease needs its own Touch ID, the grace does not stand in for it
  sv get V_A >/dev/null; n="$(vcalls)"
  sv lease V_X >/dev/null 2>&1
  check "026: a lease asks a new Touch ID in an active grace" test "$(vcalls)" = "$((n + 1))"
  check "026: leases add up" bash -c "$SV; [ \"\$(sv lease status | cut -f1 | tr '\n' ' ')\" = 'V_B V_C V_X ' ]"
  # the later end stays for a name that is leased again
  e1="$("$TV" lease-status | awk -F'\t' '$1 == "V_B" { print $2 }')"
  sv lease --for 1h V_B >/dev/null 2>&1
  e2="$("$TV" lease-status | awk -F'\t' '$1 == "V_B" { print $2 }')"
  check "026: the later end stays for a repeated name" bash -c "[ $((e2 - e1)) -ge -1 ] && [ $((e2 - e1)) -le 1 ] && [ $((e1 - $(date +%s))) -gt 20000 ]"
  # logs
  check "026: the log marks the reads from a lease" bash -c "awk -F'\t' '\$2 == \"run\" && \$5 ~ /lease=V_B/ { f = 1 } END { exit !f }' '$SECRET_LOG'"
  check "026: the log has the lease request" bash -c "awk -F'\t' '\$2 == \"lease\" && \$4 ~ /V_B V_C/ { f = 1 } END { exit !f }' '$SECRET_LOG'"
  check "026: the log marks get from a lease" bash -c "$SV; sv get V_B >/dev/null; awk -F'\t' '\$2 == \"get\" && \$4 == \"V_B\" && \$5 ~ /lease=V_B/ { f = 1 } END { exit !f }' '$SECRET_LOG'"
  check "026: the log has no values" bash -c "! grep -q -e second-value -e third-value '$SECRET_LOG'"
  # revoke
  "$TV" test-lock
  sv lease --revoke 2>"$TMP/revoke-err"
  check "026: SC-003 revoke says so" grep -qx 'lease revoked' "$TMP/revoke-err"
  check "026: SC-003 revoke ends the lease" bash -c "$SV; out=\$(sv run V_B -- true 2>&1); [ \$? -ne 0 ] && [[ \$out == *'not leased: V_B'* ]]"
  check "026: the log has the revoke" bash -c "awk -F'\t' '\$2 == \"lease-revoke\" { f = 1 } END { exit !f }' '$SECRET_LOG'"
  check "026: lease status after revoke" bash -c "$SV; out=\$(sv lease status 2>&1); [ \$? -eq 0 ] && [ \"\$out\" = 'no lease' ]"
  "$TV" test-unlock
  # lock ends the lease, also with an open screen
  sv lease V_B >/dev/null 2>&1
  sv lock 2>/dev/null
  check "026: SC-003 lock ends the lease" bash -c "$SV; [ \"\$(sv lease status 2>&1)\" = 'no lease' ]"
  # set and rm take the name out of the lease, the others stay
  sv lease V_B V_C V_X >/dev/null 2>&1
  "$TV" test-lock
  echo changed-value | sv set V_B 2>/dev/null
  check "026: SC-003 set takes the name out of the lease" bash -c "$SV; out=\$(sv run V_B -- true 2>&1); [ \$? -ne 0 ] && [[ \$out == *'not leased: V_B'* ]] && [ \"\$(sv run V_C -- sh -c 'printf %s \"\$V_C\"')\" = third-value ]"
  sv rm V_X 2>/dev/null
  check "026: SC-003 rm takes the name out of the lease" bash -c "$SV; ! sv run V_X -- true 2>/dev/null && [ \"\$(sv lease status | cut -f1)\" = V_C ]"
  "$TV" test-unlock
  echo second-value | sv set V_B 2>/dev/null
  sv lock 2>/dev/null
  # the limit of the term: continuous requests do not extend it, a sleep does not stop the clock
  export SECRET_TEST_MAX_LEASE=3
  sv lease --for 5h V_B >/dev/null 2>&1
  unset SECRET_TEST_MAX_LEASE
  "$TV" test-lock
  r=""
  for i in 1 2 3 4 5; do
    if sv run V_B -- true >/dev/null 2>&1; then r="${r}y"; else r="${r}n"; fi
    sleep 1
  done
  check "026: SC-002 the term ends the lease under continuous requests" bash -c "[[ '$r' == y*nn ]] && [[ '$r' != *ny* ]]"
  sv lock 2>/dev/null
  # refused Touch ID, bad calls
  echo deny > "$SECRET_TEST_AUTH"; n="$(vcalls)"
  out="$(sv lease V_B 2>&1)"; rc=$?
  check "026: SC-004 a refused Touch ID gives no lease" bash -c "[ $rc -ne 0 ] && [ \"\$($SV; sv lease status 2>&1)\" = 'no lease' ]"
  echo allow > "$SECRET_TEST_AUTH"; n="$(vcalls)"
  out="$(sv lease --for 25h V_B 2>&1)"; rc=$?
  check "026: SC-004 25h is refused before the dialog" bash -c "[ $rc -eq 64 ] && [[ '$out' == *'--for must be 1m..24h'* ]] && [ \"\$(cat '$SECRET_TEST_AUTH_LOG' | wc -l | tr -d ' ')\" = $n ]"
  check "026: --for 1441m and a bad form are refused" bash -c "$SV; ! sv lease --for 1441m V_B 2>/dev/null && ! sv lease --for 2d V_B 2>/dev/null && ! sv lease --for 0m V_B 2>/dev/null"
  check "026: --for 24h is accepted" bash -c "$SV; sv lease --for 24h V_B 2>/dev/null && sv lease --revoke 2>/dev/null"
  n="$(vcalls)"
  printf 'PLAIN=1\n# C=secret:V_B\n' > "$TMP/noref.env"
  out="$(sv lease -e "$TMP/noref.env" 2>&1)"; rc=$?
  check "026: SC-004 an env file without references is refused before the dialog" bash -c "[ $rc -eq 64 ] && [[ '$out' == *'lease needs NAME'* ]] && [ \"\$(cat '$SECRET_TEST_AUTH_LOG' | wc -l | tr -d ' ')\" = $n ]"
  check "026: lease without names is refused" bash -c "$SV; ! sv lease 2>/dev/null"
  out="$(sv lease V_NOPE 2>&1)"; rc=$?
  check "026: a missing name is refused before the dialog" bash -c "[ $rc -eq 3 ] && [[ '$out' == *'not found: V_NOPE'* ]] && [ \"\$(cat '$SECRET_TEST_AUTH_LOG' | wc -l | tr -d ' ')\" = $n ]"
  printf 'B=secret:V_B\nC=secret:V_C\nB2=secret:V_B\n' > "$TMP/refs.env"
  check "026: lease -e takes the names of the references" bash -c "$SV; sv lease -e '$TMP/refs.env' 2>/dev/null && [ \"\$(sv lease status | cut -f1 | tr '\n' ' ')\" = 'V_B V_C ' ]"
  check "026: SECRET_NO_DIALOG=1 gives no lease" bash -c "$SV; sv lock 2>/dev/null; out=\$(SECRET_NO_DIALOG=1 SECRET_KEYCHAIN='$KC5' SECRET_VAULT_HELPER='$TV' SECRET_STORE_MODE='$TMP/v-mode' '$SECRET' lease V_B 2>&1); [ \$? -eq 5 ] && [[ \$out == *SECRET_NO_DIALOG* ]] && [ \"\$(sv lease status 2>&1)\" = 'no lease' ]"
  for i in 1 2 3 4 5; do echo l-value | sv set V_L$i 2>/dev/null; done
  sv lease --for 1h V_B V_C V_L1 V_L2 V_L3 V_L4 V_L5 >/dev/null 2>&1
  check "026: a long list in the dialog shows five names and the rest as a count" bash -c "tail -1 '$SECRET_TEST_AUTH_LOG' | grep -qx 'lease V_B, V_C, V_L1, V_L2, V_L3 and 2 more for 1h'"
  for i in 1 2 3 4 5; do sv rm V_L$i 2>/dev/null; done
  sv lock 2>/dev/null
  echo allow > "$SECRET_TEST_AUTH"

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

# --- 027: Safari cookies (a synthetic Cookies.binarycookies, no Safari, no Full Disk Access)
CK_DIR="$ROOT/build/test"
CK="$CK_DIR/secret-cookies-test"
if [ ! -x "$CK" ] || [ "$(cat "$CK_DIR/secret-cookies-test.src-sha256" 2>/dev/null)" != "$(shasum -a 256 "$ROOT/helper/cookies/main.swift" | cut -d' ' -f1)" ]; then
  "$ROOT/helper/cookies/build.sh" Test "$CK_DIR" >/dev/null 2>&1 || rm -f "$CK"
fi
# fixture: a directory like Safari's Library, the default profile and profiles in WebsiteDataStore/<UUID>
CKS="$TMP/safari"
UA=AAAAAAAA-1111-2222-3333-444444444444
UB=BBBBBBBB-1111-2222-3333-444444444444
CKF="$CKS/Cookies/Cookies.binarycookies"
if [ -x "$CK" ]; then
  mkdir -p "$TMP/mkc"
  cat > "$TMP/mkc/main.swift" <<'SWIFT'
import Foundation
func le32(_ v: Int) -> [UInt8] { [UInt8(v & 255), UInt8((v >> 8) & 255), UInt8((v >> 16) & 255), UInt8((v >> 24) & 255)] }
func be32(_ v: Int) -> [UInt8] { le32(v).reversed() }
func le64(_ d: Double) -> [UInt8] { let b = d.bitPattern; return (0..<8).map { UInt8((b >> UInt64(8 * $0)) & 255) } }
// domain, name, path, value, flags, expiry (Mac epoch seconds, 0 = none)
// argv: output file, row set (default, profile-a)
typealias Row = (String, String, String, String, Int, Double)
let sets: [String: [Row]] = [
    "default": [
        (".shop.test", "sid", "/", "VAL-SID-1", 5, 802000000),
        ("www.shop.test", "pref", "/", "VAL-PREF", 0, 0),
        (".shop.test", "dup", "/a", "VAL-DUP-A", 1, 0),
        (".shop.test", "dup", "/b", "VAL-DUP-B", 1, 0),
        (".other.test", "sid", "/", "VAL-OTHER", 1, 0),
        (".shop.test", "shared", "/", "VAL-SH-DEF", 1, 802000000),
        (".shop.test", "split", "/x", "VAL-SPLIT-X", 1, 0),
        (".shop.test", "JSESSIONID", "/", "VAL-JSID", 1, 802000000),
    ],
    "profile-a": [
        (".shop.test", "onlyp", "/", "VAL-ONLY-P", 1, 802000000),
        (".shop.test", "shared", "/", "VAL-SH-PROF", 1, 810000000),
        (".shop.test", "split", "/y", "VAL-SPLIT-Y", 1, 0),
    ],
]
let rows = sets[CommandLine.arguments[2]]!
func record(_ r: Row) -> [UInt8] {
    let strs = [r.0, r.1, r.2, r.3].map { Array($0.utf8) + [0] }
    var offs: [Int] = []
    var o = 56
    for s in strs { offs.append(o); o += s.count }
    var b = le32(o) + le32(0) + le32(r.4) + le32(0)
    for x in offs { b += le32(x) }
    b += [UInt8](repeating: 0, count: 8) + le64(r.5) + le64(0)
    for s in strs { b += s }
    return b
}
let recs = rows.map(record)
var page = be32(0x100) + le32(recs.count)
var off = 8 + 4 * recs.count + 4
for r in recs { page += le32(off); off += r.count }
page += le32(0)
for r in recs { page += r }
let file = Array("cook".utf8) + be32(1) + be32(page.count) + page
try! Data(file).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT
  mkdir -p "$CKS/Cookies" "$CKS/WebKit/WebsiteDataStore/$UA/Cookies" "$CKS/WebKit/WebsiteDataStore/$UB"
  swiftc -swift-version 5 "$TMP/mkc/main.swift" -o "$TMP/mkc/mk" 2>/dev/null && "$TMP/mkc/mk" "$CKF" default \
    && "$TMP/mkc/mk" "$CKS/WebKit/WebsiteDataStore/$UA/Cookies/Cookies.binarycookies" profile-a
fi
if [ ! -s "$CKF" ]; then
  echo "skip  027: no test build of the cookies helper or the fixture (swiftc is needed)"
else
  export SECRET_TEST_SAFARI="$CKS" SECRET_COOKIES_HELPER="$CK"
  TAB=$'\t'
  check "027: list shows name, path, flags and date" bash -c "'$CK' list shop.test | grep -qE '^sid${TAB}/${TAB}Secure,HTTPOnly${TAB}20[0-9]{2}-[0-9]{2}-[0-9]{2}${TAB}default\$'"
  check "027: list shows no value" bash -c "! '$CK' list shop.test | grep -q VAL-"
  check "027: list: a cookie without flags and date" bash -c "'$CK' list www.shop.test | grep -qx \"pref${TAB}/${TAB}-${TAB}-${TAB}default\""
  check "027: list: a leading-dot cookie covers a subdomain" bash -c "'$CK' list api.shop.test | grep -q '^sid'"
  check "027: list: a host-only cookie does not cover its parent" bash -c "! '$CK' list shop.test | grep -q '^pref'"
  check "027: list: other domains are not mixed in" bash -c "! '$CK' list shop.test | grep -q other"
  check "027: list: an empty domain exits 0 with no output" bash -c "out=\$('$CK' list none.test); [ \$? -eq 0 ] && [ -z \"\$out\" ]"
  check "027: value" test "$("$CK" value shop.test sid)" = VAL-SID-1
  check "027: value of the other domain" test "$("$CK" value other.test sid)" = VAL-OTHER
  check "027: value: several paths need PATH, no value shown" bash -c "out=\$('$CK' value shop.test dup 2>&1); [ \$? -eq 3 ] && [[ \$out == */a* && \$out == */b* && \$out != *VAL-* ]]"
  check "027: value with PATH" test "$("$CK" value shop.test dup /b)" = VAL-DUP-B
  check "027: value: missing cookie exits 1" bash -c "'$CK' value shop.test nope 2>/dev/null; [ \$? -eq 1 ]"
  mkdir -p "$TMP/safari-noperm/Cookies"; : > "$TMP/safari-noperm/Cookies/Cookies.binarycookies"; chmod 000 "$TMP/safari-noperm/Cookies/Cookies.binarycookies"
  check "027: an unreadable file exits 77" bash -c "SECRET_TEST_SAFARI='$TMP/safari-noperm' '$CK' list x.test 2>/dev/null; [ \$? -eq 77 ]"
  chmod 600 "$TMP/safari-noperm/Cookies/Cookies.binarycookies"
  mkdir -p "$TMP/safari-junk/Cookies"; printf 'cookXXXXXXXX' > "$TMP/safari-junk/Cookies/Cookies.binarycookies"
  check "027: a damaged file is an error, not a crash" bash -c "SECRET_TEST_SAFARI='$TMP/safari-junk' '$CK' list x.test 2>/dev/null; [ \$? -eq 65 ]"
  check "027: cookie ls prints a table without values" bash -c "out=\$('$SECRET' cookie ls shop.test); [[ \$out == *NAME* && \$out == *sid* && \$out != *VAL-* ]]"
  s cookie pull shop.test sid --as CK_SID >/dev/null 2>&1
  check "027: pull stores the value" test "$(s get CK_SID)" = VAL-SID-1
  check "027: pull sets the comment" test "$(s note CK_SID)" = "safari cookie shop.test sid, profile default"
  check "027: pull sets the expiry from the cookie" bash -c "'$SECRET' ls -l | grep -qE '^CK_SID +20[0-9]{2}-[0-9]{2}-[0-9]{2} +safari cookie shop.test sid, profile default\$'"
  s cookie pull www.shop.test pref --as CK_PREF >/dev/null 2>&1
  check "027: pull of a cookie without a date sets no expiry" bash -c "'$SECRET' ls -l | grep -E '^CK_PREF ' | grep -vqE '20[0-9]{2}-[0-9]{2}-[0-9]{2}'"
  check "027: pull: several paths without --path fail, nothing stored" bash -c "! '$SECRET' cookie pull shop.test dup --as CK_DUP 2>/dev/null && ! '$SECRET' has CK_DUP"
  s cookie pull shop.test dup --path /a --as CK_DUP >/dev/null 2>&1
  check "027: pull --path" test "$(s get CK_DUP)" = VAL-DUP-A
  check "027: pull: a missing cookie fails, nothing stored" bash -c "! '$SECRET' cookie pull shop.test nope --as CK_NOPE 2>/dev/null && ! '$SECRET' has CK_NOPE"
  check "027: pull needs --as" bash -c "! '$SECRET' cookie pull shop.test sid 2>/dev/null"
  check "027: pull checks the secret name" bash -c "! '$SECRET' cookie pull shop.test sid --as 'bad name' 2>/dev/null"
  check "027: pull keeps the value out of the output" bash -c "out=\$('$SECRET' cookie pull shop.test sid --as CK_SID 2>&1); [[ \$out != *VAL-* ]]"
  check "027: no helper: unavailable, other commands work" bash -c "out=\$(SECRET_COOKIES_HELPER='$TMP/none' '$SECRET' cookie ls shop.test 2>&1); [ \$? -ne 0 ] && [[ \$out == *'not available'* ]] && '$SECRET' has CK_SID"
  # 029: profiles
  check "029: a cookie only in a profile is listed with its UUID" bash -c "'$SECRET' cookie ls shop.test | grep -E '^onlyp ' | grep -q '$UA\$'"
  s cookie pull shop.test onlyp --as CK_ONLY >/dev/null 2>&1
  check "029: pull of a profile-only cookie" test "$(s get CK_ONLY)" = VAL-ONLY-P
  check "029: pull comment names the profile" test "$(s note CK_ONLY)" = "safari cookie shop.test onlyp, profile $UA"
  s cookie pull shop.test shared --as CK_SH >/dev/null 2>&1
  check "029: same cookie in two profiles: the latest expiry wins" test "$(s get CK_SH)" = VAL-SH-PROF
  check "029: the expiry comes from the chosen cookie" bash -c "'$SECRET' ls -l | grep -E '^CK_SH ' | grep -q ' 2026-09-02 '"
  s cookie pull shop.test shared --profile default --as CK_SHD >/dev/null 2>&1
  check "029: --profile default reads the default profile" test "$(s get CK_SHD)" = VAL-SH-DEF
  check "029: --profile default: expiry of the default cookie" bash -c "'$SECRET' ls -l | grep -E '^CK_SHD ' | grep -q ' 2026-06-01 '"
  check "029: ls --profile shows one profile" bash -c "out=\$('$SECRET' cookie ls --profile $UA shop.test); [[ \$out == *onlyp* && \$out != *pref* ]]"
  check "029: an unknown profile exits 1" bash -c "out=\$('$CK' --profile nope list shop.test 2>&1); [ \$? -eq 1 ] && [[ \$out == *'no Safari profile'* ]]"
  check "029: pull with an unknown profile fails" bash -c "out=\$('$SECRET' cookie pull shop.test sid --profile nope --as CK_NP 2>&1); [ \$? -ne 0 ] && [[ \$out == *'no Safari profile'* ]] && ! '$SECRET' has CK_NP"
  mkdir -p "$TMP/safari-def/Cookies"; cp "$CKF" "$TMP/safari-def/Cookies/"
  check "029: no WebsiteDataStore: only the default profile" bash -c "SECRET_TEST_SAFARI='$TMP/safari-def' '$CK' value shop.test sid | grep -qx VAL-SID-1 && [ \$(SECRET_TEST_SAFARI='$TMP/safari-def' '$CK' path | wc -l) -eq 1 ]"
  check "029: a profile dir without a cookie file is skipped" bash -c "'$CK' list shop.test >/dev/null 2>&1; [ \$? -eq 0 ] && '$CK' list shop.test | grep -q onlyp"
  cp -R "$CKS" "$TMP/safari-bad"; mkdir -p "$TMP/safari-bad/WebKit/WebsiteDataStore/$UB/Cookies"; printf 'cookXXXXXXXX' > "$TMP/safari-bad/WebKit/WebsiteDataStore/$UB/Cookies/Cookies.binarycookies"
  check "029: a damaged profile file exits 65 and names the file" bash -c "SECRET_TEST_SAFARI='$TMP/safari-bad' '$CK' list shop.test >/dev/null 2>'$TMP/bad.err'; rc=\$?; [ \$rc -eq 65 ] && grep -q '$UB' '$TMP/bad.err'"
  check "029: two paths in two profiles exit 3 with both paths" bash -c "out=\$('$CK' value shop.test split 2>&1); [ \$? -eq 3 ] && [[ \$out == */x* && \$out == */y* && \$out != *VAL-* ]]"
  check "029: pull of such a cookie stores nothing" bash -c "! '$SECRET' cookie pull shop.test split --as CK_SPLIT 2>/dev/null && ! '$SECRET' has CK_SPLIT"
  check "029: path lists default and each UUID" bash -c "out=\$('$CK' path); printf '%s\n' \"\$out\" | grep -q '^default${TAB}' && printf '%s\n' \"\$out\" | grep -q '^$UA${TAB}' && printf '%s\n' \"\$out\" | grep -q '^$UB${TAB}'"
  check "029: which prints profile and expiry" bash -c "out=\$('$CK' which shop.test shared); [ \"\$out\" = \"$UA${TAB}2026-09-02\" ]"
  check "029: which and path show no value" bash -c "! { '$CK' which shop.test shared; '$CK' path; } | grep -q VAL-"
  check "029: no secret comment holds a value" bash -c "! '$SECRET' ls -l | grep -q 'VAL-'"
  # 030: pull --all gathers the persistent cookies of the domain into one jar
  s cookie pull shop.test --all --as CK_JAR >/dev/null 2>&1
  check "030: pull --all stores a jar of the persistent cookies" bash -c "j=\$('$SECRET' get CK_JAR | base64 -D); grep -q VAL-SID-1 <<<\"\$j\" && grep -q VAL-ONLY-P <<<\"\$j\" && ! grep -q -e VAL-PREF -e VAL-DUP <<<\"\$j\""
  check "030: pull --all: the latest expiry wins, HttpOnly marked" bash -c "j=\$('$SECRET' get CK_JAR | base64 -D); grep -q VAL-SH-PROF <<<\"\$j\" && ! grep -q VAL-SH-DEF <<<\"\$j\" && grep -q '^#HttpOnly_.shop.test	TRUE	/	TRUE	[0-9]*	sid	VAL-SID-1\$' <<<\"\$j\""
  check "030: pull --all: comment and expiry" bash -c "[ \"\$('$SECRET' note CK_JAR)\" = 'cookie jar shop.test via safari, 4 cookies' ] && '$SECRET' ls -l | grep -E '^CK_JAR ' | grep -qE ' 20[0-9]{2}-[0-9]{2}-[0-9]{2} '"
  check "030: pull --all prints no value" bash -c "out=\$('$SECRET' cookie pull shop.test --all --as CK_JAR 2>&1); [[ \$out != *VAL-* ]]"
  check "030: pull --all takes no NAME" bash -c "! '$SECRET' cookie pull shop.test sid --all --as CK_JAR2 2>/dev/null"
  check "030: pull --all of an empty domain stores nothing" bash -c "! '$SECRET' cookie pull none.test --all --as CK_JAR3 2>/dev/null && ! '$SECRET' has CK_JAR3"
  check "030: ls gives the hint for a known session cookie name" bash -c "'$SECRET' cookie ls shop.test 2>&1 >/dev/null | grep -qF 'session cookie not on disk: capture it with the Safari extension (secret cookie import --as NAME)'"
  check "030: pull --all gives the same hint" bash -c "'$SECRET' cookie pull shop.test --all --as CK_JAR 2>&1 >/dev/null | grep -qF 'session cookie not on disk'"
  unset SECRET_TEST_SAFARI SECRET_COOKIES_HELPER
fi

# --- 030: cookie import, cookie jar, mask of short values
{
  T=$'\t'
  FJAR="$TMP/login.jar"
  printf '# Netscape HTTP Cookie File\n#HttpOnly_.shop.test\tTRUE\t/\tTRUE\t0\tASP.NET_SessionId\tSESSVAL-AAAA\n.shop.test\tTRUE\t/\tFALSE\t1893456000\tpref\tPREFVAL-BBBB\nshop.test\tFALSE\t/\tFALSE\t0\tisEmp\t0\n' > "$FJAR"
  printf '#HttpOnly_.shop.test\tTRUE\t/\tTRUE\t0\tonly1\tONLYVAL-1111\nshop.test\tFALSE\t/\tFALSE\t0\tonly2\tONLYVAL-2222\n' > "$TMP/session.jar"
  printf '.shop.test\tTRUE\t/\tFALSE\t0\t.ASPXAUTH\tAUTHVAL-3333\n' > "$TMP/aspx.jar"
  : > "$TMP/empty.jar"
  s cookie import --as LJ_A < "$FJAR" >/dev/null 2>"$TMP/login.err"
  check "030: import stores a base64 jar (one line, decodes to the jar)" bash -c "v=\$('$SECRET' get LJ_A); [[ \$v != *\$'\n'* ]] && [ \"\$(printf '%s' \"\$v\" | base64 -D)\" = \"\$(cat '$FJAR')\" ]"
  check "030: import comment names the cookies and the session-only ones" test "$(s note LJ_A)" = "cookie jar shop.test via safari extension, 3 cookies, session-only: ASP.NET_SessionId,isEmp"
  check "030: import sets the earliest expiry of the persistent cookies" bash -c "'$SECRET' ls -l | grep -E '^LJ_A ' | grep -q ' 2030-01-01 '"
  check "030: import prints no value" bash -c "! grep -q -e SESSVAL -e PREFVAL '$TMP/login.err'"
  check "030: import comment holds no value" bash -c "! '$SECRET' ls -l | grep -q -e SESSVAL -e PREFVAL"
  s cookie import --as LJ_D --domain other.test < "$FJAR" >/dev/null 2>&1
  check "030: import --domain sets the domain in the comment" bash -c "[[ \$('$SECRET' note LJ_D) == 'cookie jar other.test via safari extension,'* ]]"
  s cookie import --as LJ_S < "$TMP/session.jar" >/dev/null 2>&1
  check "030: all cookies session-only: comment says session, no expiry" bash -c "[ \"\$('$SECRET' note LJ_S)\" = 'cookie jar shop.test via safari extension, 2 cookies, session' ] && ! '$SECRET' ls -l | grep -E '^LJ_S ' | grep -qE '20[0-9]{2}-'"
  check "030: an empty jar stores nothing" bash -c "! '$SECRET' cookie import --as LJ_E < '$TMP/empty.jar' 2>/dev/null && ! '$SECRET' has LJ_E"
  check "030: ASP.NET cookies without ASP.NET_SessionId: hint" bash -c "'$SECRET' cookie import --as LJ_H < '$TMP/aspx.jar' 2>&1 | grep -qF 'session cookie not on disk: capture it with the Safari extension'"
  check "030: import needs --as" bash -c "! '$SECRET' cookie import < '$FJAR' 2>/dev/null"
  check "030: import takes no value in argv (unknown argument)" bash -c "! '$SECRET' cookie import --as LJ_X SESSVAL-AAAA < '$FJAR' 2>/dev/null && ! '$SECRET' has LJ_X"

  # 031: merge
  JA="$TMP/ma.jar"; JB="$TMP/mb.jar"; JA2="$TMP/ma2.jar"; JC="$TMP/mc.jar"
  printf '# Netscape HTTP Cookie File\n#HttpOnly_.a.test\tTRUE\t/\tTRUE\t0\tsidA\tAVAL-1111\n.a.test\tTRUE\t/\tFALSE\t1900000000\tprefA\tAVAL-2222\n' > "$JA"
  printf '# Netscape HTTP Cookie File\n.b.test\tTRUE\t/\tFALSE\t1800000000\tprefB\tBVAL-3333\n' > "$JB"
  printf '# Netscape HTTP Cookie File\n.a.test\tTRUE\t/\tTRUE\t0\tsidA\tAVAL-9999\n' > "$JA2"
  printf '# Netscape HTTP Cookie File\n.c.test\tTRUE\t/\tFALSE\t0\tonlyC\tCVAL-4444\n' > "$JC"
  s cookie import --as MG_J < "$JA" >/dev/null 2>&1
  s cookie import --as MG_J < "$JB" >"$TMP/mg.out" 2>&1
  check "031: merge keeps the cookies of both domains" bash -c "out=\$('$SECRET' cookie ls --jar MG_J); [[ \$out == *sidA* && \$out == *prefA* && \$out == *prefB* ]]"
  check "031: merge keeps one header line" bash -c "[ \$('$SECRET' get MG_J | base64 -D | grep -c '^# Netscape HTTP Cookie File\$') = 1 ]"
  check "031: merge comment and expiry cover the merged set" bash -c "[ \"\$('$SECRET' note MG_J)\" = 'cookie jar b.test via safari extension, 3 cookies, session-only: sidA' ] && '$SECRET' ls -l | grep -E '^MG_J ' | grep -q ' 2027-01-15 '"
  s cookie import --as MG_J < "$JA2" >/dev/null 2>&1
  check "031: same key updated, no duplicate" bash -c "j=\$('$SECRET' get MG_J | base64 -D); [ \$(grep -c 'sidA' <<<\"\$j\") = 1 ] && grep -q AVAL-9999 <<<\"\$j\" && ! grep -q AVAL-1111 <<<\"\$j\" && grep -q prefB <<<\"\$j\""
  check "031: HttpOnly prefix does not split the key" bash -c "j=\$('$SECRET' get MG_J | base64 -D); ! grep -q '#HttpOnly_.a.test.*sidA' <<<\"\$j\" && [ \$(grep -c sidA <<<\"\$j\") = 1 ]"
  s cookie import --as MG_J --replace < "$JC" >/dev/null 2>&1
  check "031: --replace keeps only the last jar" bash -c "j=\$('$SECRET' get MG_J | base64 -D); grep -q onlyC <<<\"\$j\" && ! grep -q -e sidA -e prefB <<<\"\$j\""
  check "031: --replace recomputes the comment and drops the expiry" bash -c "[ \"\$('$SECRET' note MG_J)\" = 'cookie jar c.test via safari extension, 1 cookies, session' ] && ! '$SECRET' ls -l | grep -E '^MG_J ' | grep -qE '20[0-9]{2}-'"
  check "031: import prints no value" bash -c "! grep -q -e AVAL -e BVAL '$TMP/mg.out'"
  check "031: ls --jar after merge prints no values" bash -c "! '$SECRET' cookie ls --jar MG_J 2>&1 | grep -q -e AVAL -e BVAL -e CVAL"
  check "031: a new name is stored without a merge" bash -c "'$SECRET' cookie import --as MG_N < '$JA' >/dev/null 2>&1 && [ \"\$('$SECRET' get MG_N | base64 -D)\" = \"\$(cat '$JA')\" ]"

  # ls --jar
  check "030: ls --jar shows names, domains and flags" bash -c "out=\$('$SECRET' cookie ls --jar LJ_A); [[ \$out == *ASP.NET_SessionId* && \$out == *HttpOnly,Secure,session* && \$out == *2030-01-01* && \$out == *shop.test* ]]"
  check "030: ls --jar prints no values" bash -c "! '$SECRET' cookie ls --jar LJ_A 2>&1 | grep -q -e SESSVAL -e PREFVAL"
  check "030: ls --jar of a missing secret fails" bash -c "! '$SECRET' cookie ls --jar LJ_NOPE 2>/dev/null"

  # run --cookie-jar: a fake command that looks at the jar file
  cat > "$TMP/jarcmd.sh" <<'SH'
#!/bin/bash
printf '%s' "$SECRET_COOKIE_JAR" > "$JAR_PATH_OUT"
stat -f %Lp "$SECRET_COOKIE_JAR" > "$JAR_MODE_OUT"
cat "$SECRET_COOKIE_JAR"
if [ -n "${JAR_APPEND:-}" ]; then printf '.shop.test\tTRUE\t/\tFALSE\t0\tnewc\tNEWVAL-CCCC\n' >> "$SECRET_COOKIE_JAR"; fi
if [ -n "${JAR_REWRITE:-}" ]; then { echo '# rewritten header'; grep -v '^# Netscape' "$SECRET_COOKIE_JAR"; } > "$SECRET_COOKIE_JAR.t"; cat "$SECRET_COOKIE_JAR.t" > "$SECRET_COOKIE_JAR"; rm -f "$SECRET_COOKIE_JAR.t"; fi
exit "${JAR_RC:-0}"
SH
  chmod +x "$TMP/jarcmd.sh"
  export JAR_PATH_OUT="$TMP/jar.path" JAR_MODE_OUT="$TMP/jar.mode"
  out="$(s run --cookie-jar LJ_A -- "$TMP/jarcmd.sh" 2>/dev/null)"
  check "030: run --cookie-jar gives the cmd the jar in a file" bash -c "[[ '$out' == *SESSVAL-AAAA* && '$out' == *PREFVAL-BBBB* ]]"
  check "030: the jar file has mode 600" test "$(cat "$TMP/jar.mode")" = 600
  check "030: the jar file is deleted after cmd" bash -c "p=\$(cat '$TMP/jar.path'); [ -n \"\$p\" ] && [ ! -e \"\$p\" ]"
  s run --cookie-jar LJ_A -- sh -c 'exit 5' >/dev/null 2>&1; rc=$?
  check "030: the exit code of cmd is kept" test "$rc" = 5
  ( s run --cookie-jar LJ_A -- sh -c 'printf %s "$SECRET_COOKIE_JAR" > "$JAR_PATH_OUT"; kill -TERM $PPID; sleep 5' >/dev/null 2>&1 ) 
  check "030: the jar file is deleted on a signal" bash -c "p=\$(cat '$TMP/jar.path'); [ -n \"\$p\" ] && [ ! -e \"\$p\" ]"
  out="$(s run --mask --cookie-jar LJ_A -- "$TMP/jarcmd.sh" 2>&1)"
  check "030: mask covers each cookie value of the jar" bash -c "[[ '$out' != *SESSVAL-AAAA* && '$out' != *PREFVAL-BBBB* && '$out' == *'ASP.NET_SessionId'* ]]"
  s run --mask --cookie-jar LJ_A --update -- "$TMP/jarcmd.sh" >/dev/null 2>&1
  b64_before="$(s get LJ_A)"
  check "030: --update without a change keeps the secret" test "$(s get LJ_A)" = "$b64_before"
  JAR_REWRITE=1 s run --cookie-jar LJ_A --update -- "$TMP/jarcmd.sh" >/dev/null 2>&1
  check "030: --update: only a changed header keeps the secret" test "$(s get LJ_A)" = "$b64_before"
  JAR_APPEND=1 s run --mask --cookie-jar LJ_A --update -- "$TMP/jarcmd.sh" >/dev/null 2>&1
  check "030: --update saves a changed jar back" bash -c "'$SECRET' get LJ_A | base64 -D | grep -q NEWVAL-CCCC"
  check "030: --update: the saved jar is listed" bash -c "'$SECRET' cookie ls --jar LJ_A | grep -q '^newc '"
  check "030: --update keeps the comment" test "$(s note LJ_A)" = "cookie jar shop.test via safari extension, 3 cookies, session-only: ASP.NET_SessionId,isEmp"
  check "030: --update keeps the expiry" bash -c "'$SECRET' ls -l | grep -E '^LJ_A ' | grep -q ' 2030-01-01 '"
  b64_u="$(s get LJ_A)"
  s run --cookie-jar LJ_A -- true >/dev/null 2>&1
  check "030: without --update the secret is not changed" test "$(s get LJ_A)" = "$b64_u"
  check "030: --update needs --cookie-jar" bash -c "! '$SECRET' run --update LJ_A -- true 2>/dev/null"
  check "030: --cookie-jar of a missing secret fails" bash -c "! '$SECRET' run --cookie-jar LJ_NOPE -- true 2>/dev/null"
  check "030: --cookie-jar with a secret: both in one run" test "$(s run --mask --cookie-jar LJ_A T_B -- sh -c 'test -f "$SECRET_COOKIE_JAR" && echo "$T_B"' 2>/dev/null)" = '***'
  check "030: run --cookie-jar is logged with the name" bash -c "tail -1 '$SECRET_LOG' | grep -q \$'\\trun\\t' && tail -1 '$SECRET_LOG' | grep -q LJ_A"
  check "030: log has no cookie value" bash -c "! grep -q -e SESSVAL -e PREFVAL -e NEWVAL '$SECRET_LOG'"

  # short values are not masked (FR-012)
  printf '%s' 0 | s set SH_ZERO 2>/dev/null
  printf '%s' 302 | s set SH_302 2>/dev/null
  printf '%s' abc | s set SH_ABC 2>/dev/null
  err="$TMP/short.err"
  check "030: mask: a value of 1 character is not masked" test "$(s run --mask SH_ZERO -- sh -c 'echo "code 302 ok"' 2>"$err")" = 'code 302 ok'
  check "030: mask: warning names the secret, once" bash -c "[ \"\$(grep -c 'mask skipped for short value SH_ZERO' '$err')\" = 1 ]"
  check "030: mask: an all-digit value of 3 characters is not masked" test "$(s run --mask SH_302 -- sh -c 'echo "got 302"' 2>/dev/null)" = 'got 302'
  check "030: mask: a value of 3 characters is not masked" test "$(s run --mask SH_ABC -- sh -c 'echo "abc"' 2>/dev/null)" = abc
  check "030: mask: a value of 4 characters is masked" bash -c "printf %s abcd | '$SECRET' set SH_ABCD 2>/dev/null; [ \"\$('$SECRET' run --mask SH_ABCD -- sh -c 'echo xabcdx' 2>/dev/null)\" = 'x***x' ]"
  check "030: the short cookie isEmp=0 is not masked, the warning names it" bash -c "out=\$('$SECRET' run --mask --cookie-jar LJ_A -- sh -c 'echo \"302 \$(grep -c isEmp \"\$SECRET_COOKIE_JAR\")\"' 2>'$TMP/iemp.err'); [ \"\$out\" = '302 1' ] && grep -q 'mask skipped for short value isEmp' '$TMP/iemp.err'"
  check "030: without --mask no warning" bash -c "! '$SECRET' run SH_ZERO -- true 2>&1 | grep -q 'mask skipped'"
  rm -f "$TMP/session.jar"

  # hook: nobody reads the jar file
  check "030: hook blocks: cat \$SECRET_COOKIE_JAR" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'cat \"\$SECRET_COOKIE_JAR\"'; [ \$? -eq 2 ]"
  check "030: hook blocks: head \${SECRET_COOKIE_JAR}" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'head -3 \${SECRET_COOKIE_JAR}'; [ \$? -eq 2 ]"
  check "030: hook blocks: cp to another file" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'cp \$SECRET_COOKIE_JAR /tmp/x'; [ \$? -eq 2 ]"
  check "030: hook blocks: tail in secret run" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'secret run --cookie-jar J -- tail \$SECRET_COOKIE_JAR'; [ \$? -eq 2 ]"
  check "030: hook blocks: less in sh -c" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'secret run --cookie-jar J -- sh -c \"less \$SECRET_COOKIE_JAR\"'; [ \$? -eq 2 ]"
  check "030: hook blocks: a jar temp path" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'cat /tmp/secret-jar.AbC123'; [ \$? -eq 2 ]"
  check "030: hook blocks: redirect from the jar" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'while read l; do echo \$l; done < \"\$SECRET_COOKIE_JAR\"'; [ \$? -eq 2 ]"
  check "030: hook passes: curl -b \$SECRET_COOKIE_JAR" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'secret run --mask --cookie-jar J --update -- curl -s -b \"\$SECRET_COOKIE_JAR\" -c \"\$SECRET_COOKIE_JAR\" https://shop.test/'"
  check "030: hook passes: curl with words like cat/cut in the URL" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'secret run --cookie-jar J -- curl -s -b \"\$SECRET_COOKIE_JAR\" https://shop.test/cat/cut | grep ok; echo SECRET_COOKIE_JAR'"
  check "030: hook passes: grep of a file, jar used by curl" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'grep foo notes.txt; curl -b \"\$SECRET_COOKIE_JAR\" https://shop.test/'"
  check "030: hook passes: cookie import and ls --jar" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'secret cookie import --as J < jar.txt && secret cookie ls --jar J'"
  unset JAR_PATH_OUT JAR_MODE_OUT
}

# --- 012: SecretBar. Разбор вывода команд (--selftest); бинарник без entitlements и без вызовов keychain
APP_SUM="$(cat "$ROOT"/app/SecretBar/*.swift "$ROOT/app/SecretBar.xcodeproj/project.pbxproj" "$ROOT"/app/SecretBar/Assets.xcassets/AppIcon.appiconset/Contents.json "$ROOT/app/SecretBar/Localizable.xcstrings" | shasum -a 256 | cut -d' ' -f1)"
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

# --- 023: текст heredoc для cat, tee, git не проверяется; helper хранилища можно осмотреть
hook_blocks() { hook "$1"; [ $? -eq 2 ]; }
for c in $'cat <<EOF | sh\nsecret get X\nEOF' \
         $'bash <<EOF\nsecret get X\nEOF' \
         $'zsh <<\'EOF\'\nFOO=1 secret get X\nEOF' \
         $'cat > f <<EOF\nx\nEOF\nsecret get X' \
         'ls $(build/secret-vault read r X)' \
         'codesign -dv `build/secret-vault read r X`' \
         'codesign -dv build/secret-vault && build/secret-vault read r X'; do
  check "023: hook blocks: ${c//$'\n'/ ⏎ }" hook_blocks "$c"
done
for c in $'cat > spec.md <<\'EOF\'\nrun `secret touchid repair` after an upgrade\nEOF' \
         $'git commit -F - <<EOF\ndocs: secret get is blocked\nEOF' \
         $'tee f >/dev/null <<"EOF"\nSECRET_GH=./fake\nEOF' \
         $'cd x && cat > f <<-EOF\n\tsecret copy X\n\tEOF' \
         'codesign --verify --strict build/secret-vault' \
         'ls -l build/secret-vault && shasum -a 256 build/secret-vault'; do
  check "023: hook passes: ${c//$'\n'/ ⏎ }" hook "$c"
done

# --- 023: хук и правила агента для Claude Code (временные settings.json и CLAUDE.md)
CS="$TMP/claude/settings.json"; CM="$TMP/claude/CLAUDE.md"
mkdir -p "$TMP/claude"
printf '{\n  "model": "x",\n  "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "/old/place/hooks/claude-pretooluse.sh"}, {"type": "command", "command": "/other/hook.sh"}]}]}\n}\n' > "$CS"
printf '# My rules\n\nkeep this\n' > "$CM"
"$ROOT/hooks/install-claude.sh" "$ROOT" "$CS" "$CM" 2>/dev/null
"$ROOT/hooks/install-claude.sh" "$ROOT" "$CS" "$CM" 2>/dev/null
hooks_of() { /usr/bin/python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(" ".join(h["command"] for e in d["hooks"]["PreToolUse"] for h in e["hooks"]))' "$1"; }
check "023: claude: one hook of ours, new path" test "$(hooks_of "$CS")" = "/other/hook.sh $ROOT/hooks/claude-pretooluse.sh"
check "023: claude: other settings kept" grep -q '"model": "x"' "$CS"
check "023: claude: rules imported once" test "$(grep -c "^@$ROOT/docs/claude-md-secrets.md\$" "$CM")" = 1
check "023: claude: own text kept" grep -qx 'keep this' "$CM"
"$ROOT/hooks/install-claude.sh" /opt/elsewhere "$CS" "$CM" 2>/dev/null
check "023: claude: a new root replaces the block" bash -c "[ \$(grep -c '^@' '$CM') = 1 ] && grep -qx '@/opt/elsewhere/docs/claude-md-secrets.md' '$CM' && grep -qx 'keep this' '$CM'"
check "023: claude: a new root replaces the hook" test "$(hooks_of "$CS")" = "/other/hook.sh /opt/elsewhere/hooks/claude-pretooluse.sh"
check "014: copy under Claude Code is refused" bash -c "out=\$(CLAUDECODE=1 '$SECRET' copy T_B 2>&1); [ \$? -ne 0 ] && [[ \$out == *'copy is for the user'* ]]"
check "014: SECRET_VIA names the source in the log" bash -c "SECRET_VIA=shortcuts '$SECRET' get T_B >/dev/null && tail -1 '$SECRET_LOG' | cut -f3 | grep -qx shortcuts"
check "014: SECRET_VIA cannot hide the agent" bash -c "CLAUDECODE=1 SECRET_VIA=secretbar '$SECRET' run T_B -- true && tail -1 '$SECRET_LOG' | cut -f3 | grep -qx agent"
check "hook blocks: secret copy X" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'secret copy X'; [ \$? -eq 2 ]"
check "hook passes: secret migrate --back" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'secret migrate --back'"
check "hook passes: helper/store/build-vault.sh Release build" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'helper/store/build-vault.sh Release build'"
check "hook passes: cat build/secret-vault.src-sha256" bash -c "$(declare -f hook); HOOK='$HOOK'; hook 'cat build/secret-vault.src-sha256'"

check "024: version" bash -c "'$SECRET' version | grep -qxE 'secret [0-9]+\.[0-9]+\.[0-9]+'"
check "024: --version" test "$(s --version)" = "$(s version)"
check "024: version is marked for release-please" grep -qE '^VERSION="[0-9.]+" # x-release-please-version$' "$SECRET"

# --- 030: bridge daemon (loopback), without a browser
BR_DIR="$ROOT/build/test"
BR="$BR_DIR/secret-bridge-test"
if [ ! -x "$BR" ] || [ "$(cat "$BR_DIR/secret-bridge-test.src-sha256" 2>/dev/null)" != "$(shasum -a 256 "$ROOT/helper/bridge/main.swift" | cut -d' ' -f1)" ]; then
  "$ROOT/helper/bridge/build.sh" Test "$BR_DIR" >/dev/null 2>&1 || rm -f "$BR"
fi
if [ ! -x "$BR" ]; then
  echo "skip  030-bridge: no test build of the bridge daemon (swiftc is needed)"
else
  BRS="$TMP/bridge/bridge.json"
  mkdir -p "$TMP/bridge"
  BRP="$(perl -MIO::Socket::INET -e '$s = IO::Socket::INET->new(Listen => 1, LocalAddr => "127.0.0.1", LocalPort => 0) or die; print $s->sockport')"
  export SECRET_BRIDGE_STATE="$BRS" SECRET_BRIDGE_PORT="$BRP" SECRET_BRIDGE_BIN="$BR"
  BRJAR="$TMP/bridge.jar"
  printf '# Netscape HTTP Cookie File\n#HttpOnly_.shop.test\tTRUE\t/\tTRUE\t0\tASP.NET_SessionId\tBRSESS-7777\n.shop.test\tTRUE\t/\tFALSE\t1893456000\tpref\tBRPREF-8888\n' > "$BRJAR"

  check "030-bridge: start without a token fails" bash -c "! '$SECRET' cookie bridge start 2>/dev/null"
  BTOK="$(s cookie bridge token)"
  check "030-bridge: token is 48 hex characters" bash -c "[[ '$BTOK' =~ ^[0-9a-f]{48}\$ ]]"
  check "030-bridge: state file is 0600 with token and port" bash -c "[ \"\$(stat -f %Lp '$BRS')\" = 600 ] && grep -q '\"token\":\"$BTOK\"' '$BRS'"
  check "030-bridge: token is stable on the second call" test "$(s cookie bridge token)" = "$BTOK"
  check "030-bridge: start" bash -c "'$SECRET' cookie bridge start | grep -q 'running on 127.0.0.1:$BRP'"
  check "030-bridge: pid file written" test -s "$TMP/bridge/bridge.pid"
  check "030-bridge: listens on 127.0.0.1 only" bash -c "l=\$(lsof -nP -iTCP:$BRP -sTCP:LISTEN); grep -q '127.0.0.1:$BRP' <<<\"\$l\" && ! grep -qE '(\\*|\\[::\\]):$BRP' <<<\"\$l\""
  post() { curl -s -o /dev/null -w '%{http_code}' --max-time 20 -X POST --data-binary @"$BRJAR" -H 'Content-Type: text/plain' "$@"; }
  U="http://127.0.0.1:$BRP"
  check "030-bridge: good token stores the jar (200)" test "$(post -H "X-Secret-Token: $BTOK" "$U/jar?as=BR_OK")" = 200
  check "030-bridge: the jar arrived (ls --jar)" bash -c "out=\$('$SECRET' cookie ls --jar BR_OK); [[ \$out == *ASP.NET_SessionId* && \$out == *pref* ]]"
  check "030-bridge: the stored jar equals the body" bash -c "[ \"\$('$SECRET' get BR_OK | base64 -D)\" = \"\$(cat '$BRJAR')\" ]"
  check "030-bridge: wrong token is rejected (403) and stores nothing" bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -X POST --data-binary @'$BRJAR' -H 'X-Secret-Token: nope' '$U/jar?as=BR_BAD')\" = 403 ] && ! '$SECRET' has BR_BAD"
  check "030-bridge: missing token is rejected (401) and stores nothing" bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -X POST --data-binary @'$BRJAR' '$U/jar?as=BR_NOTOK')\" = 401 ] && ! '$SECRET' has BR_NOTOK"
  check "030-bridge: a foreign Host header is rejected (403)" bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -X POST --data-binary @'$BRJAR' -H 'Host: evil.test' -H 'X-Secret-Token: $BTOK' '$U/jar?as=BR_HOST')\" = 403 ] && ! '$SECRET' has BR_HOST"
  check "030-bridge: other path gives 404" test "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "X-Secret-Token: $BTOK" "$U/other")" = 404
  check "030-bridge: GET /jar is not allowed (405)" test "$(curl -s -o /dev/null -w '%{http_code}' -H "X-Secret-Token: $BTOK" "$U/jar?as=BR_G")" = 405
  check "030-bridge: bad secret name gives 400" test "$(post -H "X-Secret-Token: $BTOK" "$U/jar?as=bad%20name")" = 400
  check "030-bridge: missing name gives 400" test "$(post -H "X-Secret-Token: $BTOK" "$U/jar")" = 400
  check "030-bridge: a body without cookies is refused and stores nothing" bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -X POST --data-binary 'nothing here' -H 'X-Secret-Token: $BTOK' '$U/jar?as=BR_EMPTY')\" = 422 ] && ! '$SECRET' has BR_EMPTY"
  check "030-bridge: preflight OPTIONS answers 204" test "$(curl -s -o /dev/null -w '%{http_code}' -X OPTIONS "$U/jar")" = 204
  check "030-bridge: the daemon does not print cookie values" bash -c "! grep -q -e BRSESS -e BRPREF '$TMP/bridge/bridge.err'"
  check "030-bridge: stop" bash -c "'$SECRET' cookie bridge stop | grep -q stopped && sleep 0.3 && ! curl -s --max-time 2 '$U/jar' && [ ! -e '$TMP/bridge/bridge.pid' ]"
  check "030-bridge: stop when not running" bash -c "'$SECRET' cookie bridge stop | grep -q 'not running'"
  check "030-bridge: no helper: unavailable" bash -c "out=\$(SECRET_BRIDGE_BIN='$TMP/none' '$SECRET' cookie bridge start 2>&1); [ \$? -ne 0 ] && [[ \$out == *'not available'* ]]"
  "$SECRET" cookie bridge stop >/dev/null 2>&1
  unset SECRET_BRIDGE_STATE SECRET_BRIDGE_PORT SECRET_BRIDGE_BIN
fi

echo
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
