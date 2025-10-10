---------------------------------------------------------------------
-- BODYBAG (SERVER) - Syn Network
-- Autor: Synthix
-- Dependências: vRP, recurso 'discord' (exports["discord"]:Embed)
---------------------------------------------------------------------

---------------------------------------------------------------------
-- CONFIG (podes mover para um config.lua se preferires)
---------------------------------------------------------------------
Config = Config or {}
Config.debug               = Config.debug               ~= nil and Config.debug               or false
Config.actionCooldownMs    = Config.actionCooldownMs    or 3000     -- cooldown por jogador
Config.maxPerArea          = Config.maxPerArea          or 50       -- limite por “quadrícula” (50m x 50m) a cada ~2min
Config.hospitalCoords      = Config.hospitalCoords      or vector3(1129.74,-1579.38,35.38)
Config.logsChannelPlayers  = Config.logsChannelPlayers  or "Bodybags" -- canal para logs de players ensacados
Config.logsChannel         = Config.logsChannel         or "Socorro"  -- fallback/geral

-- Notificações (TriggerClientEvent("Notify", src, Título, Mensagem, Cor, Tempo))
Config.notify = Config.notify or {
  ok          = { "Body Bag", "Saco <b>colocado</b> com sucesso.", "verde",   4500 },
  busy        = { "Body Bag", "Não foi possível realizar agora.",  "amarelo", 4500 },
  cooldown    = { "Body Bag", "Aguarda <b>alguns segundos</b>.",   "amarelo", 3500 },
  self_block  = { "Body Bag", "Não podes ensacar a <b>ti próprio</b>.", "vermelho", 4500 }
}

---------------------------------------------------------------------
-- VRP bootstrap (module() se existir; senão exports["vrp"])
---------------------------------------------------------------------
local hasModule = type(module) == "function"
local Tunnel, Proxy

if hasModule then
  local okT, t = pcall(function() return module("vrp","lib/Tunnel") end)
  local okP, p = pcall(function() return module("vrp","lib/Proxy") end)
  if okT and t and okP and p then
    Tunnel, Proxy = t, p
  end
end

if not Tunnel or not Proxy then
  if exports and exports["vrp"] then
    Tunnel = exports["vrp"]:Tunnel()
    Proxy  = exports["vrp"]:Proxy()
  else
    Tunnel, Proxy = { bindInterface = function() end, getInterface = function() return {} end },
                    { getInterface = function() return {} end }
  end
end

vRP  = Proxy.getInterface("vRP") or {}
vRPC = Tunnel.getInterface("vRP") or {}

---------------------------------------------------------------------
-- INTERFACE
---------------------------------------------------------------------
local Creative = {}
Tunnel.bindInterface("bodybag", Creative)

---------------------------------------------------------------------
-- ESTADO
---------------------------------------------------------------------
local lastAction   = {}  -- cooldown por source
local areaBuckets  = {}  -- { "gx:gy" -> { count, last } }

---------------------------------------------------------------------
-- DEBUG / HELPERS
---------------------------------------------------------------------
local function sdbg(...)
  if Config and Config.debug then
    local parts = {...}
    for i=1,#parts do parts[i] = tostring(parts[i]) end
    print(("^3[bodybag][SERVER]^0 %s"):format(table.concat(parts," ")))
  end
end

local function toNumber(v, default)
  if type(v) == "number" then return v end
  local n = tonumber(v); if n then return n end
  if type(v) == "table" then
    return tonumber(v.value or v.ms or v.count or v.n) or default
  end
  return default
end

local function readVec3(v)
  if type(v) == "vector3" then return v.x, v.y, v.z end
  if type(v) == "table" then
    local x = v.x or v[1] or 0.0
    local y = v.y or v[2] or 0.0
    local z = v.z or v[3] or 0.0
    return x,y,z
  end
  return 0.0,0.0,0.0
end

-- usa normalização local sempre que comparar
local function inCooldown(src)
  local ac = toNumber(Config and Config.actionCooldownMs, 3000)
  local last = lastAction[src] or 0
  return (os.clock() * 1000 - last) < ac
end

local function markCooldown(src)
  lastAction[src] = os.clock() * 1000
