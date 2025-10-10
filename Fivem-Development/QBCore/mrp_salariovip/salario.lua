local QBCore = exports['qb-core']:GetCoreObject()

-- Load configuration
local Config = Config or {}

-- Function to get VIP status
local function getVipStatus(playerId)
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    local result = MySQL.Sync.fetchScalar('SELECT vip_status FROM players WHERE citizenid = ?', {xPlayer.PlayerData.citizenid})
    return result
end

-- Function to set VIP status
local function setVipStatus(playerId, vipStatus)
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    MySQL.Sync.execute('UPDATE players SET vip_status = ? WHERE citizenid = ?', {vipStatus, xPlayer.PlayerData.citizenid})
end

-- Function to get VIP salary
local function getVipSalary(vipStatus)
    return Config.Salaries[vipStatus] or Config.Salaries.default
end

-- Function to give VIP salary
local function giveVipSalary()
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local vipStatus = getVipStatus(playerId)
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        local salary = getVipSalary(vipStatus)

        if salary > 0 then
            xPlayer.Functions.AddMoney('bank', salary)
            QBCore.Functions.Notify(playerId, 'Recebeste o teu salário VIP de $' .. salary, 'success')
        end
    end
end

-- Timer for salary
CreateThread(function()
    while true do
        Wait(Config.PaymentInterval)
        giveVipSalary()
    end
end)

-- Function to check if a player is allowed to set VIP
local function isAllowedToSetVIP(citizenid)
    for _, id in ipairs(Config.AllowedVIPSetters) do
        if id == citizenid then
            return true
        end
    end
    return false
end

-- Command to set VIP
QBCore.Commands.Add('setvip', 'Definir status vip para jogador', {{name = 'id', help = 'Player ID'}, {name = 'status', help = 'VIP Status'}}, true, function(source, args)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if isAllowedToSetVIP(xPlayer.PlayerData.citizenid) then
        local targetId = tonumber(args[1])
        local vipStatus = args[2]
        if targetId and vipStatus then
            setVipStatus(targetId, vipStatus)
            QBCore.Functions.Notify(src, 'VIP status definido!', 'success')
        else
            QBCore.Functions.Notify(src, 'Usage: /setvip [playerId] [vipStatus]', 'error')
        end
    else
        QBCore.Functions.Notify(src, 'Não tens permissão!', 'error')
    end
end)

-- Command to force pay
QBCore.Commands.Add('forcepay', 'Forçar pagamentos VIP', {}, true, function(source)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if isAllowedToSetVIP(xPlayer.PlayerData.citizenid) then
        giveVipSalary()
        QBCore.Functions.Notify(src, 'Salarios VIP Pagos!', 'success')
    else
        QBCore.Functions.Notify(src, 'Não tens permissão!', 'error')
    end
end)

-- Command to check VIP and salary
QBCore.Commands.Add('vervip', 'Verificar o teu VIP e respectivo salário.', {}, true, function(source)
    local src = source
    local vipStatus = getVipStatus(src)
    local salary = getVipSalary(vipStatus)

    if vipStatus then
        QBCore.Functions.Notify(src, 'O teu VIP é ' .. (vipStatus or 'None') .. ' e o teu salário é $' .. salary, 'success')
    else
        QBCore.Functions.Notify(src, 'Não conseguimos verificar o teu VIP.', 'error')
    end
end)
