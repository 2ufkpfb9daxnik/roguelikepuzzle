import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# 3934付近
old_cnt_1 = 'var s_cnt = min(int((sm.ehp if sm else 0) / swordt), int(score_mgr.divscore[PieceType.SWORD] / (swordt * 100.0)))'
new_cnt_1 = 'var s_cnt = min(int((sm.ehp if sm else 0) / (swordt * 100.0)), int(score_mgr.divscore[PieceType.SWORD] / (swordt * 100.0)))'
content = content.replace(old_cnt_1, new_cnt_1)

# 4084付近
old_cnt_2 = 'var raw_sword_cnt: int = min(int((sm.ehp if sm else 0) / swordt), int(score_mgr.divscore[PieceType.SWORD] / (swordt * 100.0)))'
new_cnt_2 = 'var raw_sword_cnt: int = min(int((sm.ehp if sm else 0) / (swordt * 100.0)), int(score_mgr.divscore[PieceType.SWORD] / (swordt * 100.0)))'
content = content.replace(old_cnt_2, new_cnt_2)

# 追加で切り上げ(ceil)の方が良いなら、ceilに変える
# sword_cntは上限なので、少し多めに1本余分に投げる（オーバーキル用）という意味で +1 しておくと安全。
# ただ、とりあえず 100.0 で割ることで「敵のHP分」の剣数が正しく計算される。

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
