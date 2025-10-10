-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local Config = {
    Helicrash = {
        -- Cooldown opcional por baú recém criado (se o teu chest usar cooldown por key)
        SpawnCooldownSeconds = 0
    },
    Cycle = {
        ActiveSeconds   = 3600, -- 1h ativo
        InactiveSeconds = 21600  -- 1h inativo até cair de novo
    }
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE / VARS
-----------------------------------------------------------------------------------------------------------------------------------------
GlobalState["Helicrash"] = false
GlobalState["Helibox"]   = 0

local LootBoxes     = 0
local ActiveSince   = 0  -- momento em que começou o helicrash atual
local LastCrashAt   = 0  -- momento em que terminou (para contar a inatividade)
local _tickRunning  = false

-- LOG HELPER (Discord -> sala "Airdrop")
local function LogAirdrop(title, lines)
    if exports["discord"] and exports["discord"].Embed then
        local body = title
        if lines and #lines > 0 then body = body.."\n\n"..table.concat(lines, "\n") end
        exports["discord"]:Embed("Helicrash", body)
    end
end


-- Helper: extrai coords de vector3 OU de tabela {x=,y=,z=} OU {x,y,z}
local function CoordsOf(pos)
    if type(pos) == "vector3" then
        return (pos.x + 0.0), (pos.y + 0.0), (pos.z + 0.0)
    elseif type(pos) == "table" then
        local x = tonumber(pos.x or pos[1]) or 0.0
        local y = tonumber(pos.y or pos[2]) or 0.0
        local z = tonumber(pos.z or pos[3]) or 0.0
        return x, y, z
    end
    return nil, nil, nil
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOOTS (mantidos)
-----------------------------------------------------------------------------------------------------------------------------------------
local Loots = {
    { ["1"]={item="analgesic",amount=4}, ["2"]={item="meth",amount=4}, ["3"]={item="gauze",amount=4},
      ["4"]={item="WEAPON_PISTOL50-"..os.time(),amount=1}, ["5"]={item="WEAPON_PISTOL_AMMO",amount=100}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=4}, ["2"]={item="meth",amount=4}, ["3"]={item="gauze",amount=4},
      ["4"]={item="WEAPON_SNSPISTOL-"..os.time(),amount=1}, ["5"]={item="WEAPON_PISTOL_AMMO",amount=100}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=4}, ["2"]={item="meth",amount=4}, ["3"]={item="gauze",amount=4},
      ["4"]={item="WEAPON_VINTAGEPISTOL-"..os.time(),amount=1}, ["5"]={item="WEAPON_PISTOL_AMMO",amount=100}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=4}, ["2"]={item="meth",amount=4}, ["3"]={item="gauze",amount=4},
      ["4"]={item="WEAPON_PISTOL_MK2-"..os.time(),amount=1}, ["5"]={item="WEAPON_PISTOL_AMMO",amount=100}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=4}, ["2"]={item="meth",amount=4}, ["3"]={item="gauze",amount=4},
      ["4"]={item="WEAPON_SNSPISTOL_MK2-"..os.time(),amount=1}, ["5"]={item="WEAPON_PISTOL_AMMO",amount=100}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=3}, ["2"]={item="meth",amount=3}, ["3"]={item="gauze",amount=3},
      ["4"]={item="WEAPON_MACHINEPISTOL-"..os.time(),amount=1}, ["5"]={item="WEAPON_SMG_AMMO",amount=100}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=3}, ["2"]={item="meth",amount=3}, ["3"]={item="gauze",amount=3},
      ["4"]={item="WEAPON_MICROSMG-"..os.time(),amount=1}, ["5"]={item="WEAPON_SMG_AMMO",amount=100}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=3}, ["2"]={item="meth",amount=3}, ["3"]={item="gauze",amount=3},
      ["4"]={item="WEAPON_ASSAULTSMG-"..os.time(),amount=1}, ["5"]={item="WEAPON_SMG_AMMO",amount=100}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=3}, ["2"]={item="meth",amount=3}, ["3"]={item="gauze",amount=3},
      ["4"]={item="WEAPON_MINISMG-"..os.time(),amount=1}, ["5"]={item="WEAPON_SMG_AMMO",amount=100}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=3}, ["2"]={item="meth",amount=3}, ["3"]={item="gauze",amount=3},
      ["4"]={item="WEAPON_SMG_MK2-"..os.time(),amount=1}, ["5"]={item="WEAPON_SMG_AMMO",amount=100}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=3}, ["2"]={item="meth",amount=3}, ["3"]={item="gauze",amount=3},
      ["4"]={item="WEAPON_APPISTOL-"..os.time(),amount=1}, ["5"]={item="WEAPON_SMG_AMMO",amount=100}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=2}, ["2"]={item="meth",amount=2}, ["3"]={item="gauze",amount=2},
      ["4"]={item="WEAPON_ADVANCEDRIFLE-"..os.time(),amount=1}, ["5"]={item="WEAPON_RIFLE_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=2}, ["2"]={item="meth",amount=2}, ["3"]={item="gauze",amount=2},
      ["4"]={item="WEAPON_COMPACTRIFLE-"..os.time(),amount=1}, ["5"]={item="WEAPON_RIFLE_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=2}, ["2"]={item="meth",amount=2}, ["3"]={item="gauze",amount=2},
      ["4"]={item="WEAPON_PISTOL_MK2-"..os.time(),amount=1}, ["5"]={item="WEAPON_RIFLE_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=2}, ["2"]={item="meth",amount=2}, ["3"]={item="gauze",amount=2},
      ["4"]={item="WEAPON_BULLPUPRIFLE-"..os.time(),amount=1}, ["5"]={item="WEAPON_RIFLE_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=2}, ["2"]={item="meth",amount=2}, ["3"]={item="gauze",amount=2},
      ["4"]={item="WEAPON_ASSAULTRIFLE-"..os.time(),amount=1}, ["5"]={item="WEAPON_RIFLE_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=2}, ["2"]={item="meth",amount=2}, ["3"]={item="gauze",amount=2},
      ["4"]={item="WEAPON_HEAVYRIFLE-"..os.time(),amount=1}, ["5"]={item="WEAPON_RIFLE_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=2}, ["2"]={item="meth",amount=2}, ["3"]={item="gauze",amount=2},
      ["4"]={item="WEAPON_ASSAULTRIFLE-"..os.time(),amount=1}, ["5"]={item="WEAPON_RIFLE_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=2}, ["2"]={item="meth",amount=2}, ["3"]={item="gauze",amount=2},
      ["4"]={item="WEAPON_SPECIALCARBINE-"..os.time(),amount=1}, ["5"]={item="WEAPON_RIFLE_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=2}, ["2"]={item="meth",amount=2}, ["3"]={item="gauze",amount=2},
      ["4"]={item="WEAPON_SPECIALCARBINE_MK2-"..os.time(),amount=1}, ["5"]={item="WEAPON_RIFLE_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=2}, ["2"]={item="meth",amount=2}, ["3"]={item="gauze",amount=2},
      ["4"]={item="WEAPON_SPECIALCARBINE_MK2-"..os.time(),amount=1}, ["5"]={item="WEAPON_RIFLE_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=2}, ["2"]={item="meth",amount=2}, ["3"]={item="gauze",amount=2},
      ["4"]={item="WEAPON_SPECIALCARBINE_MK2-"..os.time(),amount=1}, ["5"]={item="WEAPON_RIFLE_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=3}, ["2"]={item="meth",amount=3}, ["3"]={item="gauze",amount=3},
      ["4"]={item="WEAPON_GUSENBERG-"..os.time(),amount=1}, ["5"]={item="WEAPON_SMG_AMMO",amount=120}, ["6"]={item="dollar",amount=10000} },
    { ["1"]={item="analgesic",amount=4}, ["2"]={item="meth",amount=4}, ["3"]={item="gauze",amount=4},
      ["4"]={item="WEAPON_GUSENBERG-"..os.time(),amount=1}, ["5"]={item="WEAPON_SMG_AMMO",amount=90}, ["6"]={item="dollar",amount=10000} }
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- START (com logs "Airdrop")
-----------------------------------------------------------------------------------------------------------------------------------------
local function startHelicrash(Selected)
    LootBoxes   = 0
    ActiveSince = os.time()

    local logLines = {
        ("🗺️ **Mapa/Componente:** #%d"):format(Selected),
        ("⏱️ **Ativo por:** %d min"):format((Config.Cycle.ActiveSeconds or 0) / 60)
    }

    for Number, data in pairs(Components[Selected]) do
        if Number ~= "1" then
            LootBoxes = LootBoxes + 1

            local Loot = math.random(#Loots)
            vRP.SetSrvData("Helicrash:"..Number, Loots[Loot], true)
          
            local x, y, z = CoordsOf(data)
            if x and y and z then
                table.insert(logLines, ("• Caixa **%s** → (%.2f, %.2f, %.2f)"):format(tostring(Number), x, y, z))
            else
                table.insert(logLines, ("• Caixa **%s**"):format(tostring(Number)))
            end
        end
    end

    GlobalState["Helibox"]   = LootBoxes
    GlobalState["Helicrash"] = Selected

    -- 🔵 Aviso global + LOG
    TriggerClientEvent("Notify",-1,"Queda de Aeronave","Mayday! Mayday! Problemas críticos nos motores. Suprimentos espalhados no local do impacto!","azul",30000)

    table.insert(logLines, 1, ("🚁 **HELICRASH INICIADO**"))
    table.insert(logLines,     ("📦 **Caixas:** %d"):format(LootBoxes))
    table.insert(logLines,     ("🕒 **Início:** %s"):format(os.date("%d/%m/%Y %H:%M")))
    LogAirdrop("🚁 HELICRASH INICIADO", logLines)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- STOP (com logs "Airdrop")
-----------------------------------------------------------------------------------------------------------------------------------------
local function stopHelicrash(reason)
    if GlobalState["Helicrash"] then
        local selected  = GlobalState["Helicrash"]
        local remaining = GlobalState["Helibox"] or 0

        GlobalState["Helicrash"] = false
        GlobalState["Helibox"]   = 0
        LootBoxes   = 0
        LastCrashAt = os.time()

        -- 🔵 Aviso global
        TriggerClientEvent("Notify",-1,"Queda de Aeronave","Todos os suprimentos foram saqueados ou o tempo expirou.","azul",20000)

        -- 🟣 LOG
        local lines = {
            ("🗺️ **Mapa/Componente:** #%d"):format(selected or -1),
            ("📦 **Restantes ao terminar:** %d"):format(remaining),
            ("🕒 **Fim:** %s"):format(os.date("%d/%m/%Y %H:%M"))
        }
        if reason == "saqueado" then
            table.insert(lines, 2, "✅ **Motivo:** Todas as caixas foram saqueadas")
        elseif reason == "tempo" then
            table.insert(lines, 2, "⏳ **Motivo:** Tempo ativo expirou")
        else
            table.insert(lines, 2, "ℹ️ **Motivo:** Encerrado")
        end
        LogAirdrop("🟪 HELICRASH ENCERRADO", lines)
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- MAIN TICK (ciclo horário)
-----------------------------------------------------------------------------------------------------------------------------------------
local function MainTick()
    if _tickRunning then return end
    _tickRunning = true

    CreateThread(function()
        while true do
            local now = os.time()

            if GlobalState["Helicrash"] then
                -- ativo: fecha por tempo
                if (now - ActiveSince) >= Config.Cycle.ActiveSeconds then
                    -- ⚠️ ALTERAÇÃO: garantir motivo "tempo" no log e respeitar janela inativa de 1h
                    stopHelicrash("tempo")
                end
            else
                -- inativo: abre por tempo
                if (now - LastCrashAt) >= Config.Cycle.InactiveSeconds then
                    local Selected = math.random(#Components)
                    startHelicrash(Selected)
                end
            end

            Wait(15000) -- 15s de resolução é suficiente para este ciclo
        end
    end)
end
MainTick()

-----------------------------------------------------------------------------------------------------------------------------------------
-- (Opcional) AVISOS PROGRAMADOS - mantidos, mas o ciclo horário já garante spawn por tempo
-----------------------------------------------------------------------------------------------------------------------------------------
local function TimedNotifiesTick()
    SetTimeout(30000, function()
        local hm = os.date("%H:%M")
        if TimersNotify and TimersNotify[hm] then
            TriggerClientEvent("Notify",-1,"Queda de Aeronave","A torre de controlo reporta uma aeronave em queda. Impacto em ~5 minutos.","azul",30000)
        end
        -- Timers (se quiseres avisos/forçar perto da hora), mas o ciclo principal é quem manda.
        TimedNotifiesTick()
    end)
end
TimedNotifiesTick()

-----------------------------------------------------------------------------------------------------------------------------------------
-- ADMIN: FORÇAR (encerra o atual se existir e inicia um novo)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("helicrash", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport or not vRP.HasGroup(Passport,"Admin") then
        if source > 0 then
            TriggerClientEvent("Notify",source,"Queda de Aeronave","Sem permissão para usar este comando.","vermelho",5000)
        end
        return
    end

    local Selected
    if args and args[1] and Components[tonumber(args[1])] then
        Selected = tonumber(args[1])
    else
        Selected = math.random(#Components)
    end

    local wasActive = (GlobalState["Helicrash"] and GlobalState["Helicrash"] ~= false)

    -- se estiver ativo, encerra já o atual (motivo admin)
    if wasActive then
        stopHelicrash("admin")
    end

    -- inicia novo
    startHelicrash(Selected)

    -- notify ao staff que usou
    if wasActive then
        TriggerClientEvent("Notify",source,"Queda de Aeronave","Evento anterior <b>encerrado</b>. Novo helicrash <b>forçado</b> e blip criado no mapa.","verde",6000)
    else
        TriggerClientEvent("Notify",source,"Queda de Aeronave","Evento <b>forçado</b> com sucesso. Blip criado no mapa.","verde",6000)
    end

    -- log na sala Airdrop
    if LogAirdrop then
        local name = vRP.FullName(Passport) or "Indefinido"
        LogAirdrop("🛠️ HELICRASH FORÇADO (Admin)", {
            ("👮 **Staff:** %s (%s)"):format(name, Passport),
            ("🗺️ **Mapa/Componente:** #%d"):format(Selected),
            wasActive and "♻️ **Ação:** Encerrado o evento anterior e iniciado um novo" or "🚀 **Ação:** Iniciado novo evento",
            ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M"))
        })
    end
end)
