
local QBCore = exports['qb-core']:GetCoreObject()

-- Função para obter moedas do jogador
local function GetPlayerCoins(identifier)
    local result = MySQL.scalar.await('SELECT coins FROM s_vips_coins WHERE identifier = ?', {identifier})
    return result or 0
end

-- Função para atualizar moedas do jogador
local function UpdatePlayerCoins(identifier, amount)
    MySQL.update('UPDATE s_vips_coins SET coins = ? WHERE identifier = ?', {amount, identifier})
end

-- Função para adicionar moedas
local function AddPlayerCoins(identifier, amount)
    local currentCoins = GetPlayerCoins(identifier)
    UpdatePlayerCoins(identifier, currentCoins + amount)
end

-- Função para remover moedas
local function RemovePlayerCoins(identifier, amount)
    local currentCoins = GetPlayerCoins(identifier)
    UpdatePlayerCoins(identifier, math.max(0, currentCoins - amount))
end

-- Callback para obter moedas do jogador
QBCore.Functions.CreateCallback('vipshop:getPlayerCoins', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local identifier = Player.PlayerData.license
        local coins = GetPlayerCoins(identifier)
        cb(coins)
    else
        cb(0)
    end
end)

-- Evento para lidar com a compra
RegisterNetEvent('vipshop:attemptPurchase', function(caseType, price, displayName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local identifier = Player.PlayerData.license

    local playerCoins = GetPlayerCoins(identifier)

    if playerCoins >= price then
        RemovePlayerCoins(identifier, price)
        Player.Functions.AddItem(caseType, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[caseType], "add")
        TriggerClientEvent('QBCore:Notify', src, "Compraste uma " .. displayName .. ".", "success")
    else
        TriggerClientEvent('QBCore:Notify', src, "Não tens moedas suficientes!", "error")
    end
end)

-- Comando para verificar moedas
QBCore.Commands.Add('checkcoins', 'Verifica quantas moedas o jogador tem.', {{name = 'id', help = 'ID do Jogador'}}, true, function(source, args)
    local targetId = tonumber(args[1])
    if targetId then
        local Player = QBCore.Functions.GetPlayer(targetId)
        if Player then
            local identifier = Player.PlayerData.license
            local coins = GetPlayerCoins(identifier)
            TriggerClientEvent('QBCore:Notify', source, 'O jogador tem ' .. coins .. ' moedas.')
        else
            TriggerClientEvent('QBCore:Notify', source, 'Jogador não encontrado.', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'ID do jogador inválido.', 'error')
    end
end, 'god')

-- Comando para adicionar moedas
QBCore.Commands.Add('addcoins', 'Adiciona moedas ao jogador.', {{name = 'id', help = 'ID do Jogador'}, {name = 'amount', help = 'Quantidade de Moedas'}}, true, function(source, args)
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    if targetId and amount then
        local Player = QBCore.Functions.GetPlayer(targetId)
        if Player then
            local identifier = Player.PlayerData.license
            AddPlayerCoins(identifier, amount)
            TriggerClientEvent('QBCore:Notify', source, 'Adicionaste ' .. amount .. ' moedas ao jogador.')
        else
            TriggerClientEvent('QBCore:Notify', source, 'Jogador não encontrado.', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'ID do jogador ou quantidade inválida.', 'error')
    end
end, 'god')

-- Comando para remover moedas
QBCore.Commands.Add('removecoins', 'Remove moedas do jogador.', {{name = 'id', help = 'ID do Jogador'}, {name = 'amount', help = 'Quantidade de Moedas'}}, true, function(source, args)
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    if targetId and amount then
        local Player = QBCore.Functions.GetPlayer(targetId)
        if Player then
            local identifier = Player.PlayerData.license
            RemovePlayerCoins(identifier, amount)
            TriggerClientEvent('QBCore:Notify', source, 'Removeste ' .. amount .. ' moedas do jogador.')
        else
            TriggerClientEvent('QBCore:Notify', source, 'Jogador não encontrado.', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'ID do jogador ou quantidade inválida.', 'error')
    end
end, 'god')
