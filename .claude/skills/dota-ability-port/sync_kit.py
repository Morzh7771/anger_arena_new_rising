#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rebuild each hero's ability slots to match the live patch.

Spectre showed why this is needed: the addon still runs her pre-rework kit, so
Desolate sits in a normal slot instead of being the innate, Haunt is one slot
off, and spectre_shadow_step does not exist at all. Filling only empty slots -
which is all the earlier pass did - cannot fix that.

The target layout is Valve's Ability1..9, with two adjustments:

  * where the addon runs its own implementation of a Dota ability under a
    different name (abaddon_aphotic_shield_lua, crystal_maiden_brilliance_aura_aa),
    that name is kept - only the slot follows Valve
  * abilities the addon invented, which Dota knows nothing about, are moved to
    the first free slots after Valve's, never dropped

A Dota ability the addon has no definition for is copied from the patch, with
MaxLevel set the way this addon does it - 7 for a learnable ability, 1 for an
innate or a NOT_LEARNABLE one - and every level array rescaled to match.

usage: python sync_kit.py [--dry-run] [hero ...]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
HEROES = os.path.join(ROOT, 'scripts', 'npc', 'heroes')
PATCH = r"C:\Users\admin\Desktop\dota 2 patch\scripts\npc"
PATCH_HERO_DIR = os.path.join(PATCH, 'heroes')

_p = {'__file__': os.path.join(HERE, 'port.py')}
_src = open(os.path.join(HERE, 'port.py'), encoding='utf-8').read().split('def port_hero(')[0]
_src = _src.replace('main()', '')
exec(compile(_src, 'port_part', 'exec'), _p)
parse = _p['parse']
read = _p['read']
rescale = _p['rescale']
NUMS = _p['NUMS']

SLOT = re.compile(r'^Ability([1-9])$')
SUFFIX = re.compile(r'_(lua|aa|custom|custom_aa)$')
MAX_SLOT = 9


def base_name(n):
    return SUFFIX.sub('', n)


def hero_key(hkv):
    for k, v in hkv.items():
        if isinstance(v, dict) and k.startswith('npc_dota_hero_'):
            return k, v
    return None, None


def target_maxlevel(body, siblings_max):
    beh = body.get('AbilityBehavior', '') or ''
    if body.get('Innate') == '1' or 'NOT_LEARNABLE' in beh:
        return 1
    try:
        if int(body.get('MaxLevel', '0')) == 1:
            return 1
    except ValueError:
        pass
    return siblings_max or 7


def render_block(name, body, ml, indent='\t'):
    """Serialise a patch ability block with MaxLevel and rescaled arrays."""
    out = ['%s"%s"' % (indent, name), '%s{' % indent]
    inner = indent + '\t'
    out.append('%s"MaxLevel"\t\t\t\t\t"%d"' % (inner, ml))
    for k, v in body.items():
        if k in ('MaxLevel', 'AbilityValues'):
            continue
        if isinstance(v, str):
            val = rescale(v, ml) or v if k.startswith('Ability') else v
            out.append('%s"%s"\t\t\t\t"%s"' % (inner, k, val))
    av = body.get('AbilityValues')
    if isinstance(av, dict):
        out.append('%s"AbilityValues"' % inner)
        out.append('%s{' % inner)
        deep = inner + '\t'
        for k, v in av.items():
            if isinstance(v, dict):
                out.append('%s"%s"' % (deep, k))
                out.append('%s{' % deep)
                for sk, sv in v.items():
                    if isinstance(sv, str):
                        sval = rescale(sv, ml) or sv if sk == 'value' else sv
                        out.append('%s\t"%s"\t\t\t\t"%s"' % (deep, sk, sval))
                out.append('%s}' % deep)
            elif isinstance(v, str):
                out.append('%s"%s"\t\t\t\t"%s"' % (deep, k, rescale(v, ml) or v))
        out.append('%s}' % inner)
    out.append('%s}' % indent)
    return '\n'.join(out) + '\n'


