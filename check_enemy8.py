import codecs
with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    lines = f.readlines()
    print(lines[83].strip())
