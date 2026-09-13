#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit addon localization against the KV data it describes.

Reports, for items and hero abilities:
  * %placeholder% tokens in a tooltip that name no AbilityValues key on that
    ability - they render as blank text in game
  * AbilityValues keys that are stat bonuses but have no per-key tooltip line
  * tokens present in English but missing in Russian, and the reverse

usage: python loc_audit.py [--items] [--abilities] [--missing-only]
"""
import os, re, sys, collections

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
EN = os.path.join(ROOT, 'resource', 'addon_english.txt')
RU = os.path.join(ROOT, 'resource', 'addon_russian.txt')

_v = {'__file__': os.path.join(HERE, 'validate.py')}
_src = open(os.path.join(HERE, 'validate.py'), encoding='utf-8').read().split('def check_hero(')[0]
exec(compile(_src, 'validate_part', 'exec'), _v)
parse = _v['parse']
read = _v['read']

# %foo% inside a tooltip refers to an AbilityValues key; these are engine-wide
BUILTIN = {
    'abilitycooldown', 'abilitymanacost', 'abilitycastrange', 'abilitycastpoint',
    'abilityduration', 'abilitychanneltime', 'abilitydamage', 'attack_range',
    'dstat_level_1', 'dstat_level_2', 'dstat_level_3', 'dstat_level_4',
    'value', 'bonus_movement_speed',
}
PLACEHOLDER = re.compile(r'%([a-zA-Z_][a-zA-Z0-9_]*)%')
TOKEN = re.compile(r'^\s*"(DOTA_Tooltip_ability_[A-Za-z0-9_]+)"\s*"(.*)"\s*$')

SUFFIXES = ('_Description', '_Lore', '_Note0', '_Note1', '_Note2', '_Note3',
            '_Note4', '_Note5', '_aghanim_description', '_shard_description')


def load_tokens(path):
    out = {}
    if not os.path.isfile(path):
        return out
    for line in read(path).splitlines():
        m = TOKEN.match(line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def load_kv_values():
    """{ability_or_item_name: set(AbilityValues keys)}"""
    out = {}
    roots = [
        os.path.join(ROOT, 'scripts', 'npc', 'items'),
        os.path.join(ROOT, 'scripts', 'npc'),
    ]
    files = []
    for r in roots:
        if not os.path.isdir(r):
            continue
        for fn in sorted(os.listdir(r)):
            if fn.endswith('.txt') and os.path.isfile(os.path.join(r, fn)):
                files.append(os.path.join(r, fn))
    hero_dir = os.path.join(ROOT, 'scripts', 'npc', 'heroes')
    if os.path.isdir(hero_dir):
        for h in sorted(os.listdir(hero_dir)):
            p = os.path.join(hero_dir, h, 'ability_data.txt')
            if os.path.isfile(p):
                files.append(p)
    for p in files:
        kv, _ = parse(read(p))
        for name, body in kv.items():
            if not isinstance(body, dict):
                continue
            av = body.get('AbilityValues')
            keys = set(av) if isinstance(av, dict) else set()
            for k in ('AbilityCooldown', 'AbilityManaCost', 'AbilityCastRange'):
                if k in body:
                    keys.add(k)
            out.setdefault(name, set()).update(keys)
    return out


def main():
    want_items = '--items' in sys.argv or '--abilities' not in sys.argv
    want_abils = '--abilities' in sys.argv or '--items' not in sys.argv
    missing_only = '--missing-only' in sys.argv

    en, ru = load_tokens(EN), load_tokens(RU)
    kv = load_kv_values()

    broken = []
    for token, text in sorted(en.items()):
        base = token[len('DOTA_Tooltip_ability_'):]
        for suf in SUFFIXES:
            if base.endswith(suf):
                base = base[:-len(suf)]
                break
        is_item = base.startswith('item_')
        if is_item and not want_items:
            continue
        if not is_item and not want_abils:
            continue
        if base not in kv:
            continue
        have = {k.lower() for k in kv[base]}
        for ph in PLACEHOLDER.findall(text):
            if ph.lower() in BUILTIN or ph.lower() in have:
                continue
            broken.append((base, token.split(base + '_')[-1] if base in token else token, ph))

    only_en = sorted(set(en) - set(ru))
    only_ru = sorted(set(ru) - set(en))

    if not missing_only:
        print('=== tooltip placeholders naming no KV key (render blank) ===')
        by_item = collections.defaultdict(set)
        for base, part, ph in broken:
            by_item[base].add(ph)
        for base in sorted(by_item):
            print('  %-38s %s' % (base, ', '.join(sorted(by_item[base]))))
        print('  total: %d placeholder(s) across %d entries' % (len(broken), len(by_item)))
        print()

    print('=== tokens in English but not Russian: %d ===' % len(only_en))
    for t in only_en[:40]:
        print('  ', t)
    if len(only_en) > 40:
        print('   ... and %d more' % (len(only_en) - 40))
    print()
    print('=== tokens in Russian but not English: %d ===' % len(only_ru))
    for t in only_ru[:40]:
        print('  ', t)
    if len(only_ru) > 40:
        print('   ... and %d more' % (len(only_ru) - 40))


main()
