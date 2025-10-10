---------------------------------------------------------------------
-- VRP
---------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

---------------------------------------------------------------------
-- CONNECTION
---------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("autoschool", Creative)
vSERVER = Tunnel.getInterface("autoschool")

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local function notify(title, msg, color, time)
    TriggerEvent("Notify", title or "Autoescola", msg or "", color or "azul", time or 5000)
end

local function drawMarkerAt(pos)
    DrawMarker(1, pos.x, pos.y, pos.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 1.0, 255, 255, 255, 120, false, false, 2, false, nil, nil, false)
end

local function freezeVehicleSeconds(veh, seconds)
    if veh == 0 then return end
    local ms = math.max(200, math.floor((seconds or 1) * 1000))
    SetVehicleHandbrake(veh, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleUndriveable(veh, false)
    SetVehicleForwardSpeed(veh, 0.0)
    Wait(ms)
    SetVehicleHandbrake(veh, false)
end

-- === Helpers novos para garantir deteção e delete confiável ===
local function distPointToSegment(p0, p1, c)
    local v = p1 - p0
    local w = c - p0
    local c1 = v.x*w.x + v.y*w.y + v.z*w.z
    if c1 <= 0.0 then return #(c - p0) end
    local c2 = v.x*v.x + v.y*v.y + v.z*v.z
    if c2 <= c1 then return #(c - p1) end
    local b = c1 / (c2 == 0.0 and 0.0001 or c2)
    local pb = p0 + (v * b)
    return #(c - pb)
end

local function DeleteEntitySafe(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local timeout = GetGameTimer() + 2500
    NetworkRegisterEntityAsNetworked(ent)
    local netId = NetworkGetNetworkIdFromEntity(ent)
    if netId and netId ~= 0 then
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, true)
    end
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(ent)
        Wait(50)
    end
    SetEntityAsMissionEntity(ent, true, true)
    SetVehicleAsNoLongerNeeded(ent)
    DeleteVehicle(ent)
    if DoesEntityExist(ent) then
        DeleteEntity(ent)
    end
end

local function bringToHalt(veh)
    if veh == 0 then return end
    SetVehicleHandbrake(veh, true)
    SetVehicleEngineOn(veh, false, true, false)
    SetVehicleUndriveable(veh, true)
    BringVehicleToHalt(veh, 0.2, 1, false)
    SetVehicleForwardSpeed(veh, 0.0)
    SetEntityCollision(veh, false, false)
end

local function ejectPlayerFromVehicle(veh)
    local ped = PlayerPedId()
    if veh == 0 or not DoesEntityExist(veh) then return end
    if GetPedInVehicleSeat(veh, -1) == ped then
        TaskLeaveVehicle(ped, veh, 0)
    end
    local t = GetGameTimer() + 2000
    while GetVehiclePedIsIn(ped, false) ~= 0 and GetGameTimer() < t do
        Wait(50)
    end
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        ClearPedTasksImmediately(ped)
        local px,py,pz = table.unpack(GetEntityCoords(veh))
        SetEntityCoords(ped, px + 1.5, py, pz + 0.2, false, false, false, false)
        Wait(50)
    end
end

---------------------------------------------------------------------
-- ESTADO VIA GlobalState
---------------------------------------------------------------------
AutoSchool_Categories = {}
AutoSchool_Questions  = {}
AutoSchool_Pass       = 70
AutoSchool_Route      = {}
AutoSchool_NPC        = nil
AutoSchool_Spawn      = nil

---------------------------------------------------------------------
-- vKEYBOARD helpers (com fallback)
---------------------------------------------------------------------
local function kb_ExamYesNo(question)
    if exports["keyboard"] and exports["keyboard"].ExamYesNo then
        return exports["keyboard"]:ExamYesNo(question)
    end
    return exports["keyboard"]:Instagram({ "Sim","Não" })
end

local function kb_ExamQuestion(title, subtitle, options)
    if exports["keyboard"] and exports["keyboard"].ExamQuestion then
        return exports["keyboard"]:ExamQuestion(title, subtitle, options)
    end
    return exports["keyboard"]:Instagram(options)
end

---------------------------------------------------------------------
-- BOOTSTRAP
---------------------------------------------------------------------
CreateThread(function()
    while not GlobalState["AutoSchool:Categories"] do Wait(100) end
    AutoSchool_Categories = GlobalState["AutoSchool:Categories"] or {}
    AutoSchool_Questions  = GlobalState["AutoSchool:Questions"] or {}
    AutoSchool_Pass       = GlobalState["AutoSchool:Pass"] or 70
    AutoSchool_Route      = GlobalState["AutoSchool:Route"] or {}
    AutoSchool_NPC        = GlobalState["AutoSchool:NPC"]
    AutoSchool_Spawn      = GlobalState["AutoSchool:Spawn"]

    if AutoSchool_NPC then
        exports["target"]:AddCircleZone("autoschool:npc", vec3(AutoSchool_NPC.x, AutoSchool_NPC.y, AutoSchool_NPC.z), 1.0, {
            name = "autoschool:npc",
            heading = AutoSchool_NPC.w or 0.0,
            debugPoly = false
        }, {
            Distance = 2.0,
            options = {
                { event = "autoschool:StartExam",     label = "Fazer Exame Teórico", tunnel = "client" },
                { event = "autoschool:StartPractice", label = "Iniciar Aula Prática", tunnel = "client" }
            }
        })
    end
end)

AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() then
        pcall(function() exports["target"]:RemoveZone("autoschool:npc") end)
    end
end)

