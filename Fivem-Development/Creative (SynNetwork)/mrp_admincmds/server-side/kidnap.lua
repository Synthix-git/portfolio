-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function isOnline(src)
    return src and GetPlayerName(src) ~= nil
end

local function notify(src, title, message, color, time)
    -- padrão Syn Network: TriggerClientEvent("Notify", src, titulo, mensagem, cor, tempo)
    if src and src > 0 then
        TriggerClientEvent("Notify", src, title or "Info", message or "", color or "amarelo", time or 5000)
    else
        print(("[Notify:%s] %s"):format(title or "Info", message or ""))
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- KIDNAP (kick por staff ou consola) — PASSAPORTE in-game / SOURCE na consola
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("kidnap", function(source, args)
    if source > 0 then
        ---------------------------------------------------------------------
        -- IN-GAME (usa PASSAPORTE)
        ---------------------------------------------------------------------
        local staffPassport = vRP.Passport(source)
        if not staffPassport then
            print("[KIDNAP] Falha ao obter passaporte do staff (source "..tostring(source)..").")
            return
        end

        if not vRP.HasPermission(staffPassport, "Admin", 2) then
            notify(source, "Kick", "Sem permissão.", "vermelho", 5000)
            return
        end

        local arg = args and args[1]
        local targetPassport = tonumber(arg or "")
        if not targetPassport then
            notify(source, "Kick", "Uso: /kidnap <passaporte>", "amarelo", 6000)
            return
        end

        local targetSrc = vRP.Source(targetPassport)
        if not isOnline(targetSrc) then
            notify(source, "Kick", "Jogador offline.", "vermelho", 6000)
            return
        end

        -- Cena/anim do lado do client (se existir esse handler)
        TriggerClientEvent("kick:ilv-scripts:KickKidnapScene", targetSrc)

        -- Kick após 10s
        SetTimeout(10000, function()
            if isOnline(targetSrc) then
                DropPlayer(targetSrc, "Foste raptado e expulso do servidor.")
            end
        end)

        print(("[KIDNAP] Passaporte %s kickado pelo staff Passaporte %s."):format(targetPassport, staffPassport))
        notify(source, "Kick", "Jogador será removido em 10 segundos.", "verde", 5000)

    else
        ---------------------------------------------------------------------
        -- CONSOLA (usa SOURCE diretamente)
        ---------------------------------------------------------------------
        local targetSrc = tonumber(args and args[1] or "")
        if not isOnline(targetSrc) then
            print("^1[ERRO] Uso: kidnap <source> (consola) | ID inválido/offline.^0")
            return
        end

        TriggerClientEvent("kick:ilv-scripts:KickKidnapScene", targetSrc)

        SetTimeout(10000, function()
            if isOnline(targetSrc) then
                DropPlayer(targetSrc, "Foste raptado e expulso do servidor (consola).")
            end
        end)

        print(("^2[KIDNAP] Source %s kickado pela consola.^0"):format(targetSrc))
    end
end)
