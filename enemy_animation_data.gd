class_name EnemyAnimationData

# 全24体の敵キャラクターのスプライトシート定義（通常攻撃、スキル、待機、被弾）
const SHEETS: Dictionary = {
	"enemy1": {
		"attack": {
			"path": "res://Texture/enemy/grimreaper-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 0.90
		},
		"skill": {
			"path": "res://Texture/enemy/grimreaper-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 0.90
		},
		"idle": {
			"path": "res://Texture/enemy/grimreaper-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 0.90
		},
		"damaged": {
			"path": "res://Texture/enemy/grimreaper-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 0.90
		},
	},
	"enemy2": {
		"attack": {
			"path": "res://Texture/enemy/cursedmummy-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.15
		},
		"skill": {
			"path": "res://Texture/enemy/cursedmummy-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.15
		},
		"idle": {
			"path": "res://Texture/enemy/cursedmummy-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.15
		},
		"damaged": {
			"path": "res://Texture/enemy/cursedmummy-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.15
		},
	},
	"enemy3": {
		"attack": {
			"path": "res://Texture/enemy/poisontoad-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.45
		},
		"skill": {
			"path": "res://Texture/enemy/poisontoad-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.45
		},
		"idle": {
			"path": "res://Texture/enemy/poisontoad-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.45
		},
		"damaged": {
			"path": "res://Texture/enemy/poisontoad-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.45
		},
	},
	"enemy4": {
		"attack": {
			"path": "res://Texture/enemy/magmagolem-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.20
		},
		"skill": {
			"path": "res://Texture/enemy/magmagolem-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.20
		},
		"idle": {
			"path": "res://Texture/enemy/magmagolem-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.20
		},
		"damaged": {
			"path": "res://Texture/enemy/magmagolem-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.20
		},
	},
	"enemy5": {
		"attack": {
			"path": "res://Texture/enemy/deepsahuagin-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.42
		},
		"skill": {
			"path": "res://Texture/enemy/deepsahuagin-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.58
		},
		"idle": {
			"path": "res://Texture/enemy/deepsahuagin-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.09
		},
		"damaged": {
			"path": "res://Texture/enemy/deepsahuagin-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.31
		},
	},
	"enemy6": {
		"attack": {
			"path": "res://Texture/enemy/Fungus Lord-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.31
		},
		"skill": {
			"path": "res://Texture/enemy/Fungus Lord-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.31
		},
		"idle": {
			"path": "res://Texture/enemy/Fungus Lord-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.31
		},
		"damaged": {
			"path": "res://Texture/enemy/Fungus Lord-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.31
		},
	},
	"enemy7": {
		"attack": {
			"path": "res://Texture/enemy/skeltonknight-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.05
		},
		"skill": {
			"path": "res://Texture/enemy/skeltonknight-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.05
		},
		"idle": {
			"path": "res://Texture/enemy/skeltonknight-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.05
		},
		"damaged": {
			"path": "res://Texture/enemy/skeltonknight-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.05
		},
	},
	"enemy8": {
		"attack": {
			"path": "res://Texture/enemy/killerhornet-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.11
		},
		"skill": {
			"path": "res://Texture/enemy/killerhornet-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.11
		},
		"idle": {
			"path": "res://Texture/enemy/killerhornet-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.11
		},
		"damaged": {
			"path": "res://Texture/enemy/killerhornet-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.11
		},
	},
	"enemy9": {
		"attack": {
			"path": "res://Texture/enemy/Crimson Warlock-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.03
		},
		"skill": {
			"path": "res://Texture/enemy/Crimson Warlock-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.03
		},
		"idle": {
			"path": "res://Texture/enemy/Crimson Warlock-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.03
		},
		"damaged": {
			"path": "res://Texture/enemy/Crimson Warlock-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.03
		},
	},
	"enemy10": {
		"attack": {
			"path": "res://Texture/enemy/jewelarachne-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.31
		},
		"skill": {
			"path": "res://Texture/enemy/jewelarachne-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.31
		},
		"idle": {
			"path": "res://Texture/enemy/jewelarachne-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.31
		},
		"damaged": {
			"path": "res://Texture/enemy/jewelarachne-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.31
		},
	},
	"enemy11": {
		"attack": {
			"path": "res://Texture/enemy/granddragon-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.14
		},
		"skill": {
			"path": "res://Texture/enemy/granddragon-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.14
		},
		"idle": {
			"path": "res://Texture/enemy/granddragon-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.14
		},
		"damaged": {
			"path": "res://Texture/enemy/granddragon-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.14
		},
	},
	"enemy12": {
		"attack": {
			"path": "res://Texture/enemy/werewolf-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.33
		},
		"skill": {
			"path": "res://Texture/enemy/werewolf-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.33
		},
		"idle": {
			"path": "res://Texture/enemy/werewolf-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.33
		},
		"damaged": {
			"path": "res://Texture/enemy/werewolf-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.33
		},
	},
	"enemy13": {
		"attack": {
			"path": "res://Texture/enemy/darkpixie-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.25
		},
		"skill": {
			"path": "res://Texture/enemy/darkpixie-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.25
		},
		"idle": {
			"path": "res://Texture/enemy/darkpixie-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.25
		},
		"damaged": {
			"path": "res://Texture/enemy/darkpixie-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.25
		},
	},
	"enemy14": {
		"attack": {
			"path": "res://Texture/enemy/gargoyle-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.32
		},
		"skill": {
			"path": "res://Texture/enemy/gargoyle-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.32
		},
		"idle": {
			"path": "res://Texture/enemy/gargoyle-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.32
		},
		"damaged": {
			"path": "res://Texture/enemy/gargoyle-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.32
		},
	},
	"enemy15": {
		"attack": {
			"path": "res://Texture/enemy/rainbowserpent-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.09
		},
		"skill": {
			"path": "res://Texture/enemy/rainbowserpent-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.09
		},
		"idle": {
			"path": "res://Texture/enemy/rainbowserpent-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.09
		},
		"damaged": {
			"path": "res://Texture/enemy/rainbowserpent-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.09
		},
	},
	"enemy16": {
		"attack": {
			"path": "res://Texture/enemy/abysslizard-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.32
		},
		"skill": {
			"path": "res://Texture/enemy/abysslizard-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.32
		},
		"idle": {
			"path": "res://Texture/enemy/abysslizard-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.32
		},
		"damaged": {
			"path": "res://Texture/enemy/abysslizard-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.32
		},
	},
	"enemy17": {
		"attack": {
			"path": "res://Texture/enemy/frostdragon-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 2.19
		},
		"skill": {
			"path": "res://Texture/enemy/frostdragon-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 2.16
		},
		"idle": {
			"path": "res://Texture/enemy/frostdragon-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.14
		},
		"damaged": {
			"path": "res://Texture/enemy/frostdragon-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.86
		},
	},
	"enemy18": {
		"attack": {
			"path": "res://Texture/enemy/demonius-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.40
		},
		"skill": {
			"path": "res://Texture/enemy/demonius-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.40
		},
		"idle": {
			"path": "res://Texture/enemy/demonius-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.40
		},
		"damaged": {
			"path": "res://Texture/enemy/demonius-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.40
		},
	},
	"enemy19": {
		"attack": {
			"path": "res://Texture/enemy/octopus-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.33
		},
		"skill": {
			"path": "res://Texture/enemy/octopus-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.33
		},
		"idle": {
			"path": "res://Texture/enemy/octopus-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.33
		},
		"damaged": {
			"path": "res://Texture/enemy/octopus-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.33
		},
	},
	"enemy20": {
		"attack": {
			"path": "res://Texture/enemy/sasori-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.31
		},
		"skill": {
			"path": "res://Texture/enemy/sasori-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.31
		},
		"idle": {
			"path": "res://Texture/enemy/sasori-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.31
		},
		"damaged": {
			"path": "res://Texture/enemy/sasori-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.31
		},
	},
	"enemy21": {
		"attack": {
			"path": "res://Texture/enemy/snake-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.28
		},
		"skill": {
			"path": "res://Texture/enemy/snake-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.13
		},
		"idle": {
			"path": "res://Texture/enemy/snake-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 0.95
		},
		"damaged": {
			"path": "res://Texture/enemy/snake-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 0.97
		},
	},
	"enemy22": {
		"attack": {
			"path": "res://Texture/enemy/snake-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.28
		},
		"skill": {
			"path": "res://Texture/enemy/snake-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.13
		},
		"idle": {
			"path": "res://Texture/enemy/snake-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 0.95
		},
		"damaged": {
			"path": "res://Texture/enemy/snake-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 0.97
		},
	},
	"enemy23": {
		"attack": {
			"path": "res://Texture/enemy/treeman-iso_custom_attack1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.29
		},
		"skill": {
			"path": "res://Texture/enemy/treeman-iso_custom_skill_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.29
		},
		"idle": {
			"path": "res://Texture/enemy/treeman-iso_custom_idle1_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": false,
			"scale_mult": 1.29
		},
		"damaged": {
			"path": "res://Texture/enemy/treeman-iso_custom_damaged_down.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.29
		},
	},
	"enemy24": { # 冥狼フェンリル
		"attack": {
			"path": "res://Texture/enemy/wolf-attack.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.05
		},
		"skill": {
			"path": "res://Texture/enemy/wolf-skill.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.88
		},
		"idle": {
			"path": "res://Texture/enemy/wolf-idle1.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.51
		}
	}
}