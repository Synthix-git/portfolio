---------------------------------------------------------------------
-- VRP
---------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP  = Proxy.getInterface("vRP")
vRPC = Tunnel.getInterface("vRP")

-- Teclado (UI)
vKEYBOARD = Tunnel.getInterface("keyboard") or {}

---------------------------------------------------------------------
-- CONFIG (SIMPLE!)
---------------------------------------------------------------------
local Config = {}

-- Licenças (armazenadas em SrvData: "Licensas:<Passport>")
Config.Licenses = {
  Firearm = { label = "Porte de Arma" },
  Hunter  = { label = "Licença de Caçador" },
  Fishing = { label = "Licença de Pesca" },
  Lawyer  = { label = "Licença de Advogado" },
  Judge   = { label = "Licença de Juiz" },
  Homo = { label = "Licença Homosexual"},
}

-- MATRIZ SIMPLES: por licença diz quem pode dar/remover.
-- Regras:
--   { group="Nome" }                      -> pode DAR e REMOVER (basta estar no grupo)
--   { group="Nome", grant=true }          -> pode DAR (HasGroup); remove herda do grant se 'remove' não existir
--   { group="Nome", grant=2 }             -> pode DAR (HasPermission nível >= 2)
--   { group="Nome", remove=true }         -> pode REMOVER (HasGroup)
--   { group="Nome", remove=3 }            -> pode REMOVER (HasPermission nível >= 3)

-- EXEMPLOS

-- { group = "Policia", grant = 2, remove = 3 } -- Polícia: dar 2+, tirar 3+

--   default aplica-se a todas as licenças sem regra própria.
Config.Matrix = {
  default = {
    { group = "Admin" } -- Admin pode dar e tirar tudo
  },

  Firearm = {
    { group = "Admin" },
    { group = "AmmunationNorte", grant=true },
    { group = "AmmunationSul", grant=true },
    { group = "AmmunationCentro", grant=true },
    { group = "Admin" },
    { group = "Policia" } -- qualquer polícia pode dar e tirar
  },

  Hunter = {
    { group = "Admin" },
    { group = "AmmunationNorte", grant=true },
    { group = "AmmunationSul", grant=true },
    { group = "AmmunationCentro", grant=true },
    { group = "Policia" } -- qualquer polícia pode dar e tirar
  },

  Fishing = {
    { group = "Admin" },
    { group = "Policia" } -- qualquer polícia pode dar e tirar
  },

  Lawyer = {
    { group = "Admin" }
  },

  Judge = {
    { group = "Admin" }
  },

  Homo = {
    { group = "Admin" }
  }
}

-- Canal de logs no recurso "discord"
Config.DiscordHook = "Licenças"

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local function safePassportName(passport)
  if not passport then return "Sistema" end
  local src = vRP.Source(passport)
  if src then
    local ok, fullname = pcall(vRP.FullName, passport)
    if ok and fullname and fullname ~= "" then
      return fullname
    end
  end
  return ("Passaporte %d"):format(tonumber(passport) or 0)
end

local function _hasBySpec(passport, ruleValue, group)
  -- ruleValue: true (HasGroup) | number (HasPermission nível) | nil (já tratado fora)
  if ruleValue == true then
    return vRP.HasGroup(passport, group)
  elseif type(ruleValue) == "number" then
    return vRP.HasPermission(passport, group, ruleValue)
  else
    -- ausência de grant/remove na regra => basta pertencer ao grupo
    return vRP.HasGroup(passport, group)
  end
end

local function _rulesFor(licenseId)
  local m = Config.Matrix or {}
  return m[licenseId] or m.default or {}
end

local function canGrant(passport, licenseId)
  local rules = _rulesFor(licenseId)
  for _, r in ipairs(rules) do
    if r.group and _hasBySpec(passport, (r.grant ~= nil) and r.grant or true, r.group) then
      return true
    end
  end
  return false
end

local function canRemove(passport, licenseId)
  local rules = _rulesFor(licenseId)
  for _, r in ipairs(rules) do
    if r.group then
      -- herda do grant se remove não existir
      local spec = (r.remove ~= nil) and r.remove or ((r.grant ~= nil) and r.grant or true)
      if _hasBySpec(passport, spec, r.group) then
        return true
      end
    end
  end
  return false
end

local function canGrantAny(passport)
  for id,_ in pairs(Config.Licenses) do
    if canGrant(passport, id) then return true end
  end
  return false
end

local function canRemoveAny(passport)
  for id,_ in pairs(Config.Licenses) do
    if canRemove(passport, id) then return true end
  end
  return false
end

