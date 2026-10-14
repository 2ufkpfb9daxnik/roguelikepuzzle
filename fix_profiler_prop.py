import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# Fix the broken add_child and queue_free injections
# We have patterns like:
# something.Profiler.add_child_count += 1; add_child(
# Profiler.add_child_count += 1; add_child(
# queue_free(); Profiler.queue_free_count += 1

# First, fix some_object.Profiler.add_child_count += 1; add_child(
content = re.sub(r'(\w+)\.Profiler\.add_child_count \+= 1; add_child\(', r'Profiler.add_child_count += 1; \1.add_child(', content)

# Also fix Profiler.add_child_count += 1; something.add_child( 
# Wait, my regex was exactly Profiler.add_child_count += 1; add_child( 
# So something.add_child( became something.Profiler.add_child_count += 1; add_child(.
# The regex above '(\w+)\.Profiler\.add_child_count \+= 1; add_child\(' fixes effects_parent.Profiler.add_child_count += 1; add_child(.

# What about queue_free?
# something.queue_free(); Profiler.queue_free_count += 1
# If original was item["node"].queue_free(), it became item["node"].queue_free(); Profiler.queue_free_count += 1.
# This is actually valid syntax! item["node"].queue_free(); Profiler.queue_free_count += 1 works perfectly.
# Wait, what if it was sp_i.finished.connect(asp_i.queue_free)? 
# It became sp_i.finished.connect(asp_i.queue_free); Profiler.queue_free_count += 1 -> Wait, it didn't match queue_free()! My regex was \bqueue_free\(\).
# So it only matched queue_free().

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

print("SUCCESS")
