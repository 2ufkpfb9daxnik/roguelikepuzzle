import codecs

with codecs.open('score_manager.gd', 'r', 'utf-8') as f:
    text = f.read()

import re
text = re.sub(r'(\n\t*for cell in component_cells:\n\t*if grid_element\.size.*?\n\t*update_elem_labels\(\)\n)+', '', text, flags=re.DOTALL)

with codecs.open('score_manager.gd', 'w', 'utf-8') as f:
    f.write(text)
