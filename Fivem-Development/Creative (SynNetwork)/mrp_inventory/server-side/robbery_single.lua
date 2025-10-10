-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP / TUNNEL
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")
vRPC         = Tunnel.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- ESTADOS
-----------------------------------------------------------------------------------------------------------------------------------------
local Active         = Active or {}          -- Active[passport] = os.time() + tempo
local RobberyActive  = RobberyActive or {}   -- RobberyActive[passport] = Mode

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS / POLÍCIA (SEM SERVIÇO)
-----------------------------------------------------------------------------------------------------------------------------------------
local GrupoConfig = {
    Policia = { "LSPD", "SWAT", "FIB" } -- ✔ certifica-te que é BCSO
}

local function GetPoliceCount()
    local count = 0
    local players = vRP.Players() or {} -- [passport] = source
    for passport, _ in pairs(players) do
        for _, g in ipairs(GrupoConfig.Policia) do
            if vRP.HasGroup(passport, g) then
                count = count + 1
                break
            end
        end
    end
    return count
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SISTEMA DE NÍVEL / XP (Assaltante)
-----------------------------------------------------------------------------------------------------------------------------------------
-- Ajusta aqui os valores base por modo (XP por sucesso e multiplicadores de dinheiro)
local Leveling = {
    XP = {
        Ammunation = 10,
        Department = 7,
        Eletronic  = 5
    },
    -- Retorna multiplicadores por nível (ex.: dinheiro ↑ com o nível)
    -- Se já tiveres uma API vRP.AddExperience/Level, usa-a. Aqui só exemplo de leitura do bônus.
    GetBonus = function(passport)
        -- Substitui isto pela tua API real de leitura de bónus
        -- Ex.: local lvl = vRP.GetExperienceLevel(passport,"Assaltante")
        -- money_mult pode crescer com o nível; time_mult não é aplicado aqui (server-side progress fixo)
        local money_mult = 1.0
        return { money_mult = money_mult }
    end
}

