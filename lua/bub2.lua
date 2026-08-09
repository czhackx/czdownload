-- ████╗   ██╗   ██████╗   ██████╗  ██████╗ ██╗  ██╗ ██████╗ ██╗     █████╗  ██████╗  ██████╗ ██████╗    ██╗ --
-- ██╔██╗  ██║ ██╔═════╝   ██╔══██╗ ██╔═══╝ ██║  ██║ ██╔═══╝ ██║    ██╔══██╗ ██╔══██╗ ██╔═══╝ ██╔══██╗   ██║ --
-- ██║╚██╗ ██║ ██║         ██║  ██║ █████╗  ██║  ██║ █████╗  ██║    ██║  ██║ ██████╔╝ █████╗  ██████╔╝   ██║ --
-- ██║ ╚██╗██║ ██║         ██║  ██║ ██╔══╝  ╚██╗██╔╝ ██╔══╝  ██║    ██║  ██║ ██╔═══╝  ██╔══╝  ██╔══██╗   ╚═╝ --
-- ██║  ╚████║ ╚═██████╗   ██████╔╝ ██████╗  ╚███╔╝  ██████╗ ██████╗╚█████╔╝ ██║      ██████╗ ██║  ██║   ██╗ --
-- ╚═╝   ╚═══╝   ╚═════╝   ╚═════╝  ╚═════╝   ╚══╝   ╚═════╝ ╚═════╝ ╚════╝  ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝ --

Config.DefaultDeathCause = 'ไม่ทราบสาเหตุ'

Config.DeathCauses = {
	['WEAPON_UNARMED'] = 'มือเปล่า',

	-- Explosion
	['WEAPON_EXPLOSION'] = 'การระเบิด',

	-- Falling
	['WEAPON_FALL'] = 'การตกจากที่สูง หรือ ขาดอาหาร',

	-- Drawning
	['WEAPON_DROWNING'] = 'การจมน้ำ',
	['WEAPON_DROWNING_IN_VEHICLE'] = 'การจมน้ำขณะอยู่บนยานพาหนะ',

	-- Animal
	['WEAPON_ANIMAL'] = 'การโดนสัตว์ทำร้าย',
	['WEAPON_COUGAR'] = 'การโดนเสือภูเขาทำร้าย',

	-- Hitting by Vehicle
	['WEAPON_RAMMED_BY_CAR'] = { 'ยานพาหนะ %s ทะเบียน %s', 'ยานพาหนะ' },
	['WEAPON_RUN_OVER_BY_CAR'] = { 'ยานพาหนะ %s ทะเบียน %s', 'ยานพาหนะ' },

	-- Vehicle
	['WEAPON_STINGER'] = 'Stinger',
	['WEAPON_HELI_CRASH'] = 'เฮลิคอปเตอร์ระเบิด',
	['WEAPON_VEHICLE_ROCKET'] = 'อาวุธจากยานพาหนะ (Vehicle Rocket)',
	['WEAPON_AIRSTRIKE_ROCKET'] = 'อาวุธจากยานพาหนะ (Airstrike Rocket)',
	['WEAPON_PASSENGER_ROCKET'] = 'อาวุธจากยานพาหนะ (Passenger Rocket)',

	-- Other
	['WEAPON_GRENADELAUNCHER_SMOKE'] = 'Grenade Launcher Smoke',

	-- Can found in new version of es_extended
	['WEAPON_STONE_HATCHET'] = 'Stone Hatchet',
	['WEAPON_CERAMICPISTOL'] = 'Ceramic Pistol',
	['WEAPON_NAVYREVOLVER'] = 'Navy Revolver',
	['WEAPON_PISTOL_MK2'] = 'Pistol MK2',
	['WEAPON_RAYPISTOL'] = 'Up-N-Atomizer',
	['WEAPON_REVOLVER_MK2'] = 'Heavy Revolver MK2',
	['WEAPON_SNSPISTOL_MK2'] = 'SNS Pistol MK2',
	['WEAPON_COMBATMG_MK2'] = 'Combat MG MK2',
	['WEAPON_SMG_MK2'] = 'SMG MK2',
	['WEAPON_RAYCARBINE'] = 'Unholy Hellbringer',
	['WEAPON_ASSAULTRIFLE_MK2'] = 'Assault Rifle MK2',
	['WEAPON_BULLPUPRIFLE_MK2'] = 'Bullpup Rifle MK2',
	['WEAPON_CARBINERIFLE_MK2'] = 'Carbine Rifle MK2',
	['WEAPON_PUMPSHOTGUN_MK2'] = 'Pump Shotgun MK2',
	['WEAPON_SPECIALCARBINE_MK2'] = 'Special Carbine MK2',
	['WEAPON_HEAVYSNIPER_MK2'] = 'Heavy Sniper MK2',
	['WEAPON_MARKSMANRIFLE_MK2'] = 'Marksman Rifle MK2',
	['WEAPON_RAYMINIGUN'] = 'Widowmaker'
}



exports("Discord", function(data)
    print(data.webhook)
    print(data.xPlayer)
    print(data.message)
    print('Block')
end)

print('TEST')print('TEST')print('TEST')print('TEST')print('TEST')print('TEST')print('TEST')print('TEST')print('TEST')print('TEST')print('TEST')