---------------------------------------------------------------------
-- Escolher categoria
---------------------------------------------------------------------
local function pickCategory(prompt)
    local opts = {}
    for _, c in ipairs(AutoSchool_Categories) do
        opts[#opts+1] = c.label
    end
    local res = kb_ExamQuestion("Autoescola", prompt or "Selecione a categoria", opts)
    if res and res[1] then return tostring(res[1]) end
    return nil
end

---------------------------------------------------------------------
-- EXAME TEÓRICO (cancelável)
---------------------------------------------------------------------
local examActive = false
local examCancel = false

RegisterNetEvent("autoschool:CancelTheory")
AddEventHandler("autoschool:CancelTheory", function()
    if examActive then
        examCancel = true
        notify("Autoescola", "Exame teórico <b>cancelado</b>.", "amarelo", 5000)
    end
end)

RegisterNetEvent("autoschool:StartExam")
AddEventHandler("autoschool:StartExam", function()
    if #AutoSchool_Categories == 0 or #AutoSchool_Questions == 0 then
        notify("Autoescola", "Sistema não inicializado. Tenta novamente.", "amarelo", 4000)
        return
    end

    if examActive then
        notify("Autoescola", "Já estás a fazer um exame.", "amarelo", 4000)
        return
    end

    local chosen = pickCategory("Selecione a categoria para o exame teórico")
    if not chosen then
        notify("Autoescola", "Operação cancelada.", "amarelo", 4000)
        return
    end

    examActive = true
    examCancel = false

    local correct = 0
    for _, q in ipairs(AutoSchool_Questions) do
        if examCancel then
            examActive = false
            examCancel = false
            return
        end

        local ans = kb_ExamYesNo(q.q)
        if not ans or not ans[1] then
            notify("Autoescola", "Exame cancelado.", "amarelo", 4000)
            examActive = false
            examCancel = false
            return
        end
        if tostring(ans[1]) == tostring(q.correct) then
            correct = correct + 1
        end
        Wait(120)
    end

    local score = math.floor((correct / #AutoSchool_Questions) * 100 + 0.5)
    local ok = vSERVER.FinishExam(chosen, score)
    if ok then
        notify("Autoescola", "Teórico aprovado! Recebeste <b>licença temporária</b>. Faz a <b>prática</b> para concluir.", "verde", 8000)
    end

    examActive = false
    examCancel = false
end)

---------------------------------------------------------------------
-- AULA PRÁTICA
---------------------------------------------------------------------
local practiceVeh = 0
local currentIndex = 0
local routeBlip = 0
local practicePlate = ""

local function clearPractice()
    if DoesEntityExist(practiceVeh) then
        local plate = GetVehicleNumberPlateText(practiceVeh) or practicePlate
        if plate and plate ~= "" then
            TriggerServerEvent("autoschool:UnregisterPractice", plate)
        end
        DeleteEntitySafe(practiceVeh)
    elseif practicePlate ~= "" then
        TriggerServerEvent("autoschool:UnregisterPractice", practicePlate)
    end
    practiceVeh = 0
    practicePlate = ""
    if DoesBlipExist(routeBlip) then RemoveBlip(routeBlip) end
    routeBlip = 0
    currentIndex = 0
end

local function makeBlipAt(pos, text)
    if DoesBlipExist(routeBlip) then RemoveBlip(routeBlip) end
    routeBlip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(routeBlip, 1)
    SetBlipAsShortRange(routeBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(text or "Ponto da Aula")
    EndTextCommandSetBlipName(routeBlip)
end

-- Recebe do servidor a confirmação de posse e liberta condução
RegisterNetEvent("autoschool:PracticeRegistered", function(netId)
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId or 0) or 0)
    if ent and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 2 then
        SetVehicleEngineOn(ent, true, true, false)
        SetVehicleUndriveable(ent, false)
        SetVehicleDoorsLocked(ent, 1)
    end
end)

-- Spawn vehicle helper (owned/unlocked/no hotwire + registo no servidor)
local function spawnPracticeVehicle(modelName)
    local model = GetHashKey(modelName)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local x,y,z,w = AutoSchool_Spawn.x, AutoSchool_Spawn.y, AutoSchool_Spawn.z, AutoSchool_Spawn.w or 0.0
    practiceVeh = CreateVehicle(model, x, y, z, w, true, false)
    SetEntityAsMissionEntity(practiceVeh, true, true)

    local plate = ("EXAME%03d"):format(math.random(0,999))
    SetVehicleNumberPlateText(practiceVeh, plate)
    practicePlate = plate

    SetVehicleOnGroundProperly(practiceVeh)
    TaskWarpPedIntoVehicle(PlayerPedId(), practiceVeh, -1)
    SetVehicleEngineOn(practiceVeh, true, true, false)
    SetVehicleUndriveable(practiceVeh, false)
    SetVehicleNeedsToBeHotwired(practiceVeh, false)
    SetVehicleIsStolen(practiceVeh, false)
    SetVehicleDoorsLocked(practiceVeh, 1)
    SetVehicleDoorsLockedForAllPlayers(practiceVeh, false)
    SetVehRadioStation(practiceVeh, "OFF")
    SetVehicleDirtLevel(practiceVeh, 0.0)

    local netId = NetworkGetNetworkIdFromEntity(practiceVeh)
    if netId == 0 then
        NetworkRegisterEntityAsNetworked(practiceVeh)
        netId = NetworkGetNetworkIdFromEntity(practiceVeh)
    end
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetNetworkIdCanMigrate(netId, true)

    -- regista posse no servidor (ele responde com PracticeRegistered)
    TriggerServerEvent("autoschool:RegisterPractice", plate, netId)

    -- redundância
    CreateThread(function()
        Wait(100)
        SetVehicleDoorsLocked(practiceVeh, 1)
        SetVehicleDoorsLockedForAllPlayers(practiceVeh, false)
        SetVehicleEngineOn(practiceVeh, true, true, false)
        SetVehicleUndriveable(practiceVeh, false)
    end)

    SetModelAsNoLongerNeeded(model)
end

RegisterNetEvent("autoschool:StartPractice")
AddEventHandler("autoschool:StartPractice", function()
    if not AutoSchool_Spawn or #AutoSchool_Route == 0 then
        notify("Autoescola", "Aula prática indisponível.", "vermelho", 5000); return
    end
    if DoesEntityExist(practiceVeh) then
        notify("Autoescola", "Já estás numa aula prática.", "amarelo", 4000); return
    end

    local chosen = pickCategory("Selecione a categoria para a prática")
    if not chosen then
        notify("Autoescola", "Operação cancelada.", "amarelo", 4000); return
    end

    -- valida TEMP no servidor antes de spawnar
    if not vSERVER.CanDoPractice(chosen) then
        notify("Autoescola", "Precisas de passar no <b>exame teórico</b> dessa categoria antes de começar a prática.", "amarelo", 7000)
        return
    end

    local modelName = "blista"
    for _, c in ipairs(AutoSchool_Categories) do
        if c.label == chosen or c.id == chosen then
            modelName = c.vehicle or "blista"
            break
        end
    end

    spawnPracticeVehicle(modelName)
    notify("Autoescola", "Veículo de treino <b>spawnado</b>. Segue os pontos no mapa.", "verde", 6000)

    currentIndex = 1
    makeBlipAt(AutoSchool_Route[currentIndex].pos, "Ponto 1")

    CreateThread(function()
        local HIT_RADIUS = 4.5
        local DRAW_DIST  = 120.0
        local lastPos    = GetEntityCoords(PlayerPedId())

        while currentIndex > 0 and currentIndex <= #AutoSchool_Route do
            local ped   = PlayerPedId()
            local veh   = GetVehiclePedIsIn(ped, false)
            local pos   = AutoSchool_Route[currentIndex].pos
            local curPos = GetEntityCoords(ped)

            if #(curPos - pos) <= DRAW_DIST then
                drawMarkerAt(pos)
            end

            local passed = false
            if veh ~= 0 then
                local d = distPointToSegment(lastPos, curPos, pos)
                if d <= HIT_RADIUS then
                    passed = true
                end
            else
                if #(curPos - pos) <= (HIT_RADIUS * 0.8) then
                    passed = true
                end
            end

            if passed then
                local stepMsg = AutoSchool_Route[currentIndex].msg or "Aguarde"
                notify("Autoescola", stepMsg, "verde", 2500)

                if veh ~= 0 then
                    freezeVehicleSeconds(veh, 1)
                end

                notify("Autoescola", "Passo <b>concluído</b>.", "verde", 1500)

                currentIndex = currentIndex + 1
                if currentIndex <= #AutoSchool_Route then
                    makeBlipAt(AutoSchool_Route[currentIndex].pos, "Ponto")
                else
                    if DoesBlipExist(routeBlip) then RemoveBlip(routeBlip) end
                    routeBlip = 0
                    notify("Autoescola", "Aula prática <b>concluída</b>! A validar habilitação...", "verde", 4000)

                    local ok = vSERVER.FinishPractice(chosen)
                    if ok then
                        notify("Autoescola", "Licença <b>definitiva</b> atribuída. Parabéns!", "verde", 5000)
                    end

                    -- Limpeza imediata e robusta
                    local vehToDel = practiceVeh
                    if DoesEntityExist(vehToDel) then
                        local plate = GetVehicleNumberPlateText(vehToDel) or practicePlate
                        bringToHalt(vehToDel)
                        ejectPlayerFromVehicle(vehToDel)
                        if plate and plate ~= "" then
                            TriggerServerEvent("autoschool:UnregisterPractice", plate)
                        end
                        DeleteEntitySafe(vehToDel)
                    elseif practicePlate ~= "" then
                        TriggerServerEvent("autoschool:UnregisterPractice", practicePlate)
                    end

                    practiceVeh   = 0
                    practicePlate = ""
                    currentIndex  = 0
                    break
                end

                Wait(250)
            end

            lastPos = curPos
            Wait(0)
        end
    end)
end)

-- Comando auxiliar para cancelar prática
RegisterCommand("cancelarpratica", function()
    clearPractice()
    notify("Autoescola", "Aula prática cancelada.", "amarelo", 4000)
end)
