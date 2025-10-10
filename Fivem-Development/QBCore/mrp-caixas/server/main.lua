local QBCore = exports['qb-core']:GetCoreObject()

-- Função para obter moedas do jogador
local function GetPlayerCoins(identifier)
    local result = MySQL.scalar.await('SELECT coins FROM s_vips_coins WHERE identifier = ?', {identifier})
    if result then
        print("Moedas atuais para o jogador com identifier " .. identifier .. ": " .. result)
    else
        print("Nenhuma moeda encontrada para o jogador com identifier " .. identifier .. ". Criando novo registro.")
        MySQL.insert.await('INSERT INTO s_vips_coins (identifier, coins) VALUES (?, ?)', {identifier, 0})
        result = 0
    end
    return result
end

-- Função para atualizar moedas do jogador
local function UpdatePlayerCoins(identifier, amount)
    local success = MySQL.update.await('UPDATE s_vips_coins SET coins = ? WHERE identifier = ?', {amount, identifier})
    if success then
        print("Moedas atualizadas para " .. amount .. " para o jogador com identifier " .. identifier)
    else
        print("Erro ao atualizar moedas para o jogador com identifier " .. identifier)
    end
end

-- Função para adicionar moedas ao jogador
local function AddPlayerCoins(identifier, amount)
    local currentCoins = GetPlayerCoins(identifier)
    if currentCoins == nil then
        print("Erro ao obter as moedas atuais para o jogador com identifier " .. identifier)
        return
    end
    local newTotal = currentCoins + amount
    UpdatePlayerCoins(identifier, newTotal)
    print("Moedas atualizadas para: " .. newTotal .. " para o jogador com identifier " .. identifier)
end

-- Função para adicionar coins diretamente ao jogador
local function AddCoins(player, amount)
    local identifier = player.PlayerData.license
    if not amount or amount <= 0 then
        print("Erro: Quantidade inválida para adicionar coins ao jogador:", amount)
        return
    end

    print("Iniciando a adição de coins para o jogador com license:", identifier, "Quantidade:", amount)

    -- Adiciona moedas ao jogador
    AddPlayerCoins(identifier, amount)

    -- Verificação opcional para confirmar a adição no banco de dados
    local newCoins = GetPlayerCoins(identifier)
    if newCoins and newCoins >= amount then
        print("Coins adicionados com sucesso. Novo total:", newCoins)
    else
        print("Erro: Falha ao adicionar coins. Novo total esperado era:", newCoins)
    end
end

-- Função para escolher um item aleatório com base no peso
local function weighted_random(pool)
    local poolsize = 0
    for i = 1, #pool do
        local v = pool[i]
        poolsize = poolsize + v['weight']
    end
    local selection = math.random(poolsize)
    for i = 1, #pool do
        local v = pool[i]
        selection = selection - v['weight']
        if selection <= 0 then
            return i
        end
    end
end

CreateThread(function()
    for k, v in pairs(Config.Rewards) do
        QBCore.Functions.CreateUseableItem(k, function(source, item)
            local src = source
            local Player = QBCore.Functions.GetPlayer(src)
            if Player.Functions.RemoveItem(k, 1) then
                local random = weighted_random(Config.Rewards[k])
                local reward = Config.Rewards[k][random]

                -- Verifica se o valor de 'amount' é válido antes de prosseguir
                if reward.isCoins or reward.isMoney then
                    if not reward.amount or type(reward.amount) ~= "number" or reward.amount <= 0 then
                        print("Erro: Valor inválido de 'amount' para recompensa no item:", reward.item or "coins")
                        return
                    end
                end

                -- Define a quantidade, utilizando randomQuantity se presente
                local quantity
                if reward.randomQuantity then
                    quantity = math.random(reward.randomQuantity.min, reward.randomQuantity.max)
                else
                    quantity = reward.quantity or reward.amount or 1
                end

                -- Log para depuração
                print("Quantidade definida para o item:", reward.item or "undefined", "Quantidade:", quantity)

                SetTimeout(9500, function()
                    if reward.isMoney then
                        Player.Functions.AddMoney('cash', reward.amount)
                        TriggerClientEvent('inventory:client:ItemBox', src, {name = "cash", label = "Money", image = reward.image}, "add")
                        TriggerClientEvent('QBCore:Notify', src, 'Ganhaste $' .. reward.amount .. '!', 'success')
                    elseif reward.isCoins then
                        -- Adiciona coins diretamente na base de dados
                        print("Jogador ganhou coins:", reward.amount)
                        AddCoins(Player, reward.amount)
                        TriggerClientEvent('QBCore:Notify', src, 'Ganhaste ' .. reward.amount .. ' Coins!', 'success')
                    else
                        if Player.Functions.AddItem(reward.item, quantity) then
                            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[reward.item], "add")
                            TriggerClientEvent('QBCore:Notify', src, 'Ganhaste ' .. quantity .. 'x ' .. QBCore.Shared.Items[reward.item]['label']..'!', 'success')
                        end
                    end
                end)
                -- Certifique-se de que o item caixa foi removido corretamente
                TriggerClientEvent('qb-lootcrate:client:open', src, k, random)
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[k], "remove")
            else
                print("Erro: Falha ao remover o item caixa.")
            end
        end)
    end
end)
