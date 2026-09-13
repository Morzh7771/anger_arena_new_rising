#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Make native (non-Lua) items use Valve's key names only.

An item without a Lua script is driven entirely by the engine, and the engine
only reads the key names the live patch defines. Any other key in its
AbilityValues is inert - it does nothing, however good the number looks.

So for every native item this script:
  * migrates a renamed key's addon value into Valve's key name, preserving the
    addon's scale (RENAMES below - hand-built, never guessed by similarity)
  * deletes the remaining inert keys, printing the value it removed

Deleting an inert key cannot change gameplay: the engine was already ignoring
it. What changes is that the tooltip stops promising an effect that never fired.

Lua-backed items (bloodstone and friends) are never touched.

usage: python fix_items.py [--dry-run]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
ITEMS_DIR = os.path.join(ROOT, 'scripts', 'npc', 'items')
DOTA_ITEMS = os.path.join(ROOT, 'scripts', 'npc', 'dota_items.txt')
PATCH_ITEMS = r"C:\Users\admin\Desktop\dota 2 patch\scripts\npc\items.txt"

# addon key -> Valve key. Only entries where the two mean the same thing.
# Keyed by item family so a name collision across items stays safe.
RENAMES = {
    'item_tpscroll':      {'minimun_distance': 'minimum_distance'},
    'item_spirit_vessel': {'hp_regen_reduction_enemy': 'restoration_reduction_enemy'},
    'item_skadi':         {'heal_reduction': 'restoration_reduction'},
}

# engine-level keys are read from AbilityValues whatever the patch lists there,
# so they are never inert
ENGINE_KEYS = {
    'AbilityCooldown', 'AbilityManaCost', 'AbilityCastRange', 'AbilityCastPoint',
    'AbilityChannelTime', 'AbilityCharges', 'AbilityChargeRestoreTime',
    'AbilityDuration', 'AbilityDamage', 'AbilityChannelledManaCostPerSecond',
}

_p = {'__file__': os.path.join(HERE, 'port.py')}
_src = open(os.path.join(HERE, 'port.py'), encoding='utf-8').read().split('def port_hero(')[0]
_src = _src.replace('main()', '')
exec(compile(_src, 'port_part', 'exec'), _p)
parse = _p['parse']
read = _p['read']
find_blocks = _p['find_blocks']
find_scalar = _p['find_scalar']


def is_custom(body):
    return ('ScriptFile' in body
            or body.get('BaseClass') in ('ability_lua', 'item_lua', 'ability_datadriven'))


def family(name):
    return re.sub(r'_[2-9]$', '', name)


def item_files():
    out = []
    for fn in sorted(os.listdir(ITEMS_DIR)):
        if fn.endswith('.txt'):
            out.append(os.path.join(ITEMS_DIR, fn))
    out.append(DOTA_ITEMS)
    return out


def val_of(v):
    return v.get('value', '') if isinstance(v, dict) else v


def main():
    dry = '--dry-run' in sys.argv
    patch_kv, _ = parse(read(PATCH_ITEMS))
    P = {k: v for k, v in patch_kv.items() if isinstance(v, dict)}

    def patch_of(n):
        return P.get(n) or P.get(family(n))

    tot_ren = tot_del = 0

    for path in item_files():
        kv, _ = parse(read(path))
        raw = read(path)
        crlf = '\r\n' in raw
        text = raw.replace('\r\n', '\n')
        cuts, renames, notes = [], [], []

        def walk(start, end):
            for name, _ks, bo, bc in list(find_blocks(text, start, end)):
                if name in ('DOTAAbilities', 'DOTAItems', 'Version'):
                    walk(bo + 1, bc)
                    continue
                body = kv.get(name)
                if not isinstance(body, dict) or is_custom(body):
                    continue
                if name.startswith('item_recipe_'):
                    continue
                pb = patch_of(name)
                av = body.get('AbilityValues')
                if not isinstance(pb, dict) or not isinstance(av, dict):
                    continue
                pv = pb.get('AbilityValues')
                if not isinstance(pv, dict):
                    continue

                av_open = av_close = None
                for k2, _k, bo2, bc2 in find_blocks(text, bo + 1, bc):
                    if k2 == 'AbilityValues':
                        av_open, av_close = bo2, bc2
                        break
                if av_open is None:
                    continue

                fam_map = RENAMES.get(family(name), {})
                for key in list(av):
                    if key in pv or key in ENGINE_KEYS:
                        continue
                    target = fam_map.get(key)
                    # locate this key's statement inside AbilityValues
                    kb = None
                    for k3, ks3, bo3, bc3 in find_blocks(text, av_open + 1, av_close):
                        if k3 == key:
                            kb = (ks3, bc3)
                            break
                    if kb is not None:
                        stmt_start = text.rfind('\n', 0, kb[0]) + 1
                        stmt_end = text.find('\n', kb[1])
                        stmt_end = len(text) if stmt_end == -1 else stmt_end + 1
                    else:
                        f = find_scalar(text, av_open, av_close, key)
                        if not f:
                            continue
                        stmt_start = text.rfind('\n', 0, f[0]) + 1
                        stmt_end = text.find('\n', f[1])
                        stmt_end = len(text) if stmt_end == -1 else stmt_end + 1

                    if target:
                        # Write the addon's number into Valve's key - but only if
                        # that key is not already carrying a tuned value. Skadi
                        # had a live "restoration_reduction" alongside a dead
                        # "heal_reduction"; overwriting the live one silently
                        # nerfed the item.
                        tf = find_scalar(text, av_open, av_close, target)
                        if tf:
                            current = av.get(target)
                            current = val_of(current) if current is not None else None
                            default = val_of(pv.get(target))
                            if current in (None, '', default):
                                renames.append((name, key, target, val_of(av[key])))
                                cuts.append((tf[0], tf[1], val_of(av[key])))
                                cuts.append((stmt_start, stmt_end, ''))
                                continue
                            notes.append((name, key,
                                          '%s (kept live %s=%r)' % (val_of(av[key]), target, current)))
                            cuts.append((stmt_start, stmt_end, ''))
                            continue
                    notes.append((name, key, val_of(av[key])))
                    cuts.append((stmt_start, stmt_end, ''))

        walk(0, len(text))

        if not cuts:
            continue
        cuts.sort(key=lambda c: c[0], reverse=True)
        for a, b, repl in cuts:
            text = text[:a] + repl + text[b:]
        if not dry:
            if crlf:
                text = text.replace('\n', '\r\n')
            with open(path, 'w', encoding='utf-8', newline='') as f:
                f.write(text)

        print(os.path.relpath(path, ROOT))
        for n, k, t, v in renames:
            print('   -> %-24s %-28s -> %-28s value kept %r' % (n, k, t, v))
        for n, k, v in notes:
            print('   xx %-24s %-28s inert, removed (was %r)' % (n, k, v))
        tot_ren += len(renames)
        tot_del += len(notes)

    print()
    print('TOTAL: %d migrated, %d inert keys removed%s'
          % (tot_ren, tot_del, '  (dry run)' if dry else ''))


main()
