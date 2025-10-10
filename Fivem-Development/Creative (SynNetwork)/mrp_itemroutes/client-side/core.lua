-- [NO TOPO DO SERVER-SIDE]
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

-- Interface client (caso o servidor precise chamar funções no client)
local Creative = {}
Tunnel.bindInterface("routes", Creative)

-- Ponte para o servidor (é isto que vais usar: Permission/Start/Finish/Deliver/ForceFinish)
vSERVER = Tunnel.getInterface("routes")


-- Multiplicador VIP (1=ouro, 2=prata, 3=bronze)
local function VipMult(src, passport)
    if not passport then return 1.0 end
    if not vRP.HasGroup(passport, "Premium") then return 1.0 end
    local tier = (vRP.LevelPremium and vRP.LevelPremium(src)) or 0
    if     tier == 1 then return 1.30  -- ouro
    elseif tier == 2 then return 1.20  -- prata
    elseif tier == 3 then return 1.10  -- bronze
    end
    return 1.0
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Blip = nil
local Initial = {}
local Selectedz = 1
local Actived = false
local Progress = false

-- Anti-spam de entrega
local lastDeliver = 0
local DELIVER_COOLDOWN_MS = 1200

-- Trigger e movimento
local TRIGGER_RADIUS = 5.0      -- raio de detecção (maior para não falhar)
local MAX_SPEED = 2.5           -- m/s (≈ 9 km/h) para detecção “lenta”

-- Guarda a posição anterior do veículo para detetar cruzamento rápido
local lastVehPos = nil

-----------------------------------------------------------------------------------------------------------------------------------------
-- UTILS
-----------------------------------------------------------------------------------------------------------------------------------------


-- helper para limpar estado local (colocar no TOPO do ficheiro)
local function _resetRouteClient()
	Actived  = false
	Progress = false
	lastVehPos = nil

	if Blip and DoesBlipExist(Blip) then
		RemoveBlip(Blip)
		Blip = nil
	end

	SetNuiFocus(false,false)
	SendNUIMessage({ Action = "Close" })
end



local function toV3(vec)
	-- Aceita vector3/vec3/tabela
	if type(vec) == "vector3" then return vec end
	if type(vec) == "table" then
		if vec.x and vec.y and vec.z then
			return vector3(vec.x, vec.y, vec.z)
		elseif vec[1] and vec[2] and vec[3] then
			return vector3(vec[1], vec[2], vec[3])
		end
	end
	return nil
end

local function drawGroundMarker(pos)
	-- Marker maior (quase o tamanho do carro)
	DrawMarker(
		1,
		pos.x, pos.y, pos.z - 1.0,
		0.0, 0.0, 0.0,
		0.0, 0.0, 0.0,
		3.5, 3.5, 1.2,      -- tamanho aumentado
		0, 150, 255, 180,   -- cor/alpha
		false, false, 0, false, nil, nil, false
	)
end

