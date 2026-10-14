import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# Let's completely undo and redo the await replacements by searching explicitly.
# I will just write a python script to manually set the tabs for lines 2987-2989 and 3087-3089.

lines = content.split('\n')
for i in range(len(lines)):
    if '_start_breaking_animation()' in lines[i]:
        # Context around 2989
        pass

# It's easier to just use fix_depth.py logic again on those lines
for i in range(len(lines)):
    if 'var _t_aw_tween_finished = Time.get_ticks_usec()' in lines[i]:
        # we need to look at the previous line
        l_prev = lines[i-1]
        tabs = len(l_prev) - len(l_prev.lstrip('\t'))
        if 'if ' in l_prev or 'else:' in l_prev or 'elif ' in l_prev:
            tabs += 1
        lines[i] = '\t'*tabs + lines[i].lstrip()
        lines[i+1] = '\t'*tabs + lines[i+1].lstrip()
        lines[i+2] = '\t'*tabs + lines[i+2].lstrip()

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")
