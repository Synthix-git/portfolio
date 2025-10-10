Config = {}


-- Blip fixo no mapa (local do serviço)
Config.StartBlip = {
    enabled = true,
    sprite = 477,    -- ícone de camião (ajusta se quiseres)
    color  = 5,
    scale  = 0.5,
    name   = "Camionista"
}


-- NPC e spawn do camião
Config.NPCLocation        = vec4(914.07, -1273.46, 26.10, 69.0)
Config.TruckSpawnLocation = vec4(907.31, -1259.96, 25.66, 36.0)
Config.TruckModel         = `pounder`

-- Pagamentos FIXOS (fallback) e Gorjeta
Config.PaymentRange = { min = 8500, max = 30000 }
Config.TipAmount    = { min = 2500, max = 5000 }

-- Método de pagamento
-- Delivery = "Cash" (item dollar) ou "Bank"
-- Tip      = "Cash" (item dollar) ou "Bank"
Config.PaymentMethod = {
    Delivery = "Bank",
    Tip      = "Cash"
}

-- Timer para voltar ao camião
Config.LeaveTruckTimer = 120   -- segundos fora do camião antes de ser despedido
Config.TipChance       = 20   -- % de chance de gorjeta

-- Mensagens de gorjeta
Config.TipMessages = {
    male = {
        "A cliente ficou impressionada com a tua rapidez e deu-te uma gorjeta.",
        "Serviço impecável! Recebeste uma gorjeta.",
        "Atendimento prestável — saiu gorjeta.",
        "A empregada achou-te bonito e deu-te uma gorjeta",
        "O cliente ficou impressionado com o teu trabalho e deu-te uma gorjeta",
        "Recebeste uma gorjeta por seres tão prestável"
    },
    female = {
        "O cliente ficou impressionado com a tua rapidez e deu-te uma gorjeta.",
        "Serviço impecável! Recebeste uma gorjeta.",
        "Atendimento prestável — saiu gorjeta.",
        "O empregado achou-te engraçada e deu-te uma gorjeta",
        "A cliente ficou impressionada com o teu trabalho e deu-te uma gorjeta",
        "Recebeste uma gorjeta por seres tão prestável"
    }
}

-- Pontos de entrega
Config.Deliveries = {
    {name = "Bugstars Pest Control", location = vec3(161.76, -3088.68, 5.96)},
    {name = "Hangar Grand Senora",  location = vec3(1737.55, 3287.59, 41.13)},
    {name = "YouTool",              location = vec3(2700.64, 3449.73, 55.79)},
    {name = "Vinhas Buen Vino",     location = vec3(-1876.61, 2039.77, 140.22)},
    {name = "The Jetty",            location = vec3(-2039.56, -272.37, 23.38)},
    {name = "Pacific Bluffs",       location = vec3(-2985.99, 75.86, 11.61)},
    {name = "The Paint Job",        location = vec3(-1117.64, 2677.41, 18.44)},
    {name = "Harmony Shopping Centre", location = vec3(644.68, 2780.96, 41.94)},
    {name = "Larry's RV Sales",     location = vec3(1209.51, 2712.53, 38.00)},
    {name = "The Boat House",       location = vec3(1536.96, 3769.63, 34.05)},
    {name = "Liquor Market",        location = vec3(2482.80, 4117.33, 38.06)},
    {name = "H.J. Silos",           location = vec3(2856.11, 4418.68, 48.83)},
    {name = "Globe Oil 24/7",       location = vec3(1725.89, 6399.03, 34.47)},
    {name = "Zancudo Grain Growers", location = vec3(424.70, 6533.65, 27.70)},
    {name = "Bell Farms",           location = vec3(83.90, 6327.97, 31.23)},
    {name = "Clucking Bell Farms",  location = vec3(-127.27, 6216.81, 31.20)},
    {name = "Morris & Sons",        location = vec3(-32.46, 6414.87, 31.49)},
    {name = "Paleto Bay Market",    location = vec3(-359.40, 6069.92, 31.47)},
    {name = "Willies",              location = vec3(-79.97, 6490.82, 31.49)},
    {name = "Palla Springs",        location = vec3(-772.77, 5575.72, 33.48)},
    {name = "Hookies",              location = vec3(-2198.19, 4262.91, 48.16)},
    {name = "Pipeline Inn",         location = vec3(-2179.12, -411.03, 13.15)},
    {name = "Del Perro Pier",       location = vec3(-1638.84, -814.44, 10.17)},
    {name = "Viceroy Medical Center", location = vec3(-832.44, -1268.52, 5.00)},
    {name = "Higgins Helitours",    location = vec3(-745.15, -1501.35, 4.99)},
    {name = "Bilgeco",              location = vec3(-878.58, -2732.61, 13.83)},
    {name = "Jetsam",               location = vec3(-760.46, -2600.45, 13.83)},
    {name = "Alpha Mail",           location = vec3(-743.97, -2472.07, 13.94)},
    {name = "Carson Self Storage",  location = vec3(107.44, -1818.00, 26.56)},
    {name = "Davis Mega Mall",      location = vec3(19.81, -1763.17, 29.30)},
    {name = "Box Office",           location = vec3(1094.29, 250.26, 80.85)},
    {name = "LSDWP",                location = vec3(745.82, 129.20, 79.48)},
    {name = "CNT",                  location = vec3(776.73, 223.39, 85.56)},
    {name = "Vinewood Bowl",        location = vec3(691.44, 606.73, 128.91)},
    {name = "Stoner Cement Works",  location = vec3(1219.22, 1840.56, 79.17)},
    {name = "Eastern Motel",        location = vec3(327.88, 2627.55, 44.50)},
    {name = "Galileo Observatory",  location = vec3(-411.21, 1175.50, 325.64)}
}
