import os

def to_name(string):
    string = string.replace('npc_dota_hero_', '')
    while '\t' in string:
        string = string.replace('\t', '')
    while '\n' in string:
        string = string.replace('\n', '')
    while '\t1' in string:
        string = string.replace('\t1', '')
    while ' ' in string:
        string = string.replace(' ', '')
    while '"' in string:
        string = string.replace('"', '')
    string = string.replace('1', '')
    string = string.replace('0', '')
    return string

names = []
path = 'D:\\Steam\\steamapps\\common\\dota 2 beta\\game\\dota_addons\\anger_arena_new_rising\\scripts\\npc'

with open(f'{path}\\herolist.txt', 'r') as herolist:
    for count, line in enumerate(herolist):
        pass # посчитали количество строк в файле

with open(f'{path}\\herolist.txt', 'r', encoding="utf-8") as herolist:
    for i in range(count):
        text = herolist.readline() # записали очередную строку
        if 'dota_hero' in text: # проверили, содержит ли строка имя героя
            text = to_name(text) # отреплейсили строку во все дыры и получили имя
            names.append(text) # добавили очередное имя в список
            
for i in range(len(names)):
    if not os.path.exists(f'{path}\\heroes\\{names[i]}'):
        os.makedirs(f'{path}\\heroes\\{names[i]}') # если не существует папки с именем героя, то генерируется папка с файлами

with open(f'{path}\\npc_heroes.txt', 'r') as npcheroes:
    lines = npcheroes.readlines()
    heroeslink = []
    for i in range(len(lines)):
        if 'npc_dota_hero_' in lines[i] and not 'LastHitChallenge' in lines[i] and not 'target' in lines[i] and not 'persona' in lines[i] and not 'base' in lines[i]:
            name = to_name(lines[i])
            print(name)
            found = False
            abfound = False
            j = i
            while not found:
                if '"Ability1"' in lines[j] and not abfound:
                    print('ability')
                    abfound = True
                    index1 = j
                elif '"ItemSlots"' in lines[j]:
                    print('item')
                    index2 = j
                    found = True
                else:
                    j += 1
            print('found')
            with open(f'{path}\\heroes\\{name}\\hero_data.txt', 'w') as herodata:
                herodata.write('"DOTAHeroes"\n')
                herodata.write('{\n')
                herodata.write(f'\t"npc_dota_hero_{name}"\n')
                herodata.write('\t{\n')
                herodata.write(f'\t\t"override_hero"\t\t"npc_dota_hero_{name}"\n')
                for k in range(index1, index2):
                    herodata.write(lines[k])
                herodata.write('\t}\n')
                herodata.write('}')
                heroeslink.append(f'#base heroes/{name}/hero_data.txt\n')

for i in range(len(names)):
    with open(f'{path}\\heroes\\{names[i]}\\ability_data.txt', 'w') as abdata:
        abdata.write('DOTAAbilities\n{\n')

with open(f'{path}\\npc_abilities.txt', 'r') as npcabilities:
    print('abstart')
    lines = npcabilities.readlines()
    abslink = []
    for i in range(len(lines)):
        for j in range(len(names)):
            if names[j] in lines[i] and not 'AbilityDraft' in lines[i] and not 'ad_link' in lines[i] and not 'special_bonus' in lines[i]:
                index1 = i
                found = False
                k = i
                while not found:
                    if '}' in lines[k]:
                        index2 = k
                    elif '//====' in lines[k]:
                        found = True
                    k += 1
                with open(f'{path}\\heroes\\{names[j]}\\ability_data.txt', 'a') as abdata:
                    for k in range(index1, index1 + 4):
                        abdata.write(lines[k])
                    abdata.write(f'\t\t"BaseClass"\t\t{lines[index1]}')
                    abdata.write('\t\t"MaxLevel"\t\t"7"\n')
                    for k in range(index1 + 5, index2 + 1):
                        abdata.write(lines[k])

for i in range(len(names)):
    with open(f'{path}\\heroes\\{names[i]}\\ability_data.txt', 'a') as abdata, open(f'{path}\\npc_heroes_custom.txt', 'a') as herocustom, open(f'{path}\\npc_abilities_custom.txt', 'a') as abcustom:
        abdata.write('}')
        #herocustom.write(f'#base heroes/{names[i]}/hero_data.txt\n')
        #abcustom.write(f'#base heroes/{names[i]}/ability_data.txt\n')
    