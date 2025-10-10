-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")
vSERVER      = Tunnel.getInterface("trucker")

-----------------------------------------------------------------------------------------------------------------------------------------
-- DECOR (compat com imobilizador das garagens)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    pcall(DecorRegister, "Player_Vehicle", 3) -- 3 = int
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIÁVEIS
-----------------------------------------------------------------------------------------------------------------------------------------
local inJob = false
local truck = nil
local leaveTruckTimer = nil
local isLeavingTruck = false
local deliveriesCompleted = 0
local totalEarnings = 0
local totalTips = 0
local deliveryBlip = nil
local currentDelivery = nil

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEANUP
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() then
        if deliveryBlip then RemoveBlip(deliveryBlip) end
        if DoesEntityExist(truck) then
            DeleteVehicle(truck)
        end
    end
end)


-- BLIP FIXO DO SERVIÇO (mapa)
CreateThread(function()
    if not Config.StartBlip or not Config.StartBlip.enabled then return end

    local c = Config.NPCLocation
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, Config.StartBlip.sprite or 477)
    SetBlipColour(blip, Config.StartBlip.color or 5)
    SetBlipScale(blip, Config.StartBlip.scale or 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.StartBlip.name or "Camionista")
    EndTextCommandSetBlipName(blip)
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- TARGET: ZONA NO LOCAL (SEM CRIAR NPC)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    local c = Config.NPCLocation
    local center = vec3(c.x, c.y, c.z)

    local length, width = 1.2, 1.2
    local opts = { name = "TruckerNPC", heading = c.w, minZ = c.z - 1.0, maxZ = c.z + 1.5 }
    local target = {
        Distance = 2.0,
        options = {
            { event = "trucker:begin", label = "Começar serviço", tunnel = "client" },
            { event = "trucker:end",   label = "Sair de serviço", tunnel = "client" }
        }
    }

    if GetResourceState("target") == "started" then
        exports["target"]:AddBoxZone("TruckerNPC", center, length, width, opts, target)
    else
        CreateThread(function()
            local shown = false
            while true do
                local ped = PlayerPedId()
                local p = GetEntityCoords(ped)
                if #(p - center) < 2.0 then
                    if not shown then
                        TriggerEvent("Notify","Camionista","Carrega <b>E</b> para <b>Começar</b> ou <b>Shift+E</b> para <b>Terminar</b>.","azul",3500)
                        shown = true
                    end
                    if IsControlJustPressed(0,38) then
                        TriggerEvent("trucker:begin")
                    elseif IsControlPressed(0,21) and IsControlJustPressed(0,38) then
                        TriggerEvent("trucker:end")
                    end
                else
                    shown = false
                end
                Wait(100)
            end
        end)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- COMEÇAR SERVIÇO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("trucker:begin")
