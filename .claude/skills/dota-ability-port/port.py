#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Import current-patch ability data into the addon, additively.

What it does, per hero, for every NATIVE ability present in both files:
  * adds AbilityValues keys the live patch has and the addon lacks,
    with the patch's numbers rescaled to the addon's MaxLevel
  * fixes level arrays whose length does not match MaxLevel

What it deliberately never does:
  * delete any key
  * change any existing number's base value
  * touch a Lua ability's structure (ScriptFile / ability_lua / ability_datadriven)

Edits are made on raw text so indentation and comments survive.

usage: python port.py <hero> [<hero> ...]
       python port.py --all
       python port.py --all --dry-run
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
ADDON = os.path.join(ROOT, 'scripts', 'npc', 'heroes')
PATCH = r"C:\Users\admin\Desktop\Dota 2 7.42\scripts\npc\heroes"

_v = {'__file__': os.path.join(HERE, 'validate.py')}
_src = open(os.path.join(HERE, 'validate.py'), encoding='utf-8').read().split('def check_hero(')[0]
exec(compile(_src, 'validate_part', 'exec'), _v)
parse = _v['parse']
read = _v['read']
is_lua = _v['is_lua']
strip_comments = _v['strip_comments']
NUMS = _v['NUMS']
LEVEL_KEYS = _v['LEVEL_KEYS']

# keys the addon's own Lua reads - never rescale these away, never reorder
LUA_KEYS = set()
_luare = re.compile(r'GetSpecialValueFor[A-Za-z]*\(\s*"([A-Za-z0-9_]+)"')
for dirpath, _dirs, files in os.walk(os.path.join(ROOT, 'scripts', 'vscripts')):
    for fn in files:
        if fn.endswith('.lua'):
            try:
                with open(os.path.join(dirpath, fn), 'r', encoding='utf-8', errors='ignore') as f:
                    LUA_KEYS.update(_luare.findall(f.read()))
            except OSError:
                pass


# ------------------------------------------------------------------ rescale
def fmt(x, as_int):
    if as_int:
        return str(int(round(x)))
    s = ('%.2f' % x).rstrip('0').rstrip('.')
    return s if s not in ('', '-0') else '0'


def rescale(value, ml):
    """Return value stretched to ml levels, or None if nothing to do."""
    if not isinstance(value, str):
        return None
    parts = value.split()
    if not parts or not all(NUMS.match(p) for p in parts):
        return None
    nums = [float(p) for p in parts]
    if len(set(nums)) == 1:
        return parts[0] if len(parts) != 1 else None
    if len(nums) == ml:
        return None
    if ml <= 1:
        return None
    as_int = all('.' not in p for p in parts)
    n = len(nums)
    increasing = nums[-1] > nums[0]
    if increasing:
        step = (nums[-1] - nums[0]) / (n - 1)          # preserve step
    else:
        step = (nums[-1] - nums[0]) / (ml - 1)         # preserve range
    out = [nums[0] + i * step for i in range(ml)]
    return ' '.join(fmt(x, as_int) for x in out)


# -------------------------------------------------------- raw text scanning
def find_blocks(text, start, end):
    """Yield (key, key_start, brace_open, brace_close) for entries in [start,end)."""
    i = start
    n = end
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == '\\' else 1
            key = text[i + 1:j]
            k = j + 1
            # skip whitespace and comments
            while k < n:
                if text[k] in ' \t\r\n':
                    k += 1
                elif text[k] == '/' and k + 1 < n and text[k + 1] == '/':
                    while k < n and text[k] != '\n':
                        k += 1
                else:
                    break
            if k < n and text[k] == '{':
                close = match_brace(text, k, n)
                yield key, i, k, close
                i = close + 1
                continue
            i = j + 1
            continue
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                i += 1
            continue
        i += 1


def match_brace(text, open_idx, end):
    depth = 0
    i = open_idx
    while i < end:
        c = text[i]
        if c == '"':
            i += 1
            while i < end and text[i] != '"':
                i += 2 if text[i] == '\\' else 1
        elif c == '/' and i + 1 < end and text[i + 1] == '/':
            while i < end and text[i] != '\n':
                i += 1
            continue
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return end - 1


