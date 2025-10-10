--[[
    Syn Network - LeaveLogger (Server)
    - Guarda última posição reportada do jogador
    - No playerDropped: envia log (canal "Disconnect") e manda mostrar TEXTO 3D a todos os clientes
    - Logs no padrão Syn via exports["discord"].Embed (Markdown + emojis permitido)
]]

local lastCoords = {} -- [source] = { x=, y=, z= }

local SConfig = {
    Channel = "Disconnect",
    Color = 0xFFD166,
    DisplayTime = 1000 * 10 -- 🔴 10 segundos
}


-- Util: extrai license
local function getLicense(src)
    -- Algumas builds têm GetPlayerIdentifierByType, mas garantimos manualmente.
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:find("^license:") then
            return id
        end
    end
    return "N/D"
end

-- Util: menciona Discord se existir
local function getDiscordMention(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:find("^discord:") then
            local snowflake = id:gsub("discord:", "")
            if snowflake and snowflake ~= "" then
                return "<@" .. snowflake .. ">"
            end
        end
    end
    return "Desconhecido"
end

-- Evento: atualização periódica de posição
RegisterNetEvent("leavelogger:UpdatePos", function(x, y, z)
    local src = source
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then return end
    lastCoords[src] = { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end)

-- PLAYER DROPPED
AddEventHandler("playerDropped", function(reason)
    local src = source
    local name = GetPlayerName(src) or "Desconhecido"
    local lic = getLicense(src)
    local disc = getDiscordMention(src)
    local coords = lastCoords[src] or { x = 0.0, y = 0.0, z = 0.0 }

    -- 1) Enviar TEXTO 3D para todos os clientes
    TriggerClientEvent("leavelogger:ShowText", -1, {
        x = coords.x, y = coords.y, z = coords.z,
        id = src, name = name, reason = reason or "Desconhecido",
        duration = SConfig.DisplayTime
    })

    -- 2) Log bonito no canal "Disconnect"
    local dateUTC = os.date("!%Y-%m-%d %H:%M:%S UTC")
    local content = table.concat({
        ("**👤 Jogador:** %s"):format(name),
        ("**🆔 ID:** %s"):format(src),
        ("**🪪 License:** `%s`"):format(lic),
        ("**💬 Discord:** %s"):format(disc),
        ("**📍 Coordenadas:** X: %.2f  Y: %.2f  Z: %.2f"):format(coords.x, coords.y, coords.z),
        ("**📝 Motivo:** %s"):format(reason or "Desconhecido"),
        ("**🗓️ Data:** %s"):format(dateUTC)
    }, "\n")

    if exports["discord"] and exports["discord"].Embed then
        -- Assinatura típica: Embed(canal, titulo, descricao, cor_decimal)
        exports["discord"]:Embed(SConfig.Channel, "📤 Desconexão de jogador", content, SConfig.Color)
    else
        -- Fallback local (caso o recurso de logs não esteja ativo)
        print(("[Disconnect] %s | ID %s | %s | %s | (%.2f, %.2f, %.2f) | %s | %s"):
            format(name, src, lic, disc, coords.x, coords.y, coords.z, reason or "Desconhecido", dateUTC))
    end

    -- limpeza de memória
    lastCoords[src] = nil
end)
