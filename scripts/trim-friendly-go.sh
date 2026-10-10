#!/bin/bash
# 删除 friendly-snippets go.json 中与自定义 snippets/go.json 前缀重复的项，
# 让自定义的中文 snippet 成为唯一来源（避免补全菜单出现同名双条目）。
# 用法: Lazy update 还原后跑一次: bash ~/.config/nvim/scripts/trim-friendly-go.sh
set -euo pipefail
MINE="$HOME/.config/nvim/snippets/go.json"
FILE="$HOME/.local/share/nvim/lazy/friendly-snippets/snippets/go.json"
if [ ! -f "$FILE" ]; then
  echo "找不到 friendly-snippets go.json: $FILE"
  exit 1
fi
python3 - "$MINE" "$FILE" <<'PY'
import json, sys
mine = json.load(open(sys.argv[1]))
foreign = sys.argv[2]
d = json.load(open(foreign))

def prefixes(v):
    p = v.get('prefix')
    if p is None:
        return []
    return [p] if isinstance(p, str) else list(p)

mine_pref = set()
for v in mine.values():
    mine_pref.update(prefixes(v))

removed = []
for k in list(d.keys()):
    if any(p in mine_pref for p in prefixes(d[k])):
        del d[k]
        removed.append(k)

json.dump(d, open(foreign, 'w'), indent=2, ensure_ascii=False)
print('removed:', len(removed))
print('remaining keys:', len(d))
PY
