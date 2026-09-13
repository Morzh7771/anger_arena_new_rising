#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Validate one ported hero against the live-patch reference.

usage: python validate.py <hero_folder_name> [--all]
exit code 0 = clean, 1 = problems found.
"""
import os, sys, re

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
ADDON = os.path.join(ROOT, 'scripts', 'npc', 'heroes')
PATCH = r"C:\Users\admin\Desktop\dota 2 patch\scripts\npc\heroes"


# ---------------------------------------------------------------- KV parsing
def strip_comments(text):
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(text[i + 1]); i += 2; continue
            if c == '"':
                in_str = False
            i += 1; continue
        if c == '"':
            in_str = True; out.append(c); i += 1; continue
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                i += 1
            continue
        out.append(c); i += 1
    return ''.join(out)


def tokenize(text):
    text = strip_comments(text)
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in ' \t\r\n':
            i += 1; continue
        if c in '{}':
            yield c; i += 1; continue
        if c == '"':
            j, buf = i + 1, []
            while j < n and text[j] != '"':
                if text[j] == '\\' and j + 1 < n:
                    buf.append(text[j + 1]); j += 2; continue
                buf.append(text[j]); j += 1
            yield ('S', ''.join(buf)); i = j + 1; continue
        j = i
        while j < n and text[j] not in ' \t\r\n{}"':
            j += 1
        yield ('S', text[i:j]); i = j


def parse(text):
    toks = list(tokenize(text))
    pos = 0
    dup = []

    def block(path):
        nonlocal pos
        d = {}
        while pos < len(toks):
            t = toks[pos]
            if t == '}':
                pos += 1; return d
            if t == '{':
                pos += 1; continue
            key = t[1]; pos += 1
            # repeated keys are legitimate inside these containers
            if key in d and not any(p in ('precache', 'MovementSpeedActivityModifiers',
                                          'AbilityPreview') for p in path):
                dup.append('/'.join(path + [key]))
            if pos < len(toks) and toks[pos] == '{':
                pos += 1
                d[key] = block(path + [key])
            elif pos < len(toks) and isinstance(toks[pos], tuple):
                d[key] = toks[pos][1]; pos += 1
            else:
                d[key] = ''
        return d

    root = {}
    while pos < len(toks):
        t = toks[pos]
        if t == '{':
            pos += 1; root.update(block([])); continue
        if t == '}':
            pos += 1; continue
        key = t[1]; pos += 1
        if pos < len(toks) and toks[pos] == '{':
            pos += 1; root[key] = block([key])
        elif pos < len(toks) and isinstance(toks[pos], tuple):
            root[key] = toks[pos][1]; pos += 1
    for wrap in ('DOTAAbilities', 'DOTAHeroes'):
        if isinstance(root.get(wrap), dict):
            return root[wrap], dup
    return root, dup


def read(p):
    for enc in ('utf-8-sig', 'utf-8', 'cp1251', 'latin-1'):
        try:
            with open(p, 'r', encoding=enc) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    return ''


def brace_balance(text):
    t = strip_comments(text)
    depth, in_str, i = 0, False, 0
    while i < len(t):
        c = t[i]
        if in_str:
            if c == '\\':
                i += 2; continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth < 0:
                return depth
        i += 1
    return depth


NUMS = re.compile(r'^-?\d+(?:\.\d+)?$')


def numeric_array(v):
    if not isinstance(v, str):
        return None
    parts = v.split()
    if len(parts) < 2:
        return None
    if all(NUMS.match(p) for p in parts):
        return parts
    return None


def is_lua(body):
    return 'ScriptFile' in body or body.get('BaseClass') in ('ability_lua', 'ability_datadriven')


LEVEL_KEYS = ('AbilityCooldown', 'AbilityManaCost', 'AbilityCastRange', 'AbilityCastPoint',
              'AbilityChannelTime', 'AbilityDamage', 'AbilityDuration')


def check_hero(hero):
    problems = []
    hdir = os.path.join(ADDON, hero)
    afile = os.path.join(hdir, 'ability_data.txt')
    hfile = os.path.join(hdir, 'hero_data.txt')
    if not os.path.isfile(afile):
        return ['%s: ability_data.txt not found' % hero]

    raw = read(afile)
    bal = brace_balance(raw)
    if bal != 0:
        problems.append('BRACES: ability_data.txt unbalanced (depth %d)' % bal)
        return ['%s: %s' % (hero, p) for p in problems]

    addon, dup = parse(raw)
    for d in dup:
        problems.append('DUPLICATE KEY: %s' % d)

    # locate reference
    pfile = os.path.join(PATCH, 'npc_dota_hero_%s.txt' % hero)
    hero_key = None
    if os.path.isfile(hfile):
        hraw = read(hfile)
        if brace_balance(hraw) != 0:
            problems.append('BRACES: hero_data.txt unbalanced')
        hdata, hdup = parse(hraw)
        for d in hdup:
            problems.append('DUPLICATE KEY in hero_data.txt: %s' % d)
        for k in hdata:
            if k.startswith('npc_dota_hero_'):
                hero_key = k
                break
    else:
        hdata = {}
    if not os.path.isfile(pfile) and hero_key:
        cand = os.path.join(PATCH, '%s.txt' % hero_key)
        if os.path.isfile(cand):
            pfile = cand
    if not os.path.isfile(pfile):
        print('%s: custom hero, no reference file - skipped' % hero)
        return ['%s: %s' % (hero, p) for p in problems]

    patch, _ = parse(read(pfile))

    for name, body in addon.items():
        if not isinstance(body, dict) or name.startswith('special_bonus_'):
            continue
        lua = is_lua(body)
        try:
            ml = int(body.get('MaxLevel', '0'))
        except ValueError:
            ml = 0

        if 'AbilitySpecial' in body and not lua:
            problems.append('%s: legacy AbilitySpecial block not converted' % name)

        if ml > 1:
            def check_len(label, val):
                arr = numeric_array(val)
                if arr and len(arr) != ml:
                    problems.append('%s: %s has %d values, MaxLevel is %d  ->  "%s"'
                                    % (name, label, len(arr), ml, val))
                # negatives are legitimate for talent bonuses; only cost/time keys must stay positive
                if arr and label in ('AbilityCooldown', 'AbilityManaCost', 'AbilityCastRange',
                                     'AbilityCastPoint', 'AbilityChannelTime'):
                    if any(float(x) < 0 for x in arr):
                        problems.append('%s: %s has a negative value  ->  "%s"'
                                        % (name, label, val))
                    if label in ('AbilityCooldown', 'AbilityManaCost') and any(
                            float(x) == 0 for x in arr) and not all(float(x) == 0 for x in arr):
                        problems.append('%s: %s drops to 0  ->  "%s"' % (name, label, val))

            for k in LEVEL_KEYS:
                if k in body:
                    check_len(k, body[k])
            av = body.get('AbilityValues')
            if isinstance(av, dict):
                for k, v in av.items():
                    check_len('AbilityValues/' + k, v.get('value', '') if isinstance(v, dict) else v)
            asp = body.get('AbilitySpecial')
            if isinstance(asp, dict):
                for blk in asp.values():
                    if isinstance(blk, dict):
                        for k, v in blk.items():
                            if k != 'var_type':
                                check_len('AbilitySpecial/' + k, v)

        # native abilities must carry every patch AbilityValues key
        pb = patch.get(name)
        if isinstance(pb, dict) and not lua:
            pav = pb.get('AbilityValues')
            aav = body.get('AbilityValues')
            if isinstance(pav, dict):
                have = set(aav) if isinstance(aav, dict) else set()
                for k in pav:
                    if k not in have:
                        problems.append('%s: missing patch AbilityValues key "%s"' % (name, k))

    # hero_data slots
    if hero_key and isinstance(hdata.get(hero_key), dict):
        hb = hdata[hero_key]
        seen = {}
        for k, v in hb.items():
            if re.fullmatch(r'Ability\d+', k) and isinstance(v, str) and v:
                if v in seen and v != 'generic_hidden':
                    problems.append('hero_data.txt: "%s" used in both %s and %s' % (v, seen[v], k))
                seen[v] = k
                if v not in ('generic_hidden', '') and not v.startswith('special_bonus_') \
                        and v not in addon and v not in patch:
                    problems.append('hero_data.txt: %s -> "%s" is defined nowhere' % (k, v))

    return ['%s: %s' % (hero, p) for p in problems]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if '--all' in sys.argv:
        heroes = sorted(d for d in os.listdir(ADDON) if os.path.isdir(os.path.join(ADDON, d)))
    elif args:
        heroes = args
    else:
        print(__doc__); sys.exit(2)

    total = 0
    for h in heroes:
        probs = check_hero(h)
        if probs:
            total += len(probs)
            for p in probs:
                print(p)
    if total:
        print('\n%d problem(s)' % total)
        sys.exit(1)
    print('OK - clean')


main()
