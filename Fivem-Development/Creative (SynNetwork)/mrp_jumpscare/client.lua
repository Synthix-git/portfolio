-----------------------------------------------------------------------------------------------------------------------------------------
-- NUI TOGGLE
-----------------------------------------------------------------------------------------------------------------------------------------
local function nuiToggle(state)
    SendNUIMessage({ type = "ui", display = state })
end

RegisterNetEvent("jumpscare:Open")
AddEventHandler("jumpscare:Open",function()
    -- mostra imediatamente
    nuiToggle(true)
    -- sem foco para não bloquear input
    SetNuiFocus(false,false)
end)

RegisterNetEvent("jumpscare:Close")
AddEventHandler("jumpscare:Close",function()
    nuiToggle(false)
end)

-- limpeza ao parar o resource
AddEventHandler("onResourceStop",function(res)
    if res == GetCurrentResourceName() then
        nuiToggle(false)
    end
end)