local function setRouteBlip()
	if Blip and DoesBlipExist(Blip) then
		RemoveBlip(Blip)
		Blip = nil
	end
	if not Progress then return end
	local target = toV3(Initial[Progress].Coords[Selectedz])
	if not target then return end

	Blip = AddBlipForCoord(target)
	SetBlipSprite(Blip, 1)
	SetBlipColour(Blip, 77)
	SetBlipScale(Blip, 0.5)
	SetBlipRoute(Blip, true)
	SetBlipAsShortRange(Blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString("Entrega")
	EndTextCommandSetBlipName(Blip)
end

-- Retorna true se o segmento [prev -> curr] passa a <= radius do centro (detecção de cruzamento rápido)
local function crossedMarker(prev, curr, center, radius)
	if not prev or not curr or not center then return false end

	local px,py,pz = prev.x, prev.y, prev.z
	local cx,cy,cz = center.x, center.y, center.z
	local vx,vy,vz = (curr.x - px), (curr.y - py), (curr.z - pz)
	local wx,wy,wz = (center.x - px), (center.y - py), (center.z - pz)

	local c1 = vx*wx + vy*wy + vz*wz
	local c2 = vx*vx + vy*vy + vz*vz
	local t = 0.0
	if c2 > 0.0 then
		t = math.max(0.0, math.min(1.0, c1 / c2))
	end

	local closest = vector3(px + t*vx, py + t*vy, pz + t*vz)
	local d = #(closest - center)
	return d <= radius
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADINIT (targets + preparação lista)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	Initial = Config

	for Name, data in pairs(Config) do
		-- Prépara a lista para a NUI (Name/Price/Active)
		for Index, v in ipairs(data.List) do
			local itemName = ItemName and ItemName(v.Item) or v.Item
			Config[Name].List[Index] = {
				Index  = v.Item,
				Name   = itemName,
				Price  = v.Price or 0,
				Active = false
			}
		end

		-- Target
		exports["target"]:AddCircleZone("Routes:"..Name, data.Init, data.Circle or 1.5, {
			name = "Routes:"..Name,
			heading = 0.0,
			useZ = true,
			debugPoly = data.DebugPoly == true
		},{
			shop = Name,
			Distance = 2.0,
			options = {
				{ event = "routes:Open", label = "Abrir", tunnel = "client" }
			}
		})
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ABRIR UI
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("routes:Open")
AddEventHandler("routes:Open", function(Name)
	-- Já tens rota ativa E é a mesma → abre como "em progresso"
	if Progress and Progress == Name then
		SetNuiFocus(true,true)
		SendNUIMessage({
			Action  = "Open",
			Payload = { true, Actived or Initial[Name].List, Name }
		})
		return
	end

	-- Tens rota ativa mas de outro tipo → bloqueia troca
	if Progress and Progress ~= Name then
		TriggerEvent("Notify","Atenção","Volta ao emprego de <b>"..Progress.."</b> e finaliza-o antes de iniciar outro.","amarelo",6000)
		return
	end

	-- Sem rota ativa → envia 'false' (mostra botão INICIAR no NUI)
	if vSERVER.Permission(Name) then
		-- garante estado limpo antes de abrir
		Actived  = false
		Selectedz = 1

		SetNuiFocus(true,true)
		SendNUIMessage({
			Action  = "Open",
			Payload = { false, Initial[Name].List, Name }
		})
	else
		TriggerEvent("Notify","Acesso","Não tens permissão para esta rota.","vermelho",5000)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- NUI START
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Start", function(Data, Callback)
	Progress = Data.Name
	if not Initial[Progress] then
		Callback(false)
		return
	end

	Selectedz = 1
	Actived = Initial[Progress].List

	for _, Number in ipairs(Data.Items or {}) do
		if Actived[Number] then
			Actived[Number].Active = true
		end
	end

	local ok = vSERVER.Start(Data.Items or {}, Progress)
	if ok then
		setRouteBlip()
	end

	Callback(ok)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- NUI FINISH
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Finish", function(_, Callback)
	local ok = vSERVER.Finish()
	if ok then
		Actived  = false
		Progress = false
		lastVehPos = nil

		if Blip and DoesBlipExist(Blip) then
			RemoveBlip(Blip)
			Blip = nil
		end
	end

	Callback(not not ok)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- NUI CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Close", function(_, Callback)
	SetNuiFocus(false,false)
	Callback("Ok")
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOOP: entrega por PESSOA (a pé, condutor ou passageiro)
-----------------------------------------------------------------------------------------------------------------------------------------
-- substitui lastVehPos por lastPos (posição anterior do próprio)
local lastPos = nil

CreateThread(function()
    while true do
        local idle = 900

        if Progress then
            local ped = PlayerPedId()
            local target = toV3(Initial[Progress].Coords[Selectedz])

            if target then
                local inVeh = IsPedInAnyVehicle(ped)
                local mover = ped
                local speed = 0.0

                -- posição/speed
                local pos = GetEntityCoords(ped)
                if inVeh then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh ~= 0 then
                        speed = GetEntitySpeed(veh)
                        pos = GetEntityCoords(veh)
                    else
                        speed = GetEntitySpeed(ped)
                    end
                else
                    speed = GetEntitySpeed(ped)
                end

                local dist = #(pos - target)

                if dist <= 35.0 then
                    idle = 1
                    drawGroundMarker(target)

                    local crossedFast = crossedMarker(lastPos, pos, target, TRIGGER_RADIUS + 1.0)
                    local slowInside  = (dist <= TRIGGER_RADIUS and speed <= MAX_SPEED)

                    if (crossedFast or slowInside) then
                        local now = GetGameTimer()
                        if (now - lastDeliver) >= DELIVER_COOLDOWN_MS then
                            -- ENTREGA SÓ PARA MIM (sem targets)
                            if vSERVER.Deliver() then
                                lastDeliver = now
                                -- avançar ponto vem do servidor via evento "routes:AdvancePoint"
                            end
                        end
                    end
                end

                lastPos = pos
            else
                lastPos = nil
            end
        else
            lastPos = nil
        end

        Wait(idle)
    end
end)


-- Todos avançam o próprio ponto quando receberem do server
RegisterNetEvent("routes:AdvancePoint")
AddEventHandler("routes:AdvancePoint", function(routeName, isSequential)
    if not Progress or Progress ~= routeName then return end

    if isSequential then
        Selectedz = (Selectedz >= #Initial[Progress].Coords) and 1 or (Selectedz + 1)
    else
        local last = Selectedz
        if #Initial[Progress].Coords > 1 then
            repeat
                Selectedz = math.random(#Initial[Progress].Coords)
                Wait(0)
            until Selectedz ~= last
        end
    end

    setRouteBlip()
end)




RegisterNetEvent("routes:ForceFinish")
AddEventHandler("routes:ForceFinish", function()
	-- chama SEMPRE o server (pode estar desincronizado)
	local ok = vSERVER.ForceFinish()
	_resetRouteClient()
	if ok then
	else
	end
end)


-- receber reset remoto (quando o server força sem passar por este handler)
RegisterNetEvent("routes:ResetClient")
AddEventHandler("routes:ResetClient", function()
    _resetRouteClient()
end)