local function AddRobberyXP(passport, mode)
    local xp = Leveling.XP[mode] or 15
    if vRP.AddExperience then
        vRP.AddExperience(passport, "Assaltante", xp)
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PAY (sempre direto — sem chest)
-----------------------------------------------------------------------------------------------------------------------------------------
local function PayDirect(Passport, Payment, money_mult)
    if not Payment or not Payment.List then return { summary = {}, totalDirty = 0 } end

    local mMin = (Payment.Multiplier and Payment.Multiplier.Min) or 1
    local mMax = (Payment.Multiplier and Payment.Multiplier.Max) or 1
    local multRandom = math.random(mMin, mMax)
    local appliedMult = (money_mult or 1.0) * multRandom

    local summary, totalDirty = {}, 0

    for _, entry in ipairs(Payment.List) do
        local chance = entry.Chance or 100
        if math.random(100) <= chance then
            local item  = entry.Item
            local minA  = entry.Min or 1
            local maxA  = entry.Max or minA
            local amount = math.floor((math.random(minA, maxA) * appliedMult) + 0.5)

            if amount > 0 then
                vRP.GiveItem(Passport, item, amount, true)

                -- resumo p/ log
                summary[item] = (summary[item] or 0) + amount
                if item == "dirtydollar" then
                    totalDirty = totalDirty + amount
                end
            end
        end
    end

    return { summary = summary, totalDirty = totalDirty }
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOG DISCORD (canal "Assaltos")
-----------------------------------------------------------------------------------------------------------------------------------------
local function LogAssalto(src, passport, modeName, pointNumber, payInfo)
    local fullName = vRP.FullName(passport) or ("Passaporte "..passport)
    local itemsTxt = {}
    for item, qtd in pairs(payInfo.summary or {}) do
        itemsTxt[#itemsTxt+1] = ("• **%s** x **%s**"):format(item, qtd)
    end
    local itemsBlock = (#itemsTxt > 0) and table.concat(itemsTxt, "\n") or "• *(sem itens)*"

    local msg = ([[**💰 Assalto Concluído**  
👤 **%s** (#%s)  
🏪 **Alvo:** %s (ponto %s)

📦 **Itens:**
%s

💵 **Valor sujo total:** **%s**]]):format(fullName, passport, modeName, pointNumber, itemsBlock, payInfo.totalDirty or 0)

    if exports["discord"] and exports["discord"].Embed then
        exports["discord"]:Embed("Assaltos", msg, src)
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- NOTIFY HELPER
-----------------------------------------------------------------------------------------------------------------------------------------
local function Notify(src, titulo, mensagem, cor, tempo)
    TriggerClientEvent("Notify", src, titulo, mensagem, cor or "azul", tempo or 5000)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local Config = {
    ["Ammunation"] = {
        Last = 1,
        Police = 1,
        Timer = 60,
        Wanted = 1800,
        Delay = 3600,
        Active = false,
        Cooldown = os.time(),
        Name = "Ammunation",
        Residual = "Resquício de Línter",
        Payment = {
            Multiplier = { Min = 1, Max = 1 },
            List = {
                { Item = "dirtydollar",       Chance = 100, Min = 125000, Max = 175000 },
                { Item = "WEAPON_SMG",        Chance = 5,   Min = 1,    Max = 1    },
                { Item = "WEAPON_PISTOL",     Chance = 10,   Min = 1,    Max = 1    },
                { Item = "WEAPON_PISTOL_AMMO",Chance = 20,  Min = 60,   Max = 180  },
                { Item = "WEAPON_SMG_AMMO",   Chance = 20,  Min = 30,   Max = 120  }
            }
        },
        Need = { Amount = 1, Consume = false, Item = "lockpick" },
        Animation = { Dict = "mini@safe_cracking", Name = "dial_turn_anti_fast_1" }
    },

    ["Department"] = {
        Last = 1,
        Police = 1,
        Timer = 60,
        Wanted = 1800,
        Delay = 3600,
        Active = false,
        Cooldown = os.time(),
        Name = "Lojinha",
        Residual = "Resquício de Línter",
        Payment = {
            Multiplier = { Min = 1, Max = 1 },
            List = {
                { Item = "dirtydollar", Chance = 100, Min = 52250, Max = 85000 },
                { Item = "diamond_pure",Chance = 15,  Min = 3,    Max = 30   }
            }
        },
        Need = { Amount = 1, Consume = false, Item = "lockpick" },
        Animation = { Dict = "mini@safe_cracking", Name = "dial_turn_anti_fast_1" }
    },

    ["Eletronic"] = {
        Last = 1,
        Police = 1,
        Timer = 30,
        Wanted = 600,
        Delay = 900,
        Active = false,
        Cooldown = os.time(),
        Name = "Caixa Eletrônico",
        Residual = "Resquício de Línter",
        Payment = {
            Multiplier = { Min = 1, Max = 1 },
            List = {
                { Item = "dirtydollar", Chance = 100, Min = 25000, Max = 57500 },
            }
        },
        Need = { Amount = 1, Consume = false, Item = "safependrive" },
        Animation = { Dict = "oddjobs@shop_robbery@rob_till", Name = "loop" }
    }
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:ROBBERYSINGLEACTIVE (reset externo)
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("inventory:RobberySingleActive", function(Mode)
    if Config[Mode] and Config[Mode].Active then
        Config[Mode].Active = false
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CANCEL / CLEANUP
-----------------------------------------------------------------------------------------------------------------------------------------
local function CancelRobbery(src, passport, Mode)
    if Active[passport] then
        Active[passport] = nil
    end
    if RobberyActive[passport] then
        RobberyActive[passport] = nil
    end
    if Config[Mode] and Config[Mode].Active == passport then
        Config[Mode].Active = false
    end
    if src then
        Player(src)["state"]["Buttons"] = false
        vRPC.Destroy(src)
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:ROBBERYSINGLE (principal)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:RobberySingle")
AddEventHandler("inventory:RobberySingle", function(Number, Mode)
    local src = source
    local Passport = vRP.Passport(src)
    Number = tonumber(Number)

    if not Passport or not Number or Number < 1 or Number > 9999 then
        if src then Notify(src, "Atenção", "Ponto de roubo inválido.", "amarelo", 5000) end
        return
    end
    if not Config[Mode] then return end
    if Active[Passport] then return end
    if Config[Mode].Active then return end

    -- polícia
    local policeRequirement = Config[Mode].Police or 0
    if policeRequirement > 0 and GetPoliceCount() < policeRequirement then
        Notify(src, "Atenção", "Contingente indisponível.", "amarelo", 5000)
        return
    end

    -- item necessário
    local need = Config[Mode].Need
    if need then
        local needItem   = need.Item
        local needAmount = need.Amount or 1
        if not vRP.ConsultItem(Passport, needItem, needAmount) then
            Notify(src, "Atenção", ("Precisa de <b>%dx %s</b>."):format(needAmount, ItemName(needItem)), "amarelo", 5000)
            return
        end
    end

    -- cooldown
    local cooldown = Config[Mode].Cooldown or 0
    if cooldown > os.time() then
        if Config[Mode].Last == Number then
            Notify(src, "Atenção", "Este ponto ainda está em cooldown.", "amarelo", 4000)
        else
            Notify(src, "Atenção", "Aguarde "..CompleteTimers(cooldown - os.time())..".", "amarelo", 5000)
        end
        return
    end

    -- ativar roubo
    RobberyActive[Passport] = Mode
    Config[Mode].Active = Passport
    Player(src)["state"]["Buttons"] = true
    
    -- aviso polícia IMEDIATO
    if exports["vrp"] and exports["vrp"].CallPolice then
        exports["vrp"]:CallPolice({
            ["Source"]     = src,
            ["Passport"]   = Passport,
            ["Permission"] = "Policia",
            ["Name"]       = Config[Mode].Name,
            ["Percentage"] = 0, -- 0% porque o assalto só iniciou
            ["Wanted"]     = Config[Mode].Wanted,
            ["Code"]       = 31,
            ["Color"]      = 46 -- cor diferente para "em andamento" (pode ajustar)
        })
    end
    
    local totalTime = Config[Mode].Timer
    Active[Passport] = os.time() + totalTime

    TriggerClientEvent("player:Residual", src, Config[Mode].Residual)
    TriggerClientEvent("Progress", src, "Roubando", totalTime * 1000)
    vRPC.playAnim(src, false, { Config[Mode].Animation.Dict, Config[Mode].Animation.Name }, true)

    -- loop de progresso (anti-F6 reaplica animação a cada ~2s)
    CreateThread(function()
        local nextAnimTick = GetGameTimer() + 1900
        while Active[Passport] do
            if GetGameTimer() >= nextAnimTick then
                nextAnimTick = GetGameTimer() + 1900
                vRPC.playAnim(src, false, { Config[Mode].Animation.Dict, Config[Mode].Animation.Name }, true)
            end
            if os.time() >= Active[Passport] then
                break
            end
            Wait(150)
        end

        if not Active[Passport] then
            -- foi cancelado por alguma razão externa
            CancelRobbery(src, Passport, Mode)
            return
        end

        -- fim do progresso (SUCESSO)
        vRPC.Destroy(src)
        Active[Passport] = nil
        Player(src)["state"]["Buttons"] = false

        -- consumir item se configurado
        if need and need.Consume then
            local needItem   = need.Item
            local needAmount = need.Amount or 1
            if not vRP.TakeItem(Passport, needItem, needAmount) then
                CancelRobbery(src, Passport, Mode)
                return
            end
        end

        -- bónus por nível (dinheiro)
        local bonus = Leveling.GetBonus(Passport)
        local money_mult = (bonus and bonus.money_mult) or 1.0

        -- pagamento direto
        local payInfo = PayDirect(Passport, Config[Mode].Payment, money_mult)

        -- XP
        AddRobberyXP(Passport, Mode)

        -- cooldown e reset
        Config[Mode].Last     = Number
        Config[Mode].Active   = false
        Config[Mode].Cooldown = os.time() + (Config[Mode].Delay or 600)
        RobberyActive[Passport] = nil

        -- logs + notify
        LogAssalto(src, Passport, Config[Mode].Name, Number, payInfo)
        Notify(src, Config[Mode].Name, "Assalto <b>concluído</b> com sucesso!", "verde", 5500)
    end)
end)
