--[[
    Syn Network - LeaveLogger (Client)
    - Envia a última posição periodicamente ao servidor (coords fiáveis no drop)
    - Desenha TEXTO 3D (sem marker) no local do disconnect durante X tempo
    - Padrão de performance: dorme mais quando não há nada para mostrar
]]

local isThreadRunning = false
local texts = {} -- { { coords=vec3, id=number, name=string, reason=string, expireAt=ms } }
local lastSent = vec3(0.0, 0.0, 0.0)

local Config = {
    Distance = 25.0,                 
    DisplayTime = 1000 * 10,     -- 🔴 10 segundos
    PositionTick = 1500,         
    MinMoveToSync = 1.0,         
    Text = {
        Template = "[%s] %s saiu do servidor.\n~w~Motivo: %s",
        Color = { r = 255, g = 0, b = 0, a = 255 }, -- 🔴 vermelho
        Font = 4,
        Scale = 0.35
    }
}

-- Desenho de texto 3D
local function draw3DText(x, y, z, msg, r, g, b, a)
    SetDrawOrigin(x, y, z, 0)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(msg)
    SetTextFont(Config.Text.Font)
    SetTextScale(Config.Text.Scale, Config.Text.Scale)
    SetTextColour(r, g, b, a)
    SetTextCentre(true)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Thread responsável por desenhar os textos ativos
local function ensureDrawThread()
    if isThreadRunning then return end
    isThreadRunning = true

    CreateThread(function()
        while true do
            local now = GetGameTimer()
            local me = PlayerPedId()
            local pCoords = GetEntityCoords(me)
            local nearAny = false

            -- Limpa expirados e desenha os válidos
            for i = #texts, 1, -1 do
                local t = texts[i]
                if t.expireAt <= now then
                    table.remove(texts, i)
                else
                    local dist = #(pCoords - t.coords)
                    if dist <= Config.Distance then
                        nearAny = true
                        local msg = string.format(Config.Text.Template, tostring(t.id), tostring(t.name), tostring(t.reason or "Desconhecido"))
                        draw3DText(t.coords.x, t.coords.y, t.coords.z - 0.5, msg, Config.Text.Color.r, Config.Text.Color.g, Config.Text.Color.b, Config.Text.Color.a)
                    end
                end
            end

            if #texts == 0 then
                isThreadRunning = false
                return
            end

            if nearAny then
                Wait(0)          -- alguém por perto? desenha a cada frame
            else
                Wait(250)        -- ninguém por perto? poupa CPU
            end
        end
    end)
end

-- Recebe pedido do servidor para mostrar o texto no local da desconexão
RegisterNetEvent("leavelogger:ShowText", function(data)
    -- data: { x, y, z, id, name, reason, duration }
    if not data or not data.x or not data.y or not data.z then return end

    local entry = {
        coords = vec3(data.x + 0.0, data.y + 0.0, data.z + 0.0),
        id = tonumber(data.id) or -1,
        name = tostring(data.name or "Desconhecido"),
        reason = tostring(data.reason or "Desconhecido"),
        expireAt = GetGameTimer() + (tonumber(data.duration) or Config.DisplayTime)
    }

    -- cap de 30 textos simultâneos para evitar poluição visual
    if #texts >= 30 then table.remove(texts, 1) end
    texts[#texts + 1] = entry
    ensureDrawThread()
end)

-- Loop de atualização de posição (para o servidor ter coords fiáveis no drop)
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if ped ~= 0 then
            local coords = GetEntityCoords(ped)
            if #(coords - lastSent) >= Config.MinMoveToSync then
                lastSent = coords
                TriggerServerEvent("leavelogger:UpdatePos", coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
            end
        end
        Wait(Config.PositionTick)
    end
end)
