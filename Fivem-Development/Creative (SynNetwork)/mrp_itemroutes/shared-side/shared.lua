-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
Config = {
	-- ROTA PÚBLICA
	["Rotas"] = {
		["Route"] = true,           -- true=sequência; false=aleatório
		["Circle"] = 1.0,
		["Wanted"] = false,
		["Battlepass"] = true,
		["DebugPoly"] = false,
		["Permission"] = false,     -- público
		["Blocked"] = false,        -- sem bloqueios
		["Mode"] = "Always",
		["Init"] = vec3(287.44,-991.51,33.09),
		["Experience"] = {
			["Name"] = "Driver",
			["Amount"] = 10,
			-- Boosts suaves/probabilísticos (podem ou não ocorrer)
			["Boosts"] = {
				{ at = 20,  mult = 1.10, chance = 30 }, -- 30% de chance de +10%
				{ at = 50,  mult = 1.15, chance = 25 }, -- 25% de chance de +15%
				{ at = 75,  mult = 1.20, chance = 20 }, -- 20% de chance de +20%
				{ at = 90,  mult = 1.25, chance = 15 }  -- 15% de chance de +25% (máx)
			}
		},
		["List"] = {
			{ ["Item"] = "joint",   ["Chance"] = 25, ["Min"] = 1, ["Max"] = 3, ["Price"] = 1000 },
			{ ["Item"] = "cocaine", ["Chance"] = 25, ["Min"] = 1, ["Max"] = 3, ["Price"] = 1000 },
			{ ["Item"] = "meth",    ["Chance"] = 25, ["Min"] = 1, ["Max"] = 3, ["Price"] = 1000 },
			{ ["Item"] = "bandage", ["Chance"] = 25, ["Min"] = 1, ["Max"] = 3, ["Price"] = 100 },
			{ ["Item"] = "medkit",  ["Chance"] = 25, ["Min"] = 1, ["Max"] = 3, ["Price"] = 100 },
			{ ["Item"] = "nitro",   ["Chance"] = 25, ["Min"] = 1, ["Max"] = 3, ["Price"] = 1000 },
			{ ["Item"] = "tyres",   ["Chance"] = 25, ["Min"] = 1, ["Max"] = 3, ["Price"] = 100 },
			{ ["Item"] = "lockpick",["Chance"] = 25, ["Min"] = 1, ["Max"] = 3, ["Price"] = 100 },
			{ ["Item"] = "safependrive",["Chance"] = 25, ["Min"] = 1, ["Max"] = 1, ["Price"] = 1000 },
			{ ["Item"] = "weaponparts",["Chance"] = 25, ["Min"] = 1, ["Max"] = 1, ["Price"] = 2500 },
			{ ["Item"] = "riflebody",["Chance"] = 25, ["Min"] = 1, ["Max"] = 1, ["Price"] = 2500 },
			{ ["Item"] = "metalspring",["Chance"] = 25, ["Min"] = 1, ["Max"] = 1, ["Price"] = 2500 }
			
		},
		["Coords"] = {
			vec3(-509.26,-1018.72,23.52),
			vec3(-1602.07,-828.71,10.04),
			vec3(-536.90,-40.95,42.71),
			vec3(-66.67,82.04,71.53),
			vec3(582.61,128.70,98.03),
			vec3(813.88,-86.04,80.61),
			vec3(1120.46,-349.74,67.06),
			vec3(1066.99,-782.99,58.27),
			vec3(1134.64,-974.33,46.57),
			vec3(1184.44,-1285.63,34.90),
			vec3(967.92,-1822.81,31.09),
			vec3(803.06,-2225.59,29.50),
			vec3(676.94,-2736.46,6.02),
			vec3(269.90,-2504.28,6.44),
			vec3(94.33,-2673.05,6.00),
			vec3(-55.10,-2531.44,6.00),
			vec3(196.42,-2028.02,18.28),
			vec3(-303.99,-2187.71,10.09),
			vec3(-570.96,-1783.84,22.49),
			vec3(-345.41,-1561.58,25.22),
			vec3(-146.39,-1414.64,30.62),
			vec3(64.34,-1401.79,29.35),
			vec3(330.78,-1281.53,31.76),
			vec3(490.17,-1472.42,29.13),
			vec3(23.49,-1305.56,29.17),
			vec3(261.33,-1348.03,31.93),
			vec3(-718.50,-1112.47,11.20),
			vec3(-839.51,-1127.40,6.91),
			vec3(491.74,-893.05,25.70)
		}
	}
	-- ,
	----- ROTA COM BLOQUEIO (ex.: Admin e Policia não podem)
	-- ["EntregasRestritas"] = {
	-- 	["Route"] = false,          -- aleatória
	-- 	["Circle"] = 1.0,
	-- 	["Wanted"] = false,
	-- 	["Battlepass"] = false,
	-- 	["DebugPoly"] = false,
	-- 	["Permission"] = false,     -- pública...
	-- 	["Blocked"] = { "Admin", "Policia" }, -- ...mas bloqueada p/ estes grupos
	-- 	["Mode"] = "Always",
	-- 	["Init"] = vec3(901.92,-167.98,74.07),
	-- 	["Experience"] = {
	-- 		["Name"] = "Delivery",
	-- 		["Amount"] = 1,
	-- 		["Boosts"] = {
	-- 			{ at = 20,  mult = 1.08, chance = 30 },
	-- 			{ at = 50,  mult = 1.12, chance = 25 },
	-- 			{ at = 75,  mult = 1.18, chance = 20 }
	-- 		}
	-- 	},
	-- 	["List"] = {
	-- 		{ ["Item"] = "bandage", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 2, ["Price"] = 50 },
	-- 		{ ["Item"] = "medkit",  ["Chance"] = 30, ["Min"] = 1, ["Max"] = 1, ["Price"] = 100 },
	-- 		{ ["Item"] = "lockpick",["Chance"] = 20, ["Min"] = 1, ["Max"] = 2, ["Price"] = 75 }
	-- 	},
	-- 	["Coords"] = {
	-- 		vec3(275.36,-345.06,45.17),
	-- 		vec3(-1212.47,-1241.50,6.73),
	-- 		vec3(112.62,-1460.35,29.29),
	-- 		vec3(23.62,-1340.51,29.50),
	-- 		vec3(-705.90,-914.56,19.22),
	-- 		vec3(1159.48,-317.05,69.20),
	-- 		vec3(2557.38,382.20,108.62)
	-- 	}
	-- }
}