end

local function areaKeyFromVec3(vec)
  local x,y = readVec3(vec)
  local gx = math.floor(x / 50.0)
  local gy = math.floor(y / 50.0)
  return ("%d:%d"):format(gx, gy)
end

local function areaRateLimit(pos)
  local key = areaKeyFromVec3(pos)
  local now = os.clock() * 1000
  local bucket = areaBuckets[key] or { count = 0, last = 0 }

  if now - bucket.last > 120000 then
    bucket.count = 0
    bucket.last = now
  end

  local maxPer = toNumber(Config and Config.maxPerArea, 50)
  if bucket.count >= maxPer then
    return false
  end

  bucket.count = bucket.count + 1
  bucket.last = now
  areaBuckets[key] = bucket
  return true
end

local function notify(src, tpl)
  if not tpl then return end
  TriggerClientEvent("Notify", src, tpl[1], tpl[2], tpl[3] or "azul", tpl[4] or 4000)
end

---------------------------------------------------------------------
-- LOGS
---------------------------------------------------------------------
local function logDispatch(src, data)
  if not exports or not exports["discord"] or not exports["discord"].Embed then
    sdbg("discord:Embed indisponível (resource 'discord' não carregado?)")
    return
  end

  local passport = vRP.Passport and vRP.Passport(src)
  local name = (vRP.FullName and vRP.FullName(passport)) or ("Passport #" .. tostring(passport or 0))
  local px,py,pz = readVec3(data.pos or {})
  local msg = ("**Body Bag | Despacho**\n\nExecutor: **%s** (#%s)\nLocal: `%.1f, %.1f, %.1f`\nAlvo: **%s**\nHora: <t:%d:F>")
    :format(name, tostring(passport or "?"), px, py, pz, data.targetLabel or "NPC", math.floor(os.time()))

  local channel = (Config and Config.logsChannel) or "Socorro"
  local ok = pcall(function() exports["discord"]:Embed(channel, msg, src) end)
  if not ok then sdbg("Falha ao enviar embed para canal '"..tostring(channel).."'.") end
end

-- 👇 Log específico e bonito para caso de PLAYER ensacado
local function logPlayerBag(src, targetSrc, pos)
  if not exports or not exports["discord"] or not exports["discord"].Embed then
    sdbg("discord:Embed indisponível (resource 'discord' não carregado?)")
    return false
  end

  local now      = os.time()
  local passport = vRP.Passport and vRP.Passport(src)
  local tPass    = vRP.Passport and vRP.Passport(targetSrc)

  local name     = (vRP.FullName and vRP.FullName(passport)) or ("Passaporte #" .. tostring(passport or "?"))
  local tName    = (vRP.FullName and vRP.FullName(tPass))     or ("Passaporte #" .. tostring(tPass or "?"))

  local px,py,pz = readVec3(pos or {})

  local title = "👜 **Body Bag | Jogador ensacado**"
  local lines = {
    "👮 **Executor:** "..name.." (#"..tostring(passport or "?")..")",
    "🧍 **Alvo:** "..tName.." (#"..tostring(tPass or "?")..")",
    ("📍 **Local:** `%.1f, %.1f, %.1f`"):format(px,py,pz),
    "<t:"..tostring(now)..":F>"
  }
  local msg = title.."\n\n"..table.concat(lines,"\n")

  local channel = (Config and (Config.logsChannelPlayers or Config.logsChannel)) or "Bodybags"
  local ok = pcall(function() exports["discord"]:Embed(channel, msg, src) end)
  if not ok then
    sdbg("Falha ao enviar embed para canal '"..tostring(channel).."'. Verifica se existe no recurso 'discord'.")
    return false
  end

  sdbg("Log enviado para canal '"..channel.."'.")
  return true
end

---------------------------------------------------------------------
-- HELPER: valida se o ped (via netId) está morto (server-safe)
-- Regra: morto quando GetEntityHealth(ent) <= 101
---------------------------------------------------------------------
local function isDeadPedNet(netId)
  if not netId then return false end
  local ent = NetworkGetEntityFromNetworkId(netId)
  if not ent or ent == 0 then return false end
  if GetEntityType(ent) ~= 1 then return false end -- 1 = ped
  local hp = GetEntityHealth(ent) or 200
  return hp <= 101
