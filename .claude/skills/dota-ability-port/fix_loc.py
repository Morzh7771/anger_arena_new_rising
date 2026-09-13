#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Repair item tooltips that reference KV keys which no longer exist.

A %placeholder% naming no AbilityValues key renders as blank text in game, so
the tooltip silently promises an effect the item does not have.

Two repairs, in order:
  1. renamed keys - rewrite the placeholder to the key's current name
  2. everything else - replace the whole token with Valve's current text for
     that item, taken from the live patch localisation. Tier entries
     (item_x_2, item_x_3) inherit the base item's text.

Lua-backed items are never touched: their effects really are custom, so Valve's
wording would be wrong for them.

usage: python fix_loc.py [--dry-run]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
LOC = {
    'en': (os.path.join(ROOT, 'resource', 'addon_english.txt'),
           r"C:\Users\admin\Desktop\dota 2 patch\resource\localization\abilities_english.txt"),
    'ru': (os.path.join(ROOT, 'resource', 'addon_russian.txt'),
           r"C:\Users\admin\Desktop\dota 2 patch\resource\localization\abilities_russian.txt"),
}

# placeholder rewrites for keys this port renamed
RENAMED = {
    'heal_reduction': 'restoration_reduction',
    'hp_regen_reduction_enemy': 'restoration_reduction_enemy',
    'minimun_distance': 'minimum_distance',
}

_v = {'__file__': os.path.join(HERE, 'validate.py')}
_src = open(os.path.join(HERE, 'validate.py'), encoding='utf-8').read().split('def check_hero(')[0]
exec(compile(_src, 'validate_part', 'exec'), _v)
parse = _v['parse']
read = _v['read']

PLACEHOLDER = re.compile(r'%([a-zA-Z_][a-zA-Z0-9_]*)%')
LINE = re.compile(r'^(\s*)"(DOTA_Tooltip_ability_[A-Za-z0-9_]+)"(\s*)"(.*)"(\s*)$')
TIER = re.compile(r'_[2-9]$')
BUILTIN = {'abilitycooldown', 'abilitymanacost', 'abilitycastrange', 'abilityduration',
           'abilitychanneltime', 'abilitydamage', 'value'}

SUFFIXES = ('_Description', '_Lore', '_Note0', '_Note1', '_Note2', '_Note3',
            '_Note4', '_Note5', '_aghanim_description', '_shard_description')


def item_kv():
    """{item_name: (set(AbilityValues keys), is_lua)}"""
    out = {}
    d = os.path.join(ROOT, 'scripts', 'npc', 'items')
    files = [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.endswith('.txt')]
    files.append(os.path.join(ROOT, 'scripts', 'npc', 'dota_items.txt'))
    for p in files:
        kv, _ = parse(read(p))
        for k, v in kv.items():
            if not isinstance(v, dict):
                continue
            av = v.get('AbilityValues')
            lua = ('ScriptFile' in v
                   or v.get('BaseClass') in ('ability_lua', 'item_lua', 'ability_datadriven'))
            out[k] = (set(av) if isinstance(av, dict) else set(), lua)
    return out


def valve_tokens(path):
    out = {}
    for line in read(path).splitlines():
        m = LINE.match(line)
        if m:
            out[m.group(2)] = m.group(4)
    return out


def base_of(token):
    """DOTA_Tooltip_ability_item_x_2_Description -> (item_x_2, '_Description')"""
    body = token[len('DOTA_Tooltip_ability_'):]
    for suf in SUFFIXES:
        if body.endswith(suf):
            return body[:-len(suf)], suf
    m = re.match(r'^(item_[a-z0-9_]+?)_([a-z0-9_]+)$', body)
    return body, ''


def main():
    dry = '--dry-run' in sys.argv
    kv = item_kv()

    for lang, (addon_path, valve_path) in LOC.items():
        if not os.path.isfile(addon_path) or not os.path.isfile(valve_path):
            print('%s: missing file, skipped' % lang)
            continue
        valve = valve_tokens(valve_path)
        raw = read(addon_path)
        crlf = '\r\n' in raw
        lines = raw.replace('\r\n', '\n').split('\n')

        renamed = replaced = dropped = 0
        for i, line in enumerate(lines):
            m = LINE.match(line)
            if not m:
                continue
            pre, token, mid, text, post = m.groups()
            name, _suf = base_of(token)
            if not name.startswith('item_'):
                continue
            entry = kv.get(name)
            if not entry:
                continue
            keys, lua = entry
            if lua:
                continue
            have = {k.lower() for k in keys}
            bad = [p for p in PLACEHOLDER.findall(text)
                   if p.lower() not in have and p.lower() not in BUILTIN]
            if not bad:
                continue

            # 1. rewrite renamed placeholders
            new_text = text
            for b in bad:
                if b in RENAMED and RENAMED[b].lower() in have:
                    new_text = new_text.replace('%' + b + '%', '%' + RENAMED[b] + '%')
            still = [p for p in PLACEHOLDER.findall(new_text)
                     if p.lower() not in have and p.lower() not in BUILTIN]
            if not still:
                lines[i] = '%s"%s"%s"%s"%s' % (pre, token, mid, new_text, post)
                renamed += 1
                continue

            # 2. fall back to Valve's current wording for the base item
            base_item = TIER.sub('', name)
            vtoken = token.replace(name, base_item, 1)
            vtext = valve.get(vtoken)
            if vtext is not None:
                vbad = [p for p in PLACEHOLDER.findall(vtext)
                        if p.lower() not in have and p.lower() not in BUILTIN]
                if not vbad:
                    lines[i] = '%s"%s"%s"%s"%s' % (pre, token, mid, vtext, post)
                    replaced += 1
                    continue
            # 3. nothing usable - leave it, report below
            dropped += 1

        if not dry:
            out = '\n'.join(lines)
            if crlf:
                out = out.replace('\n', '\r\n')
            with open(addon_path, 'w', encoding='utf-8-sig', newline='') as f:
                f.write(out)
        print('%s: %d placeholder(s) renamed, %d token(s) taken from Valve, '
              '%d still unresolved%s'
              % (lang, renamed, replaced, dropped, '  (dry run)' if dry else ''))


main()
