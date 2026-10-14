import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

import re
old_block = r'(if s_name != "":\s*var sm_for_log = _get_score_manager\(\)\s*if sm_for_log and sm_for_log\.has_method\("add_turn_element"\):\s*var e_enum = ElementDataScript\.get_element_from_name\(s_elem\)\s*if e_enum != ElementDataScript\.Element\.NONE:\s*sm_for_log\.add_turn_element\(e_enum, 1\)\s*turn_skill_log\.append\(\{.*?"target": "all"\s*\}\))'

# We'll just replace the match item_type block instead.
# Let's find "match item_type:" inside _detonate_specials
