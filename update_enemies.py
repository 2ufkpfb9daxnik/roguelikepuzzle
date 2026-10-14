import codecs
with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace(
    '\"enemy3\": {\"name\": \"ポイズントード\", \"element\": \"水属性\", \"race\": \"水属性\", \"color\": \"#00E5FF\"},',
    '\"enemy3\": {\"name\": \"ポイズントード\", \"element\": [\"水属性\", \"毒属性\"], \"race\": \"水属性\", \"color\": \"#00E5FF\"},'
)
content = content.replace(
    '\"enemy6\": {\"name\": \"フォレストガード\", \"element\": \"木属性\", \"race\": \"木属性\", \"color\": \"#69F0AE\"},',
    '\"enemy6\": {\"name\": \"フォレストガード\", \"element\": [\"木属性\", \"地属性\"], \"race\": \"木属性\", \"color\": \"#69F0AE\"},'
)
content = content.replace(
    '\"enemy9\": {\"name\": \"クリムゾンオーク\", \"element\": \"火属性\", \"race\": \"火属性\", \"color\": \"#FF1744\"},',
    '\"enemy9\": {\"name\": \"クリムゾンオーク\", \"element\": [\"火属性\", \"地属性\"], \"race\": \"火属性\", \"color\": \"#FF1744\"},'
)
content = content.replace(
    '\"enemy13\": {\"name\": \"ダークピクシー\", \"element\": \"闇属性\", \"race\": \"闇属性\", \"color\": \"#EA80FC\"},',
    '\"enemy13\": {\"name\": \"ダークピクシー\", \"element\": [\"闇属性\", \"風属性\"], \"race\": \"闇属性\", \"color\": \"#EA80FC\"},'
)
content = content.replace(
    '\"enemy23\": {\"name\": \"オーガトード\", \"element\": \"木属性\", \"race\": \"木属性\", \"color\": \"#8BC34A\"},',
    '\"enemy23\": {\"name\": \"オーガトード\", \"element\": [\"木属性\", \"毒属性\"], \"race\": \"木属性\", \"color\": \"#8BC34A\"},'
)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)
