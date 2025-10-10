----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")
vRPC = Tunnel.getInterface("vRP")
vCLIENT = Tunnel.getInterface("inventory") -- client do inventário

----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------------------------------------------------------------------------
local REQUIRE_WRENCH_STEAL = true -- exige WEAPON_WRENCH para roubar
local ALLOW_STEAL_OWNED = true -- true = permite roubar pneus de veículos com dono
local STEAL_MS = 7000 -- duração da progressbar (ms)
local STEAL_LOCK_S = 8

----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS (SERVER)
----------------------------------------------------------------------------------------------------------------------------------------
local function GetTyreInfoSafe(src, plate, netId, tyreIdx, vehHandle)
	for i = 1, 3 do
		local ok, res = pcall(function()
			return vCLIENT.tyreInfo(src, plate, netId, tyreIdx, vehHandle)
		end)
		if ok and type(res) == "table" then
			local h = tonumber(res.health) or 1000.0
			local b = res.burst and true or false
			return h, b
		end
		Wait(60)
	end
	return nil, nil
end

local function canSteal(plate, netId)
	if ALLOW_STEAL_OWNED then
		return true
	end
	if vRP.PassportPlate then
		local owner = vRP.PassportPlate(plate)
		if not owner then
			return true
		end
	else
		return true
	end
	return false
end

----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------------------------------------------------------------------------
local TyreActive = TyreActive or {}

----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVER PNEUS (só progressbar 7s; sem vRP.Task)
----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:RemoveTyres")
AddEventHandler("inventory:RemoveTyres", function(Selected)
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport or TyreActive[Passport] then
		return
	end
	if type(Selected) ~= "table" then
		return
	end

	local plate = Selected[1]
	local netId = Selected[4]
	local tyreIdx = Selected[6]
	local vehHandle = Selected[3]

	if not plate or not netId or type(tyreIdx) ~= "number" then
		TriggerClientEvent("Notify", src, "Atenção", "Alvo <b>inválido</b>.", "vermelho", 4000)
		return
	end

	if not canSteal(plate, netId) then
		TriggerClientEvent("Notify", src, "Aviso", "Não podes remover pneus deste <b>veículo</b>.", "amarelo", 4500)
		return
	end

	if REQUIRE_WRENCH_STEAL and not vCLIENT.CheckWeapon(src, "WEAPON_WRENCH") then
		TriggerClientEvent("Notify", src, "Aviso", "<b>Chave Inglesa</b> não encontrada.", "amarelo", 5000)
		return
	end

	if vRP.MaxItens and vRP.MaxItens(Passport, "tyres", 1) then
		TriggerClientEvent("Notify", src, "Atenção", "Limite de <b>pneus</b> atingido.", "vermelho", 5000)
		return
	end

	-- valida antes
	local _, burst = GetTyreInfoSafe(src, plate, netId, tyreIdx, vehHandle)
	if burst == nil then
		TriggerClientEvent(
			"Notify",
			src,
			"Atenção",
			"Não foi possível validar o <b>pneu</b> agora.",
			"vermelho",
			4500
		)
		return
	end
	if burst then
		TriggerClientEvent("Notify", src, "Atenção", "Este <b>pneu</b> já está furado.", "amarelo", 4500)
		return
	end

	TyreActive[Passport] = os.time() + STEAL_LOCK_S
	local pState = Player(src) and Player(src).state or nil
	if pState then
		pState["Buttons"] = true
	end

	-- anima + progressbar de 7s
	vRPC.playAnim(src, false, { "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer" }, true)
	TriggerClientEvent("Progress", src, "A retirar o pneu", STEAL_MS)
	Wait(STEAL_MS)

	TyreActive[Passport] = nil
	if pState then
		pState["Buttons"] = false
	end
	vRPC.Destroy(src)

	-- valida depois
	local _, burst2 = GetTyreInfoSafe(src, plate, netId, tyreIdx, vehHandle)
	if burst2 == nil then
		TriggerClientEvent(
			"Notify",
			src,
			"Atenção",
			"Falha ao validar o <b>pneu</b> após a ação.",
			"vermelho",
			3500
		)
		return
	end
	if burst2 then
		TriggerClientEvent("Notify", src, "Atenção", "O <b>pneu</b> ficou furado.", "amarelo", 3500)
		return
	end

	-- rebenta localmente o pneu removido e dá item
	TriggerClientEvent("inventory:explodeTyres", -1, netId, plate, tyreIdx)
	vRP.GenerateItem(Passport, "tyres", 1, true)
	TriggerClientEvent("Notify", src, "Sucesso", "Removeste um <b>pneu</b>.", "verde", 4000)
end)
