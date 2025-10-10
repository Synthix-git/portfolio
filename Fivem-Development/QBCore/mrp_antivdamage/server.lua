
-- Configuração
local tempoServico = 100 -- tempo em segundos para enviar novos jogadores que cometam VDM para o serviço comunitário
local limiteTempoJogo = 3600 -- 1 hora em segundos, para definir "novo jogador"
local discordWebhookURL = "https://discord.com/api/webhooks/your-webhook-id/your-webhook-token" -- Substituir pelo URL do webhook do Discord

-- Função para verificar se um jogador é novo com base no tempo de jogo
function eNovoJogador(source)
    local tempoJogo = exports['qb-core']:GetPlayerPlaytime(source)
    return tempoJogo < limiteTempoJogo
end

-- Função para enviar o jogador para serviço comunitário
function enviarParaServicoComunitario(source, tempoServico)
    local Jogador = QBCore.Functions.GetPlayer(source)
    if Jogador then
        TriggerEvent('qb-communityservice:sendToCommunityService', source, tempoServico)
        print("O jogador " .. GetPlayerName(source) .. " foi enviado para serviço comunitário por VDM.")
    end
end

-- Função para curar ou reanimar a vítima
function curarOuReanimarVitima(vitima)
    if GetEntityHealth(vitima) <= 0 then
        TriggerClientEvent('hospital:client:Revive', vitima)
    else
        TriggerClientEvent('hospital:client:HealInjuries', vitima, 'full')
    end
end

-- Função para enviar uma mensagem de log para o Discord
function enviarParaDiscord(titulo, descricao, cor)
    local embed = {
        {
            ["title"] = titulo,
            ["description"] = descricao,
            ["color"] = cor,
            ["footer"] = {
                ["text"] = os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }

    PerformHttpRequest(discordWebhookURL, function(err, text, headers) end, 'POST', json.encode({username = "Anti VDM Logger", embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- Manipulador de eventos para dano ao jogador
AddEventHandler('gameEventTriggered', function(eventName, args)
    if eventName == "CEventNetworkEntityDamage" then
        local vitima = args[1]
        local atacante = args[2]
        local weaponHash = args[5]

        if IsPedAPlayer(atacante) and IsPedInAnyVehicle(atacante, false) then
            local source = NetworkGetEntityOwner(atacante)

            if eNovoJogador(source) then
                -- Enviar o novo jogador para serviço comunitário
                enviarParaServicoComunitario(source, tempoServico)

                -- Curar ou reanimar a vítima, caso tenha sido ferida ou morta
                if IsPedAPlayer(vitima) then
                    curarOuReanimarVitima(NetworkGetEntityOwner(vitima))
                end

                -- Enviar log para o Discord
                local nomeVitima = GetPlayerName(NetworkGetEntityOwner(vitima))
                local nomeAtacante = GetPlayerName(source)
                local tituloLog = "Incidente de VDM Detetado"
                local descricaoLog = "O jogador **" .. nomeAtacante .. "** (ID: " .. source .. ") foi enviado para serviço comunitário por VDM.\nVítima: **" .. nomeVitima .. "** (ID: " .. NetworkGetEntityOwner(vitima) .. ")."
                enviarParaDiscord(tituloLog, descricaoLog, 15158332) -- Cor vermelha
            end
        end
    end
end)
