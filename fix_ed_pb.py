import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

text = text.replace('ElementData.get_element_from_enemy_name', 'ElementDataScript.get_element_from_enemy_name')
text = text.replace('ElementData.get_damage_multiplier', 'ElementDataScript.get_damage_multiplier')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(text)
