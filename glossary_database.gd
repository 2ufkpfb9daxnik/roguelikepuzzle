class_name GlossaryDatabase
extends RefCounted

## ゲーム内の固有名詞・重要用語の解説辞書（Wikipedia風リンク＆ホバー解説機能）
const GLOSSARY: Dictionary = {
	"水マス": {
		"title": "水マス (Water Tile)",
		"desc": "水属性の盤面マス。ターン終了時にHP回復やシールド獲得、水サージ等の効果を発動する。雷スキルの感電が水上全体へ拡散し、苗木が吸水して大木へ急成長する。",
		"color": "#4FC3F7"
	},
	"火マス": {
		"title": "火マス (Fire Tile)",
		"desc": "火属性の炎上マス。隣接する駒や木マスへ毎ターン延焼し、消去時に敵へ炎ダメージを与える。水マスと接触すると互いに消滅（相殺）する。",
		"color": "#FF7043"
	},
	"毒マス": {
		"title": "毒マス (Poison Tile)",
		"desc": "毒属性の盤面マス。ターン終了時にプレイヤーへ毒ダメージを与え、周囲へ侵食拡大する。マッチ消去するか、水マスや火マス等の属性ケミストリーで浄化可能。",
		"color": "#AB47BC"
	},
	"氷マス": {
		"title": "氷マス (Ice Tile)",
		"desc": "氷属性の凍結マス。動かせずマッチできない障害物だが、雷の落雷を受けると粉砕（シャッター）して周囲3x3の駒を一掃し大ダメージを与える。火マスと隣接すると水マスに変化する。",
		"color": "#80D8FF"
	},
	"木マス": {
		"title": "木マス / 植物マス (Wood Tile)",
		"desc": "木属性の植物マス。隣接するマスへ根を張り、水マスを吸収して大木へと成長する。火マスと接触すると激しく燃え広がり（延焼）大ダメージを誘発する。",
		"color": "#81C784"
	},
	"大木": {
		"title": "大木 (Great Tree)",
		"desc": "苗木が水マスを吸収して3x3に急成長した巨大樹。毎ターンプレイヤーのHP回復や実の収穫（スコア獲得）をもたらす。火属性を受けると大延焼する。",
		"color": "#66BB6A"
	},
	"苗木": {
		"title": "苗木 (Tree Sprout)",
		"desc": "盤面に植えられた植物の芽。水マスと接触することで水を吸い上げ、3x3の巨大な大木へと成長・進化する。",
		"color": "#AED581"
	},
	"黄金像": {
		"title": "黄金像 (Golden Statue)",
		"desc": "光属性の神聖な像。スワップや消去に巻き込むとプレイヤーのHP回復やコイン獲得を発生させ、周囲の敵妨害マスを浄化する。",
		"color": "#FFEE58"
	},
	"石マス": {
		"title": "石マス (Stone Tile)",
		"desc": "地属性の鉱石マス。スワップで移動可能な障害物。雷属性の落雷を受けると粉砕（シャッター）し、周囲3x3のマスを巻き込んで大ダメージを与える。",
		"color": "#B0BEC5"
	},
	"金剛石": {
		"title": "金剛石 (Diamond)",
		"desc": "地属性の究極進化によって生成される超高硬度の宝石。耐久力が高く、破壊時に周囲広範囲へ壊滅的な衝撃波ダメージを放つ。",
		"color": "#E0F7FA"
	},
	"輝石": {
		"title": "輝石 (Gem Tile)",
		"desc": "地属性の結晶石。マッチ操作で移動でき、雷の落雷によってシャッター爆発を引き起こす。",
		"color": "#B0BEC5"
	},
	"感電": {
		"title": "感電 (Shock)",
		"desc": "雷属性の電撃伝導効果。水マスや特定のオブジェクトを経由して電気が広がり、隣接するマスや敵へ追加の雷撃ダメージを与える。",
		"color": "#FFF176"
	},
	"落雷": {
		"title": "落雷 (Lightning Strike)",
		"desc": "雷スキルによって天から放たれる稲妻。盤面の駒や敵へ直撃し、水マスや石マスに当たると感電拡散やシャッターを誘発する。",
		"color": "#FFEB3B"
	},
	"シールド": {
		"title": "シールド (Shield)",
		"desc": "プレイヤーを敵の攻撃から守る防御障壁。敵から受けるダメージをHPの代わりに肩代わりして消費・軽減する。",
		"color": "#4DD0E1"
	},
	"水サージ": {
		"title": "水サージ (Water Surge)",
		"desc": "水属性の中間進化（激流の怒涛）で解放される効果。ターン終了時、盤面に溜まった水マスの数に比例した水流圧撃を敵に放ち、追加ダメージを与える。",
		"color": "#29B6F6"
	},
	"カスケード": {
		"title": "カスケード (Cascade / 連鎖落下)",
		"desc": "駒がマッチして消去された後、上の駒が落下し、さらに新しい駒が補充されることで次々と連鎖してマッチが発生する現象。",
		"color": "#FFD54F"
	},
	"スワップ": {
		"title": "スワップ (Swap)",
		"desc": "上下または左右に隣接する2つの駒の位置を入れ替える基本パズル操作。マッチが成立した時に1手（ターン）を消費する。",
		"color": "#FFB74D"
	},
	"シャッター": {
		"title": "シャッター (Shatter / 氷石粉砕)",
		"desc": "氷マスや石マスに雷の落雷や衝撃が加わった時、マスが粉々に粉砕され、周囲3x3のマスを巻き込んで一掃し、敵に大ダメージを与える現象。",
		"color": "#00E5FF"
	},
	"暗雲": {
		"title": "暗雲 / 暗黒マス (Dark Fog)",
		"desc": "闇属性の不穏なマス。通常のマッチができず視界を遮るが、闇スキルの特異点や崩壊効果の触媒となる。",
		"color": "#BA68C8"
	},
	"ブラックホール": {
		"title": "ブラックホール / 特異点 (Black Hole / Singularity)",
		"desc": "闇属性の特殊駒・重力崩壊オブジェクト。周囲の駒や障害物を強烈に吸引して大消滅させ、同時に味方の身を守る【影護マス】を展開する。",
		"color": "#7C4DFF"
	},
	"特異点": {
		"title": "特異点 / ブラックホール (Singularity / Black Hole)",
		"desc": "闇属性の極大重力場。周囲の駒やマスを中心へ強烈に吸い込み、限界に達すると大爆縮を起こして大ダメージを与える。",
		"color": "#CE93D8"
	},
	"黒穴": {
		"title": "黒穴 / ブラックホール (Black Hole)",
		"desc": "闇属性の特殊オブジェクト。周囲の駒を強力に吸引して消去し、蓄積した質量を大爆発させて敵へ放つ。",
		"color": "#CE93D8"
	},
	"延焼": {
		"title": "延焼 (Burn Spread)",
		"desc": "火マスがターン経過によって隣接する未引火マスや木マスへと燃え移り、火マスを拡大させていく現象。",
		"color": "#FF8A65"
	},
	"炎上": {
		"title": "炎上 (Ignition)",
		"desc": "マスが炎に包まれて火マス化している状態。毎ターン継続的にダメージを発生させる。",
		"color": "#FF7043"
	},
	"アフターバーン": {
		"title": "アフターバーン (Afterburn)",
		"desc": "火マスが消滅・消費された後も高熱の残熱がその場に残り、敵に継続ダメージを与え続ける効果。",
		"color": "#FF7043"
	},
	"渦潮": {
		"title": "渦潮 (Whirlpool)",
		"desc": "水属性の最終進化効果。ターン終了時の水サージ発動時、自陣の水マスが最も多い縦列の駒を押し流して消去し落下連鎖を起こす。その列の水マス数に応じた追加ダメージを与える（水マスは消費しない）。",
		"color": "#0288D1"
	},
	"鉄砲水": {
		"title": "鉄砲水 (Flash Flood)",
		"desc": "水属性の最終進化効果。1行または1列がすべて水マスで揃った瞬間に激流が駆け抜け、列上の駒を消去して大ダメージを与える。",
		"color": "#039BE5"
	},
	"癒しの雨": {
		"title": "癒しの雨 (Healing Rain)",
		"desc": "水属性の進化効果。水マスの上で駒をマッチさせるたびに、ターン終了を待たず即座にプレイヤーのHPが回復する。",
		"color": "#80CBC4"
	},
	"溢れる泉": {
		"title": "溢れる泉 (Overflowing Spring)",
		"desc": "水属性の最終進化効果。ターン終了時の回復でHPが最大値を超えた分を、自身のシールドへと変換する。",
		"color": "#4FC3F7"
	},
	"水の結界": {
		"title": "水の結界 (Water Barrier)",
		"desc": "水属性の最終進化効果。自陣の水マス上では相手の毒が広がらず、毒の伝染を防止する。",
		"color": "#4FC3F7"
	},
	"水鏡": {
		"title": "水鏡 (Water Mirror)",
		"desc": "水属性の進化効果。水マス上で駒をマッチするたび、即座に追加のシールドを獲得して防御力を補強する。",
		"color": "#81D4FA"
	},
	"永久凍土": {
		"title": "永久凍土 (Permafrost)",
		"desc": "氷属性の中間進化効果。自陣の氷マスの耐久値がターン経過で減少しなくなる。",
		"color": "#80D8FF"
	},
	"寒気": {
		"title": "寒気 (Chill)",
		"desc": "氷属性の最終進化効果。盤面の自陣氷マス1個につき、相手の攻撃力を3%低下させる（最大30%低下）。",
		"color": "#80DEEA"
	},
	"氷原": {
		"title": "氷原 (Ice Field)",
		"desc": "氷属性の最終進化効果。ターン終了時、自陣の氷マスが隣接する空きマス1つへ広がる（盤面最大10個まで）。",
		"color": "#B2EBF2"
	},
	"飛び火": {
		"title": "飛び火 (Spark Jump)",
		"desc": "火属性の中間進化効果。火が燃え尽きて消える時、周囲48マス（7×7）のランダムな1マスを炎上させ、そのマスの駒を消去する。",
		"color": "#FF7043"
	},
	"大飛び火": {
		"title": "大飛び火 (Great Spark Jump)",
		"desc": "火属性の最終進化効果。火が燃え尽きる時、周囲48マスの中から2マス同時に飛び火して炎上させる。",
		"color": "#FF5722"
	},
	"火種": {
		"title": "火種 (Ember Seed)",
		"desc": "火属性の最終進化効果。飛び火によって発生した火の寿命が1ターン延長される。",
		"color": "#FF8A65"
	},
	"焼き払い": {
		"title": "焼き払い (Scorched Earth)",
		"desc": "火属性の最終進化効果。延焼先が相手の妨害マス（毒・暗雲）や相手の石だった場合、それを焼き払って自陣の火マスに置き換える。",
		"color": "#FF3D00"
	},
	"株分け": {
		"title": "株分け (Root Cutting)",
		"desc": "木属性の最終進化効果。自陣の植物が大木に成長した瞬間、ランダムな空きマスに新たな苗木を1本植える。",
		"color": "#66BB6A"
	},
	"深い根": {
		"title": "深い根 (Deep Roots)",
		"desc": "木属性の最終進化効果。自陣の植物が火や効果で壊される時、消滅せずに1段階だけ小さくなる（苗木は消滅）。",
		"color": "#81C784"
	},
	"森の加護": {
		"title": "森の加護 (Forest Blessing)",
		"desc": "木属性の最終進化効果。自陣の植物1本につき受けるダメージを5%軽減する（最大40%軽減）。",
		"color": "#66BB6A"
	},
	"毒棘": {
		"title": "毒棘 (Poison Thorns)",
		"desc": "木属性の最終進化効果。ターン終了時、ランダムな自陣の植物1本の周囲1マスに自陣の毒マスを配置する。",
		"color": "#AB47BC"
	},
	"濃縮": {
		"title": "濃縮 (Concentration)",
		"desc": "毒属性の中間進化効果。毒マスに1〜3の段階を持たせ、重ね掛けで強化する。毒ダメージは段階に比例する。",
		"color": "#AB47BC"
	},
	"破裂": {
		"title": "破裂 (Rupture)",
		"desc": "毒属性の最終進化効果。段階3の自陣毒マスがマッチで消去されると、周囲4マスに段階1の自陣毒マスを撒き散らす。",
		"color": "#CE93D8"
	},
	"熟毒": {
		"title": "熟毒 (Matured Poison)",
		"desc": "毒属性の最終進化効果。自陣の毒マスがターン終了時にダメージを与えるたびに、その毒マスの段階が1上がる（最大3）。",
		"color": "#8E24AA"
	},
	"伝染": {
		"title": "伝染 (Contagion)",
		"desc": "毒属性の中間進化効果。自陣の毒マスが毎ターン隣接空きマス1つへ広がり（上限12）、相手妨害マスを塗り替える。",
		"color": "#9C27B0"
	},
	"蝕み": {
		"title": "蝕み (Blight)",
		"desc": "毒属性の最終進化効果。伝染で毒マスが増えるたび、相手に蝕みスタックを付与する（最大5）。1スタックにつき相手の被毒ダメージ+10%。",
		"color": "#7B1FA2"
	},
	"弱体": {
		"title": "弱体 (Weaken)",
		"desc": "毒属性の中間進化効果。盤面の自陣毒マス1個につき、相手の攻撃力を3%低下させる（最大30%低下）。",
		"color": "#BA68C8"
	},
	"麻痺毒": {
		"title": "麻痺毒 (Paralytic Poison)",
		"desc": "毒属性の最終進化効果。相手が行動する時、自陣毒マス1個につき3%の確率で行動を麻痺させて停止させる（最大30%）。",
		"color": "#E1BEE7"
	},
	"毒の種": {
		"title": "毒の種 (Poison Seed)",
		"desc": "毒属性の最終進化効果。自陣毒マス上の駒がマッチ消去されると、味方なら毒スキル駒、敵なら毒マスを生成する（ターン最大1回）。",
		"color": "#80CBC4"
	},
	"城壁": {
		"title": "城壁 (Rampart)",
		"desc": "地属性の最終進化効果。自陣の石1個につき受けるダメージを5%軽減する（最大40%軽減）。",
		"color": "#BCAAA4"
	},
	"飛礫": {
		"title": "飛礫 (Gravel)",
		"desc": "地属性の最終進化効果。自陣の石が壊れると破片が飛び散り、ランダムな周囲2マスに耐久値1の自陣の小石を置く。",
		"color": "#A1887F"
	},
	"黄金化": {
		"title": "黄金化 (Aurification)",
		"desc": "地属性の最終進化効果。ターン終了時、ランダムな自陣の石1個を自陣の黄金像に変える。",
		"color": "#FFD54F"
	},
	"地割れ": {
		"title": "地割れ (Fissure)",
		"desc": "地属性の最終進化効果。自陣の石が壊れると、隣接する相手の妨害マス（石・氷・毒）も一緒に破壊する。",
		"color": "#8D6E63"
	},
	"染色": {
		"title": "染色 (Dye)",
		"desc": "光属性の最終進化効果。盤面のランダムな駒3個を、盤面で最も多い色の駒に変える。",
		"color": "#FFF59D"
	},
	"後光": {
		"title": "後光 (Halo)",
		"desc": "光属性の最終進化効果。聖域が出ているターンの間、相手の妨害マスが新しく置かれなくなる。",
		"color": "#FFF9C4"
	},
	"毒": {
		"title": "毒 (Poison)",
		"desc": "盤面に相手の毒マスが存在する時、ターン終了時に毒ダメージを受ける状態異常。",
		"color": "#AB47BC"
	},
	"免疫": {
		"title": "免疫 (Immunity)",
		"desc": "自陣の毒マス1個につき、自身が受ける毒ダメージを5%軽減する（最大40%軽減）。",
		"color": "#80CBC4"
	},
	"火傷": {
		"title": "火傷 (Burn)",
		"desc": "盤面に相手の火マスが存在する時、ターン終了時に火傷ダメージを受ける状態異常。",
		"color": "#FF5722"
	},
	"氷柱": {
		"title": "氷柱 (Icicle)",
		"desc": "氷属性の進化効果。盤面上部から鋭利な氷の刃が降り注ぎ、敵を刺し貫いて大ダメージを与える。",
		"color": "#B2EBF2"
	},
	"帯電": {
		"title": "帯電 (Charged)",
		"desc": "コインや駒が電気を帯びた状態。マッチまたはスワップした際、蓄電された電流が弾けて敵に追加ダメージを与える。",
		"color": "#FFF59D"
	},
	"聖域": {
		"title": "聖域 (Sanctuary)",
		"desc": "光属性の神聖効果。光スキル発動ターン、自身の被ダメージを25%軽減する。",
		"color": "#FFF9C4"
	},
	"光の護符": {
		"title": "光の護符 (Holy Talisman)",
		"desc": "光属性の加護アイテム。プレイヤーが不利な状態異常を受けるのを防ぎ、HPとシールドを回復する。",
		"color": "#FFFDE7"
	},
	"浸透": {
		"title": "浸透 (Permeation)",
		"desc": "水マスや毒マスが、ターン終了時に隣接する通常のマスへとじわじわと染み出して自然拡大していく現象。",
		"color": "#80DEEA"
	},
	"巻き込み": {
		"title": "巻き込み (Vortex / Sweep)",
		"desc": "風の竜巻や水の奔流が、通過した軌道や隣接する周囲の駒を一緒に吸い込んで連鎖消去する挙動。",
		"color": "#A7FFEB"
	},
	"フィーバータイム": {
		"title": "フィーバータイム (Fever Time)",
		"desc": "フィーバーゲージが最大（7000）に達した際に突入するボーナスタイム。スコアが数倍になり、ダンサーが乱入して盤面が華やかになる。",
		"color": "#FF4081"
	},
	"連鎖": {
		"title": "連鎖 (Chain / Cascade)",
		"desc": "1手の中で駒が消えた後、上から落下した駒がさらに揃って連続して消去されること。連鎖数に応じてスコアや効果が強化される。",
		"color": "#FFD700"
	},
	"重力崩壊": {
		"title": "重力崩壊 (Gravitational Collapse)",
		"desc": "闇属性の最終進化効果。斜めライン上のマスをブラックホールへ向けて崩壊させ、壊滅的なダメージを与える。",
		"color": "#7E57C2"
	},
	"解放": {
		"title": "解放 (Discharge / Burst)",
		"desc": "雷属性の最終進化効果。蓄積したすべての電力を一瞬で解き放ち、超大出力の電撃を敵へ叩き込む。",
		"color": "#FFCA28"
	},
	"火属性": {
		"title": "火属性 (Fire Element)",
		"desc": "元素・破壊系統の属性。弱点（有利）: 風属性・毒属性に1.5倍ダメージ。耐性（不利）: 水属性に0.5倍ダメージ。盤面に炎上・延焼する【火マス】を生成し、毎ターン継続ダメージを与える。水属性と接触すると【蒸気爆発】を起こし、木属性に接触すると【大延焼】して激しく燃え広がる。",
		"color": "#FF5722"
	},
	"炎属性": {
		"title": "炎属性 / 火属性 (Fire Element)",
		"desc": "元素・破壊系統の火属性と同じ属性。弱点（有利）: 風属性・毒属性に1.5倍ダメージ。耐性（不利）: 水属性に0.5倍ダメージ。盤面を炎上させ、大爆発や延焼、誘爆などの破壊的な瞬間火力を誇る。",
		"color": "#FF5722"
	},
	"水属性": {
		"title": "水属性 (Water Element)",
		"desc": "自然・生命系統の属性。弱点（有利）: 火属性に1.5倍ダメージ。耐性（不利）: 雷属性・毒属性に0.5倍ダメージ。盤面に【水マス】を展開し、そのマス上の駒を消去して落下を誘発。進化選択により、ターン終了時のHP回復・シールド獲得・水マス数に応じた【水サージ】追撃へ分化する。火属性を消火相殺し、木属性の苗木を吸水急成長させ、雷属性の落雷を全体へ【感電拡散】させる。",
		"color": "#29B6F6"
	},
	"木属性": {
		"title": "木属性 (Wood / Nature Element)",
		"desc": "自然・生命系統の属性。盤面に【苗木】を植え、水マスを吸水して3x3の巨大な【大木】へと進化させる。毎ターンのHP自動回復や【森の加護】による被ダメージ軽減、果実収穫スコアをもたらす。火属性を受けると激しく【大延焼】し、雷属性に対しては高い耐久力を持つ。",
		"color": "#66BB6A"
	},
	"雷属性": {
		"title": "雷属性 (Thunder Element)",
		"desc": "元素・破壊系統の属性。弱点（有利）: 水属性に1.5倍ダメージ。耐性（不利）: 風属性に0.5倍ダメージ。強力な【落雷】を放ち、水マスを経由して盤面全体へ【感電拡散】する。氷マスや石マスに直撃すると【シャッター】粉砕を引き起こし、周囲3x3の駒を一掃して敵に壊滅的大ダメージを与える。",
		"color": "#FFD600"
	},
	"風属性": {
		"title": "風属性 (Wind Element)",
		"desc": "自然・生命系統の属性。弱点（有利）: 雷属性に1.5倍ダメージ。耐性（不利）: 火属性・毒属性に0.5倍ダメージ。縦列を一掃する竜巻やつむじ風を巻き起こし、駒を上空へ巻き上げ落下連鎖を誘発する。また敵の妨害マス配置を吹き飛ばして防ぐ【風の守り】を展開する。",
		"color": "#26A69A"
	},
	"地属性": {
		"title": "地属性 (Earth / Stone Element)",
		"desc": "元素・破壊系統の属性。盤面に高耐久の【石マス】や【輝石】を展開し、【城壁】による防御力向上や【飛礫】による反撃を行う。落雷を受けると【シャッター】粉砕して周囲を一掃し、究極進化では超硬度の【金剛石】や【黄金像】へと変異させる。",
		"color": "#8D6E63"
	},
	"氷属性": {
		"title": "氷属性 (Ice Element)",
		"desc": "自然・生命系統の属性。盤面に【氷マス】を展開し、敵の行動や妨害の進行を完全凍結・阻止する。【永久凍土】による耐久固定や【寒気】による相手攻撃力低下（デバフ）を操る。火属性を受けると【融解】して水マス化し、雷属性を受けると【シャッター】粉砕して大爆発する。",
		"color": "#4DD0E1"
	},
	"毒属性": {
		"title": "毒属性 (Poison Element)",
		"desc": "神秘・冥術系統の属性。弱点（有利）: 水属性・風属性に1.5倍ダメージ。耐性（不利）: 火属性・光属性に0.5倍ダメージ。盤面に【毒マス】を展開して毎ターン継続毒ダメージを与える。【伝染】による自己拡大、【濃縮】による毒レベル強化、相手の攻撃力を下げる【弱体】や【麻痺毒】を操る。水マス上では拡散速度が2倍になる。",
		"color": "#AB47BC"
	},
	"光属性": {
		"title": "光属性 (Light / Holy Element)",
		"desc": "神秘・冥術系統の属性。弱点（有利）: 闇属性・毒属性に1.5倍ダメージ。神聖な【黄金像（聖像）】を盤面に召喚し、マッチや粉砕時に大量コイン(+500G)獲得や聖光大追撃を発動する。敵の毒・火・暗雲などの妨害マスを【浄化】して一掃し、【聖域】による被ダメ軽減や【聖像共振】による一斉光線照射など、神聖な加護と殲滅力に特化する。",
		"color": "#FFEE58"
	},
	"闇属性": {
		"title": "闇属性 (Dark Element)",
		"desc": "神秘・冥術系統の属性。弱点（有利）: 光属性に1.5倍ダメージ。周囲の駒を吸い込み消滅させる【ブラックホール】や極大重力場【特異点】を発生させ、壊滅的な質量爆縮ダメージを与える。また自陣を守る【影護】や、斜め全ラインを崩壊させる【重力崩壊】などの暗黒魔術を操る。",
		"color": "#BA68C8"
	},
	"無属性": {
		"title": "無属性 (Neutral Element)",
		"desc": "特定の属性を持たないニュートラルな属性。弱点や耐性の影響を受けず、常に等倍（1.0倍）の安定したダメージを与える。物理剣撃や通常マッチ消去などに該当する。",
		"color": "#ECEFF1"
	},
	"聖属性": {
		"title": "聖属性 / 光属性 (Holy Element)",
		"desc": "光属性と同じ神聖なる属性。闇属性や毒属性に対して強力な有利（弱点1.5倍）を持ち、妨害マスを浄化して聖域の加護をもたらす。",
		"color": "#FFEE58"
	},
	"魔属性": {
		"title": "魔属性 / 闇属性 (Dark Magic Element)",
		"desc": "闇属性と同じ暗黒の魔術属性。光属性に対して有利（弱点1.5倍）を持ち、重力ブラックホールや呪詛、影護の魔力を操る。",
		"color": "#BA68C8"
	},
	"属性相性": {
		"title": "属性相性 (Elemental Compatibility)",
		"desc": "攻撃側と防御側の属性の組み合わせによるダメージ倍率補正。有利属性への攻撃は【弱点】となりダメージ1.5倍、不利属性への攻撃は【耐性】となりダメージ0.5倍（半減）となる。戦況や敵の属性を見極めたスキル選択が攻略の鍵となる。",
		"color": "#FFD54F"
	},
	"属性シナジー": {
		"title": "属性シナジー / 属性ケミストリー (Elemental Synergy)",
		"desc": "盤面上で異なる属性のマスやスキルが接触・複合した際に発生する強力な相乗反応。火×水（蒸気爆発）、雷×水（感電拡散）、雷×氷/石（シャッター粉砕）、火×木（大延焼）、水×木（吸水急成長）、水×毒（毒拡散加速）、火×氷（融解）など多彩な効果がある。",
		"color": "#64FFDA"
	},
	"属性ケミストリー": {
		"title": "属性ケミストリー (Elemental Chemistry)",
		"desc": "異なる2つの属性が衝突・融合した際に発動する特殊連鎖反応のこと。単一属性では成し得ない、盤面一掃や相殺浄化、威力跳ね上がりなどの劇的な戦況変化をもたらす。",
		"color": "#64FFDA"
	},
	"属性カテゴリー": {
		"title": "属性カテゴリー (Element Category)",
		"desc": "全10属性を【自然・生命】【元素・破壊】【神秘・冥術】の3つの系統に大別した分類。初手のレリック選択で解放した系統のスキルのみがゲーム中に登場・習得可能となる。",
		"color": "#FFCA28"
	},
	"自然・生命": {
		"title": "自然・生命系統 (Nature Category)",
		"desc": "水属性・氷属性・木属性・風属性の4属性からなる系統カテゴリー。HP回復、シールド獲得、凍結封鎖、妨害マスの浄化など、持続的な生存力と盤面コントロールに優れる。",
		"color": "#00E676"
	},
	"元素・破壊": {
		"title": "元素・破壊系統 (Force Category)",
		"desc": "火属性・雷属性・地属性の3属性からなる系統カテゴリー。大爆発の火炎、連鎖感電の落雷、岩盤粉砕のシャッターなど、圧倒的な瞬間火力と豪快な盤面破壊力に特化する。",
		"color": "#FF3D00"
	},
	"神秘・冥術": {
		"title": "神秘・冥術系統 (Mystic Category)",
		"desc": "毒属性・光属性・闇属性の3属性からなる系統カテゴリー。猛毒の侵食とステータス弱体、聖像や聖域による妨害浄化、ブラックホールの重力吸引と混沌崩壊を操る。",
		"color": "#E040FB"
	},
	"弱点": {
		"title": "弱点 (Weakness / 属性有利)",
		"desc": "敵の苦手とする属性で攻撃した際に成立する属性有利効果。与える最終ダメージが1.5倍に増加し、ダメージ表示に「WEAKNESS!」と強調される。",
		"color": "#FF5252"
	},
	"耐性": {
		"title": "耐性 (Resistance / 属性不利)",
		"desc": "敵が得意とする属性で攻撃してしまった際の属性不利効果。与える最終ダメージが0.5倍（50%減少）に半減され、ダメージ表示に「RESIST!」と表示される。",
		"color": "#78909C"
	},
	"蒸気爆発": {
		"title": "蒸気爆発 (Steam Detonation)",
		"desc": "水属性と火属性が衝突した際に発生する属性ケミストリー。水マスと火マスが互いを相殺消火しながら高圧蒸気を噴出させ、周囲のマスを一掃して敵に蒸気追撃ダメージを与える。",
		"color": "#80DEEA"
	},
	"融解": {
		"title": "融解 (Melting)",
		"desc": "氷マスが火属性の熱気に触れた際に発生する反応。凍りついた氷マスが瞬時に解けて【水マス】へと変貌し、水属性の各種効果（HP回復や水サージ）として再利用可能になる。",
		"color": "#4DD0E1"
	},
	"感電拡散": {
		"title": "感電拡散 (Shock Propagation)",
		"desc": "水マスの上に雷属性の落雷が落ちた際に発生する反応。水面を伝って盤面上のすべての水マスへ高圧電流が瞬時に走り、広範囲の駒を一掃しながら敵へ大感電ダメージを与える。",
		"color": "#FFEB3B"
	},
	"大延焼": {
		"title": "大延焼 (Great Wildfire)",
		"desc": "火マスや火属性攻撃が木属性の苗木や大木に引火した際に発生する激しい燃焼反応。植物が薪となって広範囲の周囲マスを一瞬で焼き払い、敵へ強大な炎上追加ダメージを与える。",
		"color": "#FF3D00"
	},
	"吸水": {
		"title": "吸水 (Water Absorption)",
		"desc": "木属性の苗木や植物が隣接する水マスの水分を吸い上げる現象。水マスを消費して一回り大きな若木や3x3の巨大大木へと急成長・進化を遂げる。",
		"color": "#81C784"
	},
	"影護マス": {
		"title": "影護マス (Shadow Veil Tile)",
		"desc": "闇属性の加護マス。敵の妨害マス（呪い・毒）を安全に上書きし、マッチ消去時に敵へ闇属性ダメージを与えながらプレイヤーのHPを吸収回復する。",
		"color": "#82B1FF"
	},
	"影護": {
		"title": "影護 (Shadow Veil)",
		"desc": "闇属性の加護効果。敵の妨害や反動ダメージを受けず、マッチ消去時に敵へ闇ダメージを与えつつプレイヤーのHPを吸収回復する。",
		"color": "#82B1FF"
	},
	"風の守り": {
		"title": "風の守り (Wind Ward)",
		"desc": "風属性の防護効果。上昇気流や旋風によって縦列を護り、相手の妨害マス（毒・火・暗雲・岩石）の侵入や落下配置を完全に遮断・無効化する。",
		"color": "#64FFDA"
	},
	"暴風圏": {
		"title": "暴風圏 (Storm Field)",
		"desc": "風属性の進化効果。強烈な暴風が盤面全体を包み込み、落下する駒の連鎖確率と風スキル威力を大幅に引き上げる。",
		"color": "#26A69A"
	},
	"破片": {
		"title": "破片 (Shrapnel)",
		"desc": "火属性の進化スキル（ブレイズブラストの破片等）や石マスの破砕時に四方へ飛び散る飛び石や爆風の破片。着弾地点の駒を消去して更なる連鎖落下を誘発する。",
		"color": "#FF9800"
	},
	"榴弾": {
		"title": "榴弾 (High-Explosive Shell)",
		"desc": "火属性の最終進化効果。爆発スキル起爆時に周囲広域へ高威力の榴弾破片を散布し、隣接する敵駒や障害物を一撃で粉砕消滅させる。",
		"color": "#FF5722"
	},
	"十字炎": {
		"title": "十字炎 (Cross Flame)",
		"desc": "火属性の最終進化効果。爆発の炎が上下左右の十字方向に盤端まで突き抜け、直線上の駒を一網打尽にする。",
		"color": "#FF3D00"
	},
	"浄化": {
		"title": "浄化 (Purification)",
		"desc": "盤面に存在する毒マス、炎上マス、凍結マス、暗雲などの敵による妨害マスをすべて取り除き、クリーンな通常マスへ戻す神聖な効果。光属性スキルや水マスで発動可能。",
		"color": "#FFF59D"
	},
	"聖像": {
		"title": "聖像 (Sacred Statue)",
		"desc": "光属性の神聖な彫像。盤面に召喚され、自由にスワップ移動可能。マッチ消去時に大量のコインとスコアを獲得し、周囲の敵妨害マスを消滅・浄化する。",
		"color": "#FFEE58"
	},
	"蓄電": {
		"title": "蓄電 (Charge Accumulation)",
		"desc": "雷属性のチャージボムや特殊駒が隣接消去によって電力を溜め込むこと。蓄電カウントが完了すると超広範囲へ特大放電爆発を放つ。",
		"color": "#FFD54F"
	},
	"腐食": {
		"title": "腐食 (Corrosion)",
		"desc": "毒属性の浸食効果。敵のアーマーやシールドを溶解して継続的な被ダメージを増加させ、防御力を大きく削ぎ落とす。",
		"color": "#8E24AA"
	},
	"火砕流": {
		"title": "火砕流 (Pyroclastic Flow)",
		"desc": "地属性の岩石と火属性の超高熱が合わさることで発生する過熱瓦礫の津波。ライン上の駒を一瞬で焼き払い、敵へ超強力な火・地複合ダメージを与える。",
		"color": "#FF6D00"
	}
}

