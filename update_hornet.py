import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

old = '\"enemy8\": {\"name\": \"キラーホーネット\", \"element\": \"風属性\", \"race\": \"風属性\", \"color\": \"#64FFDA\"}'
new = '\"enemy8\": {\"name\": \"キラーホーネット\", \"element\": [\"風属性\", \"毒属性\"], \"race\": \"風属性\", \"color\": \"#64FFDA\"}'

content = content.replace(old, new)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)
