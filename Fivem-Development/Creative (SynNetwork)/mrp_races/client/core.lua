-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP / TUNNEL
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
vSERVER      = Tunnel.getInterface("races")

-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Saved           = 0
local Objects         = {}
local Selected        = 1
local Markers         = {}
local Checkpoint      = 1
local Rankings        = false
local ExplodeTimers   = false
local ExplodeCooldown = GetGameTimer()

-- helper: load model
local function LoadModel(model)
    if type(model) == "string" then model = GetHashKey(model) end
    if not HasModelLoaded(model) then
        RequestModel(model)
        local tries = 0
        while not HasModelLoaded(model) and tries < 50 do
            Wait(100)
            tries = tries + 1
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATE STATIC BLIPS (retry até Races carregar)
-----------------------------------------------------------------------------------------------------------------------------------------
local _blipsCreated = false
CreateThread(function()
    while true do
        if not _blipsCreated and type(Races) == "table" and next(Races) then
            for _, Info in pairs(Races) do
                local Blip = AddBlipForCoord(Info["Init"]["x"], Info["Init"]["y"], Info["Init"]["z"])
                SetBlipSprite(Blip, 38)
                SetBlipDisplay(Blip, 4)
                SetBlipAsShortRange(Blip, true)
                SetBlipColour(Blip, 4)
                SetBlipScale(Blip, 0.4)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("Circuito")
                EndTextCommandSetBlipName(Blip)
            end
            _blipsCreated = true
        end
        Wait(1000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- THE CREW MARKERS (CONFIG)
-----------------------------------------------------------------------------------------------------------------------------------------
local Crew_Enabled          = true
local Crew_MaxDrawDist      = 2000.0
local Crew_MinHeight        = 0.0
local Crew_MaxHeight        = 160.0
local Crew_HeightPerMeter   = 0.12
local Crew_LineRadius       = 0.40
local Crew_DotRadius        = 0.32
local Crew_TextGapAboveDot  = 1.65
local Crew_LineRGBA         = { 255, 255, 255, 255 }
local Crew_TextRGBA         = { 255, 255, 255, 255 }
local Crew_TextBigBase      = 10.50
local Crew_TextFarBoost     = 0.0022
local Crew_TextFarMax       = 3.5

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function drawDistanceLabel(pos, meters, dist)
    local cam  = GetGameplayCamCoords()
    local toCam= #(cam - pos)
    local base = (1.0 / math.max(toCam, 0.01)) * 2.0
    base       = base * ((1.0 / GetGameplayCamFov()) * 100.0)
    local farMult = 1.0 + math.min(dist * Crew_TextFarBoost, Crew_TextFarMax)
    local scale = Crew_TextBigBase * farMult * base

    SetDrawOrigin(pos.x, pos.y, pos.z, 0)
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(0.0, scale)
    SetTextColour(Crew_TextRGBA[1], Crew_TextRGBA[2], Crew_TextRGBA[3], Crew_TextRGBA[4])
    SetTextCentre(1)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(string.format("%dM", meters))
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function crewRenderOne(center, playerCoords)
    local dist = #(playerCoords - center)
    if dist > Crew_MaxDrawDist then return end

    local ok, groundZ = GetGroundZFor_3dCoord(center.x, center.y, center.z + 50.0, false)
    local baseZ = (ok and groundZ) or center.z
    local heightLine = clamp(dist * Crew_HeightPerMeter, Crew_MinHeight, Crew_MaxHeight)
    local zTop  = baseZ + heightLine
    local zBall = zTop + Crew_DotRadius + 0.01

    local cam   = GetGameplayCamCoords()
    local toCam = #(cam - vector3(center.x, center.y, zBall))
    local base  = (1.0 / math.max(toCam, 0.01)) * 2.0
    base        = base * ((1.0 / GetGameplayCamFov()) * 100.0)
    local far   = 1.0 + math.min(dist * Crew_TextFarBoost, Crew_TextFarMax)
    local tScale= Crew_TextBigBase * far * base

    local zText   = zBall + (Crew_TextGapAboveDot + math.min(dist * 0.02, 10.0) + (tScale * 0.20))
    local meters  = math.floor(dist + 0.5)

    -- Texto
    SetDrawOrigin(center.x, center.y, zText, 0)
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(0.0, tScale)
    SetTextColour(Crew_TextRGBA[1], Crew_TextRGBA[2], Crew_TextRGBA[3], Crew_TextRGBA[4])
    SetTextCentre(1)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(string.format("%dM", meters))
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()

    -- Bola
    DrawMarker(
        28, center.x, center.y, zBall,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        Crew_DotRadius, Crew_DotRadius, Crew_DotRadius,
        Crew_LineRGBA[1], Crew_LineRGBA[2], Crew_LineRGBA[3], Crew_LineRGBA[4],
        false, true, 2, false, nil, nil, false
    )

    -- Poste (sem rotação)
    if heightLine > 0.01 then
        DrawMarker(
            30, center.x, center.y, baseZ + heightLine * 0.5,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            Crew_LineRadius, Crew_LineRadius, heightLine,
            Crew_LineRGBA[1], Crew_LineRGBA[2], Crew_LineRGBA[3], Crew_LineRGBA[4],
            false, false, 2, false, nil, nil, false
        )
    end
end

function CrewRenderNextCheckpoint()
    if not Crew_Enabled then return end
    if not LocalPlayer or not LocalPlayer["state"] or not LocalPlayer["state"]["Races"] then return end
    if not Races or not Races[Selected] or not Races[Selected]["Coords"] then return end
    local cp = Races[Selected]["Coords"][Checkpoint]
    if not cp or not cp.Center then return end
    local ped = PlayerPedId()
    crewRenderOne(cp.Center, GetEntityCoords(ped))
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- INITCIRCUIT
-----------------------------------------------------------------------------------------------------------------------------------------
local function InitCircuit()
    LoadModel("prop_beachflag_01")
    LoadModel("prop_offroad_tyres02")

    for Number = 1, #Races[Selected]["Coords"] do
        -- Blip de checkpoint
        Markers[Number] = AddBlipForCoord(
            Races[Selected]["Coords"][Number]["Center"]["x"],
            Races[Selected]["Coords"][Number]["Center"]["y"],
            Races[Selected]["Coords"][Number]["Center"]["z"]
        )
        SetBlipSprite(Markers[Number], 1)
        SetBlipColour(Markers[Number], 77)
        SetBlipScale(Markers[Number], 0.85)
        ShowNumberOnBlip(Markers[Number], Number)
        SetBlipAsShortRange(Markers[Number], true)
        if Number == 1 then
            SetBlipRoute(Markers[Number], true)
        end

        -- Props laterais
        local Prop = (Number == #Races[Selected]["Coords"]) and "prop_beachflag_01" or "prop_offroad_tyres02"
        local LeftObject = CreateObjectNoOffset(Prop,
            Races[Selected]["Coords"][Number]["Left"]["x"],
            Races[Selected]["Coords"][Number]["Left"]["y"],
            Races[Selected]["Coords"][Number]["Left"]["z"], false, false, false)
        local RightObject = CreateObjectNoOffset(Prop,
            Races[Selected]["Coords"][Number]["Right"]["x"],
            Races[Selected]["Coords"][Number]["Right"]["y"],
            Races[Selected]["Coords"][Number]["Right"]["z"], false, false, false)

        SetEntityAsMissionEntity(LeftObject, true, true)
        SetEntityLodDist(LeftObject, 0xFFFF)
        PlaceObjectOnGroundProperly(LeftObject)
        SetEntityCollision(LeftObject, false, false)

        SetEntityAsMissionEntity(RightObject, true, true)
        SetEntityLodDist(RightObject, 0xFFFF)
        PlaceObjectOnGroundProperly(RightObject)
        SetEntityCollision(RightObject, false, false)

        Objects[#Objects + 1] = LeftObject
        Objects[#Objects + 1] = RightObject
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEANCIRCUIT
-----------------------------------------------------------------------------------------------------------------------------------------
local function CleanCircuit()
    -- blips
    for _, blip in pairs(Markers) do
        if DoesBlipExist(blip) then
            SetBlipRoute(blip, false)
            RemoveBlip(blip)
        end
    end
    Wait(0)
    for _, blip in pairs(Markers) do
        if DoesBlipExist(blip) then
            SetBlipRoute(blip, false)
            RemoveBlip(blip)
        end
    end
    -- props
    for _, obj in pairs(Objects) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    Markers = {}
    Objects = {}
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- STOPCIRCUIT
-----------------------------------------------------------------------------------------------------------------------------------------
local function StopCircuit()
    SendNUIMessage({ name = "Display", payload = { false } })
    LocalPlayer["state"]:set("Races", false, false)
    vSERVER.Cancel()
    CleanCircuit()

    if ExplodeTimers then
        ExplodeTimers = false
        SetTimeout(3000, function()
            local Vehicle = GetPlayersLastVehicle()
            if Vehicle == 0 then
                local Ped    = PlayerPedId()
                local Coords = GetEntityCoords(Ped)
                AddExplosion(Coords, 2, 0.5, false, false, false)
            else
                NetworkExplodeVehicle(Vehicle, true, false, true)
            end
        end)
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- MAIN LOOP
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        local TimeDistance = 999

        if not LocalPlayer["state"]["TestDrive"] then
            local Ped     = PlayerPedId()
            local Coords  = GetEntityCoords(Ped)
            local Vehicle = GetPlayersLastVehicle()

            if LocalPlayer["state"]["Races"] then
                TimeDistance = 1
                local Points = GetGameTimer() - Saved

                if ExplodeTimers and GetGameTimer() >= ExplodeCooldown then
                    ExplodeTimers   = ExplodeTimers - 1
                    ExplodeCooldown = GetGameTimer() + 1000
                end

                SendNUIMessage({ name = "Progress", payload = { Points, ExplodeTimers } })

                -- Render estilo The Crew
                CrewRenderNextCheckpoint()

                if (not IsPedInAnyVehicle(Ped)) or (GetPedInVehicleSeat(Vehicle, -1) ~= Ped) or (ExplodeTimers and ExplodeTimers <= 0) then
                    StopCircuit()
                else
                    if not Races[Selected] or not Races[Selected]["Coords"] or not Races[Selected]["Coords"][Checkpoint] then
                        StopCircuit()
                    else
                        local nextCenter = Races[Selected]["Coords"][Checkpoint]["Center"]
                        local Distance   = #(Coords - nextCenter)

                        if Distance <= (Races[Selected]["Coords"][Checkpoint]["Distance"] + 1.0) then
                            -- Pagar checkpoint no server (1x por ordem)
                            vSERVER.HitCheckpoint(Selected, Checkpoint)

                            -- remover blip atual SEMPRE
                            if DoesBlipExist(Markers[Checkpoint]) then
                                SetBlipRoute(Markers[Checkpoint], false)
                                RemoveBlip(Markers[Checkpoint])
                                Markers[Checkpoint] = nil
                            end

                            -- fim?
                            if Checkpoint >= #Races[Selected]["Coords"] then
                                SendNUIMessage({ name = "Display", payload = { false } })

                                -- finalizar no server
                                local resp = vSERVER.Finish(Selected, Points)

                                -- limpeza dura
                                CleanCircuit()

                                Saved         = 0
                                Checkpoint    = 1
                                ExplodeTimers = false
                                LocalPlayer["state"]:set("Races", false, false)

                                -- feedback local caso falhe
                                if type(resp) ~= "table" or not resp.ok then
                                    TriggerEvent("Notify", "Circuitos",
                                        (resp and resp.reason) and ("Falha ao finalizar: "..resp.reason) or "Falha ao finalizar corrida.",
                                        "amarelo", 5000
                                    )
                                else
                                    -- opcional: mostrar bónus local
                                    if resp.value then
                                        TriggerEvent("Notify", "Circuitos",
                                            ("Bónus por tempo: <b>%dx dirtydollar</b>."):format(tonumber(resp.value) or 0),
                                            "verde", 5000
                                        )
                                    end
                                end

                                -- Ranking popup
                                SendNUIMessage({ name = "Ranking", payload = { true, vSERVER.Ranking(Selected) } })
                                Selected = 1
                                SetTimeout(5000, function()
                                    SendNUIMessage({ name = "Ranking", payload = { false } })
                                end)
                            else
                                -- próximo checkpoint
                                Checkpoint = Checkpoint + 1
                                if DoesBlipExist(Markers[Checkpoint]) then
                                    SetBlipRoute(Markers[Checkpoint], true)
                                end
                                SendNUIMessage({ name = "Checkpoint" })
                            end
                        end
                    end
                end
            else
                -- fora de corrida
                if IsPedInAnyVehicle(Ped) and not IsPedOnAnyBike(Ped) and not IsPedInAnyHeli(Ped) and not IsPedInAnyBoat(Ped) and not IsPedInAnyPlane(Ped) then
                    if type(Races) == "table" then
                        for Number, v in pairs(Races) do
                            local Distance = #(Coords - v["Init"])
                            if Distance <= 25 and GetPedInVehicleSeat(Vehicle, -1) == Ped then
                                DrawMarker(23, v["Init"]["x"], v["Init"]["y"], v["Init"]["z"] - 0.35,
                                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                    10.0, 10.0, 10.0,
                                    255, 255, 255, 100, 0, 0, 0, 0)
                                TimeDistance = 1

                                if Distance <= 5 then
                                    -- Ranking (G)
                                    if IsControlJustPressed(1, 47) then
                                        if not Rankings then
                                            Rankings = true
                                            SendNUIMessage({ name = "Ranking", payload = { true, vSERVER.Ranking(Number) } })
                                        else
                                            Rankings = false
                                            SendNUIMessage({ name = "Ranking", payload = { false } })
                                        end
                                    end

                                    -- Iniciar (E)
                                    if IsControlJustPressed(1, 38) then
                                        local resp = vSERVER.Start(Number)
                                        if type(resp) ~= "table" or not resp.ok then
                                            local remainTxt = ""
                                            if resp and resp.remaining then
                                                local mins = math.floor(resp.remaining / 60)
                                                local secs = resp.remaining % 60
                                                remainTxt = string.format(" (%dm%02ds)", mins, secs)
                                            end
                                            TriggerEvent("Notify", "Circuitos",
                                                (resp and resp.reason or "Não foi possível iniciar a corrida.") .. remainTxt,
                                                "amarelo", 5000
                                            )
                                        else
                                            ExplodeTimers = resp.explosive
                                            SendNUIMessage({ name = "Display", payload = { true, #Races[Number]["Coords"], ExplodeTimers } })

                                            if ExplodeTimers then
                                                ExplodeCooldown = GetGameTimer() + 1000
                                            end

                                            Saved      = GetGameTimer()
                                            Selected   = Number
                                            Checkpoint = 1

                                            LocalPlayer["state"]:set("Races", true, false)
                                            InitCircuit()
                                        end
                                    end
                                else
                                    if Rankings then
                                        Rankings = false
                                        SendNUIMessage({ name = "Ranking", payload = { false } })
                                    end
                                end
                            end
                        end
                    end
                else
                    if Rankings then
                        Rankings = false
                        SendNUIMessage({ name = "Ranking", payload = { false } })
                    end
                end
            end
        end

        Wait(TimeDistance)
    end
end)
