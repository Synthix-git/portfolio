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
    -- fallback “no-vrp”: evita crash mesmo sem vRP (dev only)
    Tunnel, Proxy = { bindInterface = function() end, getInterface = function() return {} end },
                     { getInterface = function() return {} end }
  end
end

vRP = Proxy.getInterface("vRP") or {}

Creative = {}
Tunnel.bindInterface("bodybag", Creative)
vSERVER = Tunnel.getInterface("bodybag") or {}

---------------------------------------------------------------------
-- DEBUG / UTILS
---------------------------------------------------------------------
local function notify(tpl)
  if tpl then TriggerEvent("Notify", tpl[1], tpl[2], "azul", 4000) end
end

local function cdbg(msg)
  if Config and Config.debug then
    print(("^2[bodybag][CLIENT]^0 %s"):format(tostring(msg)))
  end
end

local function isDeadStrict(ped)
  return IsPedFatallyInjured(ped) or IsEntityDead(ped) or (GetEntityHealth(ped) <= 101)
end

local function ensureModel(model)
  local hash = (type(model) == "number") and model or GetHashKey(model)
  if not IsModelValid(hash) then return false, 0 end
  RequestModel(hash)
  local timeout = GetGameTimer() + 5000
  while not HasModelLoaded(hash) do
    if GetGameTimer() > timeout then return false, 0 end
    Wait(0)
  end
  return true, hash
end

local function groundZ(x,y,z)
  local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + 50.0, true)
  if ok then return gz + 0.02 end
  return z + 0.02
end

local function spawnBodybagProp(pos, heading)
  local ok, hash = ensureModel(Config.propModel or "prop_body_bag_01")
  if not ok then cdbg("Model inválido"); return nil end

  local x,y,z = pos.x + 0.0, pos.y + 0.0, pos.z + 0.0
  z = groundZ(x,y,z)

  local obj = CreateObjectNoOffset(hash, x, y, z, false, false, false)
  if DoesEntityExist(obj) then
    SetEntityHeading(obj, heading or 0.0)
    SetEntityCollision(obj, true, true)
    FreezeEntityPosition(obj, true)
    PlaceObjectOnGroundProperly(obj)
    cdbg("Saco spawnado: "..tostring(obj))

    local life = tonumber(Config.propDurationMs) or 10000
    CreateThread(function()
      Wait(life)
      if DoesEntityExist(obj) then DeleteObject(obj) end
      SetModelAsNoLongerNeeded(hash)
    end)
    return obj
  end

  SetModelAsNoLongerNeeded(hash)
  return nil
end

local function getClosestPlayerValid(maxDist)
  local ped = PlayerPedId()
  local myPos = GetEntityCoords(ped)
  local best, bestSrc, bestDist

  for _,pid in ipairs(GetActivePlayers()) do
    local tgt = GetPlayerPed(pid)
    if tgt ~= ped and DoesEntityExist(tgt) and isDeadStrict(tgt) then
      local dist = #(GetEntityCoords(tgt) - myPos)
      if dist <= (maxDist or (Config.maxDistance or 3.5)) and (not bestDist or dist < bestDist) then
        best, bestDist = tgt, dist
        bestSrc = GetPlayerServerId(pid)
      end
    end
  end

  return best, bestSrc
end

local function getClosestPedValid(maxDist)
  local ped = PlayerPedId()
  local myPos = GetEntityCoords(ped)
  local handle, findPed = FindFirstPed()
  local success
  local best, bestDist

  repeat
   if DoesEntityExist(findPed) and findPed ~= ped and not IsPedAPlayer(findPed) and isDeadStrict(findPed) then
      local dist = #(GetEntityCoords(findPed) - myPos)
      if dist <= (maxDist or (Config.maxDistance or 3.5)) and (not bestDist or dist < bestDist) then
        best, bestDist = findPed, dist
      end
    end
    success, findPed = FindNextPed(handle)
  until not success

  EndFindPed(handle)
  return best
end

-- anima “mecânico” rápida (enter + aceleração)
local function fastKneel(duration)
  local ped = PlayerPedId()
  local dict, anim = "amb@medic@standing@tendtodead@enter", "enter"
  RequestAnimDict(dict)
  while not HasAnimDictLoaded(dict) do Wait(0) end

  TaskPlayAnim(ped, dict, anim, 8.0, 8.0, duration or -1, 49, 0, false, false, false)
  if Config.anim and Config.anim.speedMult then
    SetEntityAnimSpeed(ped, dict, anim, Config.anim.speedMult + 0.0)
  end
end

