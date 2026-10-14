import codecs

with codecs.open('current_stage.tscn', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'name="RichTextLabel"' in lines[i] or 'name="RichTextLabel2"' in lines[i]:
        for j in range(i, i+15):
            print(str(j+1) + ': ' + lines[j].strip())
        print('---')
