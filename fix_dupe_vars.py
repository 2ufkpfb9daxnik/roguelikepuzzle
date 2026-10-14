import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    lines = f.readlines()

new_lines = lines[:144] + lines[146:]

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.writelines(new_lines)