static var _sorted_keys: Array = []
static var _dynamic_terms: Dictionary = {}

## レリック名・スキル名など、後から登録される用語を追加する。
static func register_term(term_key: String, title: String, desc: String, color: String = "#4FC3F7") -> void:
	var key = term_key.strip_edges()
	if key.is_empty():
		return
	_dynamic_terms[key] = {
		"title": title if not title.is_empty() else key,
		"desc": desc,
		"color": color
	}
	_sorted_keys.clear()

## レリック図鑑の全名称をホバー解説へ登録する。
static func register_relic_terms() -> void:
	for relic_id in RelicDatabase.RELICS:
		var relic: Dictionary = RelicDatabase.RELICS[relic_id]
		var relic_name: String = str(relic.get("name", ""))
		if relic_name.is_empty():
			continue
		var color: String = "#B0BEC5"
		match str(relic.get("rarity", "common")):
			"legendary": color = "#FFD700"
			"epic": color = "#E040FB"
			"rare": color = "#29B6F6"
			"uncommon": color = "#4CAF50"
			"cursed": color = "#FF1744"
		var desc: String = RelicDatabase.get_description(str(relic_id), 1)
		if desc.is_empty():
			desc = str(relic.get("description", ""))
		register_term(relic_name, relic_name, desc, color)

