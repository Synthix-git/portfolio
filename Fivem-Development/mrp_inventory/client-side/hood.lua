-----------------------------------------------------------------------------------------------------------------------------------------
-- HOOD / CAPUZ
-----------------------------------------------------------------------------------------------------------------------------------------
local HoodNet, HoodEnt = nil, nil
local HoodModel = "prop_money_bag_01"

local function loadFromNet(netId, tries)
    tries = tries or 50
    local ent
    for i=1,tries do
        ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            return ent
        end
        Wait(10)
    end
    return nil
end

local function tryAttachToHead(ped, obj)
    local head = GetPedBoneIndex(ped, 31086)
    local presetsByModel = {
        [GetHashKey("p_binbag_01_s")] = {
            { off = vec3(-0.05, 0.04, 0.00), rot = vec3(0.0, 90.0, 0.0) },
        },
		[GetHashKey("prop_money_bag_01")] = {
			{ off = vec3(0.2, 0.02, 0.00), rot = vec3(90.0, 90.0, 180.0) },
		},
        [GetHashKey("prop_paper_bag_small")] = {
            {off=vec3(0.00,0.03,0.03), rot=vec3(180.0,0.0,0.0)},
            {off=vec3(0.00,0.02,0.05), rot=vec3(180.0,0.0,10.0)},
        }
    }
    local model = GetEntityModel(obj)
    local presets = presetsByModel[model] or {
        {off=vec3(0.0,0.02,0.10), rot=vec3(0.0,90.0,180.0)},
        {off=vec3(0.0,0.03,0.02), rot=vec3(180.0,0.0,0.0)},
    }
    SetEntityCollision(obj, false, false)
    for i=1,#presets do
        local p = presets[i]
        AttachEntityToEntity(
            obj, ped, head,
            p.off.x, p.off.y, p.off.z,
            p.rot.x, p.rot.y, p.rot.z,
            true, true, false, true, 2, true
        )
        Wait(0)
        if IsEntityAttachedToEntity(obj, ped) then
            return true
        end
    end
    local p = presets[#presets]
    for _=1,20 do
        AttachEntityToEntity(obj, ped, head, p.off.x, p.off.y, p.off.z, p.rot.x, p.rot.y, p.rot.z, true, true, false, true, 2, true)
        Wait(0)
        if IsEntityAttachedToEntity(obj, ped) then
            return true
        end
    end
    return false
end

-- Requer vRPS.CreateObject no server
RegisterNetEvent("hood:AttachProp")
AddEventHandler("hood:AttachProp", function()
    if HoodEnt and DoesEntityExist(HoodEnt) then return end
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local ok, netId = vRPS.CreateObject(HoodModel, p.x, p.y, p.z)
    if not ok or not netId then
        print("[hood] CreateObject falhou.")
        return
    end
    HoodNet = netId
    HoodEnt = loadFromNet(netId)
    if not HoodEnt then
        print("[hood] Entity do netId não carregou.")
        HoodNet = nil
        return
    end
    Wait(0); Wait(0)
    if not tryAttachToHead(ped, HoodEnt) then
        print("[hood] Attach falhou, a remover objeto.")
        TriggerServerEvent("DeleteObject", HoodNet)
        HoodNet, HoodEnt = nil, nil
        return
    end
    TriggerEvent("hud:Hood", true)
end)

RegisterNetEvent("hood:DetachProp")
AddEventHandler("hood:DetachProp", function()
    if HoodEnt and DoesEntityExist(HoodEnt) then
        DetachEntity(HoodEnt, true, true)
    end
    if HoodNet then
        TriggerServerEvent("DeleteObject", HoodNet)
    end
    HoodNet, HoodEnt = nil, nil
    TriggerEvent("hud:Hood", false)
end)

CreateThread(function()
    local wasDead = false
    while true do
        local ped = PlayerPedId()
        local dead = IsEntityDead(ped)
        if dead and not wasDead then
            wasDead = true
            if HoodEnt and DoesEntityExist(HoodEnt) then
                DetachEntity(HoodEnt, true, true)
            end
            if HoodNet then
                TriggerServerEvent("DeleteObject", HoodNet)
            end
            HoodNet, HoodEnt = nil, nil
        elseif not dead and wasDead then
            wasDead = false
        end
        Wait(300)
    end
end)