import codecs

# We'll just manually fix the known broken lines
def patch_file(file, patches):
    with codecs.open(file, 'r', 'utf-8') as f:
        content = f.read()
    for old, new in patches:
        content = content.replace(old, new)
    with codecs.open(file, 'w', 'utf-8') as f:
        f.write(content)

pb_patches = [
    ('\tvar _t_aw_revert_tween_finished = Time.get_ticks_usec()\n\tawait revert_tween.finished\n\tprint("[AWAIT] revert_tween_finished took %.2f ms" % ((Time.get_ticks_usec() - _t_aw_revert_tween_finished) / 1000.0))',
     '\t\tvar _t_aw_revert_tween_finished = Time.get_ticks_usec()\n\t\tawait revert_tween.finished\n\t\tprint("[AWAIT] revert_tween_finished took %.2f ms" % ((Time.get_ticks_usec() - _t_aw_revert_tween_finished) / 1000.0))'),
    ('\tvar _t_aw_tween_finished = Time.get_ticks_usec()\n\tawait tween.finished\n\tprint("[AWAIT] tween_finished took %.2f ms" % ((Time.get_ticks_usec() - _t_aw_tween_finished) / 1000.0))',
     '\t\tvar _t_aw_tween_finished = Time.get_ticks_usec()\n\t\tawait tween.finished\n\t\tprint("[AWAIT] tween_finished took %.2f ms" % ((Time.get_ticks_usec() - _t_aw_tween_finished) / 1000.0))'),
]

sm_patches = [
    ('\t\t\tvar _t_load = Time.get_ticks_usec()\n\t\t\ttex = ResourceLoader.load_threaded_get(path) as Texture2D\n\t\t\tvar _d_load = Time.get_ticks_usec() - _t_load\n\t\t\tif _d_load > 1000: print("[SPIKE] load_threaded_get blocked for %.2f ms" % (_d_load / 1000.0))',
     '\t\t\t\t\tvar _t_load = Time.get_ticks_usec()\n\t\t\t\t\ttex = ResourceLoader.load_threaded_get(path) as Texture2D\n\t\t\t\t\tvar _d_load = Time.get_ticks_usec() - _t_load\n\t\t\t\t\tif _d_load > 1000: print("[SPIKE] load_threaded_get blocked for %.2f ms" % (_d_load / 1000.0))')
]

patch_file('puzzle_board.gd', pb_patches)
patch_file('stage_manager.gd', sm_patches)
print("SUCCESS")
