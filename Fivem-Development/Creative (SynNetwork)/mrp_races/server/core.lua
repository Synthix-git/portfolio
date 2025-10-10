-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP / TUNNEL / PROXY
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")
vRPC         = Tunnel.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- INTERFACE
-----------------------------------------------------------------------------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("races", Creative)

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Daily          = {}
local Active         = {}   -- [Passport] = { race = Number, startMs = GetGameTimer() }
local Cooldown       = {}   -- [Passport] = os.time() + seconds
local PaidIndex      = {}   -- [Passport] = lastIndexPaid (por corrida ativa)
local SavedBest      = {}   -- [Passport] = { [race] = bestMs }
local RaceExplosive  = {}   -- [Passport] = int|false (segundos) - cache do explosivo

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local DEBUG_RACES             = false
local ExperienceRaces         = 10
local CheckpointReward        = 200       -- 200 sujo por checkpoint
local FinishPerSecondBonus    = 5         -- 5 sujo por segundo decorrido
local RaceCooldownSeconds     = 100      -- 30 minutos

-- Itens possíveis para “bilhete”
local RaceTicketItems         = { "cartao_descartavel","races","race","racescard","races_ticket","corrida" }
local RaceTicketDisplayName   = "Cartão Descartavel"



vRP.Prepare("Races/User",
    "SELECT Points FROM races WHERE Race = @Race AND Passport = @Passport LIMIT 1"
)

vRP.Prepare("Races/Insert",
    "INSERT INTO races (Race, Passport, Name, Vehicle, Points) VALUES (@Race, @Passport, @Name, @Vehicle, @Points)"
)

vRP.Prepare("Races/Update",
    "UPDATE races SET Name = @Name, Vehicle = @Vehicle, Points = @Points WHERE Race = @Race AND Passport = @Passport"
)

vRP.Prepare("Races/Consult",
    "SELECT Passport, Vehicle, Points FROM races WHERE Race = @Race ORDER BY Points ASC LIMIT 15"
)