def find_scalar(text, start, end, key):
    """Find `"key"  "value"` in [start,end); return (val_start, val_end, value)."""
    pat = re.compile(r'"%s"[ \t]*"([^"]*)"' % re.escape(key))
    depth_safe = text[start:end]
    for m in pat.finditer(depth_safe):
        return start + m.start(1), start + m.end(1), m.group(1)
    return None


# ------------------------------------------------------------------ render
def render_entry(key, pval, indent, ml, allowed_bonus):
    """Render one AbilityValues entry in addon style."""
    if not isinstance(pval, dict):
        v = rescale(pval, ml) or pval
        return '%s"%s"\t\t\t\t"%s"\n' % (indent, key, v)

    subs = []
    for sk, sv in pval.items():
        if sk.startswith('special_bonus_') and sk not in allowed_bonus:
            continue
        if not isinstance(sv, str):
            continue
        if sk == 'value':
            sv = rescale(sv, ml) or sv
        subs.append((sk, sv))
    if not subs:
        return ''
    if len(subs) == 1 and subs[0][0] == 'value':
        return '%s"%s"\t\t\t\t"%s"\n' % (indent, key, subs[0][1])
    inner = indent + '\t'
    body = ''.join('%s"%s"\t\t\t\t"%s"\n' % (inner, k, v) for k, v in subs)
    return '%s"%s"\n%s{\n%s%s}\n' % (indent, key, indent, body, indent)


# ------------------------------------------------------------------- porting
def port_hero(hero, dry=False):
    hdir = os.path.join(ADDON, hero)
    apath = os.path.join(hdir, 'ability_data.txt')
    hpath = os.path.join(hdir, 'hero_data.txt')
    if not os.path.isfile(apath):
        return None

    addon_kv, _ = parse(read(apath))
    ppath = os.path.join(PATCH, 'npc_dota_hero_%s.txt' % hero)
    if not os.path.isfile(ppath) and os.path.isfile(hpath):
        hkv, _ = parse(read(hpath))
        for k in hkv:
            cand = os.path.join(PATCH, '%s.txt' % k)
            if os.path.isfile(cand):
                ppath = cand
                break
    if not os.path.isfile(ppath):
        return {'hero': hero, 'skipped': 'no reference file'}
    patch_kv, _ = parse(read(ppath))

    # which talents / facets this hero actually has
    allowed_bonus = {'special_bonus_scepter', 'special_bonus_shard'}
    if os.path.isfile(hpath):
        hkv, _ = parse(read(hpath))
        for hb in hkv.values():
            if not isinstance(hb, dict):
                continue
            for k, v in hb.items():
                if re.fullmatch(r'Ability\d+', k) and isinstance(v, str) \
                        and v.startswith('special_bonus_'):
                    allowed_bonus.add(v)
            f = hb.get('Facets')
            if isinstance(f, dict):
                for fname in f:
                    allowed_bonus.add('special_bonus_facet_' + fname)

    text = read(apath)
    crlf = '\r\n' in text
    text = text.replace('\r\n', '\n')

    added, fixed = [], []
    # collect edits as (pos, pos_end, replacement); apply back-to-front
    edits = []

    for name, kstart, bopen, bclose in list(find_blocks(text, 0, len(text))):
        if name in ('DOTAAbilities', 'Version'):
            # descend into the wrapper
            for n2, ks2, bo2, bc2 in list(find_blocks(text, bopen + 1, bclose)):
                edits += plan_ability(text, n2, bo2, bc2, addon_kv, patch_kv,
                                      allowed_bonus, added, fixed)
            continue
        edits += plan_ability(text, name, bopen, bclose, addon_kv, patch_kv,
                              allowed_bonus, added, fixed)

    if not edits:
        return {'hero': hero, 'added': [], 'fixed': []}

    edits.sort(key=lambda e: e[0], reverse=True)
    for pos, pos_end, repl in edits:
        text = text[:pos] + repl + text[pos_end:]

    if not dry:
        if crlf:
            text = text.replace('\n', '\r\n')
        with open(apath, 'w', encoding='utf-8', newline='') as f:
            f.write(text)
    return {'hero': hero, 'added': added, 'fixed': fixed}


