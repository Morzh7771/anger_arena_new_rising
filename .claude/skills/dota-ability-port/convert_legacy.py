#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Convert legacy AbilitySpecial blocks into modern AbilityValues.

  "AbilitySpecial"                        "AbilityValues"
  {                                       {
      "01"                                    "movespeed_bonus"  "15 20 25 30 35 40 45"
      {                          ->           "damage"
          "var_type" "FIELD_INTEGER"          {
          "movespeed_bonus" "15 20 25 30"         "value"              "100 200 300 400 500 600 700"
      }                                          "LinkedSpecialBonus" "special_bonus_unique_x"
  }                                           }
                                          }

* `var_type` and the "01"/"02" index wrappers are dropped.
* LinkedSpecialBonus / ...Field / ...Operation are preserved verbatim.
* Values are stretched to the ability's MaxLevel with the same rules as port.py:
  increasing series preserve their step, decreasing series preserve their range.
* If the ability already has an AbilityValues block, entries are merged into it
  and the existing entry wins on a key collision.

usage: python convert_legacy.py <hero> [...]
       python convert_legacy.py --all [--dry-run]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
ADDON = os.path.join(ROOT, 'scripts', 'npc', 'heroes')

_p = {'__file__': os.path.join(HERE, 'port.py')}
_src = open(os.path.join(HERE, 'port.py'), encoding='utf-8').read().split('def port_hero(')[0]
_src = _src.replace('main()', '')
exec(compile(_src, 'port_part', 'exec'), _p)
parse = _p['parse']
read = _p['read']
rescale = _p['rescale']
find_blocks = _p['find_blocks']
is_lua = _p['is_lua']

LINKED = ('LinkedSpecialBonus', 'LinkedSpecialBonusField', 'LinkedSpecialBonusOperation')
PASSTHROUGH = LINKED + ('CalculateSpellDamageTooltip', 'DamageTypeTooltip',
                        'affected_by_aoe_increase', 'RequiresScepter', 'RequiresShard')


def convert_block(asp, ml, indent):
    """asp: parsed AbilitySpecial dict -> (rendered_entries_text, {key: value})."""
    out = []
    keys = {}
    for _idx, blk in asp.items():
        if not isinstance(blk, dict):
            continue
        main = None
        extras = []
        for k, v in blk.items():
            if k == 'var_type':
                continue
            if k in PASSTHROUGH or k.startswith('special_bonus_'):
                extras.append((k, v))
                continue
            if main is None and isinstance(v, str):
                main = (k, v)
            else:
                extras.append((k, v))
        if main is None:
            continue
        key, val = main
        new = rescale(val, ml) or val
        keys[key] = new
        if not extras:
            out.append('%s"%s"\t\t\t\t"%s"\n' % (indent, key, new))
        else:
            inner = indent + '\t'
            body = '%s"value"\t\t\t\t"%s"\n' % (inner, new)
            for k, v in extras:
                if isinstance(v, str):
                    body += '%s"%s"\t\t\t\t"%s"\n' % (inner, k, v)
            out.append('%s"%s"\n%s{\n%s%s}\n' % (indent, key, indent, body, indent))
    return ''.join(out), keys


def convert_hero(hero, dry=False):
    path = os.path.join(ADDON, hero, 'ability_data.txt')
    if not os.path.isfile(path):
        return None
    kv, _ = parse(read(path))
    raw = read(path)
    crlf = '\r\n' in raw
    text = raw.replace('\r\n', '\n')

    edits = []
    converted = []

    def walk(start, end):
        for name, _ks, bo, bc in list(find_blocks(text, start, end)):
            if name in ('DOTAAbilities', 'Version'):
                walk(bo + 1, bc)
                continue
            ab = kv.get(name)
            if not isinstance(ab, dict) or 'AbilitySpecial' not in ab:
                continue
            asp = ab['AbilitySpecial']
            if not isinstance(asp, dict):
                continue
            try:
                ml = int(ab.get('MaxLevel', '0'))
            except ValueError:
                ml = 0

            asp_open = asp_close = None
            av_open = av_close = None
            for k2, ks2, bo2, bc2 in find_blocks(text, bo + 1, bc):
                if k2 == 'AbilitySpecial':
                    asp_open, asp_close, asp_kstart = bo2, bc2, ks2
                elif k2 == 'AbilityValues':
                    av_open, av_close = bo2, bc2
            if asp_open is None:
                continue

            line_start = text.rfind('\n', 0, asp_kstart) + 1
            indent = re.match(r'[ \t]*', text[line_start:]).group(0)

            existing = ab.get('AbilityValues')
            existing = existing if isinstance(existing, dict) else {}

            # the existing AbilityValues wins on a key collision, so drop any
            # legacy entry whose payload key is already defined there
            if existing:
                asp = {k: v for k, v in asp.items()
                       if isinstance(v, dict)
                       and not (set(v) - {'var_type'} - set(PASSTHROUGH)) & set(existing)}
            body, produced = convert_block(asp, ml, indent + '\t')

            if not body.strip():
                # nothing new - just drop the legacy block
                end_line = text.find('\n', asp_close)
                end_line = asp_close + 1 if end_line == -1 else end_line + 1
                edits.append((line_start, end_line, ''))
                converted.append('%s: AbilitySpecial dropped (all keys already present)' % name)
                continue

            if av_open is not None:
                # merge into the existing AbilityValues, then delete AbilitySpecial
                av_line_start = text.rfind('\n', 0, av_close) + 1
                edits.append((av_line_start, av_line_start, body))
                end_line = text.find('\n', asp_close)
                end_line = asp_close + 1 if end_line == -1 else end_line + 1
                edits.append((line_start, end_line, ''))
                converted.append('%s: %d key(s) merged into AbilityValues'
                                 % (name, len(produced)))
            else:
                block = '%s"AbilityValues"\n%s{\n%s%s}\n' % (indent, indent, body, indent)
                end_line = text.find('\n', asp_close)
                end_line = asp_close + 1 if end_line == -1 else end_line + 1
                edits.append((line_start, end_line, block))
                converted.append('%s: AbilitySpecial -> AbilityValues (%d keys)'
                                 % (name, len(produced)))

    walk(0, len(text))
    if not edits:
        return {'hero': hero, 'converted': []}

    edits.sort(key=lambda e: e[0], reverse=True)
    for a, b, repl in edits:
        text = text[:a] + repl + text[b:]

    if not dry:
        if crlf:
            text = text.replace('\n', '\r\n')
        with open(path, 'w', encoding='utf-8', newline='') as f:
            f.write(text)
    return {'hero': hero, 'converted': converted}


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

    tot = 0
    for h in heroes:
        r = convert_hero(h, dry)
        if r and r['converted']:
            print(h)
            for c in r['converted']:
                print('   %s' % c)
            tot += len(r['converted'])
    print('\n%d ability block(s) converted%s' % (tot, '  (dry run)' if dry else ''))


main()
