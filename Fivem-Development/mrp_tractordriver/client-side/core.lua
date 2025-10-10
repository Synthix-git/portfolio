-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP / TUNNEL
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")
vSERVER      = Tunnel.getInterface("tractor")

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Blip, Locate, Position = nil, 1, 1
local emServico = false
local warnedVehicle = false

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG: PONTO DE SERVIÇO E ROTA
-----------------------------------------------------------------------------------------------------------------------------------------
local Locations = {
    [1] = {
        ["Service"] = { 2243.45, 5154.36, 57.88, 150.24 },
        ["Route"] = {
            {2264.91,5137.39,54.34,221.11},
            {2312.91,5086.09,46.74,308.98},
            {2326.41,5093.75,46.67,45.36},
            {2272.55,5145.59,55.15,320.32},
            {2282.64,5154.91,56.16,226.78},
            {2337.93,5099.45,47.21,314.65},
            {2346.28,5109.66,48.17,45.36},
            {2289.20,5163.10,57.66,314.65},
            {2295.87,5168.62,58.52,226.78},
            {2351.42,5113.96,48.44,133.23},
            {2341.38,5104.51,47.70,45.36},
            {2285.36,5160.08,57.20,136.07},
            {2277.78,5149.18,55.39,226.78},
            {2334.19,5094.94,46.78,138.90},
            {2322.64,5089.69,46.66,42.52},
            {2269.68,5141.15,54.54,42.52}
        }
    }
}

-- Tratores vanilla
local AllowedTractors = {
    [`tractor2`] = true,
    [`tractor3`] = true
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- TARGET: ENTRAR/SAIR DE SERVIÇO
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    for k,v in pairs(Locations) do
        exports["target"]:AddCircleZone("tractor:Service"..k, vec3(v["Service"][1], v["Service"][2], v["Service"][3]), 1.5, {
            name = "tractor:Service"..k,
            heading = v["Service"][4]
        },{
            shop = k,
            Distance = 1.5,
            options = {
                { event = "tractor:entrarServico", label = "Entrar em Serviço", tunnel = "client" },
                { event = "tractor:sairServico",   label = "Sair de Serviço",   tunnel = "client" }
            }
        })
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTOS DE SERVIÇO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("tractor:entrarServico")
AddEventHandler("tractor:entrarServico", function()
    if emServico then
        TriggerEvent("Notify","Agricultor"," Já estás em serviço.","amarelo",3000)
        return
    end
    emServico = true
    Locate, Position = 1, 1
    warnedVehicle = false

    TriggerEvent("Notify","Agricultor"," <b>Entraste em serviço</b>.","verde",3000)
    TriggerEvent("Notify","Agricultor"," Segue os pontos no GPS usando um trator.","azul",5000)

    local first = Locations[Locate]["Route"][Position]
    if first then makeBlipMarked(first[1], first[2], first[3]) end

    RouteThread()
end)

RegisterNetEvent("tractor:sairServico")
AddEventHandler("tractor:sairServico", function()
    if not emServico then
        TriggerEvent("Notify","Agricultor"," Não estás em serviço.","vermelho",3000)
        return
    end
    EndService(true)
    TriggerEvent("Notify","Agricultor"," <b>Saíste de serviço</b>.","vermelho",3000)
end)

RegisterNetEvent("tractor:ForceLeave")
AddEventHandler("tractor:ForceLeave", function()
    if emServico then EndService(true) end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOOP DE ROTA
-----------------------------------------------------------------------------------------------------------------------------------------
function RouteThread()
    CreateThread(function()
        while emServico do
            local sleep = 500
            local ped = PlayerPedId()
            local tgt = Locations[Locate] and Locations[Locate]["Route"][Position]

            -- Garante BLIP sempre no mapa, mesmo fora do veículo
            if tgt then
                if not DoesBlipExist(Blip) then
                    makeBlipMarked(tgt[1], tgt[2], tgt[3])
                else
                    -- Se por algum motivo o blip existir mas estiver noutro alvo, atualiza:
                    local bx,by,bz = table.unpack(GetBlipInfoIdCoord(Blip))
                    if #(vec3(bx,by,bz) - vec3(tgt[1],tgt[2],tgt[3])) > 1.0 then
                        makeBlipMarked(tgt[1], tgt[2], tgt[3])
                    end
                end
            end

            if IsPedInAnyVehicle(ped) and GetEntityHealth(ped) > 100 then
                local veh = GetVehiclePedIsUsing(ped)
                local hash = GetEntityModel(veh)

                if not AllowedTractors[hash] then
                    if not warnedVehicle then
                        warnedVehicle = true
                        TriggerEvent("Notify","Agricultor"," Usa um <b>trator</b> da garagem.","amarelo",5000)
                    end
                else
                    warnedVehicle = false

                    if tgt then
                        local pos = GetEntityCoords(ped)
                        local dist = #(pos - vec3(tgt[1], tgt[2], tgt[3]))

                        if dist <= 100.0 then
                            sleep = 1
                            DrawMarker(23, tgt[1],tgt[2],tgt[3]-0.5, 0.0,0.0,0.0, 0.0,0.0,0.0, 1.8,1.8,1.2, 0,122,255,120, false,false,2,false,nil,nil,false)
                        end

                        if dist <= 5.0 then
                            -- 💵 paga por checkpoint (200 + pequenos extras)
                            vSERVER.PaymentPoint()

                            -- avança / finaliza
                            if Position >= #Locations[Locate]["Route"] then
                                Position = 1
                                vSERVER.PaymentFinal()
                                TriggerEvent("Notify","Agricultor"," <b>Entrega concluída</b>. Rota reiniciada.","verde",3000)
                            else
                                Position = Position + 1
                            end

                            PlaySound(-1, "RACE_PLACED", "HUD_AWARDS", 0, 0, 1)

                            local nxt = Locations[Locate]["Route"][Position]
                            if nxt then makeBlipMarked(nxt[1], nxt[2], nxt[3]) end
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LIMPEZA / BLIPS
-----------------------------------------------------------------------------------------------------------------------------------------
function EndService(silent)
    emServico = false
    if DoesBlipExist(Blip) then RemoveBlip(Blip) Blip = nil end
end

function makeBlipMarked(x, y, z)
    if DoesBlipExist(Blip) then RemoveBlip(Blip) Blip = nil end
    Blip = AddBlipForCoord(x, y, z)
    SetBlipSprite(Blip, 1)
    SetBlipColour(Blip, 5)
    SetBlipScale(Blip, 0.7)
    SetBlipAsShortRange(Blip, false)
    SetBlipRoute(Blip, true)                -- rota GPS até ao ponto
    SetBlipRouteColour(5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("CheckPoint")
    EndTextCommandSetBlipName(Blip)
end
