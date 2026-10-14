import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace('SkillVFXNode.VFXMode.CHANT_AURA', 'SkillVFXNode.VFXMode.CHANT_CIRCLE')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