---------------------------------------------------------------------
-- USO DO ITEM 
---------------------------------------------------------------------
RegisterNetEvent("bodybag:Use")
AddEventHandler("bodybag:Use", function()
  cdbg("Use -> procurar alvo")
  local me = PlayerPedId()
  local maxd = Config.maxDistance or 3.5

  -- PLAYER
  local tPed, tSrc = getClosestPlayerValid(maxd)
  if tPed and tSrc then
    if not isDeadStrict(tPed) then
      TriggerEvent("Notify","Body Bag","O jogador ainda está <b>vivo</b>.", "vermelho", 5000)
      return
    end
    local pos = GetEntityCoords(tPed)
    local hdg = GetEntityHeading(tPed)
    --  NÃO spawna saco aqui; pede confirmação ao servidor
    TriggerServerEvent("bodybag:Try", {
      type = "player",
      targetSrc = tSrc,
      pos = { x = pos.x, y = pos.y, z = pos.z },
      heading = hdg
    })
    return
  end

  -- NPC
  local p = getClosestPedValid(maxd)
  if p and p ~= 0 then
    if not isDeadStrict(p) then
      TriggerEvent("Notify","Body Bag","Só podes ensacar <b>NPCs mortos</b>.", "vermelho", 5000)
      return
    end
    local pos = GetEntityCoords(p)
    local hdg = GetEntityHeading(p)
    local netId = NetworkGetNetworkIdFromEntity(p)

    TriggerServerEvent("bodybag:Try", {
      type = "ped",
      pos = { x = pos.x, y = pos.y, z = pos.z },
      heading = hdg,
      netId = netId
    })
    return
  end

  --  Sem alvo válido: só notifica; NÃO spawna saco.
  TriggerEvent("Notify","Body Bag","Sem alvo <b>válido</b> por perto.", "vermelho", 5000)
end)


RegisterNetEvent("bodybag:HoldKneel")
AddEventHandler("bodybag:HoldKneel", function(duration)
  duration = tonumber(duration) or (Config.anim and Config.anim.durationMs) or 1200
  local ped = PlayerPedId()

  -- bloqueio básico
  LocalPlayer.state:set("Buttons", true, true)

  -- anim. acelerada
  fastKneel(duration)

  -- progress local
  TriggerEvent("Progress", (Config.anim and Config.anim.progressText) or "Ensacando...", duration)

  local ends = GetGameTimer() + duration
  while GetGameTimer() < ends do
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 21, true)
    DisableControlAction(0, 22, true)
    DisableControlAction(0, 32, true)
    DisableControlAction(0, 33, true)
    DisableControlAction(0, 34, true)
    DisableControlAction(0, 35, true)
    Wait(0)
  end

  -- fallback de limpeza 
  CreateThread(function()
    Wait(250)
    if IsEntityPlayingAnim(ped, "amb@medic@standing@tendtodead@enter", "enter", 3) then
      ClearPedTasks(ped)
    end
    LocalPlayer.state:set("Buttons", false, true)
  end)
end)

---------------------------------------------------------------------
-- TELEPORT (ALVO)
---------------------------------------------------------------------
RegisterNetEvent("bodybag:TeleportHospital")
AddEventHandler("bodybag:TeleportHospital", function(coords)
  if type(coords) ~= "table" then return end
  local ped = PlayerPedId()
  local x,y,z = coords.x + 0.0, coords.y + 0.0, coords.z + 0.1

  if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
    NetworkResurrectLocalPlayer(x, y, z, 0.0, true, true, false)
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
  end

  SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
  ClearPedBloodDamage(ped)
  ClearPedTasksImmediately(ped)
end)

---------------------------------------------------------------------
-- COMANDO DE TESTE
---------------------------------------------------------------------
-- RegisterCommand("bbtest", function()
--   cdbg("Comando /bbtest -> HoldKneel + Use")
--   local duration = (Config.anim and Config.anim.durationMs) or 1200
--   TriggerEvent("bodybag:HoldKneel", duration)
--   SetTimeout(duration + 50, function()
--     TriggerEvent("bodybag:Use")
--   end)
-- end)


-- Server confirmou NPC: apaga o ped (pelo netId) e spawna o saco
RegisterNetEvent("bodybag:ConfirmPed")
AddEventHandler("bodybag:ConfirmPed", function(data)
  if type(data) ~= "table" then return end
  local ent = data.netId and NetworkGetEntityFromNetworkId(data.netId) or 0
  if ent ~= 0 and DoesEntityExist(ent) then
    SetEntityAsMissionEntity(ent, true, true)
    DeletePed(ent)
    Wait(50)
  end
  spawnBodybagProp({ x = data.pos.x, y = data.pos.y, z = data.pos.z }, data.heading or 0.0)
end)

-- Server confirmou Player: apenas spawna o saco no local dado
RegisterNetEvent("bodybag:ConfirmPlayer")
AddEventHandler("bodybag:ConfirmPlayer", function(data)
  if type(data) ~= "table" then return end
  spawnBodybagProp({ x = data.pos.x, y = data.pos.y, z = data.pos.z }, data.heading or 0.0)
end)
