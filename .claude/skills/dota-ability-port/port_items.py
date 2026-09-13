#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Import current-patch item data into the addon, additively.

Item tiers here are separate entries - item_x, item_x_2, item_x_3 - sharing one
BaseClass, with ItemBaseLevel picking which index of the value array applies.
Families differ: some have three tiers, some two, most just one, so each item is
fitted to its OWN tier count rather than to a fixed number.

For every addon item WITHOUT a Lua script that matches a live-patch item:
  * adds AbilityValues keys the patch has and the addon lacks
  * extends numeric arrays that are shorter than the family's tier count

Arrays are only ever extended. One longer than the tier count is left alone -
the surplus values are never read, whereas truncating would restate a lower
tier's number and quietly change the balance.

Never deletes a key, never changes an existing number's base value, never
touches an item that has ScriptFile / ability_lua / item_lua - those are custom
(bloodstone and friends).

usage: python port_items.py [--dry-run] [--report]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
ITEMS_DIR = os.path.join(ROOT, 'scripts', 'npc', 'items')
DOTA_ITEMS = os.path.join(ROOT, 'scripts', 'npc', 'dota_items.txt')
PATCH_ITEMS = r"C:\Users\admin\Desktop\dota 2 patch\scripts\npc\items.txt"

TIERS = 3

_p = {'__file__': os.path.join(HERE, 'port.py')}
_src = open(os.path.join(HERE, 'port.py'), encoding='utf-8').read().split('def port_hero(')[0]
_src = _src.replace('main()', '')
exec(compile(_src, 'port_part', 'exec'), _p)
parse = _p['parse']
read = _p['read']
find_blocks = _p['find_blocks']
find_scalar = _p['find_scalar']
render_entry = _p['render_entry']
rescale = _p['rescale']
NUMS = _p['NUMS']


def is_custom(body):
    return ('ScriptFile' in body
            or body.get('BaseClass') in ('ability_lua', 'item_lua', 'ability_datadriven'))


def patch_lookup(name, patch_items):
    if name in patch_items:
        return patch_items[name]
    stripped = re.sub(r'_[2-9]$', '', name)
    return patch_items.get(stripped)


def family(name):
    return re.sub(r'_[2-9]$', '', name)


def tier_counts(files):
    """How many tier entries each item family actually has."""
    seen = {}
    for path in files:
        kv, _ = parse(read(path))
        for k, v in kv.items():
            if not isinstance(v, dict) or k.startswith('item_recipe_'):
                continue
            seen.setdefault(family(k), set()).add(k)
    return {f: len(s) for f, s in seen.items()}


def item_files():
    out = []
    if os.path.isdir(ITEMS_DIR):
        for fn in sorted(os.listdir(ITEMS_DIR)):
            if fn.endswith('.txt'):
                out.append(os.path.join(ITEMS_DIR, fn))
    if os.path.isfile(DOTA_ITEMS):
        out.append(DOTA_ITEMS)
    return out


def main():
    dry = '--dry-run' in sys.argv
    report_only = '--report' in sys.argv

    patch_kv, _ = parse(read(PATCH_ITEMS))
    patch_items = {k: v for k, v in patch_kv.items() if isinstance(v, dict)}
    tiers = tier_counts(item_files())

    tot_add = tot_fix = 0
    skipped_custom = 0
    unmatched = []

    for path in item_files():
        kv, _ = parse(read(path))
        raw = read(path)
        crlf = '\r\n' in raw
        text = raw.replace('\r\n', '\n')
        edits = []
        added, fixed = [], []

        def walk(start, end):
            for name, kstart, bo, bc in list(find_blocks(text, start, end)):
                if name in ('DOTAAbilities', 'DOTAItems', 'Version'):
                    walk(bo + 1, bc)
                    continue
                body = kv.get(name)
                if not isinstance(body, dict):
                    continue
                nonlocal skipped_custom
                if is_custom(body):
                    skipped_custom += 1
                    continue
                pb = patch_lookup(name, patch_items)

                av_open = av_close = None
                for k2, _ks2, bo2, bc2 in find_blocks(text, bo + 1, bc):
                    if k2 == 'AbilityValues':
                        av_open, av_close = bo2, bc2
                        break

                av = body.get('AbilityValues')
                av = av if isinstance(av, dict) else {}

                # fit existing arrays to however many tiers this family has
                nt = tiers.get(family(name), 1)
                if av_open is not None and nt > 1:
                    for k, v in av.items():
                        cur = v.get('value') if isinstance(v, dict) else v
                        if not isinstance(cur, str):
                            continue
                        parts = cur.split()
                        if len(parts) < 2 or not all(NUMS.match(x) for x in parts):
                            continue
                        # only ever extend. An array longer than the tier count
                        # is harmless - the extra values are never read - but
                        # truncating it would silently restate lower tiers.
                        if len(parts) >= nt:
                            continue
                        new = rescale(cur, nt)
                        if not new or new == cur:
                            continue
                        if isinstance(v, dict):
                            sub = None
                            for k3, _k, bo3, bc3 in find_blocks(text, av_open + 1, av_close):
                                if k3 == k:
                                    sub = find_scalar(text, bo3, bc3, 'value')
                                    break
                            if sub:
                                edits.append((sub[0], sub[1], new))
                                fixed.append('%s / %s: "%s" -> "%s"' % (name, k, cur, new))
                        else:
                            f = find_scalar(text, av_open, av_close, k)
                            if f and f[2] == cur:
                                edits.append((f[0], f[1], new))
                                fixed.append('%s / %s: "%s" -> "%s"' % (name, k, cur, new))

                if not isinstance(pb, dict):
                    if not name.startswith('item_recipe_'):
                        unmatched.append(name)
                    continue

                pav = pb.get('AbilityValues')
                if not isinstance(pav, dict) or av_open is None:
                    continue
                missing = [k for k in pav if k not in av]
                if not missing:
                    continue
                line_start = text.rfind('\n', 0, av_close) + 1
                indent = re.match(r'[ \t]*', text[line_start:av_close]).group(0) + '\t'
                chunk = ''
                for k in missing:
                    piece = render_entry(k, pav[k], indent, 1, set())
                    if piece:
                        chunk += piece
                        added.append('%s / %s' % (name, k))
                if chunk:
                    edits.append((line_start, line_start, chunk))

        walk(0, len(text))

        if edits and not (dry or report_only):
            edits.sort(key=lambda e: e[0], reverse=True)
            for a, b, repl in edits:
                text = text[:a] + repl + text[b:]
            if crlf:
                text = text.replace('\n', '\r\n')
            with open(path, 'w', encoding='utf-8', newline='') as f:
                f.write(text)

        if added or fixed:
            tot_add += len(added)
            tot_fix += len(fixed)
            print('%s' % os.path.relpath(path, ROOT))
            for a in added:
                print('   + %s' % a)
            for f in fixed:
                print('   ~ %s' % f)

    print()
    print('custom (Lua) items skipped: %d' % skipped_custom)
    if unmatched:
        print('no patch counterpart (left alone): %d' % len(unmatched))
    print('TOTAL: %d keys added, %d arrays fitted to their tier count (%d max)%s'
          % (tot_add, tot_fix, TIERS, '  (dry run)' if dry or report_only else ''))


main()