def main():
    dry = '--dry-run' in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith('--')]

    pher, _ = parse(read(os.path.join(PATCH, 'npc_heroes.txt')))
    heroes = only or sorted(os.listdir(HEROES))

    tot_slots = tot_defs = 0
    for hero in heroes:
        hdir = os.path.join(HEROES, hero)
        hp = os.path.join(hdir, 'hero_data.txt')
        ap = os.path.join(hdir, 'ability_data.txt')
        if not os.path.isfile(hp):
            continue
        hkv, _ = parse(read(hp))
        hname, hb = hero_key(hkv)
        if not hname:
            continue
        pb = pher.get(hname)
        if not isinstance(pb, dict):
            continue

        akv = {}
        if os.path.isfile(ap):
            akv, _ = parse(read(ap))

        pabil = {}
        pf = os.path.join(PATCH_HERO_DIR, '%s.txt' % hname)
        if os.path.isfile(pf):
            pabil, _ = parse(read(pf))

        addon_slots = {int(SLOT.match(k).group(1)): v for k, v in hb.items()
                       if SLOT.match(k) and isinstance(v, str)}
        patch_slots = {int(SLOT.match(k).group(1)): v for k, v in pb.items()
                       if SLOT.match(k) and isinstance(v, str) and v}
        if not patch_slots:
            continue

        # addon name for each Dota ability, if it runs its own variant
        by_base = {}
        for v in addon_slots.values():
            if v and v != 'generic_hidden':
                by_base.setdefault(base_name(v), v)

        target = {}
        for s, t in patch_slots.items():
            target[s] = by_base.get(t, t)

        # addon-only abilities keep a home in the first free slots
        placed = set(target.values())
        leftover = [v for s, v in sorted(addon_slots.items())
                    if v and v != 'generic_hidden' and v not in placed
                    and base_name(v) not in patch_slots.values()]
        free = [s for s in range(1, MAX_SLOT + 1) if s not in target]
        for v in leftover:
            if not free:
                break
            target[free.pop(0)] = v

        changes = [(s, addon_slots.get(s), t) for s, t in sorted(target.items())
                   if addon_slots.get(s) != t]
        if not changes:
            continue

        # sibling MaxLevel, so a new ability matches the hero's scaling
        sib = 0
        for n, b in akv.items():
            if isinstance(b, dict) and not n.startswith('special_bonus_'):
                try:
                    sib = max(sib, int(b.get('MaxLevel', '0')))
                except ValueError:
                    pass

        new_defs = []
        for _s, _old, t in changes:
            if t in akv or t == 'generic_hidden':
                continue
            body = pabil.get(t)
            if isinstance(body, dict):
                new_defs.append((t, render_block(t, body, target_maxlevel(body, sib))))

        print('%s' % hero)
        for s, old, t in changes:
            print('    Ability%-2d %-40s -> %s' % (s, old or '(none)', t))
        for t, _ in new_defs:
            print('    + definition copied from patch: %s' % t)
        tot_slots += len(changes)
        tot_defs += len(new_defs)

        if dry:
            continue

        # write slots
        raw = open(hp, 'rb').read()
        crlf = b'\r\n' in raw
        bom = raw[:3] == b'\xef\xbb\xbf'
        text = raw.decode('utf-8-sig', 'replace').replace('\r\n', '\n')
        for s, old, t in changes:
            key = 'Ability%d' % s
            if old is None:
                anchor = re.search(r'(?m)^([ \t]*)"Ability1"\s*"[^"]*"\s*$', text)
                if anchor:
                    ins = anchor.end() + 1
                    text = (text[:ins] + '%s"%s"\t\t"%s"\n' % (anchor.group(1), key, t)
                            + text[ins:])
                continue
            text = re.sub(r'("%s"\s*")%s(")' % (re.escape(key), re.escape(old)),
                          lambda m: m.group(1) + t + m.group(2), text, count=1)
        out = text.replace('\n', '\r\n') if crlf else text
        with open(hp, 'w', encoding='utf-8-sig' if bom else 'utf-8', newline='') as f:
            f.write(out)

        # append missing definitions
        if new_defs and os.path.isfile(ap):
            raw = open(ap, 'rb').read()
            crlf = b'\r\n' in raw
            bom = raw[:3] == b'\xef\xbb\xbf'
            t2 = raw.decode('utf-8-sig', 'replace').replace('\r\n', '\n')
            close = t2.rstrip().rfind('}')
            if close != -1:
                add = '\n' + ''.join(b for _n, b in new_defs)
                t2 = t2[:close] + add + t2[close:]
                out = t2.replace('\n', '\r\n') if crlf else t2
                with open(ap, 'w', encoding='utf-8-sig' if bom else 'utf-8',
                          newline='') as f:
                    f.write(out)

    print()
    print('TOTAL: %d slot change(s), %d definition(s) copied%s'
          % (tot_slots, tot_defs, '  (dry run)' if dry else ''))


main()