AddEventHandler("trucker:begin", function()
    if inJob then
        TriggerEvent("Notify","Camionista","Já estás em serviço.","amarelo",4000)
        return
    end

    inJob = true
    deliveriesCompleted = 0
    totalEarnings = 0
    totalTips = 0
    currentDelivery = nil

    -- Spawn do camião
    local model = Config.TruckModel
    RequestModel(model)
    local tries = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < tries do Wait(0) end

    local s = Config.TruckSpawnLocation
    truck = CreateVehicle(model, s.x, s.y, s.z, s.w, true, false)

    if DoesEntityExist(truck) then
        -- Network/ownership
        if not NetworkGetEntityIsNetworked(truck) then
            NetworkRegisterEntityAsNetworked(truck)
        end
        local netid = NetworkGetNetworkIdFromEntity(truck)
        if netid then
            SetNetworkIdExistsOnAllMachines(netid, true)
            SetNetworkIdCanMigrate(netid, true)
        end

        SetEntityAsMissionEntity(truck, true, false)
        SetVehicleHasBeenOwnedByPlayer(truck, true)
        SetVehicleNeedsToBeHotwired(truck, false)
        SetVehicleIsStolen(truck, false)

        if not DecorExistOn(truck, "Player_Vehicle") then
            DecorSetInt(truck, "Player_Vehicle", -1)
        else
            DecorSetInt(truck, "Player_Vehicle", -1)
        end

        SetVehicleDoorsLocked(truck, 1)
        SetVehicleDoorsLockedForAllPlayers(truck, false)
        SetVehicleOnGroundProperly(truck)
        SetVehRadioStation(truck, "OFF")
        SetVehicleEngineOn(truck, true, true, false)
        SetVehicleUndriveable(truck, false)

        TaskWarpPedIntoVehicle(PlayerPedId(), truck, -1)

        CreateThread(function()
            Wait(200)
            if DoesEntityExist(truck) then
                SetVehicleDoorsLocked(truck,1)
                SetVehicleDoorsLockedForAllPlayers(truck,false)
                SetVehicleEngineOn(truck,true,true,false)
                SetVehicleUndriveable(truck,false)
            end
        end)

        if SetVehicleFuelLevel then SetVehicleFuelLevel(truck, 100.0) end
        DecorSetBool(truck, "_Fuel_Infinite", false)
        SetVehicleDirtLevel(truck, 0.0)

        -- Mods leves
        SetVehicleModKit(truck, 0)
        ToggleVehicleMod(truck, 18, true) -- Turbo
        for i=11,13 do
            local max = GetNumVehicleMods(truck, i)
            if max and max > 0 then SetVehicleMod(truck, i, max-1, false) end
        end
    else
        TriggerEvent("Notify","Camionista","Falha ao criar o camião.","vermelho",5000)
        inJob = false
        return
    end

    StartDelivery()
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- TERMINAR SERVIÇO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("trucker:end")
AddEventHandler("trucker:end", function()
    if not inJob then
        TriggerEvent("Notify","Camionista","Não estás em serviço.","amarelo",4000)
        return
    end

    inJob = false
    local total = totalEarnings + totalTips

    if deliveriesCompleted > 0 then
        TriggerEvent("Notify","Camionista","Turno terminado. Entregas: <b>"..deliveriesCompleted.."</b> • Ganhos: <b>$"..totalEarnings.."</b> • Gorjetas: <b>$"..totalTips.."</b> • Total: <b>$"..total.."</b>.","verde",8000)
    else
        TriggerEvent("Notify","Camionista","Terminaste sem entregas concluídas.","amarelo",5000)
    end

    leaveTruckTimer = nil
    isLeavingTruck = false
    currentDelivery = nil

    if DoesEntityExist(truck) then
        DeleteVehicle(truck)
    end
    truck = nil

    if deliveryBlip then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ENTREGAS (pagamento segue Config.PaymentRange/PaymentMethod)
-----------------------------------------------------------------------------------------------------------------------------------------
local function setDeliveryBlip(coords)
    if deliveryBlip then RemoveBlip(deliveryBlip) end
    deliveryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipColour(deliveryBlip, 5)
    SetBlipScale(deliveryBlip, 0.8)
    SetBlipAsShortRange(deliveryBlip, true)
    BeginTextCommandSetBlipName("STRING"); AddTextComponentString("Entrega"); EndTextCommandSetBlipName(deliveryBlip)
end

function StartDelivery()
    if not inJob then return end

    local idx = math.random(1,#Config.Deliveries)
    currentDelivery = Config.Deliveries[idx]
    if not currentDelivery then return end

    setDeliveryBlip(currentDelivery.location)
    SetNewWaypoint(currentDelivery.location.x, currentDelivery.location.y)
    TriggerEvent("Notify","Camionista","Segue para o ponto <b>"..(currentDelivery.name or "Entrega").."</b> marcado no GPS.","azul",5000)

    CreateThread(function()
        local coords = currentDelivery.location
        while inJob and currentDelivery == currentDelivery do
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)

            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0,0.0,0.0, 0.0,0.0,0.0, 3.0,3.0,1.0, 255,255,0, 100, false,false,2,false,nil,nil,false)

            if #(p - coords) < 5.0 then
                if deliveryBlip then RemoveBlip(deliveryBlip); deliveryBlip = nil end

                -- pagamento FIXO da config
                local pay = math.random(Config.PaymentRange.min, Config.PaymentRange.max)
                deliveriesCompleted = deliveriesCompleted + 1
                totalEarnings = totalEarnings + pay
                TriggerServerEvent("trucker:pay", pay, Config.PaymentMethod.Delivery)

                -- gorjeta via percentagem
                if math.random(1,100) <= Config.TipChance then
                    local tip = math.random(Config.TipAmount.min, Config.TipAmount.max)
                    totalTips = totalTips + tip
                    TriggerServerEvent("trucker:tip", tip, Config.PaymentMethod.Tip)
                end

                Wait(400)
                StartDelivery()
                break
            end

            Wait(0)
        end
    end)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- MONITORIZAR SAÍDA DO CAMIÃO
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        if inJob then
            local ped = PlayerPedId()

            if IsPedInAnyVehicle(ped,false) and GetVehiclePedIsIn(ped,false) == truck then
                if isLeavingTruck then
                    isLeavingTruck = false
                    leaveTruckTimer = nil
                    TriggerEvent("Notify","Camionista","Voltaste ao camião a tempo.","verde",2500)
                end
            else
                if not isLeavingTruck then
                    isLeavingTruck = true
                    leaveTruckTimer = GetGameTimer() + (Config.LeaveTruckTimer * 1000)

                    CreateThread(function()
                        while leaveTruckTimer and GetGameTimer() < leaveTruckTimer do
                            local left = math.ceil((leaveTruckTimer - GetGameTimer())/1000)
                            TriggerEvent("Notify","Camionista","Volta ao camião em <b>"..left.."s</b> ou serás despedido!","amarelo",900)
                            Wait(1000)
                        end

                        if leaveTruckTimer and GetGameTimer() >= leaveTruckTimer then
                            TriggerServerEvent("trucker:fire")
                            TriggerEvent("trucker:end")
                            leaveTruckTimer = nil
                        end
                    end)
                end
            end
        end
        Wait(1000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ECRÃ “FOSTE DESPEDIDO”
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("trucker:firedScreen")
AddEventHandler("trucker:firedScreen", function()
    CreateThread(function()
        local sc = RequestScaleformMovie("mp_big_message_freemode")
        while not HasScaleformMovieLoaded(sc) do Wait(0) end

        BeginScaleformMovieMethod(sc,"SHOW_SHARD_WASTED_MP_MESSAGE")
        PushScaleformMovieMethodParameterString("FOSTE DESPEDIDO")
        PushScaleformMovieMethodParameterString("")
        PushScaleformMovieMethodParameterInt(5)
        EndScaleformMovieMethod()

        local t = GetGameTimer() + 4500
        while GetGameTimer() < t do
            DrawScaleformMovieFullscreen(sc,255,255,255,255)
            Wait(0)
        end
        SetScaleformMovieAsNoLongerNeeded(sc)
    end)

    PlaySoundFrontend(-1,"Bed","WastedSounds", true)

    if deliveryBlip then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
end)
