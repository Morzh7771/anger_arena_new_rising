#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Sync BASE item recipes to the live patch.

Only `item_recipe_<name>` entries are touched. The addon's own tier upgrades -
`item_recipe_<name>_2`, `_3`, built from two copies of the previous tier - are
left exactly as they are; Dota has no equivalent to compare them against.

For each base recipe present in both files, ItemRequirements and ItemCost are
replaced with the patch's. Components are checked first: a recipe is skipped if
it needs an item that exists in neither the addon nor base Dota.

usage: python sync_recipes.py [--dry-run]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
ITEMS_DIR = os.path.join(ROOT, 'scripts', 'npc', 'items')
DOTA_ITEMS = os.path.join(ROOT, 'scripts', 'npc', 'dota_items.txt')
PATCH_ITEMS = r"C:\Users\admin\Desktop\Dota 2 7.42\scripts\npc\items.txt"

_p = {'__file__': os.path.join(HERE, 'port.py')}
_src = open(os.path.join(HERE, 'port.py'), encoding='utf-8').read().split('def port_hero(')[0]
_src = _src.replace('main()', '')
exec(compile(_src, 'port_part', 'exec'), _p)
parse = _p['parse']
read = _p['read']
find_blocks = _p['find_blocks']
find_scalar = _p['find_scalar']

TIER = re.compile(r'_[2-9]$')


def files():
    out = [os.path.join(ITEMS_DIR, f) for f in sorted(os.listdir(ITEMS_DIR))
           if f.endswith('.txt')]
    out.append(DOTA_ITEMS)
    return out


def components(body):
    r = body.get('ItemRequirements')
    if not isinstance(r, dict):
        return None
    out = set()
    for v in r.values():
        for c in str(v).split(';'):
            c = c.strip().rstrip('*')
            if c:
                out.add(c)
    return out


def main():
    dry = '--dry-run' in sys.argv
    pkv, _ = parse(read(PATCH_ITEMS))
    P = {k: v for k, v in pkv.items() if isinstance(v, dict)}

    addon = {}
    for p in files():
        kv, _ = parse(read(p))
        for k, v in kv.items():
            if isinstance(v, dict):
                addon.setdefault(k, v)
    available = set(addon) | set(P)

    total = 0
    for path in files():
        kv, _ = parse(read(path))
        raw = read(path)
        crlf = '\r\n' in raw
        text = raw.replace('\r\n', '\n')
        edits, log = [], []

        def walk(start, end):
            for name, _ks, bo, bc in list(find_blocks(text, start, end)):
                if name in ('DOTAAbilities', 'DOTAItems', 'Version'):
                    walk(bo + 1, bc)
                    continue
                if not name.startswith('item_recipe_') or TIER.search(name):
                    continue
                ad = kv.get(name)
                pb = P.get(name)
                if not isinstance(ad, dict) or not isinstance(pb, dict):
                    continue
                pc = components(pb)
                if pc is None:
                    continue
                absent = sorted(c for c in pc if c not in available)
                if absent:
                    log.append('%-34s SKIPPED, addon has no %s' % (name, ', '.join(absent)))
                    continue

                # A recipe that currently needs an addon-only component is a
                # deliberate gate, not patch drift - Divine Rapier costing 6275
                # behind item_boss_soul is a design choice. Adopting Valve's
                # recipe would delete the gate and the price with it.
                ac = components(ad) or set()
                custom = sorted(c for c in ac if c not in P)
                if custom:
                    log.append('%-34s SKIPPED, gated behind custom %s'
                               % (name, ', '.join(custom)))
                    continue

                changed = []
                # ItemCost is deliberately NOT synced - recipe prices are the
                # addon's own economy, tuned by hand, and Valve's numbers would
                # overwrite them wholesale. Only the component list follows the
                # patch, so an item that Valve rebuilt (Shiva off Veil) rebuilds
                # here too, at the addon's price.

                # ItemRequirements block body
                if components(ad) != pc:
                    req_open = req_close = None
                    for k2, _k, bo2, bc2 in find_blocks(text, bo + 1, bc):
                        if k2 == 'ItemRequirements':
                            req_open, req_close = bo2, bc2
                            break
                    preq = pb.get('ItemRequirements')
                    if req_open is not None and isinstance(preq, dict):
                        line_start = text.rfind('\n', 0, req_close) + 1
                        indent = re.match(r'[ \t]*', text[line_start:req_close]).group(0)
                        body = ''.join('%s\t"%s"\t\t\t\t\t"%s"\n' % (indent, k3, v3)
                                       for k3, v3 in sorted(preq.items()))
                        edits.append((req_open + 1, req_close, '\n' + body + indent))
                        changed.append('%s -> %s'
                                       % (sorted(components(ad) or []), sorted(pc)))
                if changed:
                    log.append('%-34s %s' % (name, '; '.join(changed)))

        walk(0, len(text))
        if not edits:
            for l in log:
                print('   ', l)
            continue
        edits.sort(key=lambda e: e[0], reverse=True)
        for a, b, repl in edits:
            text = text[:a] + repl + text[b:]
        if not dry:
            if crlf:
                text = text.replace('\n', '\r\n')
            with open(path, 'w', encoding='utf-8', newline='') as f:
                f.write(text)
        print(os.path.relpath(path, ROOT))
        for l in log:
            print('   ', l)
            total += 1

    print()
    print('TOTAL: %d base recipe(s) synced%s' % (total, '  (dry run)' if dry else ''))


main()
