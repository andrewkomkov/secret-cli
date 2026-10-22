#!/bin/bash
# Claude Code integration (023): the PreToolUse hook in settings.json and the agent rules in
# CLAUDE.md. The rules are an import line, so Claude Code reads docs/claude-md-secrets.md of this
# install at start and they follow each update. A second run replaces the old entries.
#   hooks/install-claude.sh ROOT [SETTINGS] [CLAUDE_MD]
set -euo pipefail
root="${1:?ROOT}"
settings="${2:-$HOME/.claude/settings.json}"
claude_md="${3:-$HOME/.claude/CLAUDE.md}"
mkdir -p "$(dirname "$settings")" "$(dirname "$claude_md")"

[ -f "$settings" ] || echo '{}' > "$settings"
cp -p "$settings" "$settings.bak"
# python3 вместо perl: json в python сохраняет порядок ключей файла
/usr/bin/python3 - "$settings" "$root/hooks/claude-pretooluse.sh" <<'PY'
import json, sys
path, hook = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
pre = data.setdefault('hooks', {}).setdefault('PreToolUse', [])
ours = lambda h: h.get('command', '').endswith('/hooks/claude-pretooluse.sh')
if any(h.get('command') == hook for e in pre for h in e.get('hooks', [])) \
        and sum(ours(h) for e in pre for h in e.get('hooks', [])) == 1:
    print('claude hook: already in ' + path, file=sys.stderr)
    sys.exit(0)
for e in pre:
    e['hooks'] = [h for h in e.get('hooks', []) if not ours(h)]
pre[:] = [e for e in pre if e.get('hooks')]
pre.append({'matcher': 'Bash', 'hooks': [{'type': 'command', 'command': hook}]})
with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
print('claude hook: ' + hook + ' in ' + path, file=sys.stderr)
PY

[ -f "$claude_md" ] || : > "$claude_md"
block="<!-- secret-cli: agent rules, updated by install.sh -->
@$root/docs/claude-md-secrets.md
<!-- /secret-cli -->"
if grep -qxF "@$root/docs/claude-md-secrets.md" "$claude_md"; then
  echo "claude rules: already in $claude_md" >&2
  exit 0
fi
cp -p "$claude_md" "$claude_md.bak"
# the old block goes, the new one comes at the end
/usr/bin/perl -0pi -e 's/\n*<!-- secret-cli:[^\n]*-->\n.*?<!-- \/secret-cli -->\n?//s' "$claude_md"
[ ! -s "$claude_md" ] || printf '\n' >> "$claude_md"
printf '%s\n' "$block" >> "$claude_md"
echo "claude rules: $root/docs/claude-md-secrets.md imported in $claude_md" >&2
