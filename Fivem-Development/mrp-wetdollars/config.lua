WETMONEY_CONFIG = {
	Items = {
		WetClean   = "wetdollar",       -- dinheiro limpo molhado
		DryClean   = "dollar",          -- dinheiro limpo seco
		WetDirty   = "wetdirtydollar",  -- dinheiro sujo molhado
		DryDirty   = "dirtydollar"      -- dinheiro sujo seco
	},

	-- MODO ZONAS FIXAS (sem target, sem props)
	UseZonesOnly = true,               -- ativa o modo “pontos fixos”

	-- Zonas de calor fixas (centro + raio em metros)
	HeatZones = {
		{ center = vec3(1086.84, -2002.96, 31.97), radius = 5.0, name = "Refinaria" },
		{ center = vec3(1112.01, -2009.56, 33.64), radius = 5.0, name = "Refinaria" },

        { center = vec3(387.25, -1103.92, 29.41), radius = 4.0, name = "Fogão de Mendigo" },
        { center = vec3(367.20, -1109.11, 29.41), radius = 4.0, name = "Fogão de Mendigo" },
		{ center = vec3(347.37, -1093.59, 29.41), radius = 4.0, name = "Fogão de Mendigo" },
        { center = vec3(337.03, -1085.85, 29.41), radius = 4.0, name = "Fogão de Mendigo" },

        { center = vec3(454.24, -841.42, 27.73), radius = 4.0, name = "Fogão de Mendigo" },
        { center = vec3(460.69, -863.90, 27.05), radius = 4.0, name = "Fogão de Mendigo" },
        { center = vec3(464.62, -849.56, 26.94), radius = 4.0, name = "Fogão de Mendigo" },

        { center = vec3(612.89, -565.47, 15.05), radius = 4.0, name = "Fogão de Mendigo" },
        { center = vec3(604.44, -583.47, 14.80), radius = 4.0, name = "Fogão de Mendigo" },
        { center = vec3(599.80, -595.58, 14.62), radius = 4.0, name = "Fogão de Mendigo" },
        { center = vec3(624.79, -629.15, 14.19), radius = 4.0, name = "Fogão de Mendigo" },

        { center = vec3(1071.76, -260.44, 59.08), radius = 4.0, name = "Fogão de Mendigo" },
 

        { center = vec3(37.65, -1209.15, 29.37), radius = 4.0, name = "Fogão de Mendigo" },
        { center = vec3(-11.18, -1231.05, 29.30), radius = 4.0, name = "Fogão de Mendigo" },

        { center = vec3(461.20, -529.07, 28.45), radius = 4.0, name = "Fogão de Mendigo" },
        { center = vec3(467.62, -533.59, 28.50), radius = 4.0, name = "Fogão de Mendigo" },


        { center = vec3(140.36, -1195.60, 30.04), radius = 3.0, name = "Fogão de Mendigo" },
        { center = vec3(168.58, -1224.79, 29.91), radius = 3.0, name = "Fogão de Mendigo" }
	},

	Active = {
		TimeMs = 30000,          -- 1 minuto
		LossMin = 2,             -- perda mínima (%)
		LossMax = 8,             -- perda máxima (%)
		MaxPerUse = 0,           -- 0 = sem limite por sessão; define p.ex. 2500 para limitar
		CooldownSec = 30,        -- cooldown entre tentativas
		CancelMaxMove = 1.5,     -- (usado só no modo props; no modo zona validamos pelo raio)
		RevalidatePropRadius = 3.0, -- idem
		UseHairDryerProp = false
	},

	-- (Ignorados no modo zonas, mantidos por compatibilidade)
	Target = { Label = "Secar dinheiro (1 min)", Distance = 2.5 },
	HeatProps  = {},
	HeatHashes = {}
}