local function keyFinal(passport)
  return "Licensas:"..passport
end

local function getFinal(passport)
  local t = vRP.GetSrvData(keyFinal(passport)) or {}
  if type(t) ~= "table" then t = {} end
  return t
end

local function saveFinal(passport, data)
  vRP.SetSrvData(keyFinal(passport), data, true)
end

local function notify(src, title, msg, color, time)
  TriggerClientEvent("Notify", src, title, msg, color or "azul", time or 5000)
end

local function logDiscord(msg, src)
  if exports["discord"] and exports["discord"].Embed then
    exports["discord"]:Embed(Config.DiscordHook, msg, src or 0)
  end
end

-- UI dropdown filtrado por permissões
local function promptFormFiltered(src, action)
  local staffPassport = vRP.Passport(src)
  if not staffPassport then return nil, nil end

  local optionsMap = {}
  for id, def in pairs(Config.Licenses) do
    local okAction = (action == "Grant" and canGrant(staffPassport, id)) or
                     (action == "Remove" and canRemove(staffPassport, id))
    if okAction then optionsMap[id] = def.label end
  end

  local hasAny = next(optionsMap) ~= nil
  if not hasAny then return nil, nil end

  if vKEYBOARD and vKEYBOARD.Options then
    local labels, reverse = {}, {}
    for id, label in pairs(optionsMap) do
      local lbl = tostring(label)
      if reverse[lbl] then
        lbl = ("%s (%s)"):format(lbl, id)
      end
      labels[#labels+1] = lbl
      reverse[lbl] = id
    end

    local arr = vKEYBOARD.Options(src, "Passaporte do jogador", labels)
    if type(arr) == "table" and arr[1] and arr[2] then
      local passaporte   = tonumber(arr[1])
      local selectedLabel = tostring(arr[2])
      local choiceId     = reverse[selectedLabel]
      if passaporte and passaporte > 0 and choiceId then
        return passaporte, choiceId
      end
    end
  end

  return nil, nil
end

---------------------------------------------------------------------
-- LISTAGENS
---------------------------------------------------------------------
local function getOwnedLicenses(passport)
  local data = getFinal(passport)
  local owned = {}
  for id, _ in pairs(Config.Licenses) do
    if data[id] == true then
      owned[#owned+1] = id
    end
  end
  table.sort(owned, function(a,b)
    local la = (Config.Licenses[a] and Config.Licenses[a].label) or a
    local lb = (Config.Licenses[b] and Config.Licenses[b].label) or b
    return la < lb
  end)
  return owned
end

local function labelsFromIds(ids)
  local out = {}
  for _, id in ipairs(ids) do
    out[#out+1] = (Config.Licenses[id] and Config.Licenses[id].label) or id
  end
  return out
end

local function joinLabels(labels)
  if #labels == 0 then return "" end
  return table.concat(labels, ", ")
end

---------------------------------------------------------------------
-- CORE + EXPORTS
---------------------------------------------------------------------
local function GiveLicenseInternal(giverSrc, targetPassport, licenseId)
  if not targetPassport or not licenseId or not Config.Licenses[licenseId] then
    return false, "Licença inválida."
  end

  local giverPassport = vRP.Passport(giverSrc or -1)
  if giverSrc and giverPassport and not canGrant(giverPassport, licenseId) then
    return false, "Sem permissão para conceder esta licença."
  end

  local data = getFinal(targetPassport)
  if data[licenseId] == true then
    return false, "O jogador já possui esta licença."
  end

  data[licenseId] = true
  saveFinal(targetPassport, data)

  local giverName  = giverPassport and safePassportName(giverPassport) or "Sistema"
  local targetName = safePassportName(targetPassport)
  local label      = Config.Licenses[licenseId].label

  logDiscord(([[✅ **LICENÇA CONCEDIDA**

📜 **Licença:** %s
🪪 **Destinatário:** %s (#%d)
👮 **Por:** %s (#%s)
🗓️ **Data & Hora:** %s]]):format(
    label, targetName, targetPassport,
    giverName, tostring(giverPassport or "-"),
    os.date("%d/%m/%Y %H:%M")
  ), giverSrc)

  local targetSrc = vRP.Source(targetPassport)
  if targetSrc then
    notify(targetSrc, "Licenças", ("Recebeste a licença <b>%s</b>."):format(label), "verde", 6000)
  end

  return true
end

local function RemoveLicenseInternal(removerSrc, targetPassport, licenseId)
  if not targetPassport or not licenseId then
    return false, "Parâmetros inválidos."
  end

  local removerPassport = vRP.Passport(removerSrc or -1)
  if removerSrc and removerPassport and not canRemove(removerPassport, licenseId) then
    return false, "Sem permissão para remover esta licença."
  end

  local data = getFinal(targetPassport)
  if data[licenseId] ~= true then
    return false, "O jogador não possui esta licença."
  end

  data[licenseId] = nil
  saveFinal(targetPassport, data)

  local removerName = removerPassport and safePassportName(removerPassport) or "Sistema"
  local targetName  = safePassportName(targetPassport)
  local label       = (Config.Licenses[licenseId] and Config.Licenses[licenseId].label) or licenseId

  logDiscord(([[❌ **LICENÇA REMOVIDA**

📜 **Licença:** %s
🪪 **Jogador:** %s (#%d)
👮 **Por:** %s (#%s)
🗓️ **Data & Hora:** %s]]):format(
    label, targetName, targetPassport,
    removerName, tostring(removerPassport or "-"),
    os.date("%d/%m/%Y %H:%M")
  ), removerSrc)

  local targetSrc = vRP.Source(targetPassport)
  if targetSrc then
    notify(targetSrc, "Licenças", ("A tua licença <b>%s</b> foi removida."):format(label), "amarelo", 6000)
  end

  return true
end

-- Exports
exports("HasLicense", function(passport, licenseId)
  if not passport or not licenseId then return false end
  local data = getFinal(passport)
  return data[licenseId] == true
end)
exports("GiveLicense", GiveLicenseInternal)
exports("RemoveLicense", RemoveLicenseInternal)
exports("ListLicenses", function(passport)           -- ids
  return getOwnedLicenses(passport)
end)
exports("ListLicensesLabeled", function(passport)    -- labels
  return labelsFromIds(getOwnedLicenses(passport))
end)

---------------------------------------------------------------------
-- COMMANDS
---------------------------------------------------------------------
local function cmdGiveLicense(src)
  local staffPassport = vRP.Passport(src)
  if not staffPassport then return end
  if not canGrantAny(staffPassport) then
    notify(src, "Licenças", "Não tens permissão para conceder nenhuma licença.", "vermelho", 6000)
    return
  end

  local targetPassport, choice = promptFormFiltered(src, "Grant")
  if not targetPassport or not choice then
    notify(src, "Licenças", "Formulário inválido ou cancelado.", "amarelo", 5000)
    return
  end

  local ok, err = GiveLicenseInternal(src, targetPassport, choice)
  if ok then
    notify(src, "Licenças", ("Licença <b>%s</b> concedida ao passaporte <b>%d</b>."):format(Config.Licenses[choice].label, targetPassport), "verde", 6000)
  else
    notify(src, "Licenças", err or "Falhou ao conceder licença.", "vermelho", 6000)
  end
end

local function cmdRemoveLicense(src)
  local staffPassport = vRP.Passport(src)
  if not staffPassport then return end
  if not canRemoveAny(staffPassport) then
    notify(src, "Licenças", "Não tens permissão para remover nenhuma licença.", "vermelho", 6000)
    return
  end

  local targetPassport, choice = promptFormFiltered(src, "Remove")
  if not targetPassport or not choice then
    notify(src, "Licenças", "Formulário inválido ou cancelado.", "amarelo", 5000)
    return
  end

  local owned = getOwnedLicenses(targetPassport)
  local has = false
  for _, id in ipairs(owned) do if id == choice then has = true break end end
  if not has then
    notify(src, "Licenças", "O jogador não possui essa licença.", "amarelo", 6000)
    return
  end

  local ok, err = RemoveLicenseInternal(src, targetPassport, choice)
  if ok then
    notify(src, "Licenças", ("Licença <b>%s</b> removida do passaporte <b>%d</b>."):format(Config.Licenses[choice].label, targetPassport), "verde", 6000)
  else
    notify(src, "Licenças", err or "Falhou ao remover licença.", "vermelho", 6000)
  end
end

local function cmdMyLicenses(src)
  local passport = vRP.Passport(src)
  if not passport then return end

  local owned = getOwnedLicenses(passport)
  if #owned == 0 then
    notify(src, "Licenças", "Não tens nenhuma licença.", "amarelo", 6000)
    return
  end

  local labelList = joinLabels(labelsFromIds(owned))
  notify(src, "Licenças", "As tuas licenças: <b>"..labelList.."</b>.", "azul", 9000)
end

-- Commands (com alias "licensas")
RegisterCommand("darlicenca",     function(src) cmdGiveLicense(src)   end)
RegisterCommand("removerlicenca", function(src) cmdRemoveLicense(src) end)
RegisterCommand("licencas",       function(src) cmdMyLicenses(src)    end)