static func reload_keys() -> void:
	_sorted_keys.clear()
	_get_sorted_keys()

static func _get_sorted_keys() -> Array:
	if _sorted_keys.is_empty():
		var key_map: Dictionary = {}
		for k in GLOSSARY.keys():
			key_map[k] = true
		for k in _dynamic_terms.keys():
			key_map[k] = true
		var keys = key_map.keys()
		keys.sort_custom(func(a, b): return a.length() > b.length())
		_sorted_keys = keys
	return _sorted_keys

## 指定された語句の解説データを取得
static func get_term(term_key: String) -> Dictionary:
	if GLOSSARY.has(term_key):
		return GLOSSARY[term_key]
	return _dynamic_terms.get(term_key, {})

## 説明文内の固有名詞をWikipedia風に自動強調表示（アンダーライン＋リンク色＋ホバー可能メタタグ付与）
## 既に [url]...[/url] になっている箇所は再処理しない（二重リンク防止）。
static func format_text(raw_text: String) -> String:
	if raw_text.is_empty():
		return ""

	var sorted_keys = _get_sorted_keys()
	var url_regex = RegEx.new()
	url_regex.compile("(?s)\\[url=[^\\]]*\\].*?\\[/url\\]")

	var result = ""
	var last_pos = 0
	for m in url_regex.search_all(raw_text):
		var segment = raw_text.substr(last_pos, m.get_start() - last_pos)
		result += _format_segment_with_tags(segment, sorted_keys)
		result += m.get_string()
		last_pos = m.get_end()
	result += _format_segment_with_tags(raw_text.substr(last_pos), sorted_keys)
	return result