end

---------------------------------------------------------------------
-- EVENTO PRINCIPAL
---------------------------------------------------------------------
RegisterNetEvent("bodybag:Try", function(payload)
  local src = source
  if type(payload) ~= "table" then return end

  if Config and Config.debug then
    local tAC  = type(Config.actionCooldownMs)
    local tMPA = type(Config.maxPerArea)
    print(("^3[bodybag][SERVER]^0 Try de %s -> %s | types: cooldown=%s, maxPerArea=%s")
      :format(src, (json and json.encode and json.encode(payload)) or "payload", tAC, tMPA))
  end

  local passport = vRP.Passport and vRP.Passport(src)
  if not passport then sdbg("Sem passport"); return end

  -- Cooldown
  if inCooldown(src) then
    sdbg("Cooldown")
    notify(src, Config and Config.notify and Config.notify.cooldown)
    return
  end

  local targetType = payload.type
  local targetSrc  = payload.targetSrc
  local nearPos    = payload.pos or { x = 0, y = 0, z = 0 }
  local heading    = tonumber(payload.heading) or 0.0

  -- Rate limit por área
  if not areaRateLimit(nearPos) then
    sdbg("Area limit")
    notify(src, Config and Config.notify and Config.notify.cooldown)
    return
  end

  if targetType == "player" then
    if not targetSrc or not GetPlayerPed(targetSrc) then
      notify(src, Config and Config.notify and Config.notify.busy)
      return
    end
    if targetSrc == src then
      notify(src, Config and Config.notify and Config.notify.self_block)
      return
    end

    -- só permitir se o player alvo estiver morto/inconsciente (HP <= 101)
    local ped = GetPlayerPed(targetSrc)
    if ped ~= 0 then
      local hp = GetEntityHealth(ped) or 200
      if hp > 101 then
        notify(src, { "Body Bag", "O jogador ainda está <b>vivo</b>." })
        sdbg("Bloqueado: player vivo")
        return
      end
    end

    -- teleporta o alvo para hospital
    local hx,hy,hz = readVec3(Config and Config.hospitalCoords or {0,0,0})
    TriggerClientEvent("bodybag:TeleportHospital", targetSrc, { x = hx, y = hy, z = hz })

    -- confirma ao client que pode criar o saco no local capturado
    TriggerClientEvent("bodybag:ConfirmPlayer", src, {
      pos     = { x = nearPos.x, y = nearPos.y, z = nearPos.z },
      heading = heading
    })

    -- LOG bonito para player
    logPlayerBag(src, targetSrc, nearPos)

    notify(src, Config and Config.notify and Config.notify.ok)

    local tgtPassport = vRP.Passport and vRP.Passport(targetSrc)
    local tgtName = (vRP.FullName and vRP.FullName(tgtPassport)) or "Jogador"
    logDispatch(src, {
      pos = nearPos,
      targetLabel = (tgtName and (tgtName .. " (#" .. tostring(tgtPassport or "?") .. ")")) or "Jogador"
    })

    markCooldown(src)
    sdbg("Teleport enviado a player "..tostring(targetSrc))

  elseif targetType == "ped" then
    -- aceita apenas se tiver netId e o ped estiver morto (HP <= 101)
    if not payload.netId or not isDeadPedNet(payload.netId) then
      notify(src, { "Body Bag", "Só podes ensacar <b>NPCs mortos</b>." })
      sdbg("Bloqueado: NPC vivo ou netId inválido")
      return
    end

    -- confirma ao client: apagar ped (pelo netId) e criar saco
    TriggerClientEvent("bodybag:ConfirmPed", src, {
      pos     = { x = nearPos.x, y = nearPos.y, z = nearPos.z },
      heading = heading,
      netId   = payload.netId
    })

    notify(src, Config and Config.notify and Config.notify.ok)
    logDispatch(src, { pos = nearPos, targetLabel = "NPC" })
    markCooldown(src)
    sdbg("NPC processado")

  else
    notify(src, Config and Config.notify and Config.notify.busy)
    sdbg("Payload inválido")
  end
end)
