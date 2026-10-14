import codecs
import re

with codecs.open('score_manager.gd', 'r', 'utf-8') as f:
    text = f.read()

old_loop = r'(for i in range\(mini\(5, divscorelabel\.size\(\)\)\):\s*var formatted_val = _format_comma\(divscore\[i\]\)\s*max_len = maxi\(max_len, formatted_val\.length\(\)\)\s*divscorelabel\[i\]\.text = "\[img=60\]res://Texture/%s/%s\.png\[/img\] \[b\]\[color=%s\]%s\[/color\]\[/b\]" % \[\s*TEXTURE_DIR\[i\], TEXTURE_FILE\[i\], ATT_COLORS\[i\], formatted_val\s*\])'

new_loop = r'''for i in range(mini(5, divscorelabel.size())):
		var formatted_val = _format_comma(divscore[i])
		max_len = maxi(max_len, formatted_val.length())
		var breakdown_text = ""
		if i == 0 and turn_element_gain.has(0): # PieceType.SHIELD = 0
			for el in turn_element_gain[0]:
				var el_score = turn_element_gain[0][el]
				if el_score > 0 and el != 0:
					var el_color = ElementData.ELEMENT_COLORS[el].to_html(false)
					breakdown_text += " [color=#%s]%s[/color]" % [el_color, _format_comma(el_score)]
		divscorelabel[i].text = "[img=60]res://Texture/%s/%s.png[/img] [b][color=%s]%s[/color][/b][font_size=20]%s[/font_size]" % [
			TEXTURE_DIR[i], TEXTURE_FILE[i], ATT_COLORS[i], formatted_val, breakdown_text
		]'''

text = re.sub(old_loop, new_loop, text)

with codecs.open('score_manager.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")
