Config = {}

-- Porta trancada (decorativo)
Config.DoorLocked = { coords = vec3(-308.90, -716.83, 29.64), hash = 1879668795, distance = 1.75 }

-- Entrada / Saída
Config.EntryZone     = vec3(-307.10, -711.21, 28.68)
Config.InteriorSpawn = vec4(-311.33, -724.77, 28.03, 159.66)
Config.ExitZone      = vec3(-310.20, -720.17, 28.03)
Config.OutsideExit   = vec4(-306.03, -709.91, 28.96, 341.18)

Config.EntryRadius = 2.25
Config.ExitRadius  = 1.75

-- Interações internas
Config.Points = {
  { type = "vault",    pos = vec3(-315.36, -745.78, 28.03),   radius = 2.2 },
  { type = "vault",    pos = vec3(-298.11, -730.69, 125.47),  radius = 2.2 },
  { type = "wardrobe", pos = vec3(-325.05, -739.42, 28.57),   radius = 2.2 },
  { type = "wardrobe", pos = vec3(-280.04, -722.22, 125.46),  radius = 2.2 },
  { type = "wardrobe", pos = vec3(-271.58, -730.87, 125.47),  radius = 2.2 },
  { type = "fridge",   pos = vec3(-291.21, -725.04, 125.23),  radius = 2.2 }
}

-- Capacidades
Config.VaultWeight  = 1800
Config.FridgeWeight = 400

-- Convites
Config.InviteTTLSeconds = 300
Config.InviteRatePerTargetSeconds = 8

-- Ghost visual (sem mexer na colisão)
Config.VehicleGhostMs = 8000

-- Bucket determinístico por dono
Config.BucketForOwner = function(ownerPassport)
  return 700000 + (tonumber(ownerPassport) or 0)
end

-- Canal de logs (opcional)
Config.LogsChannel = "Penthouse"
