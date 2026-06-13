#!/bin/sh
set -e

if [ -n "$CLAUDE_MODEL" ]; then
    SETTINGS=/root/.claude/settings.json
    mkdir -p /root/.claude
    node -e "
const fs = require('fs');
const p = process.env.HOME + '/.claude/settings.json';
const s = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf8')) : {};
s.model = process.env.CLAUDE_MODEL;
fs.writeFileSync(p, JSON.stringify(s, null, 2) + '\n');
console.log('Claude model set to:', process.env.CLAUDE_MODEL);
"
fi

exec tail -f /dev/null