-----------------------------------------------------------------------------------------------------------------------------------------
-- Funcão NumberHours
-----------------------------------------------------------------------------------------------------------------------------------------
-- Converte segundos em "MM:SS"
local function NumberHours(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return ("%02d:%02d"):format(mins, secs)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function nowSec() return os.time() end
local function msTimer() return GetGameTimer() end

local function AlertPoliceClandestine(src, Passport)
    -- anti-spam leve: se Task existir, usa

    local ok = pcall(function()
        if exports["vrp"] and exports["vrp"].CallPolice then
            exports["vrp"]:CallPolice({
                ["Source"]     = src,
                ["Passport"]   = Passport,
                ["Permission"] = "Policia",
                ["Name"]       = "Corrida Clandestina",
                ["Wanted"]     = 60,
                ["Code"]       = 31,
                ["Color"]      = 22
            })
        else
            error("vrp:CallPolice export ausente")
        end
    end)

    if not ok then
        local Service = vRP.NumPermission("Policia")
        for _, polSrc in pairs(Service or {}) do
            async(function()
                if vRPC.PlaySound then
                    vRPC.PlaySound(polSrc, "ATM_WINDOW", "HUD_FRONTEND_DEFAULT_SOUNDSET")
                end
                TriggerClientEvent("Notify", polSrc, "Racing",
                    "Possível <b>corrida clandestina</b> em andamento. Todas as unidades atentas.",
                    "amarelo", 8000)
            end)
        end
    end
end

-- Lê quantidade robusto
local function GetItemAmount(Passport, key)
    local ok, res = pcall(vRP.InventoryItemAmount, Passport, key)
    if ok then
        if type(res) == "number" then return res end
        if type(res) == "string" then return tonumber(res) or 0 end
        if type(res) == "table" then
            local amt = res.amount or res.qtd or res.Amount or res[2]
            if type(amt) == "string" then amt = tonumber(amt) or 0 end
            if type(amt) == "number" then return amt end
        end
    end
    local ok2, has = pcall(vRP.ConsultItem, Passport, key)
    if ok2 and has then return 1 end
    return 0
end

local function ConsumeKeyOnce(Passport, key)
    if vRP.TryGetItem and vRP.TryGetItem(Passport, key, 1, true) then return true end
    if vRP.TakeItem and vRP.TakeItem(Passport, key, 1, true) then return true end

    local before = GetItemAmount(Passport, key)
    if before > 0 and vRP.RemoveItem then
        vRP.RemoveItem(Passport, key, 1, true)
        local after = GetItemAmount(Passport, key)
        if after < before then return true end
    end
    return false
end

local function FindLikelyKeysInInventory(Passport)
    local ok, inv = pcall(vRP.Inventory, Passport)
    local hits = {}
    if not ok or type(inv) ~= "table" then return hits end

    for _, it in pairs(inv) do
        local key   = it.item or it.Item or it.index or it.Index
        local label = it.name or it.Name or it.label or it.Label
        if type(key) == "string" then
            local l = key:lower() .. " " .. (type(label)=="string" and label:lower() or "")
            if l:find("race") or l:find("corrida") or l:find("cart") or l:find("descar") then
                hits[#hits+1] = key
            end
        end
    end
    return hits
end

local function ConsumeRaceTicket(Passport)
    for _, key in ipairs(RaceTicketItems) do
        if GetItemAmount(Passport, key) > 0 and ConsumeKeyOnce(Passport, key) then
            if DEBUG_RACES then print("[races] Consumido (known):", key, "pass", Passport) end
            return true, key
        end
    end
    for _, key in ipairs(RaceTicketItems) do
        if ConsumeKeyOnce(Passport, key) then
            if DEBUG_RACES then print("[races] Consumido (force-known):", key, "pass", Passport) end
            return true, key
        end
    end
    local candidates = FindLikelyKeysInInventory(Passport)
    for _, key in ipairs(candidates) do
        if ConsumeKeyOnce(Passport, key) then
            if DEBUG_RACES then print("[races] Consumido (inventário):", key, "pass", Passport) end
            return true, key
        end
    end
    return false, nil
end

local function AwardDirty(Passport, amount)
    if amount and amount > 0 then
        vRP.GenerateItem(Passport, "dirtydollar", amount, true)
        return true
    end
    return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- START
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Start(Number)
    local src      = source
    local Passport = vRP.Passport(src)
    if not Passport or not Races or not Races[Number] then
        return { ok = false, reason = "Pista inválida." }
    end

    -- cooldown
    local now = nowSec()
    if Cooldown[Passport] and Cooldown[Passport] >= now then
        local remain = Cooldown[Passport] - now
        return { ok = false, reason = "Aguarda o cooldown.", remaining = remain }
    end

    -- ticket
    local okTicket, ticketKey = ConsumeRaceTicket(Passport)
    if not okTicket then
        TriggerClientEvent("Notify", src, "Circuitos",
            ("Precisas do <b>%s</b>."):format(RaceTicketDisplayName), "amarelo", 5000)
        return { ok = false, reason = "Precisas do Cartão Descartavel." }
    end

    -- ativa corrida
    Active[Passport]    = { race = Number, startMs = msTimer() }
    PaidIndex[Passport] = 0
    RaceExplosive[Passport] = Races[Number]["Explosive"] or false

    -- cooldown e daily
    Cooldown[Passport] = now + RaceCooldownSeconds
    Daily[Passport]    = (Daily[Passport] or 0) + 1

    -- alerta polícia (se config pedir)
    if not Races[Number]["Police"] or Races[Number]["Police"] == true then
        AlertPoliceClandestine(src, Passport)
    end

    return { ok = true, explosive = RaceExplosive[Passport], used = ticketKey }
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKPOINT HIT (paga por checkpoint, 1x por ordem)
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.HitCheckpoint(Number, index)
    local src      = source
    local Passport = vRP.Passport(src)
    if not Passport then return { ok=false } end
    local st = Active[Passport]
    if not st or st.race ~= Number then return { ok=false } end

    local last = PaidIndex[Passport] or 0
    if index ~= last + 1 then
        return { ok=false, reason="ordem inválida" }
    end

    PaidIndex[Passport] = index
    AwardDirty(Passport, CheckpointReward)
    return { ok=true, reward=CheckpointReward }
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- FINISH
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Finish(Number, pointsMs)
    local src      = source
    local Passport = vRP.Passport(src)
    if not Passport or not Races or not Races[Number] then
        return { ok = false, reason = "Pista inválida." }
    end

    local st = Active[Passport]
    if not st or st.race ~= Number then
        return { ok = false, reason = "Corrida não ativa." }
    end

    -- tempo total
    local elapsed = pointsMs or (msTimer() - (st.startMs or msTimer()))
    if elapsed < 0 then elapsed = 0 end
    local secs = math.floor(elapsed / 1000)

    -- bónus por tempo (linear)
    local bonus = math.max(0, secs * FinishPerSecondBonus)

    -- experiência
    vRP.PutExperience(Passport, "Runner", ExperienceRaces)

    -- paga bónus
    AwardDirty(Passport, bonus)

    -- best time (guardar se melhora)
    local consult = vRP.Query("Races/User", { Race = Number, Passport = Passport })

    local Identity = vRP.Identity(Passport)
    local Name  = Identity and Identity.name or "aaa"
    local Name2 = Identity and Identity.name2 or ""
    local FullName = ("%s %s"):format(Name, Name2)

    local Vehicle = vRPC.VehicleName and vRPC.VehicleName(src) or "unknown"

    if consult and consult[1] then
        if elapsed < consult[1]["Points"] then
            vRP.Query("Races/Update", { Race = Number, Passport = Passport, Name = FullName, Vehicle = Vehicle, Points = elapsed })
        end
    else
        vRP.Query("Races/Insert", { Race = Number, Passport = Passport, Name = FullName, Vehicle = Vehicle, Points = elapsed })
    end

    -- limpar estado
    Active[Passport]       = nil
    PaidIndex[Passport]    = nil
    RaceExplosive[Passport]= nil

    -- notify server-side
    TriggerClientEvent("Notify", src, "Circuitos",
        ("Concluíste a corrida! ⏱️ %dm%02ds • Bónus de tempo: <b>%dx dirtydollar</b> • +%d exp."):
            format(math.floor(secs/60), secs%60, bonus, ExperienceRaces),
        "verde", 8000
    )

    return { ok = true, value = bonus, points = elapsed }
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CANCEL
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Cancel()
    local src      = source
    local Passport = vRP.Passport(src)
    if not Passport then return end

    Active[Passport]        = nil
    PaidIndex[Passport]     = nil
    RaceExplosive[Passport] = nil
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- RANKING
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Ranking(Number)
    local Ranking = {}
    if Races and Races[Number] then
        local Consult = vRP.Query("Races/Consult", { Race = Number })
        for _, v in pairs(Consult or {}) do
            local Identity = vRP.Identity(v["Passport"])
            local Name  = Identity and Identity.name  or "N/A"
            local Name2 = Identity and Identity.name2 or ""
            local Runner = ("%s %s"):format(Name, Name2)

            Ranking[#Ranking + 1] = {
                ["Runner"]  = Runner,
                ["Points"]  = NumberHours(v["Points"] / 1000),
                ["Vehicle"] = VehicleName(v["Vehicle"]) or v["Vehicle"] or "N/A"
            }
        end
    end
    return Ranking
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- EXPORT: COOLDOWN
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Cooldown", function(Passport)
    local now = nowSec()
    if Cooldown[Passport] and Cooldown[Passport] >= now then
        local remain = Cooldown[Passport] - now
        return { active = true, remaining = remain, daily = (Daily[Passport] or 0) }
    end
    return false
end)




