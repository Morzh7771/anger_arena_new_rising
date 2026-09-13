#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Catch balance drift: numbers that were CHANGED rather than rescaled.

Compares the working tree against git HEAD. Both rescale branches in the spec
preserve the first element of an array, so a changed first element always means
the addon's tuned number was overwritten - which the spec forbids.

usage: python check_drift.py <hero> [<hero> ...]
       python check_drift.py --all
exit 0 = no drift, 1 = drift found.
"""
import os, re, sys, subprocess

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, HERE)

_v = {'__file__': os.path.join(HERE, 'validate.py')}
_src = open(os.path.join(HERE, 'validate.py'), encoding='utf-8').read()
_src = _src.split('def check_hero(')[0]
exec(compile(_src, 'validate_part', 'exec'), _v)
parse = _v['parse']
read = _v['read']
is_lua = _v['is_lua']
NUMS = _v['NUMS']

ADDON_REL = 'scripts/npc/heroes'
LEVEL_KEYS = _v['LEVEL_KEYS']


def git_show(relpath):
    try:
        out = subprocess.run(['git', 'show', 'HEAD:' + relpath],
                             cwd=ROOT, capture_output=True)
        if out.returncode != 0:
            return None
        for enc in ('utf-8-sig', 'utf-8', 'cp1251', 'latin-1'):
            try:
                return out.stdout.decode(enc)
            except UnicodeDecodeError:
                continue
    except Exception:
        return None
    return None


def first_num(v):
    """First numeric element of a value, or None if not numeric."""
    if not isinstance(v, str):
        return None
    parts = v.split()
    if not parts or not NUMS.match(parts[0]):
        return None
    return float(parts[0])


def collect(block):
    """{key: raw_value} for every level-bearing entry of one ability."""
    out = {}
    for k in LEVEL_KEYS:
        if k in block and isinstance(block[k], str):
            out[k] = block[k]
    av = block.get('AbilityValues')
    if isinstance(av, dict):
        for k, v in av.items():
            if isinstance(v, dict):
                if 'value' in v:
                    out['AbilityValues/' + k] = v['value']
                for sub, sv in v.items():
                    if sub.startswith('special_bonus_') and isinstance(sv, str):
                        out['AbilityValues/%s[%s]' % (k, sub)] = sv
            elif isinstance(v, str):
                out['AbilityValues/' + k] = v
    asp = block.get('AbilitySpecial')
    if isinstance(asp, dict):
        # Only the payload key of a legacy sub-block becomes a top-level
        # AbilityValues key; attribute keys like DamageTypeTooltip or
        # RequiresScepter end up nested under it, so they must not be
        # recorded here or conversion would look like deletion.
        attrs = ('var_type', 'CalculateSpellDamageTooltip', 'DamageTypeTooltip',
                 'affected_by_aoe_increase', 'RequiresScepter', 'RequiresShard')
        for blk in asp.values():
            if not isinstance(blk, dict):
                continue
            for k, v in blk.items():
                if k in attrs or k.startswith('Linked') or k.startswith('special_bonus_'):
                    continue
                if isinstance(v, str):
                    out['AbilityValues/' + k] = v
                    break
    return out


def check_hero(hero):
    rel = '%s/%s/ability_data.txt' % (ADDON_REL, hero)
    path = os.path.join(ROOT, rel.replace('/', os.sep))
    if not os.path.isfile(path):
        return []
    old_raw = git_show(rel)
    if old_raw is None:
        return ['%s: not in HEAD (new file) - nothing to compare' % hero]

    old, _ = parse(old_raw)
    new, _ = parse(read(path))

    drift = []
    for name, nb in new.items():
        if not isinstance(nb, dict) or name.startswith('special_bonus_'):
            continue
        ob = old.get(name)
        if not isinstance(ob, dict):
            continue
        lua = is_lua(nb)
        o_vals, n_vals = collect(ob), collect(nb)
        for k, ov in o_vals.items():
            if k not in n_vals:
                continue
            nv = n_vals[k]
            if ov == nv:
                continue
            of, nf = first_num(ov), first_num(nv)
            if of is None or nf is None:
                if lua:
                    drift.append('%s / %s: LUA ability value changed  "%s" -> "%s"'
                                 % (name, k, ov, nv))
                continue
            if abs(of - nf) > 1e-9:
                drift.append('%s / %s: base value changed  %g -> %g   ("%s" -> "%s")'
                             % (name, k, of, nf, ov, nv))
            elif lua and len(ov.split()) != len(nv.split()):
                pass  # length fix on a lua ability is permitted
        # dropped keys are legitimate but worth eyeballing
        for k in o_vals:
            if k not in n_vals and k.startswith('AbilityValues/') \
                    and '[' not in k:
                drift.append('%s / %s: key REMOVED - confirm nothing reads it' % (name, k))
    return ['%s: %s' % (hero, d) for d in drift]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    base = os.path.join(ROOT, ADDON_REL.replace('/', os.sep))
    if '--all' in sys.argv:
        heroes = sorted(d for d in os.listdir(base)
                        if os.path.isdir(os.path.join(base, d)))
    elif args:
        heroes = args
    else:
        print(__doc__); sys.exit(2)

    hard = soft = 0
    for h in heroes:
        for line in check_hero(h):
            print(line)
            if 'REMOVED' in line:
                soft += 1
            else:
                hard += 1
    print()
    print('%d changed value(s), %d removed key(s)' % (hard, soft))
    sys.exit(1 if hard else 0)


main()
