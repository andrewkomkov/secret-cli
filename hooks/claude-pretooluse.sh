#!/usr/bin/perl
# Claude Code PreToolUse hook for Bash: exit 2 stops a command that would print the value of a secret.
use strict;
use warnings;
use JSON::PP;

my $in = do { local $/; <STDIN> };
my $cmd = eval { decode_json($in)->{tool_input}{command} };
exit 0 unless defined $cmd && length $cmd;

# 023: a heredoc body that cat, tee or git get as text (a file, a commit message) is not commands.
# If the output goes on through a pipe, the body stays and is checked.
sub strip_text_heredocs {
  my @lines = split /\n/, shift, -1;
  my @out;
  while (@lines) {
    my $l = shift @lines;
    push @out, $l;
    next unless $l =~ /(?:^|[;&({])\s*(?:cat|tee|git)\b[^;&|]*<<-?\s*(['"]?)(\w+)\1[^|]*$/;
    my $word = $2;
    while (@lines) {
      my $b = shift @lines;
      if ($b =~ /^\t*\Q$word\E\s*$/) { push @out, $b; last }
    }
  }
  return join "\n", @out;
}
$cmd = strip_text_heredocs($cmd);

sub block {
  print STDERR "Blocked by secret-cli: $_[0]. Use secret run --mask with the name of the secret. "
    . "If the user wants to see the value, the user runs the command with ! in the prompt.\n";
  exit 2;
}

my $seg = qr/[^;&|\n]*/;
# start of a command: start of a line or after ; & | ( { $( `, with prefixes such as VAR=1 and sudo
my $at = qr/(?:^|[;&|({\n`]|\$\()\s*(?:(?:sudo|command|exec|nohup|time|xargs)\s+)*(?:\w+=\S*\s+)*/m;
my @rules = (
  [ qr/$at\bsecret\s+get\b/, 'secret get prints the value' ],
  [ qr/$at\bsecret\s+copy\b/, 'secret copy puts the value on the clipboard, which the agent can read' ],
  [ qr/$at\bsecurity\s+find-(?:generic|internet)-password\b$seg\s-[A-Za-z]*w\b/, 'security find-*-password -w prints the value' ],
  [ qr/$at\bsecurity\s+find-(?:generic|internet)-password\b$seg\s-[A-Za-z]*g\b/, 'security find-*-password -g prints the value' ],
  [ qr/$at\bsecurity\s+dump-keychain\b$seg\s-[A-Za-z]*d/, 'security dump-keychain -d prints the values' ],
  [ qr/$at\b(?:cat|less|more|head|tail|bat|nl|strings)\b$seg(?:^|[\s\/'"])\.env(?!\.(?:example|sample|template))(?![\w.-])/, 'printing .env shows its values' ],
  [ qr/$at\bsecret\s+run\b$seg\s--\s+(?:env|printenv)\s*(?:$|[;&|>])/, 'env inside secret run prints the values' ],
  [ qr/$at\bsecret\s+run\b$seg\s--\s+printenv\b/, 'printenv inside secret run prints the values' ],
  [ qr/$at\bsecret\s+run\b$seg\s--\s+(?:set|declare\s+-p|export\s+-p)\s*(?:$|[;&|>])/, 'set inside secret run prints the values' ],
  [ qr/$at\bsecret\s+touchid\s+(?:off|grace|repair)\b/, 'only the user changes the Touch ID settings' ],
  [ qr/touchid-ok\b/, 'only the user changes the Touch ID settings' ],
  [ qr/\bSECRET_(?:AUTH_HELPER|CONFIG|AUTH_STAMP|VAULT_HELPER|STORE_MODE|GH|CONFIRM|TEST_[A-Z_]+)=/, 'these variables are for tests only' ],
);
for my $r (@rules) { block($r->[1]) if $cmd =~ $r->[0]; }

# Only secret calls the store helper. A part of a command that only looks at the file
# (signature, size, hash) passes if it has no $( and no backquote (023).
my $vault = qr/(?<![\w.-])secret-vault(?:-test)?(?![\w-])(?!\.src-sha256\b)/;
my $look = qr/^\s*(?:\w+=\S*\s+)*(?:codesign|ls|stat|file|shasum|xattr|spctl)\b/;
for my $part (split /[;&|\n]/, $cmd) {
  next unless $part =~ $vault;
  next if $part =~ $look && $part !~ /\$\(|`/;
  block('the store helper is called by secret only');
}
exit 0;