def plan_ability(text, name, bopen, bclose, addon_kv, patch_kv,
                 allowed_bonus, added, fixed):
    edits = []
    ab = addon_kv.get(name)
    pb = patch_kv.get(name)
    if not isinstance(ab, dict):
        return edits
    if is_lua(ab):
        pb = None                      # lua: length fixes only, no imports
    try:
        ml = int(ab.get('MaxLevel', '0'))
    except ValueError:
        ml = 0

    # --- fix root-level level arrays
    if ml > 1:
        for k in LEVEL_KEYS:
            if k not in ab:
                continue
            found = find_scalar(text, bopen, bclose, k)
            if not found:
                continue
            vs, ve, cur = found
            new = rescale(cur, ml)
            if new and new != cur:
                edits.append((vs, ve, new))
                fixed.append('%s / %s: "%s" -> "%s"' % (name, k, cur, new))

    # --- locate AbilityValues block
    av_open = av_close = None
    for k2, _ks2, bo2, bc2 in find_blocks(text, bopen + 1, bclose):
        if k2 == 'AbilityValues':
            av_open, av_close = bo2, bc2
            break
    if av_open is None:
        return edits

    av = ab.get('AbilityValues') if isinstance(ab.get('AbilityValues'), dict) else {}

    # --- fix existing array lengths inside AbilityValues
    if ml > 1:
        for k, v in av.items():
            cur = v.get('value') if isinstance(v, dict) else v
            if not isinstance(cur, str):
                continue
            new = rescale(cur, ml)
            if not new or new == cur:
                continue
            if isinstance(v, dict):
                sub = None
                for k3, _ks3, bo3, bc3 in find_blocks(text, av_open + 1, av_close):
                    if k3 == k:
                        sub = find_scalar(text, bo3, bc3, 'value')
                        break
                if sub:
                    edits.append((sub[0], sub[1], new))
                    fixed.append('%s / %s: "%s" -> "%s"' % (name, k, cur, new))
            else:
                found = find_scalar(text, av_open, av_close, k)
                if found and found[2] == cur:
                    edits.append((found[0], found[1], new))
                    fixed.append('%s / %s: "%s" -> "%s"' % (name, k, cur, new))

    # --- import missing patch keys
    if isinstance(pb, dict):
        pav = pb.get('AbilityValues')
        if isinstance(pav, dict):
            missing = [k for k in pav if k not in av]
            if missing:
                line_start = text.rfind('\n', 0, av_close) + 1
                indent = re.match(r'[ \t]*', text[line_start:av_close]).group(0) + '\t'
                chunk = ''
                for k in missing:
                    piece = render_entry(k, pav[k], indent, ml, allowed_bonus)
                    if piece:
                        chunk += piece
                        added.append('%s / %s' % (name, k))
                if chunk:
                    ins = line_start
                    edits.append((ins, ins, chunk))
    return edits


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry = '--dry-run' in sys.argv
    if '--all' in sys.argv:
        heroes = sorted(d for d in os.listdir(ADDON)
                        if os.path.isdir(os.path.join(ADDON, d)))
    elif args:
        heroes = args
    else:
        print(__doc__); sys.exit(2)

    tot_a = tot_f = 0
    for h in heroes:
        r = port_hero(h, dry)
        if not r:
            continue
        if r.get('skipped'):
            print('%-26s skipped (%s)' % (h, r['skipped']))
            continue
        a, f = len(r['added']), len(r['fixed'])
        tot_a += a; tot_f += f
        if a or f:
            print('%-26s +%d keys, %d arrays rescaled' % (h, a, f))
    print()
    print('TOTAL: %d keys added, %d arrays rescaled%s'
          % (tot_a, tot_f, '  (dry run)' if dry else ''))


main()
