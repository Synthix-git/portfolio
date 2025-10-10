local function showWatermark()
    SendNUIMessage({
        type = "display",
        display = true
    })
end

-- Listen for the player's login event
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    showWatermark()
end)