static func _format_segment_with_tags(text: String, sorted_keys: Array) -> String:
	var tag_regex = RegEx.new()
	tag_regex.compile("\\[[^\\]]+\\]")
	var result = ""
	var last_pos = 0
	for m in tag_regex.search_all(text):
		var tag_start = m.get_start()
		if tag_start > last_pos:
			result += _replace_terms_in_segment(text.substr(last_pos, tag_start - last_pos), sorted_keys)
		result += m.get_string()
		last_pos = m.get_end()
	if last_pos < text.length():
		result += _replace_terms_in_segment(text.substr(last_pos), sorted_keys)
	return result

static func _replace_terms_in_segment(text: String, sorted_keys: Array) -> String:
	var placeholders: Dictionary = {}
	var ph_idx: int = 0

	for key in sorted_keys:
		if key in text:
			var ph = "__GLOSSARY_PH_%d__" % ph_idx
			var t_data = get_term(key)
			var col = t_data.get("color", "#4FC3F7")
			# Wikipedia風リンク表示: [url=KEY][color=COL][u]KEY[/u][/color][/url]
			placeholders[ph] = "[url=%s][color=%s][u]%s[/u][/color][/url]" % [key, col, key]
			text = text.replace(key, ph)
			ph_idx += 1

	for ph in placeholders:
		text = text.replace(ph, placeholders[ph])

	return text

