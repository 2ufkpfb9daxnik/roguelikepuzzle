import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

bad = '\t\tvar _t_aw_tween_finished = Time.get_ticks_usec()\n\t\tawait tween.finished\n\t\tprint("[AWAIT] tween_finished took %.2f ms" % ((Time.get_ticks_usec() - _t_aw_tween_finished) / 1000.0))'
good = '\tvar _t_aw_tween_finished = Time.get_ticks_usec()\n\tawait tween.finished\n\tprint("[AWAIT] tween_finished took %.2f ms" % ((Time.get_ticks_usec() - _t_aw_tween_finished) / 1000.0))'

content = content.replace(bad, good)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")
