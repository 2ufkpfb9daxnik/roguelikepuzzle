import codecs
with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

old = "var elem_name: String = sp_data.get(\"element\", sp_data.get(\"race\", \"無属性\"))"
new = "var elem_raw = sp_data.get(\"element\", sp_data.get(\"race\", \"無属性\"))\n\t\t\tvar elem_name: String = \"/\".join(elem_raw) if typeof(elem_raw) == TYPE_ARRAY else elem_raw"

content = content.replace(old, new)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)
