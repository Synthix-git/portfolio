local QBCore = exports['qb-core']:GetCoreObject()

-- Coordenadas para o NPC
local npcCoords = vector4(-272.03, -705.15, 38.28, 282.0)

-- Criação do NPC e configuração do qb-target
CreateThread(function()
    RequestModel(`a_m_m_business_01`)
    while not HasModelLoaded(`a_m_m_business_01`) do
        Wait(1)
    end

    local npc = CreatePed(4, `a_m_m_business_01`, npcCoords.x, npcCoords.y, npcCoords.z - 1.0, npcCoords.w, false, true)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    
    -- Adicionar o NPC ao qb-target
    exports['qb-target']:AddTargetEntity(npc, {
        options = {
            {
                type = "client",
                event = "vipshop:openShop",
                icon = "fas fa-store",
                label = "Abrir Loja VIP",
                distance = 3.0, -- Distância para interação
            },
        },
        distance = 3.0 -- Distância máxima para a interação
    })
    
    -- Criação do Blip
    local blip = AddBlipForCoord(npcCoords.x, npcCoords.y, npcCoords.z)
    SetBlipSprite(blip, 605)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.5)
    SetBlipColour(blip, 2)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Loja VIP")
    EndTextCommandSetBlipName(blip)
end)

-- Evento para abrir a loja
RegisterNetEvent('vipshop:openShop', function()
    local menu = {
        {
            header = "Loja VIP",
            isMenuHeader = true
        },
    }

    QBCore.Functions.TriggerCallback('vipshop:getPlayerCoins', function(coins)
        table.insert(menu, {
            header = "Você tem " .. coins .. " moedas",
            isMenuHeader = true
        })

        for _, item in ipairs(Config.Items) do
            table.insert(menu, {
                header = "Comprar " .. item.displayName,
                txt = "Custa " .. item.price .. " moedas",
                icon = item.icon,
                params = {
                    event = "vipshop:buyCase",
                    args = {
                        caseType = item.name,
                        price = item.price,
                        displayName = item.displayName
                    }
                }
            })
        end

        table.insert(menu, {
            header = "Fechar Menu",
            txt = "",
            params = {
                event = "qb-menu:closeMenu"
            }
        })

        exports['qb-menu']:openMenu(menu)
    end)
end)

-- Trigger para evento de compra
RegisterNetEvent('vipshop:buyCase', function(data)
    TriggerServerEvent('vipshop:attemptPurchase', data.caseType, data.price, data.displayName)
end)