## RichTextLabel をGlossaryホバー解説にバインド
static func bind_rich_text_label(rtl: RichTextLabel) -> void:
	if rtl == null:
		return
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	if not rtl.meta_hover_started.is_connected(_on_meta_hover_started.bind(rtl)):
		rtl.meta_hover_started.connect(_on_meta_hover_started.bind(rtl))
	if not rtl.meta_hover_ended.is_connected(_on_meta_hover_ended.bind(rtl)):
		rtl.meta_hover_ended.connect(_on_meta_hover_ended.bind(rtl))

static func _on_meta_hover_started(meta: Variant, rtl: RichTextLabel) -> void:
	var term_key = str(meta)
	if get_term(term_key).is_empty():
		return
	var rui = _find_relic_ui_manager(rtl)
	if rui and rui.has_method("show_glossary_tooltip"):
		var m_pos = rtl.get_global_mouse_position()
		rui.show_glossary_tooltip(term_key, m_pos)

static func _on_meta_hover_ended(_meta: Variant, rtl: RichTextLabel) -> void:
	var rui = _find_relic_ui_manager(rtl)
	if rui and rui.has_method("hide_glossary_tooltip"):
		rui.hide_glossary_tooltip()

static func _find_relic_ui_manager(node: Node) -> Node:
	if Engine.has_singleton("RelicUIManager"):
		return Engine.get_singleton("RelicUIManager")
	var tree: SceneTree = null
	if node != null and is_instance_valid(node):
		tree = node.get_tree()
	if tree == null and Engine.get_main_loop() is SceneTree:
		tree = Engine.get_main_loop() as SceneTree
	if tree and tree.get_root():
		var rui = tree.get_root().find_child("RelicUIManager", true, false)
		if rui: return rui
	return null
