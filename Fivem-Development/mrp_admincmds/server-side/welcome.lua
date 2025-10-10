-- server/welcome.lua
-- [LEMBRETE]: Persistência ON/OFF e modo; /discord usa vKEYBOARD.Copy para abrir teclado com o link.
-- [LEMBRETE]: comandos -> /welcometoggle [on|off] | /welcomestatus | /welcomemode first|always | /welcomeclear | /discord

local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP        = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG (EDITAR AQUI)
-----------------------------------------------------------------------------------------------------------------------------------------
local WelcomeCfg = {
  enabled_default   = false,               -- estado inicial se não existir persistência
  send_mode_default = "always",           -- "first" (1x por sessão) | "always" (sempre que entra)
  staff_group       = "Admin",            -- grupo com permissão

  discord_link = "https://discord.gg/VsYNTkwBSy",

  notify = {
    title = "EVENTO ESPECIAL",
    color = "rosa",
    time  = 13000,
    body  = table.concat({
      "Olá <b>{name}</b>!<br/>",
      "Bem-vindo! Está a decorrer um <b>evento especial</b> — corridas <b>legais/ilegais</b>.<br/>",
      "Vá até ao <b>discord</b> para falar com a equipa <b>staff</b> para que os mesmos te guiem nesta jornada!<br/>",
      "Até já!"
    }, "<br>")
  }
}

-- [LEMBRETE]: chaves de persistência
local KEY_ENABLED = "Welcome:Enabled"
local KEY_MODE    = "Welcome:Mode"

-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIÁVEIS
-----------------------------------------------------------------------------------------------------------------------------------------
local enabled    = WelcomeCfg.enabled_default
local send_mode  = WelcomeCfg.send_mode_default
local welcomedPassport = {}

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function getPlayerNameFromPassport(passport)
  if not passport then return "Piloto" end
  local id = vRP.Identity(passport) or {}
  return id.fullname or id.name or id.firstname or ("#"..passport)
end

local function formatBody(name)
  local s = WelcomeCfg.notify.body
  s = s:gsub("{name}", name or "Piloto")
  return s
end

local function loadPersisted()
  local pEnabled = vRP.GetSrvData(KEY_ENABLED)
  enabled = type(pEnabled) == "boolean" and pEnabled or WelcomeCfg.enabled_default

  local pMode = vRP.GetSrvData(KEY_MODE)
  send_mode = (pMode == "first" or pMode == "always") and pMode or WelcomeCfg.send_mode_default
end

local function saveEnabled(val) vRP.SetSrvData(KEY_ENABLED, val and true or false) end
local function saveMode(m) if m=="first" or m=="always" then vRP.SetSrvData(KEY_MODE,m); return true end return false end

-----------------------------------------------------------------------------------------------------------------------------------------
-- ARRANQUE
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStart", function(res)
  if res ~= GetCurrentResourceName() then return end
  loadPersisted()
  print(("[welcome] Estado: %s | Modo: %s"):format(enabled and "ON" or "OFF", send_mode))
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- NOTIFY COM RETRY
-----------------------------------------------------------------------------------------------------------------------------------------
local function TryNotifyWelcome(src)
  for _=1,24 do
    if not GetPlayerEndpoint(src) then return end
    local passport = vRP.Passport(src)
    if passport then
      if send_mode == "first" then
        if welcomedPassport[passport] then return end
        welcomedPassport[passport] = true
      end
      local msg = formatBody(getPlayerNameFromPassport(passport))
      TriggerClientEvent("Notify", src, WelcomeCfg.notify.title, msg, WelcomeCfg.notify.color, WelcomeCfg.notify.time)
      return
    end
    Wait(500)
  end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTO CLIENT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("welcome:firstSpawn")
AddEventHandler("welcome:firstSpawn", function()
  local src = source
  if not enabled then return end
  TryNotifyWelcome(src)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- COMANDOS DE GESTÃO (persistentes)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("welcometoggle", function(source, args)
  local src = source
  if src ~= 0 then
    local passport = vRP.Passport(src)
    if not passport or not vRP.HasGroup(passport, WelcomeCfg.staff_group) then
      TriggerClientEvent("Notify", src, "Permissão", "Sem permissão.", "amarelo", 4000)
      return
    end
  end

  local a = (args[1] or ""):lower()
  if a == "on" then enabled = true
  elseif a == "off" then enabled = false
  else enabled = not enabled end

  saveEnabled(enabled)
  local state = enabled and "ativado" or "desativado"
  if src == 0 then print(("[welcome] %s (persistido)"):format(state))
  else TriggerClientEvent("Notify", src, "Welcome", ("Script de Boas-Vindas %s (persistido)."):format(state), "azul", 4000) end
end, false)

RegisterCommand("welcomestatus", function(source)
  local src = source
  if src ~= 0 then
    local passport = vRP.Passport(src)
    if not passport or not vRP.HasGroup(passport, WelcomeCfg.staff_group) then
      TriggerClientEvent("Notify", src, "Permissão", "Sem permissão.", "amarelo", 4000)
      return
    end
  end

  local state = enabled and "Ativado" or "Desativado"
  local msg = ("Welcome script: <b>%s</b>\nModo: <b>%s</b>\nDiscord: <b>%s</b>")
              :format(state, send_mode, WelcomeCfg.discord_link)
  if src == 0 then print(msg:gsub("<.->",""))
  else TriggerClientEvent("Notify", src, "Welcome", msg, "azul", 8000) end
end, false)

RegisterCommand("welcomemode", function(source, args)
  local src = source
  if src ~= 0 then
    local passport = vRP.Passport(src)
    if not passport or not vRP.HasGroup(passport, WelcomeCfg.staff_group) then
      TriggerClientEvent("Notify", src, "Permissão", "Sem permissão.", "amarelo", 4000)
      return
    end
  end

  local m = (args[1] or ""):lower()
  if m ~= "first" and m ~= "always" then
    if src == 0 then print("Uso: /welcomemode first|always")
    else TriggerClientEvent("Notify", src, "Welcome", "Uso: <b>/welcomemode first</b> ou <b>/welcomemode always</b>.", "amarelo", 6000) end
    return
  end

  send_mode = m
  saveMode(m)
  if src == 0 then print("Modo alterado para "..m.." (persistido)")
  else TriggerClientEvent("Notify", src, "Welcome", ("Modo alterado para <b>%s</b> (persistido)."):format(m), "azul", 5000) end
end, false)

RegisterCommand("welcomeclear", function(source)
  local src = source
  if src ~= 0 then
    local passport = vRP.Passport(src)
    if not passport or not vRP.HasGroup(passport, WelcomeCfg.staff_group) then
      TriggerClientEvent("Notify", src, "Permissão", "Sem permissão.", "amarelo", 4000)
      return
    end
  end
  welcomedPassport = {}
  if src == 0 then print("Memória limpa")
  else TriggerClientEvent("Notify", src, "Welcome", "Memória de já avisados <b>limpa</b>.", "azul", 4000) end
end, false)
