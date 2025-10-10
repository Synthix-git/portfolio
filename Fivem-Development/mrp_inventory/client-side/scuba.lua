-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
ScubaMask = nil
ScubaTank = nil
-- OXY flags
local HasScuba = false
local ForceOxyBaseline = false

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:SCUBAREMOVE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:ScubaRemove")
AddEventHandler("inventory:ScubaRemove",function()
    if DoesEntityExist(ScubaMask) then
        TriggerServerEvent("DeleteObject",ObjToNet(ScubaMask))
        ScubaMask = nil
    end

    if DoesEntityExist(ScubaTank) then
        TriggerServerEvent("DeleteObject",ObjToNet(ScubaTank))
        ScubaTank = nil
    end

    local ped = PlayerPedId()
    SetEnableScuba(ped,false)
    SetPedMaxTimeUnderwater(ped,10.0)

    HasScuba = false

    -- Se tirou o scuba debaixo de água, fixa baseline 10s e mostra % real (sem saltar para 100)
    if IsPedSwimmingUnderWater(ped) then
        ForceOxyBaseline = true
        OxygenMax = 10.0
        local uw = GetPlayerUnderwaterTimeRemaining(PlayerId()) or 0.0
        if uw > 10.0 then uw = 10.0 end
        local pct = 100
        if OxygenMax > 0 then
            pct = math.floor((uw / OxygenMax) * 100.0 + 0.5)
            if pct > 100 then pct = 100 end
            if pct < 0   then pct = 0   end
        end
        Oxygen = pct
        SendNUIMessage({ Action = "Oxygen", Payload = pct })
    else
        -- Fora de água: esconder barra (100) e preparar próximo mergulho
        ForceOxyBaseline = false
        OxygenMax = 10.0
        Oxygen = 100
        SendNUIMessage({ Action = "Oxygen", Payload = 100 })
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:SCUBA (10 minutos de oxigénio real, barra desce)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Scuba")
AddEventHandler("inventory:Scuba",function()
    if ScubaMask or ScubaTank then
        TriggerEvent("inventory:ScubaRemove")
    else
        local Ped = PlayerPedId()
        local Coords = GetEntityCoords(Ped)

        local Progression,Network = vRPS.CreateObject("p_s_scuba_tank_s",Coords["x"],Coords["y"],Coords["z"])
        if Progression then
            ScubaTank = LoadNetwork(Network)
            AttachEntityToEntity(ScubaTank,Ped,GetPedBoneIndex(Ped,24818),-0.28,-0.24,0.0,180.0,90.0,0.0,1,1,0,0,2,1)
        end

        Progression,Network = vRPS.CreateObject("p_s_scuba_mask_s",Coords["x"],Coords["y"],Coords["z"])
        if Progression then
            ScubaMask = LoadNetwork(Network)
            AttachEntityToEntity(ScubaMask,Ped,GetPedBoneIndex(Ped,12844),0.0,0.0,0.0,180.0,90.0,0.0,1,1,0,0,2,1)
        end

        -- 10 minutos de ar
        SetEnableScuba(Ped,true)
        SetPedMaxTimeUnderwater(Ped,600.0)

        HasScuba = true
        ForceOxyBaseline = false

        -- HUD: começa cheio e vai descendo
        OxygenMax = 600.0
        Oxygen = 100
        SendNUIMessage({ Action = "Oxygen", Payload = 100 })
    end
end)
