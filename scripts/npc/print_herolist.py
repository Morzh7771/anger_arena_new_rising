import os

names = []

with open('herolist.txt', 'r', encoding="utf-8") as herolist:
    for count, line in enumerate(herolist):
        pass # посчитали количество строк в файле

with open('herolist.txt', 'r', encoding="utf-8") as herolist:
    for i in range(count):
        text = herolist.readline() # записали очередную строку
        if 'dota_hero' in text: # проверили, содержит ли строка имя героя
            text = text.replace('npc_dota_hero_', '')
            while '\t' in text:
                text = text.replace('\t', '')
            while '\n' in text:
                text = text.replace('\n', '')
            while '\t1' in text:
                text = text.replace('\t1', '')
            while ' ' in text:
                text = text.replace(' ', '')
            while '"' in text:
                text = text.replace('"', '')
            text = text.replace('1', '')
            text = text.replace('0', '') # отреплейсили строку во все дыры и получили имя
            names.append(text) # добавили очередное имя в список
            
for i in range(len(names)):
    path = 'heroes/'+names[i]
    if not os.path.exists(path):
        os.makedirs(path) # если не существует папки с именем героя, то генерируется папка с файлами
        with open(path+"/ability_data.txt", "w") as file:
            file.write('"DOTAAbilities"\n{}')
        with open(path+"/hero_data.txt", "w") as file:
            file.write('"DOTAHeroes"\n{}')
        with open(path+"/talentes_data.txt", "w") as file:
            file.write('"DOTAAbilities"\n{}')
