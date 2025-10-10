local EquippedBackpacks = {}
-- no topo do server (garante a tabela de estado)
local ActiveTyre = ActiveTyre or {}


-----------------------------------------------------------------------------------------------------------------------------------------
-- PESCA - SERVER (Syn)
-----------------------------------------------------------------------------------------------------------------------------------------
-- Stop helper (mantém)
local function StopFishing(source, Passport)
    if Player(source) and Player(source)["state"] then
        Player(source)["state"]["Buttons"] = false
    end
    Active[Passport] = nil

    if vRPC.DestroyObjects then pcall(vRPC.DestroyObjects, source) end
    if vRPC.StopAnim then pcall(vRPC.StopAnim, source) end

    TriggerClientEvent("fishing:stop", source)
end

-- [SERVER] PATCH HARD – aprova pesca SEMPRE (podes voltar atrás depois)
local function CanFish(src)
    return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- BOOSTING - SERVER (Syn)
-----------------------------------------------------------------------------------------------------------------------------------------

-- === INIT SEGURO ===
Boosting = Boosting or {}       -- evita nil global
Travel  = Travel or {}          -- cache de última posição do jogador

-- helper: estado de recurso
local function resStarted(name)
    local ok, st = pcall(GetResourceState, name)
    return ok and st == "started"
end

----------------------------------------------------------
-- LOCKPICK & LOCKPICKPLUS (só minigame vRP.Task; sem progressbar)
-- Corrige: animação pára ao concluir (sucesso ou falha), sem loops/Active.
-- Cola no @inventory/server-side/itens.lua substituindo as funções.
----------------------------------------------------------

-- helper para montar nome do veículo
local function BuildVehicleLabel(Model, Plate)
    local name = nil
    if VehicleName then name = VehicleName(Model) end
    if type(name) ~= "string" or name == "" then
        if type(Model) == "string" and Model ~= "" then
            name = Model
        else
            local dn = GetDisplayNameFromVehicleModel(Model)
            name = (type(dn) == "string" and dn ~= "" and dn) or "Desconhecido"
        end
    end
    local plateStr = (Plate ~= nil and tostring(Plate)) or "Sem Placa"
    return string.format("%s - %s", name, plateStr)
end

-- rotina comum de dispatch + unlock
local function DoUnlockFlow(source, Passport, Network, Plate, Model, opts)
    local ent = (Network and NetworkGetEntityFromNetworkId(Network)) or 0
    local notifyTitle = opts and opts.notifyTitle or "Roubo de Veículo"
    local vehicleLabel = BuildVehicleLabel(Model, Plate)

    exports["vrp"]:CallPolice({
        ["Source"] = source, ["Passport"] = Passport, ["Permission"] = "Policia",
        ["Name"] = notifyTitle, ["Percentage"] = 250, ["Wanted"] = 300, ["Code"] = 31, ["Color"] = 44,
        ["Vehicle"] = vehicleLabel
    })

    if ent ~= 0 and DoesEntityExist(ent) then
        if not vRP.PassportPlate(Plate) then
            local isDismantle = (opts and opts.isDismantle) or false
            if not isDismantle then
                Entity(ent)["state"]:set("Fuel", 100, true)
                Entity(ent)["state"]:set("Nitro", 0, true)
            end
            Entity(ent)["state"]:set("Lockpick", Passport, true)
            TriggerEvent("garages:UnlockServer", Network, true)
        else
            local chance = opts and opts.ownedUnlockChance or 50
            if math.random(100) >= chance then
                -- falhou o “bónus” de owned; nada
            else
                TriggerEvent("garages:UnlockServer", Network, true)
            end
        end
    end
end

-- minigame puro (sem progressbar):
-- tries = nº de tentativas
-- diff  = dificuldade 1..5 (maior = mais difícil)
-- time  = ms por tentativa
local function RunLockpickMinigame(source, tries, diff, time)
    for i = 1, tries do
        if vRP.Task(source, diff, time) then
            return true, i -- sucesso na tentativa i
        end
    end
    return false, tries -- falhou todas
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USE
-----------------------------------------------------------------------------------------------------------------------------------------
Use = {

	["printerdocument"] = function(source, Passport, Amount, Slot, Full, Item, Split)
		-- fecha inventário e bloqueia botões por 3s (UX)
		Active[Passport] = os.time() + 3
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close", source)
		TriggerClientEvent("Progress", source, "Abrindo documento", 3000)
		vRPC.playAnim(source, true, { "amb@world_human_clipboard@male@idle_a", "idle_c" }, true)

		CreateThread(function()
			while Active[Passport] and os.time() < Active[Passport] do
				Wait(100)
			end
			vRPC.Destroy(source)
			Player(source)["state"]["Buttons"] = false
			Active[Passport] = nil

			TriggerEvent("printer:OpenFromItem", Full, source)

			-- não consome o item! É um “viewer”
		end)
	end,

    ["bandage"] = function(source, Passport, Amount, Slot, Full, Item, Split)
        Active[Passport] = os.time() + 10
        Player(source)["state"]["Buttons"] = true
        TriggerClientEvent("inventory:Close", source)
        TriggerClientEvent("Progress", source, "Passando", 10000)
        vRPC.playAnim(source, true, { "amb@world_human_clipboard@male@idle_a", "idle_c" }, true)

        repeat
            if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
                vRPC.Destroy(source)
                Active[Passport] = nil
                Player(source)["state"]["Buttons"] = false

                if vRP.TakeItem(Passport, Full, 1, true, Slot) then
                    vRP.UpgradeStress(Passport, 5)
                    vRPC.UpgradeHealth(source, 25)

                    -- ✅ reset oficial do teu paramedic (para parar o loop de dano)
                    TriggerClientEvent("paramedic:Reset", source)

                    -- (opcional) manter painel coerente: zera bleeding na persistência do paramedic
                    TriggerEvent("paramedic:ClearBleeding:Persist", Passport)
                end
            end
            Wait(100)
        until not Active[Passport]
    end,

	["analgesic"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Passando",5000)
		vRPC.playAnim(source,true,{"amb@world_human_clipboard@male@idle_a","idle_c"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeStress(Passport,3)
					vRPC.UpgradeHealth(source,10)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

			["gauze"] = function(source, Passport, Amount, Slot, Full, Item, Split)
			Active[Passport] = os.time() + 10
        Player(source)["state"]["Buttons"] = true
        TriggerClientEvent("inventory:Close", source)
        TriggerClientEvent("Progress", source, "Passando", 10000)
        vRPC.playAnim(source, true, { "amb@world_human_clipboard@male@idle_a", "idle_c" }, true)

        repeat
            if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
                vRPC.Destroy(source)
                Active[Passport] = nil
                Player(source)["state"]["Buttons"] = false

                if vRP.TakeItem(Passport, Full, 1, true, Slot) then
                    vRP.UpgradeStress(Passport, 5)
                    vRPC.UpgradeHealth(source, 15)

                    -- ✅ reset oficial do teu paramedic (para parar o loop de dano)
                    TriggerClientEvent("paramedic:Reset", source)

                    -- (opcional) manter painel coerente: zera bleeding na persistência do paramedic
                    TriggerEvent("paramedic:ClearBleeding:Persist", Passport)
                end
            end
            Wait(100)
        until not Active[Passport]
    end,


	["bodybag"] = function(source, Passport, Amount, Slot, Full, Item, Split)
	local duration = 1200 -- rápido/fluido
	Active[Passport] = os.time() + math.ceil(duration/1000)
	Player(source)["state"]["Buttons"] = true

	TriggerClientEvent("inventory:Close", source)
	TriggerClientEvent("bodybag:HoldKneel", source, duration)

	CreateThread(function()
		while Active[Passport] and os.time() < Active[Passport] do
		Wait(50)
		end

		vRPC.Destroy(source) -- levanta/limpa
		Player(source)["state"]["Buttons"] = false
		Active[Passport] = nil

		-- NÃO consome o item
		TriggerClientEvent("bodybag:Use", source)
	end)
	end,



	["medkit"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 25
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Passando",25000)
		vRPC.playAnim(source,true,{"amb@world_human_clipboard@male@idle_a","idle_c"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeStress(Passport,20)
					vRPC.UpgradeHealth(source,45)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["meth"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 15
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Inalando",15000)
		vRPC.playAnim(source,true,{"amb@world_human_clipboard@male@idle_a","idle_c"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					TriggerClientEvent("Methamphetamine",source)
					vRP.ChemicalTimer(Passport,120)
					vRP.SetArmour(source,10)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,


	["ballisticplate"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 25
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Vestindo",25000)
		vRPC.playAnim(source,true,{"clothingtie","try_tie_negative_a"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.SetArmour(source,20)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	-- ["instagram"] = function(source,Passport,Amount,Slot,Full,Item,Split)
	-- 	local Instagram = {}
	-- 	local PhoneNumber = vRP.CleanPhone(Passport)
	-- 	local CheckInstagram = vRP.Query("smartphone/CheckInstagram",{ Phone = PhoneNumber })
	-- 	if PhoneNumber and CheckInstagram and CheckInstagram[1] then
	-- 		TriggerClientEvent("inventory:Close",source)

	-- 		for _,v in pairs(CheckInstagram) do
	-- 			Instagram[#Instagram + 1] = v["username"]
	-- 		end

	-- 		local Keyboard = vKEYBOARD.Instagram(source,Instagram)
	-- 		if Keyboard and vRP.TakeItem(Passport,Full,1,true,Slot) then
	-- 			vRP.Query("smartphone/Instagram",{ Username = Keyboard[1], Amount = 1000 })
	-- 			TriggerClientEvent("Notify",source,"Sucesso","Seguidores adicionados.","verde",5000)
	-- 		end
	-- 	end
	-- end,

	-- ["racestablet"] = function(source,Passport,Amount,Slot,Full,Item,Split)
	-- 	TriggerClientEvent("races:Open",source)
	-- 	TriggerClientEvent("inventory:Close",source)
	-- end,

	["radiomhz"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("inventory:Close",source)

		local Keyboard = vKEYBOARD.Options(source,"Frequência",{ "NTB","Bahamas","Tequila","Vanilla","Madrazo" })
		if Keyboard then
			local Frequency = sanitizeString(Keyboard[1],"0123456789")
			if not exports["radio"]:Exist(Frequency) and vRP.TakeItem(Passport,Full,1,false,Slot) then
				TriggerClientEvent("Notify",source,"Sucesso","Frequência adicionada.","verde",5000)
				exports["radio"]:Add(Frequency,Keyboard[2])
			end
		end
	end,

	["a_c_cat_01"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_cat_01")
	end,

	["a_c_husky"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_husky")
	end,

	["a_c_poodle"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_poodle")
	end,

	["a_c_pug"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_pug")
	end,

	["a_c_retriever"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_retriever")
	end,

	["a_c_rottweiler"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_rottweiler")
	end,

	["a_c_shepherd"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_shepherd")
	end,

	["a_c_westy"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_westy")
	end,

	["a_c_hen"] = function(source,Passport,Amount,Slot,Full,Item,Split)
	TriggerClientEvent("animals:Spawn",source,"a_c_hen")
	end,

	["a_c_rat"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_rat")
	end,

	["a_c_pig"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_pig")
	end,

	["a_c_mtlion"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_mtlion")
	end,

	["a_c_rabbit_01"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_rabbit_01")
	end,

	["a_c_boar"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("animals:Spawn",source,"a_c_boar")
	end,


		-- CAMERA
		["camera"] = function(source,Passport,Amount,Slot,Full,Item,Split)
			if Player(source)["state"]["Camera"] then return end

			local Ped = GetPlayerPed(source)

			-- força ficar desarmado para permitir abrir a câmara
			SetCurrentPedWeapon(Ped, `WEAPON_UNARMED`, true)

			TriggerClientEvent("inventory:Close", source)
			TriggerClientEvent("inventory:Camera", source, false)

			-- cria o prop + animação
			vRPC.CreateObjects(source, "amb@world_human_paparazzi@male@base", "base", "prop_pap_camera_01", 49, 28422)
		end,

		["binoculars"] = function(source,Passport,Amount,Slot,Full,Item,Split)
			if Player(source)["state"]["Camera"] then return end

			local Ped = GetPlayerPed(source)
			SetCurrentPedWeapon(Ped, `WEAPON_UNARMED`, true)

			TriggerClientEvent("inventory:Close", source)
			TriggerClientEvent("inventory:Camera", source, true)

			-- LOOP estável:
			-- dict:  amb@world_human_binoculars@male@idle_a
			-- clip:  idle_a
			vRPC.CreateObjects(
				source,
				"amb@world_human_binoculars@male@idle_a",
				"idle_a",
				"prop_binoc_01",
				49,
				28422
			)
		end,

	["pouch"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local uid = (Split and Split[2]) or tostring(Passport)
		TriggerClientEvent("chest:Open",source,"pouch:"..uid,"Item",false,false,true)
	end,

	["ammobox"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local uid = (Split and Split[2]) or tostring(Passport)
		TriggerClientEvent("chest:Open",source,"ammobox:"..uid,"Item",false,false,true)
	end,

	["weaponbox"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local uid = (Split and Split[2]) or tostring(Passport)
		TriggerClientEvent("chest:Open",source,"weaponbox:"..uid,"Item",false,false,true)
	end,

	["suitcase"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local uid = (Split and Split[2]) or tostring(Passport)
		TriggerClientEvent("chest:Open",source,"suitcase:"..uid,"Item",false,false,true)
	end,

	["treasurebox"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local uid = (Split and Split[2]) or tostring(Passport)
		TriggerClientEvent("chest:Open",source,"treasurebox:"..uid,"Item",Full,true,true)
	end,

	["christmas_04"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local uid = (Split and Split[2]) or tostring(Passport)
		TriggerClientEvent("chest:Open",source,"christmas_04:"..uid,"Item",Full,true,true)
	end,

	["medicbag"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local uid = (Split and Split[2]) or tostring(Passport)
		TriggerClientEvent("chest:Open",source,"medicbag:"..uid,"Item",false,false,true)
	end,


	["newchars"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if vRP.TakeItem(Passport,Full,1,false,Slot) then
			vRP.UpgradeCharacters(source)
			TriggerClientEvent("inventory:Update",source)
			TriggerClientEvent("inventory:Notify",source,"Sucesso","Personagem liberado.","verde")
		end
	end,

	["gemstone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if vRP.TakeItem(Passport,Full,Amount,false,Slot) then
			vRP.UpgradeGemstone(Passport,Amount,false)
			TriggerClientEvent("inventory:Update",source)
			TriggerClientEvent("inventory:Notify",source,"Sucesso","Diamantes adicionados.","verde")
		end
	end,

	["namechange"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("inventory:Close",source)

		local Keyboard = vKEYBOARD.Secondary(source,"Nome","Sobrenome")
		if Keyboard then
			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				TriggerClientEvent("inventory:Notify",source,"Sucesso","Passaporte atualizado.","verde")
				TriggerClientEvent("inventory:Update",source)
				vRP.UpgradeNames(Passport,Keyboard[1],Keyboard[2])
			end
		end
	end,

	["soap"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if vPLAYER.Residuals(source) then
			Active[Passport] = os.time() + 10
			Player(source)["state"]["Buttons"] = true
			TriggerClientEvent("inventory:Close",source)
			TriggerClientEvent("Progress",source,"Usando",10000)
			vRPC.playAnim(source,false,{"amb@world_human_bum_wash@male@high@base","base"},true)

			repeat
				if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
					vRPC.Destroy(source)
					Active[Passport] = nil
					Player(source)["state"]["Buttons"] = false

					if vRP.TakeItem(Passport,Full,1,true,Slot) then
						TriggerClientEvent("player:Residual",source)
					end
				end

				Wait(100)
			until not Active[Passport]
		end
	end,

	["joint"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if vRP.ConsultItem(Passport,"joint") then
			Active[Passport] = os.time() + 10
			Player(source)["state"]["Buttons"] = true
			TriggerClientEvent("inventory:Close",source)
			TriggerClientEvent("Progress",source,"Fumando",10000)
			vRPC.CreateObjects(source,"amb@world_human_aa_smoke@male@idle_a","idle_c","prop_cs_ciggy_01",49,28422)

			repeat
				if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
					vRPC.Destroy(source)
					Active[Passport] = nil
					Player(source)["state"]["Buttons"] = false

					if vRP.TakeItem(Passport,Full,1,true,Slot) then
						vRP.WeedTimer(Passport,120)
						vRP.DowngradeStress(Passport,20)
						TriggerClientEvent("Joint",source)
					end
				end

				Wait(100)
			until not Active[Passport]
		end
	end,

	["metadone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 3
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"A injetar",10000)
		vRPC.playAnim(source,true,{"amb@world_human_clipboard@male@idle_a","idle_c"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.ChemicalTimer(Passport,120)
					TriggerClientEvent("Metadone",source)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["heroin"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 15
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"A injetar",10000)
		vRPC.playAnim(source,true,{"amb@world_human_clipboard@male@idle_a","idle_c"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.ChemicalTimer(Passport,120)
					TriggerClientEvent("Heroin",source)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["crack"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 15
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"A injetar",10000)
		vRPC.playAnim(source,true,{"amb@world_human_clipboard@male@idle_a","idle_c"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.ChemicalTimer(Passport,120)
					TriggerClientEvent("Crack",source)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["codeine"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 15
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"A injetar",10000)
		vRPC.playAnim(source,true,{"amb@world_human_clipboard@male@idle_a","idle_c"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.ChemicalTimer(Passport,120)
					TriggerClientEvent("Codeine",source)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["amphetamine"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 15
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"A injetar",10000)
		vRPC.playAnim(source,true,{"amb@world_human_clipboard@male@idle_a","idle_c"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.ChemicalTimer(Passport,120)
					TriggerClientEvent("Amphetamine",source)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,


	["cocaine"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Cheirando",5000)
		vRPC.playAnim(source,true,{"anim@amb@nightclub@peds@","missfbi3_party_snort_coke_b_male3"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.WeedTimerTimer(Passport,120)
					vRP.DowngradeStress(Passport,20)
					TriggerClientEvent("Cocaine",source)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["cigarette"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if vRP.ConsultItem(Passport,"lighter") then
			Active[Passport] = os.time() + 10
			Player(source)["state"]["Buttons"] = true
			TriggerClientEvent("inventory:Close",source)
			TriggerClientEvent("Progress",source,"Fumando",10000)
			vRPC.CreateObjects(source,"amb@world_human_aa_smoke@male@idle_a","idle_c","prop_cs_ciggy_01",49,28422)

			repeat
				if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
					vRPC.Destroy(source)
					Active[Passport] = nil
					Player(source)["state"]["Buttons"] = false

					if vRP.TakeItem(Passport,Full,1,true,Slot) then
						vRP.DowngradeStress(Passport,10)
					end
				end

				Wait(100)
			until not Active[Passport]
		end
	end,

	["vape"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 20
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Fumando",20000)
		vRPC.CreateObjects(source,"anim@heists@humane_labs@finale@keycards","ped_a_enter_loop","ba_prop_battle_vape_01",49,18905,0.08,-0.00,0.03,-150.0,90.0,-10.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				vRP.DowngradeStress(Passport,20)
				Player(source)["state"]["Buttons"] = false
			end

			Wait(100)
		until not Active[Passport]
	end,




	["gsrkit"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local ClosestPed = vRPC.ClosestPed(source)
		if ClosestPed then
			Active[Passport] = os.time() + 5
			Player(source)["state"]["Buttons"] = true
			TriggerClientEvent("inventory:Close",source)
			TriggerClientEvent("Progress",source,"Usando",5000)

			repeat
				if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
					Active[Passport] = nil
					Player(source)["state"]["Buttons"] = false

					if vRP.TakeItem(Passport,Full,1,true,Slot) then
						local Informations = vPLAYER.Residuals(ClosestPed)
						if Informations then
							local Number = 0
							local Message = ""

							for Value,v in pairs(Informations) do
								Number = Number + 1
								Message = Message.."<b>"..Number.."</b>: "..Value.."<br>"
							end

							TriggerClientEvent("Notify",source,"Informações",Message,"verde",10000)
						else
							TriggerClientEvent("Notify",source,"Aviso","Nenhum resultado encontrado.","amarelo",5000)
						end
					end
				end

				Wait(100)
			until not Active[Passport]
		end
	end,

	["gdtkit"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local ClosestPed = vRPC.ClosestPed(source)
		if ClosestPed then
			local OtherPassport = vRP.Passport(ClosestPed)
			local Identity = vRP.Identity(OtherPassport)
			if OtherPassport and Identity then
				Active[Passport] = os.time() + 5
				Player(source)["state"]["Buttons"] = true
				TriggerClientEvent("inventory:Close",source)
				TriggerClientEvent("Progress",source,"Usando",5000)

				repeat
					if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
						Active[Passport] = nil
						Player(source)["state"]["Buttons"] = false

						if vRP.TakeItem(Passport,Full,1,true,Slot) then
							local weed = vRP.WeedReturn(OtherPassport)
							local chemical = vRP.ChemicalReturn(OtherPassport)
							local alcohol = vRP.AlcoholReturn(OtherPassport)

							local chemStr = ""
							local alcoholStr = ""
							local weedStr = ""

							if chemical == 0 then
								chemStr = "Nenhum"
							elseif chemical == 1 then
								chemStr = "Baixo"
							elseif chemical == 2 then
								chemStr = "Médio"
							elseif chemical >= 3 then
								chemStr = "Alto"
							end

							if alcohol == 0 then
								alcoholStr = "Nenhum"
							elseif alcohol == 1 then
								alcoholStr = "Baixo"
							elseif alcohol == 2 then
								alcoholStr = "Médio"
							elseif alcohol >= 3 then
								alcoholStr = "Alto"
							end

							if weed == 0 then
								weedStr = "Nenhum"
							elseif weed == 1 then
								weedStr = "Baixo"
							elseif weed == 2 then
								weedStr = "Médio"
							elseif weed >= 3 then
								weedStr = "Alto"
							end

							TriggerClientEvent("Notify",source,"Informações","<b>Químicos:</b> "..chemStr.."<br><b>Álcool:</b> "..alcoholStr.."<br><b>Drogas:</b> "..weedStr,"roxo",8000)
						end
					end

					Wait(100)
				until not Active[Passport]
			end
		end
	end,

	["nitro"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if not vRP.InsideVehicle(source) then
			local Vehicle,Network,Plate = vRPC.VehicleList(source)
			if Vehicle then
				vRPC.AnimActive(source)
				Active[Passport] = os.time() + 10
				Player(source)["state"]["Buttons"] = true
				TriggerClientEvent("inventory:Close",source)
				TriggerClientEvent("Progress",source,"Trocando",10000)
				vRPC.playAnim(source,false,{"mini@repair","fixing_a_player"},true)

				local Players = vRPC.Players(source)
				for _,v in pairs(Players) do
					async(function()
						TriggerClientEvent("player:VehicleHood",v,Network,"open")
					end)
				end

				repeat
					if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
						vRPC.Destroy(source)
						Active[Passport] = nil
						Player(source)["state"]["Buttons"] = false

						if vRP.TakeItem(Passport,Full,1,true,Slot) then
							local Networked = NetworkGetEntityFromNetworkId(Network)
							if DoesEntityExist(Networked) then
								Entity(Networked)["state"]:set("Nitro",2000,true)
							end
						end
					end

					Wait(100)
				until not Active[Passport]

				local Players = vRPC.Players(source)
				for _,v in pairs(Players) do
					async(function()
						TriggerClientEvent("player:VehicleHood",v,Network,"close")
					end)
				end
			end
		end
	end,

	["GADGET_PARACHUTE"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Active[Passport] = os.time() + 3
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Usando",3000)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vCLIENT.Parachute(source)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["advtoolbox"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if not vRP.InsideVehicle(source) then
			local Vehicle,Network,Plate = vRPC.VehicleList(source)
			if Vehicle then
				vRPC.AnimActive(source)
				Player(source)["state"]["Buttons"] = true
				TriggerClientEvent("inventory:Close",source)
				vRPC.playAnim(source,false,{"mini@repair","fixing_a_player"},true)

				local Players = vRPC.Players(source)
				for _,v in pairs(Players) do
					async(function()
						TriggerClientEvent("player:VehicleHood",v,Network,"open")
					end)
				end

				if vRP.Task(source,5,5000) then
					Active[Passport] = os.time() + 15
					TriggerClientEvent("Progress",source,"Reparando",15000)

					repeat
						if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
							Active[Passport] = nil

							if vRP.RemoveCharges(Passport,Full) then
								local Players = vRPC.Players(source)
								for _,v in pairs(Players) do
									async(function()
										TriggerClientEvent("inventory:RepairBoosts",v,Network,Plate)
									end)
								end
							end
						end

						Wait(100)
					until not Active[Passport]
				end

				local Players = vRPC.Players(source)
				for _,v in pairs(Players) do
					async(function()
						TriggerClientEvent("player:VehicleHood",v,Network,"close")
					end)
				end

				Player(source)["state"]["Buttons"] = false
				Active[Passport] = nil
				vRPC.Destroy(source)
			end
		end
	end,

	["toolbox"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if not vRP.InsideVehicle(source) then
			local Vehicle,Network,Plate = vRPC.VehicleList(source)
			if Vehicle then
				vRPC.AnimActive(source)
				Player(source)["state"]["Buttons"] = true
				TriggerClientEvent("inventory:Close",source)
				vRPC.playAnim(source,false,{"mini@repair","fixing_a_player"},true)

				local Players = vRPC.Players(source)
				for _,v in pairs(Players) do
					async(function()
						TriggerClientEvent("player:VehicleHood",v,Network,"open")
					end)
				end

				if vRP.Task(source,5,5000) then
					Active[Passport] = os.time() + 15
					TriggerClientEvent("Progress",source,"Reparando",15000)

					repeat
						if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
							Active[Passport] = nil

							if vRP.TakeItem(Passport,Full,1,true,Slot) then
								local Players = vRPC.Players(source)
								for _,v in pairs(Players) do
									async(function()
										TriggerClientEvent("inventory:RepairBoosts",v,Network,Plate)
									end)
								end
							end
						end

						Wait(100)
					until not Active[Passport]
				end

				local Players = vRPC.Players(source)
				for _,v in pairs(Players) do
					async(function()
						TriggerClientEvent("player:VehicleHood",v,Network,"close")
					end)
				end

				Player(source)["state"]["Buttons"] = false
				Active[Passport] = nil
				vRPC.Destroy(source)
			end
		end
	end, 

	["circuit"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if not Player(source)["state"]["Handcuff"] then
			local Vehicle,Network,Plate = vRPC.VehicleList(source)
			if Vehicle and Plate and (Boosting[Plate] and vRP.InsideVehicle(source) and Boosting[Plate]["Amount"] < 10) then
				if (not Travel[Passport] or #(vRP.GetEntityCoords(source) - Travel[Passport]) >= 100) then
					TriggerClientEvent("inventory:Close",source)

					if vDEVICE.Device(source,30) then
						if Boosting[Plate]["Class"] >= 4 then
							exports["markers"]:Enter(source,"Boosting",1,Passport,60)
						end

						vRP.UpgradeStress(Passport,3)
						Travel[Passport] = vRP.GetEntityCoords(source)
						Boosting[Plate]["Amount"] = Boosting[Plate]["Amount"] + 1

						if Boosting[Plate]["Amount"] >= 10 then
							exports["boosting"]:Payment(source,Boosting[Plate]["Passport"])
							exports["boosting"]:Remove(Boosting[Plate]["Passport"],Plate)
						else
							TriggerClientEvent("Notify",source,"Boosting [ "..Boosting[Plate]["Amount"].." / 10 ]","Progresso atualizado com sucesso.","verde",5000)
						end
					else
						Boosting[Plate]["Amount"] = Boosting[Plate]["Amount"] - 3

						if Boosting[Plate]["Amount"] < 0 then
							Boosting[Plate]["Amount"] = 0
						end

						TriggerClientEvent("Notify",source,"Boosting [ "..Boosting[Plate]["Amount"].." / 10 ]","Progresso atualizado com sucesso.","amarelo",5000)
					end
				end
			else
				TriggerClientEvent("inventory:Close",source)
				TriggerClientEvent("boosting:Open",source)
			end
		end
	end,


["lockpick"] = function(source, Passport, Amount, Slot, Full, Item, Split)
    if Player(source)["state"]["Handcuff"] then
        vRP.RemoveItem(Passport, Full, 1, true)
        Player(source)["state"]["Handcuff"] = false
        Player(source)["state"]["Commands"] = false
        TriggerClientEvent("sounds:Private", source, "uncuff", 0.5)
        return
    end

    local Vehicle, Network, Plate, Model, Class = vRPC.VehicleList(source)
    if not Vehicle then return end
    if Model == "stockade" or Class == 15 or Class == 16 or Class == 19 then return false end

    vRPC.AnimActive(source)
    Player(source)["state"]["Buttons"] = true
    TriggerClientEvent("inventory:Close", source)

    local NotifyTitle = "Roubo de Veículo"
    local ent = (Network and NetworkGetEntityFromNetworkId(Network)) or 0

    if vRP.InsideVehicle(source) then
        -- dentro do veículo: minigame rápido
        vGARAGE.StartHotwired(source)
        local ok = vRP.Task(source, 4, 4000)
        if ok then
            vGARAGE.RegisterDecors(source, Vehicle)
            TriggerClientEvent("player:Residual", source, "Resíduo de Alumínio")
            DoUnlockFlow(source, Passport, Network, Plate, Model, {
                notifyTitle = NotifyTitle,
                ownedUnlockChance = 75
            })
        end
        vGARAGE.StopHotwired(source)
        -- terminar animação SEMPRE
        vRPC.Destroy(source)
        Player(source)["state"]["Buttons"] = false
        if ok and math.random(1000) >= 875 then
            vRP.RemoveItem(Passport, Full, 1, true)
        end
        return
    end

    -- fora do veículo: minigame com N tentativas
    vRPC.playAnim(source, false, { "missfbi_s4mop", "clean_mop_back_player" }, true)

    -- flags auxiliares
    local isDismantle = (Dismantle and type(Dismantle) == "table" and Dismantle[Plate]) or false
    local isBoosting  = (Boosting  and type(Boosting)  == "table" and Boosting[Plate])  or false
    if isDismantle then
        NotifyTitle = "Desmanche"
        TriggerClientEvent("dismantle:Dispatch", source)
    end
    if isBoosting then
        NotifyTitle = "Boosting"
        TriggerClientEvent("boosting:Dispatch", source)
    end

    TriggerClientEvent("player:Residual", source, "Resíduo de Alumínio")

    -- **só minigame**: 3 tentativas, dificuldade 4, 4s cada
    local success = false
    local ok, attempt = RunLockpickMinigame(source, 3, 4, 4000)
    if ok then
        vGARAGE.RegisterDecors(source, Vehicle)
        DoUnlockFlow(source, Passport, Network, Plate, Model, {
            notifyTitle = NotifyTitle,
            isDismantle = isDismantle,
            ownedUnlockChance = 75
        })
        success = true
    end

    -- parar animação SEMPRE ao concluir
    vRPC.Destroy(source)
    Player(source)["state"]["Buttons"] = false

    if success and math.random(1000) >= 875 then
        vRP.RemoveItem(Passport, Full, 1, true)
    end
end,

["lockpickplus"] = function(source, Passport, Amount, Slot, Full, Item, Split)
    if Player(source)["state"]["Handcuff"] then return end

    local Vehicle, Network, Plate, Model, Class = vRPC.VehicleList(source)
    if not Vehicle then return end
    if Model == "stockade" or Class == 15 or Class == 16 or Class == 19 then return false end

    vRPC.AnimActive(source)
    Player(source)["state"]["Buttons"] = true
    TriggerClientEvent("inventory:Close", source)

    local NotifyTitle = "Roubo de Veículo"
    local ent = (Network and NetworkGetEntityFromNetworkId(Network)) or 0

    if vRP.InsideVehicle(source) then
        vGARAGE.StartHotwired(source)
        local ok = vRP.Task(source, 3, 3000) -- mais fácil/rápido no plus
        if ok then
            vGARAGE.RegisterDecors(source, Vehicle)
            TriggerClientEvent("player:Residual", source, "Resíduo de Alumínio")
            DoUnlockFlow(source, Passport, Network, Plate, Model, {
                notifyTitle = NotifyTitle,
                ownedUnlockChance = 50
            })
        end
        vGARAGE.StopHotwired(source)
        vRPC.Destroy(source)
        Player(source)["state"]["Buttons"] = false
        return
    end

    vRPC.playAnim(source, false, { "missfbi_s4mop","clean_mop_back_player" }, true)

    local isDismantle = (Dismantle and type(Dismantle) == "table" and Dismantle[Plate]) or false
    local isBoosting  = (Boosting  and type(Boosting)  == "table" and Boosting[Plate])  or false
    if isDismantle then
        NotifyTitle = "Desmanche"
        TriggerClientEvent("dismantle:Dispatch", source)
    end
    if isBoosting then
        NotifyTitle = "Boosting"
        TriggerClientEvent("boosting:Dispatch", source)
    end

    TriggerClientEvent("player:Residual", source, "Resíduo de Alumínio")

    -- **só minigame**: 5 tentativas, dificuldade 3, 3s cada (plus é melhor)
    local success = false
    local ok, attempt = RunLockpickMinigame(source, 5, 3, 3000)
    if ok then
        vGARAGE.RegisterDecors(source, Vehicle)
        DoUnlockFlow(source, Passport, Network, Plate, Model, {
            notifyTitle = NotifyTitle,
            isDismantle = isDismantle,
            ownedUnlockChance = 50
        })
        success = true
    end

    vRPC.Destroy(source)
    Player(source)["state"]["Buttons"] = false
end,

	["blocksignal"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if not Player(source)["state"]["Handcuff"] then
			local Vehicle,Network,Plate = vRPC.VehicleList(source)
			if Vehicle and vRP.InsideVehicle(source) then
				if not exports["garages"]:Signal(Plate) then
					vRPC.AnimActive(source)
					vGARAGE.StartHotwired(source)
					Active[Passport] = os.time() + 100
					Player(source)["state"]["Buttons"] = true
					TriggerClientEvent("inventory:Close",source)

					if vRP.Task(source,10,5000) and vRP.TakeItem(Passport,Full,1,true,Slot) then
						TriggerClientEvent("Notify",source,"Sucesso","<b>Bloqueador</b> instalado.","verde",5000)
						TriggerEvent("SignalRemove",Plate)
					end

					Player(source)["state"]["Buttons"] = false
					vGARAGE.StopHotwired(source)
					Active[Passport] = nil
				else
					TriggerClientEvent("inventory:Notify",source,"Aviso","<b>Bloqueador</b> já instalado.","amarelo")
				end
			end
		end
	end,

	["postit"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("postit:initPostit",source)
	end,

	["coffeemilk"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["water"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",5000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,25)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	-- Energético (corrida + stamina por 10s)
["energydrink"] = function(source, Passport, Amount, Slot, Full, Item, Split)
    if not source or not Passport then return end

    -- evita stack do efeito (podes trocar por cooldown se quiseres)
    if Boosting and Boosting[Passport] then
        TriggerClientEvent("Notify", source, "Energético", "Já estás sob efeito do <b>energético</b>.", "amarelo", 4000)
        return
    end

    vRPC.AnimActive(source)
    Active[Passport] = os.time() + 5
    Player(source)["state"]["Buttons"] = true

    TriggerClientEvent("inventory:Close", source)
    TriggerClientEvent("Progress", source, "Bebendo", 3000)

    -- Lata na mão (ecola) + anim beber
    vRPC.CreateObjects(
        source,
        "mp_player_intdrink","loop_bottle",
        "sf_p_sf_grass_gls_s_01a", -- modelo seguro existente
        49,               -- flag
        60309,            -- mão direita
        0.01, 0.0, -0.02, -- offsets
        0.0, 0.0, 10.0    -- rotação
    )

    repeat
        if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
            Active[Passport] = nil
            vRPC.Destroy(source, "one")
            Player(source)["state"]["Buttons"] = false

            if vRP.TakeItem(Passport, Full, 1, true, Slot) then
                vRP.UpgradeThirst(Passport, 15)

                -- marca que está “boostado” (anti-stack simples)
                Boosting = Boosting or {}
                Boosting[Passport] = true

                -- aplica boost no client por 10s (mult 1.20)
                TriggerClientEvent("syn:energy:apply", source, 30000, 1.20)

                TriggerClientEvent("Notify", source, "Energético", "Recebeste um impulso de <b>energia</b>! Corrida aumentada por <b>30s</b>.", "azul", 5000)

                -- limpa flag após 10s (lado server, para anti-stack)
                SetTimeout(30000, function()
                    if Boosting then Boosting[Passport] = nil end
                end)
            end
        end
        Wait(100)
    until not Active[Passport]
end,


	["applejuice"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["orangejuice"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["passionjuice"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)
					vRP.DowngradeStress(Passport,15)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["tangejuice"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["grapejuice"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["lemonjuice"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["strawberryjuice"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["blueberryjuice"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["bananajuice"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["acerolajuice"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["guaranajuice"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["coffeecup"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",10000)
		vRPC.CreateObjects(source,"amb@world_human_aa_coffee@idle_a", "idle_a","p_amb_coffeecup_01",49,28422)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeStress(Passport,7)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["sinkalmy"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Tomando",5000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.DowngradeStress(Passport,20)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["ritmoneury"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Tomando",5000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","vw_prop_casino_water_bottle_01a",49,60309,0.0,0.0,-0.06,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.DowngradeStress(Passport,40)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["cola"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",5000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","prop_ecola_can",49,60309,0.01,0.01,0.05,0.0,0.0,90.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,35)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["soda"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Bebendo",5000)
		vRPC.CreateObjects(source,"mp_player_intdrink","loop_bottle","ng_proc_sodacan_01b",49,60309,0.0,0.0,-0.04,0.0,0.0,130.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,35)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

-------- PESCA

	-- ["fishingrod"] = function(source,Passport,Amount,Slot,Full,Item,Split)
	-- 	if vCLIENT.Fishing(source) then
	-- 		Active[Passport] = os.time() + 100
	-- 		Player(source)["state"]["Buttons"] = true
	-- 		TriggerClientEvent("inventory:Close",source)

	-- 		if not vRPC.PlayingAnim(source,"amb@world_human_stand_fishing@idle_a","idle_c") then
	-- 			vRPC.CreateObjects(source,"amb@world_human_stand_fishing@idle_a","idle_c","prop_fishing_rod_01",49,60309)
	-- 		end

	-- 		if vRP.Task(source,10,25000) and vRP.TakeItem(Passport,"boilies") then
	-- 			local Result = RandPercentage({
	-- 				{ ["Item"] = "sardine", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "smalltrout", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "orangeroughy", ["Chance"] = 100, ["Amount"] = 1 }
	-- 			})

	-- 			exports["pause"]:AddPoints(Passport,1)
	-- 			vRP.PutExperience(Passport,"Fisherman",10)
	-- 			if vRP.CheckWeight(Passport,Result["Item"]) then
	-- 				vRP.GenerateItem(Passport,Result["Item"],Result["Amount"],true)
	-- 			else
	-- 				TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","roxo",5000)
	-- 				exports["inventory"]:Drops(Passport,source,Result["Item"],Result["Amount"])
	-- 			end
	-- 		end

	-- 		Player(source)["state"]["Buttons"] = false
	-- 		Active[Passport] = nil
	-- 	end
	-- end,

	-- ["fishingrod2"] = function(source,Passport,Amount,Slot,Full,Item,Split)
	-- 	if vCLIENT.Fishing(source) then
	-- 		Active[Passport] = os.time() + 100
	-- 		Player(source)["state"]["Buttons"] = true
	-- 		TriggerClientEvent("inventory:Close",source)

	-- 		if not vRPC.PlayingAnim(source,"amb@world_human_stand_fishing@idle_a","idle_c") then
	-- 			vRPC.CreateObjects(source,"amb@world_human_stand_fishing@idle_a","idle_c","prop_fishing_rod_01",49,60309)
	-- 		end

	-- 		if vRP.Task(source,10,25000) and vRP.TakeItem(Passport,"boilies") then
	-- 			local Result = RandPercentage({
	-- 				{ ["Item"] = "sardine", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "smalltrout", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "orangeroughy", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "anchovy", ["Chance"] = 75, ["Amount"] = 1 },
	-- 				{ ["Item"] = "catfish", ["Chance"] = 75, ["Amount"] = 1 }
	-- 			})

	-- 			exports["pause"]:AddPoints(Passport,1)
	-- 			vRP.PutExperience(Passport,"Fisherman",10)
	-- 			if vRP.CheckWeight(Passport,Result["Item"]) then
	-- 				vRP.GenerateItem(Passport,Result["Item"],Result["Amount"],true)
	-- 			else
	-- 				TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","roxo",5000)
	-- 				exports["inventory"]:Drops(Passport,source,Result["Item"],Result["Amount"])
	-- 			end
	-- 		end

	-- 		Player(source)["state"]["Buttons"] = false
	-- 		Active[Passport] = nil
	-- 	end
	-- end,

	-- ["fishingrod3"] = function(source,Passport,Amount,Slot,Full,Item,Split)
	-- 	if vCLIENT.Fishing(source) then
	-- 		Active[Passport] = os.time() + 100
	-- 		Player(source)["state"]["Buttons"] = true
	-- 		TriggerClientEvent("inventory:Close",source)

	-- 		if not vRPC.PlayingAnim(source,"amb@world_human_stand_fishing@idle_a","idle_c") then
	-- 			vRPC.CreateObjects(source,"amb@world_human_stand_fishing@idle_a","idle_c","prop_fishing_rod_01",49,60309)
	-- 		end

	-- 		if vRP.Task(source,10,25000) and vRP.TakeItem(Passport,"boilies") then
	-- 			local Result = RandPercentage({
	-- 				{ ["Item"] = "sardine", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "smalltrout", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "orangeroughy", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "anchovy", ["Chance"] = 75, ["Amount"] = 1 },
	-- 				{ ["Item"] = "catfish", ["Chance"] = 75, ["Amount"] = 1 },
	-- 				{ ["Item"] = "herring", ["Chance"] = 50, ["Amount"] = 1 },
	-- 				{ ["Item"] = "yellowperch", ["Chance"] = 50, ["Amount"] = 1 },
	-- 				{ ["Item"] = "salmon", ["Chance"] = 50, ["Amount"] = 1 }
	-- 			})

	-- 			exports["pause"]:AddPoints(Passport,1)
	-- 			vRP.PutExperience(Passport,"Fisherman",10)
	-- 			if vRP.CheckWeight(Passport,Result["Item"]) then
	-- 				vRP.GenerateItem(Passport,Result["Item"],Result["Amount"],true)
	-- 			else
	-- 				TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","roxo",5000)
	-- 				exports["inventory"]:Drops(Passport,source,Result["Item"],Result["Amount"])
	-- 			end
	-- 		end

	-- 		Player(source)["state"]["Buttons"] = false
	-- 		Active[Passport] = nil
	-- 	end
	-- end,

	-- ["fishingrod4"] = function(source,Passport,Amount,Slot,Full,Item,Split)
	-- 	if vCLIENT.Fishing(source) then
	-- 		Active[Passport] = os.time() + 100
	-- 		Player(source)["state"]["Buttons"] = true
	-- 		TriggerClientEvent("inventory:Close",source)

	-- 		if not vRPC.PlayingAnim(source,"amb@world_human_stand_fishing@idle_a","idle_c") then
	-- 			vRPC.CreateObjects(source,"amb@world_human_stand_fishing@idle_a","idle_c","prop_fishing_rod_01",49,60309)
	-- 		end

	-- 		if vRP.Task(source,10,25000) and vRP.TakeItem(Passport,"boilies") then
	-- 			local Result = RandPercentage({
	-- 				{ ["Item"] = "sardine", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "smalltrout", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "orangeroughy", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "anchovy", ["Chance"] = 75, ["Amount"] = 1 },
	-- 				{ ["Item"] = "catfish", ["Chance"] = 75, ["Amount"] = 1 },
	-- 				{ ["Item"] = "herring", ["Chance"] = 50, ["Amount"] = 1 },
	-- 				{ ["Item"] = "yellowperch", ["Chance"] = 50, ["Amount"] = 1 },
	-- 				{ ["Item"] = "salmon", ["Chance"] = 50, ["Amount"] = 1 },
	-- 				{ ["Item"] = "smallshark", ["Chance"] = 25, ["Amount"] = 1 },
	-- 				{ ["Item"] = "treasurebox", ["Chance"] = 1, ["Amount"] = 1 }
	-- 			})

	-- 			exports["pause"]:AddPoints(Passport,1)
	-- 			vRP.PutExperience(Passport,"Fisherman",10)
	-- 			if vRP.CheckWeight(Passport,Result["Item"]) then
	-- 				vRP.GenerateItem(Passport,Result["Item"],Result["Amount"],true)
	-- 			else
	-- 				TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","roxo",5000)
	-- 				exports["inventory"]:Drops(Passport,source,Result["Item"],Result["Amount"])
	-- 			end
	-- 		end

	-- 		Player(source)["state"]["Buttons"] = false
	-- 		Active[Passport] = nil
	-- 	end
	-- end,

	-- ["fishingrodplus"] = function(source,Passport,Amount,Slot,Full,Item,Split)
	-- 	if vCLIENT.Fishing(source,"fishingrodplus") then
	-- 		Active[Passport] = os.time() + 100
	-- 		Player(source)["state"]["Buttons"] = true
	-- 		TriggerClientEvent("inventory:Close",source)

	-- 		if not vRPC.PlayingAnim(source,"amb@world_human_stand_fishing@idle_a","idle_c") then
	-- 			vRPC.CreateObjects(source,"amb@world_human_stand_fishing@idle_a","idle_c","prop_fishing_rod_01",49,60309)
	-- 		end

	-- 		if vRP.Task(source,10,15000) and vRP.TakeItem(Passport,"boilies") then
	-- 			local Result = RandPercentage({
	-- 				{ ["Item"] = "sardine", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "smalltrout", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "orangeroughy", ["Chance"] = 100, ["Amount"] = 1 },
	-- 				{ ["Item"] = "anchovy", ["Chance"] = 75, ["Amount"] = 1 },
	-- 				{ ["Item"] = "catfish", ["Chance"] = 75, ["Amount"] = 1 },
	-- 				{ ["Item"] = "herring", ["Chance"] = 50, ["Amount"] = 1 },
	-- 				{ ["Item"] = "yellowperch", ["Chance"] = 50, ["Amount"] = 1 },
	-- 				{ ["Item"] = "salmon", ["Chance"] = 50, ["Amount"] = 1 },
	-- 				{ ["Item"] = "smallshark", ["Chance"] = 25, ["Amount"] = 1 },
	-- 				{ ["Item"] = "treasurebox", ["Chance"] = 1, ["Amount"] = 1 }
	-- 			})

	-- 			exports["pause"]:AddPoints(Passport,2)
	-- 			vRP.PutExperience(Passport,"Fisherman",2)
	-- 			if vRP.CheckWeight(Passport,Result["Item"]) then
	-- 				vRP.GenerateItem(Passport,Result["Item"],Result["Amount"],true)
	-- 			else
	-- 				TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","roxo",5000)
	-- 				exports["inventory"]:Drops(Passport,source,Result["Item"],Result["Amount"])
	-- 			end
	-- 		end

	-- 		Player(source)["state"]["Buttons"] = false
	-- 		Active[Passport] = nil
	-- 	end
	-- end,


-----------------------------------------------------------------------------------------------------------------------------------------
-- FISHINGROD
-----------------------------------------------------------------------------------------------------------------------------------------
["fishingrod"] = function(source,Passport,Amount,Slot,Full,Item,Split)
    -- *** REMOVIDO: CanFish ***

    TriggerClientEvent("inventory:CleanWeapons", source)

    Active[Passport] = os.time() + 100
    Player(source)["state"]["Buttons"] = true
    TriggerClientEvent("inventory:Close",source)

    if not vRPC.PlayingAnim(source,"amb@world_human_stand_fishing@idle_a","idle_c") then
        vRPC.CreateObjects(source,"amb@world_human_stand_fishing@idle_a","idle_c","prop_fishing_rod_01",49,60309)
    end

    if not vRP.TakeItem(Passport,"boilies",1,true) then
        TriggerClientEvent("Notify",source,"Pesca","Precisas de <b>isco</b> para pescar.","amarelo",5000)
        StopFishing(source, Passport)
        return
    end

    if not vRP.Task(source, 3, 5000) then
        TriggerClientEvent("Notify",source,"Pesca","A linha afrouxou e o peixe fugiu.","vermelho",4000)
        StopFishing(source, Passport)
        return
    end

    local Result = RandPercentage({
        { ["Item"] = "sardine",       ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "smalltrout",    ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "orangeroughy",  ["Chance"] = 100, ["Amount"] = 1 }
    })

    if not (Result and Result["Item"]) then
        TriggerClientEvent("Notify",source,"Pesca","Não tiveste sorte desta vez. Tenta novamente!","azul",4000)
        StopFishing(source, Passport)
        return
    end

    exports["pause"]:AddPoints(Passport,1)
    vRP.PutExperience(Passport,"Fisherman",10)

    local item = Result["Item"]
    local qty  = Result["Amount"] or 1
    local itemName = (ItemList()[item] and ItemList()[item].Name) or item

    if vRP.CheckWeight(Passport,item) then
        vRP.GenerateItem(Passport,item,qty,true)
        TriggerClientEvent("Notify",source,"Pesca","Pescaste <b>"..qty.."x "..itemName.."</b>!","verde",4000)
    else
        TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","roxo",5000)
        exports["inventory"]:Drops(Passport,source,item,qty)
    end

    StopFishing(source, Passport)
end,

-----------------------------------------------------------------------------------------------------------------------------------------
-- FISHINGROD2
-----------------------------------------------------------------------------------------------------------------------------------------
["fishingrod2"] = function(source,Passport,Amount,Slot,Full,Item,Split)
    -- *** REMOVIDO: CanFish ***

    TriggerClientEvent("inventory:CleanWeapons", source)

    Active[Passport] = os.time() + 100
    Player(source)["state"]["Buttons"] = true
    TriggerClientEvent("inventory:Close",source)

    if not vRPC.PlayingAnim(source,"amb@world_human_stand_fishing@idle_a","idle_c") then
        vRPC.CreateObjects(source,"amb@world_human_stand_fishing@idle_a","idle_c","prop_fishing_rod_01",49,60309)
    end

    if not vRP.TakeItem(Passport,"boilies",1,true) then
        TriggerClientEvent("Notify",source,"Pesca","Precisas de <b>isco</b> para pescar.","amarelo",5000)
        StopFishing(source, Passport)
        return
    end

    if not vRP.Task(source, 3, 5000) then
        TriggerClientEvent("Notify",source,"Pesca","A linha afrouxou e o peixe fugiu.","vermelho",4000)
        StopFishing(source, Passport)
        return
    end

    local Result = RandPercentage({
        { ["Item"] = "sardine",       ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "smalltrout",    ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "orangeroughy",  ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "anchovy",       ["Chance"] = 75,  ["Amount"] = 1 },
        { ["Item"] = "catfish",       ["Chance"] = 75,  ["Amount"] = 1 }
    })

    if not (Result and Result["Item"]) then
        TriggerClientEvent("Notify",source,"Pesca","Não tiveste sorte desta vez. Tenta novamente!","azul",4000)
        StopFishing(source, Passport)
        return
    end

    exports["pause"]:AddPoints(Passport,1)
    vRP.PutExperience(Passport,"Fisherman",10)

    local item = Result["Item"]
    local qty  = Result["Amount"] or 1
    local itemName = (ItemList()[item] and ItemList()[item].Name) or item

    if vRP.CheckWeight(Passport,item) then
        vRP.GenerateItem(Passport,item,qty,true)
        TriggerClientEvent("Notify",source,"Pesca","Pescaste <b>"..qty.."x "..itemName.."</b>!","verde",4000)
    else
        TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","roxo",5000)
        exports["inventory"]:Drops(Passport,source,item,qty)
    end

    StopFishing(source, Passport)
end,

-----------------------------------------------------------------------------------------------------------------------------------------
-- FISHINGROD3
-----------------------------------------------------------------------------------------------------------------------------------------
["fishingrod3"] = function(source,Passport,Amount,Slot,Full,Item,Split)
    -- *** REMOVIDO: CanFish ***

    TriggerClientEvent("inventory:CleanWeapons", source)

    Active[Passport] = os.time() + 100
    Player(source)["state"]["Buttons"] = true
    TriggerClientEvent("inventory:Close",source)

    if not vRPC.PlayingAnim(source,"amb@world_human_stand_fishing@idle_a","idle_c") then
        vRPC.CreateObjects(source,"amb@world_human_stand_fishing@idle_a","idle_c","prop_fishing_rod_01",49,60309)
    end

    if not vRP.TakeItem(Passport,"boilies",1,true) then
        TriggerClientEvent("Notify",source,"Pesca","Precisas de <b>isco</b> para pescar.","amarelo",5000)
        StopFishing(source, Passport)
        return
    end

    if not vRP.Task(source, 3, 5000) then
        TriggerClientEvent("Notify",source,"Pesca","A linha afrouxou e o peixe fugiu.","vermelho",4000)
        StopFishing(source, Passport)
        return
    end

    local Result = RandPercentage({
        { ["Item"] = "sardine",       ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "smalltrout",    ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "orangeroughy",  ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "anchovy",       ["Chance"] = 75,  ["Amount"] = 1 },
        { ["Item"] = "catfish",       ["Chance"] = 75,  ["Amount"] = 1 },
        { ["Item"] = "herring",       ["Chance"] = 50,  ["Amount"] = 1 },
        { ["Item"] = "yellowperch",   ["Chance"] = 50,  ["Amount"] = 1 },
        { ["Item"] = "salmon",        ["Chance"] = 50,  ["Amount"] = 1 }
    })

    if not (Result and Result["Item"]) then
        TriggerClientEvent("Notify",source,"Pesca","Não tiveste sorte desta vez. Tenta novamente!","azul",4000)
        StopFishing(source, Passport)
        return
    end

    exports["pause"]:AddPoints(Passport,1)
    vRP.PutExperience(Passport,"Fisherman",10)

    local item = Result["Item"]
    local qty  = Result["Amount"] or 1
    local itemName = (ItemList()[item] and ItemList()[item].Name) or item

    if vRP.CheckWeight(Passport,item) then
        vRP.GenerateItem(Passport,item,qty,true)
        TriggerClientEvent("Notify",source,"Pesca","Pescaste <b>"..qty.."x "..itemName.."</b>!","verde",4000)
    else
        TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","roxo",5000)
        exports["inventory"]:Drops(Passport,source,item,qty)
    end

    StopFishing(source, Passport)
end,

-----------------------------------------------------------------------------------------------------------------------------------------
-- FISHINGROD4
-----------------------------------------------------------------------------------------------------------------------------------------
["fishingrod4"] = function(source,Passport,Amount,Slot,Full,Item,Split)
    -- *** REMOVIDO: CanFish ***

    TriggerClientEvent("inventory:CleanWeapons", source)

    Active[Passport] = os.time() + 100
    Player(source)["state"]["Buttons"] = true
    TriggerClientEvent("inventory:Close",source)

    if not vRPC.PlayingAnim(source,"amb@world_human_stand_fishing@idle_a","idle_c") then
        vRPC.CreateObjects(source,"amb@world_human_stand_fishing@idle_a","idle_c","prop_fishing_rod_01",49,60309)
    end

    if not vRP.TakeItem(Passport,"boilies",1,true) then
        TriggerClientEvent("Notify",source,"Pesca","Precisas de <b>isco</b> para pescar.","amarelo",5000)
        StopFishing(source, Passport)
        return
    end

    if not vRP.Task(source, 3, 5000) then
        TriggerClientEvent("Notify",source,"Pesca","A linha afrouxou e o peixe fugiu.","vermelho",4000)
        StopFishing(source, Passport)
        return
    end

    local Result = RandPercentage({
        { ["Item"] = "sardine",       ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "smalltrout",    ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "orangeroughy",  ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "anchovy",       ["Chance"] = 75,  ["Amount"] = 1 },
        { ["Item"] = "catfish",       ["Chance"] = 75,  ["Amount"] = 1 },
        { ["Item"] = "herring",       ["Chance"] = 50,  ["Amount"] = 1 },
        { ["Item"] = "yellowperch",   ["Chance"] = 50,  ["Amount"] = 1 },
        { ["Item"] = "salmon",        ["Chance"] = 50,  ["Amount"] = 1 },
        { ["Item"] = "smallshark",    ["Chance"] = 25,  ["Amount"] = 1 },
        { ["Item"] = "treasurebox",   ["Chance"] = 1,   ["Amount"] = 1 }
    })

    if not (Result and Result["Item"]) then
        TriggerClientEvent("Notify",source,"Pesca","Não tiveste sorte desta vez. Tenta novamente!","azul",4000)
        StopFishing(source, Passport)
        return
    end

    exports["pause"]:AddPoints(Passport,1)
    vRP.PutExperience(Passport,"Fisherman",10)

    local item = Result["Item"]
    local qty  = Result["Amount"] or 1
    local itemName = (ItemList()[item] and ItemList()[item].Name) or item

    if vRP.CheckWeight(Passport,item) then
        vRP.GenerateItem(Passport,item,qty,true)
        TriggerClientEvent("Notify",source,"Pesca","Pescaste <b>"..qty.."x "..itemName.."</b>!","verde",4000)
    else
        TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","roxo",5000)
        exports["inventory"]:Drops(Passport,source,item,qty)
    end

    StopFishing(source, Passport)
end,

-----------------------------------------------------------------------------------------------------------------------------------------
-- FISHINGRODPLUS
-----------------------------------------------------------------------------------------------------------------------------------------
["fishingrodplus"] = function(source,Passport,Amount,Slot,Full,Item,Split)
    -- *** REMOVIDO: CanFish ***

    TriggerClientEvent("inventory:CleanWeapons", source)

    Active[Passport] = os.time() + 100
    Player(source)["state"]["Buttons"] = true
    TriggerClientEvent("inventory:Close",source)

    if not vRPC.PlayingAnim(source,"amb@world_human_stand_fishing@idle_a","idle_c") then
        vRPC.CreateObjects(source,"amb@world_human_stand_fishing@idle_a","idle_c","prop_fishing_rod_01",49,60309)
    end

    if not vRP.TakeItem(Passport,"boilies",1,true) then
        TriggerClientEvent("Notify",source,"Pesca","Precisas de <b>isco</b> para pescar.","amarelo",5000)
        StopFishing(source, Passport)
        return
    end

    if not vRP.Task(source,10,7500) then
        TriggerClientEvent("Notify",source,"Pesca","A linha afrouxou e o peixe fugiu.","vermelho",4000)
        StopFishing(source, Passport)
        return
    end

    local Result = RandPercentage({
        { ["Item"] = "sardine",       ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "smalltrout",    ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "orangeroughy",  ["Chance"] = 100, ["Amount"] = 1 },
        { ["Item"] = "anchovy",       ["Chance"] = 75,  ["Amount"] = 1 },
        { ["Item"] = "catfish",       ["Chance"] = 75,  ["Amount"] = 1 },
        { ["Item"] = "herring",       ["Chance"] = 50,  ["Amount"] = 1 },
        { ["Item"] = "yellowperch",   ["Chance"] = 50,  ["Amount"] = 1 },
        { ["Item"] = "salmon",        ["Chance"] = 50,  ["Amount"] = 1 },
        { ["Item"] = "smallshark",    ["Chance"] = 25,  ["Amount"] = 1 },
        { ["Item"] = "treasurebox",   ["Chance"] = 1,   ["Amount"] = 1 }
    })

    if not (Result and Result["Item"]) then
        TriggerClientEvent("Notify",source,"Pesca","Não tiveste sorte desta vez. Tenta novamente!","azul",4000)
        StopFishing(source, Passport)
        return
    end

    exports["pause"]:AddPoints(Passport,2)
    vRP.PutExperience(Passport,"Fisherman",2)

    local item = Result["Item"]
    local qty  = Result["Amount"] or 1
    local itemName = (ItemList()[item] and ItemList()[item].Name) or item

    if vRP.CheckWeight(Passport,item) then
        vRP.GenerateItem(Passport,item,qty,true)
        TriggerClientEvent("Notify",source,"Pesca","Pescaste <b>"..qty.."x "..itemName.."</b>!","verde",4000)
    else
        TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","roxo",5000)
        exports["inventory"]:Drops(Passport,source,item,qty)
    end

    StopFishing(source, Passport)
end,



-------------- FIM PESCA

	["colete"] = function(source, Passport, Amount, Slot, Full, Item, Split)
		if Active[Passport] then return end

		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close", source)
		TriggerClientEvent("Progress", source, "Equipando colete", 5000)

		repeat
			if Active[Passport] and os.time() >= Active[Passport] then
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport, Full, 1, true, Slot) then
					-- usa o teu evento do admin para aplicar 100 de armor
					TriggerClientEvent("admin:applyArmour", source, 100)

					-- aviso pedido
					TriggerClientEvent("Notify", source, "Inventário", "Equipaste <b>colete balístico</b>!", "verde", 5000)
				end
			end
			Wait(100)
		until not Active[Passport]
	end,



	["pizzamozzarella"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",10000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","knjgh_pizzaslice1",49,60309)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Luck",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["pizzabanana"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",10000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","knjgh_pizzaslice2",49,60309)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Luck",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["pizzachocolate"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",10000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","knjgh_pizzaslice3",49,60309)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,40)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Luck",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["sushi"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",10000)
		vRPC.playAnim(source,true,{"mp_player_inteat@burger","mp_player_int_eat_burger"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,20)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Luck",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["nigirizushi"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",10000)
		vRPC.playAnim(source,true,{"mp_player_inteat@burger","mp_player_int_eat_burger"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,20)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Luck",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["calzone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",10000)
		vRPC.playAnim(source,true,{"mp_player_inteat@burger","mp_player_int_eat_burger"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,25)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Luck",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["cookies"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",10000)
		vRPC.playAnim(source,true,{"mp_player_inteat@burger","mp_player_int_eat_burger"},true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,15)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Luck",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["hamburger"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",5000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","prop_cs_burger_01",49,60309)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,35)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["hamburger2"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",4000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","prop_cs_burger_01",49,60309)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,50)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Luck",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["hamburger3"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",4000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","prop_cs_burger_01",49,60309)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,50)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Luck",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["steak"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",5000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","prop_cs_burger_01",49,60309)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,70)
					vRP.UpgradeThirst(Passport,25)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["ration"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if not vRP.InsideVehicle(source) and not vCLIENT.CheckRation(source) then
			Active[Passport] = os.time() + 10
			Player(source)["state"]["Buttons"] = true
			TriggerClientEvent("inventory:Close",source)
			TriggerClientEvent("Progress",source,"Colocando",10000)
			vRPC.playAnim(source,false,{"anim@amb@clubhouse@tutorial@bkr_tut_ig3@","machinic_loop_mechandplayer"},true)

			repeat
				if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
					vRPC.Destroy(source)
					Active[Passport] = nil
					Player(source)["state"]["Buttons"] = false

					if vRP.TakeItem(Passport,Full,1,true,Slot) then
						TriggerClientEvent("inventory:Ration",source)
					end
				end

				Wait(100)
			until not Active[Passport]
		end
	end,

	["pistol_bench"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "gr_prop_gr_bench_02a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) then
			if vCLIENT.CheckInterior(source) then
				TriggerClientEvent("Notify",source,"Atenção","Só pode ser posicionado fora de interiores.","amarelo",5000)
				Player(source)["state"]["Buttons"] = false

				return false
			end

			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				repeat
					Selected = GenerateString("DDLLDDLL")
				until Selected and not Objects[Selected]

				Objects[Selected] = { Coords = Coords, Object = Hash, Item = Full, Mode = "Craftings", Weight = 0.75, Bucket = GetPlayerRoutingBucket(source) }
				SaveObjects[Selected] = Objects[Selected]

				TriggerClientEvent("objects:Adicionar",-1,Selected,Objects[Selected])
			end
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["smg_bench"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "gr_prop_gr_bench_02b"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) then
			if vCLIENT.CheckInterior(source) then
				TriggerClientEvent("Notify",source,"Atenção","Só pode ser posicionado fora de interiores.","amarelo",5000)
				Player(source)["state"]["Buttons"] = false

				return false
			end

			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				repeat
					Selected = GenerateString("DDLLDDLL")
				until Selected and not Objects[Selected]

				Objects[Selected] = { Coords = Coords, Object = Hash, Item = Full, Mode = "Craftings", Weight = 0.75, Bucket = GetPlayerRoutingBucket(source) }
				SaveObjects[Selected] = Objects[Selected]

				TriggerClientEvent("objects:Adicionar",-1,Selected,Objects[Selected])
			end
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["rifle_bench"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "xm3_prop_xm3_bench_04b"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) then
			if vCLIENT.CheckInterior(source) then
				TriggerClientEvent("Notify",source,"Atenção","Só pode ser posicionado fora de interiores.","amarelo",5000)
				Player(source)["state"]["Buttons"] = false

				return false
			end

			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				repeat
					Selected = GenerateString("DDLLDDLL")
				until Selected and not Objects[Selected]

				Objects[Selected] = { Coords = Coords, Object = Hash, Item = Full, Mode = "Craftings", Weight = 0.75, Bucket = GetPlayerRoutingBucket(source) }
				SaveObjects[Selected] = Objects[Selected]

				TriggerClientEvent("objects:Adicionar",-1,Selected,Objects[Selected])
			end
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["drugs_bench"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_table_01b"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) then
			if vCLIENT.CheckInterior(source) then
				TriggerClientEvent("Notify",source,"Atenção","Só pode ser posicionado fora de interiores.","amarelo",5000)
				Player(source)["state"]["Buttons"] = false

				return false
			end

			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				repeat
					Selected = GenerateString("DDLLDDLL")
				until Selected and not Objects[Selected]

				Objects[Selected] = { Coords = Coords, Object = Hash, Item = Full, Mode = "Craftings", Weight = 0.85, Bucket = GetPlayerRoutingBucket(source) }
				SaveObjects[Selected] = Objects[Selected]

				TriggerClientEvent("objects:Adicionar",-1,Selected,Objects[Selected])
			end
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["blueprint_bench"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "prop_tool_bench02"
		local Application,Coords = vRPC.ObjectControlling(source,Hash,90.0)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) then
			if vCLIENT.CheckInterior(source) then
				TriggerClientEvent("Notify",source,"Atenção","Só pode ser posicionado fora de interiores.","amarelo",5000)
				Player(source)["state"]["Buttons"] = false

				return false
			end

			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				repeat
					Selected = GenerateString("DDLLDDLL")
				until Selected and not Objects[Selected]

				Objects[Selected] = { Coords = Coords, Object = Hash, Item = Full, Mode = "Craftings", Weight = 0.85, Bucket = GetPlayerRoutingBucket(source) }
				SaveObjects[Selected] = Objects[Selected]

				TriggerClientEvent("objects:Adicionar",-1,Selected,Objects[Selected])
			end
		end

		Player(source)["state"]["Buttons"] = false
	end,

		["spikestrips"] = function(source,Passport,Amount,Slot,Full,Item,Split)
			Player(source)["state"]["Buttons"] = true
			TriggerClientEvent("inventory:Close",source)

			local Hash = "p_ld_stinger_s"
			local Application,Coords = vRPC.ObjectControlling(source,Hash,0.0,2.5)
			if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) then
				if vCLIENT.CheckInterior(source) then
					TriggerClientEvent("Notify",source,"Atenção","Só pode ser posicionado fora de interiores.","amarelo",5000)
					Player(source)["state"]["Buttons"] = false
					return false
				end

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					repeat
						Selected = GenerateString("DDLLDDLL")
					until Selected and not Objects[Selected]

					-- Igual à barreira: precisa de Item/Mode/Weight para ser “pegável”
					Objects[Selected] = {
						Coords = Coords,
						Object = Hash,
						Item = "spikestrips",  -- força o nome correto
						Mode = "Store",
						Weight = 0.50,
						Active = "Spikes",
						Bucket = GetPlayerRoutingBucket(source)
					}
					SaveObjects[Selected] = Objects[Selected]

					TriggerClientEvent("objects:Adicionar",-1,Selected,Objects[Selected])
				end
			end

			Player(source)["state"]["Buttons"] = false
		end,


	["moneywash"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_prtmachine_dryer_spin"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash,0.675) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["moneywash"]:Wash(Passport,Full,Hash,Coords,GetPlayerRoutingBucket(source),75,70)
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["moneywashplus"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_prtmachine_dryer_spin"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash,0.675) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["moneywash"]:Wash(Passport,Full,Hash,Coords,GetPlayerRoutingBucket(source),100,95)
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["weedclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"weed",{ ["Min"] = 3, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["cokeclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"coke",{ ["Min"] = 3, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["tomatoclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"tomato",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["passionclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"passion",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["tangeclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"tange",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["orangeclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"orange",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["appleclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"apple",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["grapeclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"grape",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["lemonclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"lemon",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["bananaclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"banana",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["acerolaclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"acerola",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["strawberryclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"strawberry",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["blueberryclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"blueberry",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["coffeeclone"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "bkr_prop_weed_med_01a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			exports["plants"]:Plants(Hash,Coords,GetPlayerRoutingBucket(source),"coffee",{ ["Min"] = 4, ["Max"] = 6 })
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["barrier"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "prop_mp_barrier_02b"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) then
			if vCLIENT.CheckInterior(source) then
				TriggerClientEvent("Notify",source,"Atenção","Só pode ser posicionado fora de interiores.","amarelo",5000)
				Player(source)["state"]["Buttons"] = false

				return false
			end

			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				repeat
					Selected = GenerateString("DDLLDDLL")
				until Selected and not Objects[Selected]

				Objects[Selected] = { Coords = Coords, Object = Hash, Item = Full, Mode = "Store", Weight = 0.75, Bucket = GetPlayerRoutingBucket(source) }
				SaveObjects[Selected] = Objects[Selected]

				TriggerClientEvent("objects:Adicionar",-1,Selected,Objects[Selected])
			end
		end

		Player(source)["state"]["Buttons"] = false
	end,


	["foodbag"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "prop_paper_bag_01"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) then
			if vCLIENT.CheckInterior(source) then
				TriggerClientEvent("Notify",source,"Atenção","Só pode ser posicionado fora de interiores.","amarelo",5000)
				Player(source)["state"]["Buttons"] = false

				return false
			end

			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				repeat
					Selected = GenerateString("DDLLDDLL")
				until Selected and not Objects[Selected]

				Objects[Selected] = { Coords = Coords, Object = Hash, Item = Full, Mode = "Chests", Weight = 1.0, Bucket = GetPlayerRoutingBucket(source)  }
				SaveObjects[Selected] = Objects[Selected]

				TriggerClientEvent("objects:Adicionar",-1,Selected,Objects[Selected])
			end
		end

		Player(source)["state"]["Buttons"] = false
	end,
 
	["storage25"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "prop_mb_cargo_04a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) then
			if vCLIENT.CheckInterior(source) then
				TriggerClientEvent("Notify",source,"Atenção","Só pode ser posicionado fora de interiores.","amarelo",5000)
				Player(source)["state"]["Buttons"] = false

				return false
			end

			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				repeat
					Selected = GenerateString("DDLLDDLL")
				until Selected and not Objects[Selected]

				Objects[Selected] = { Coords = Coords, Object = Hash, Item = Full, Mode = "Chests", Weight = 1.0, Bucket = GetPlayerRoutingBucket(source)  }
				SaveObjects[Selected] = Objects[Selected]

				TriggerClientEvent("objects:Adicionar",-1,Selected,Objects[Selected])
			end
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["storage50"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "prop_mb_cargo_04a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) then
			if vCLIENT.CheckInterior(source) then
				TriggerClientEvent("Notify",source,"Atenção","Só pode ser posicionado fora de interiores.","amarelo",5000)
				Player(source)["state"]["Buttons"] = false

				return false
			end

			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				repeat
					Selected = GenerateString("DDLLDDLL")
				until Selected and not Objects[Selected]

				Objects[Selected] = { Coords = Coords, Object = Hash, Item = Full, Mode = "Chests", Weight = 1.0, Bucket = GetPlayerRoutingBucket(source)  }
				SaveObjects[Selected] = Objects[Selected]

				TriggerClientEvent("objects:Adicionar",-1,Selected,Objects[Selected])
			end
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["storage75"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)

		local Hash = "prop_mb_cargo_04a"
		local Application,Coords = vRPC.ObjectControlling(source,Hash)
		if Application and Coords and not vCLIENT.ObjectExists(source,Coords,Hash) then
			if vCLIENT.CheckInterior(source) then
				TriggerClientEvent("Notify",source,"Atenção","Só pode ser posicionado fora de interiores.","amarelo",5000)
				Player(source)["state"]["Buttons"] = false

				return false
			end

			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				repeat
					Selected = GenerateString("DDLLDDLL")
				until Selected and not Objects[Selected]

				Objects[Selected] = { Coords = Coords, Object = Hash, Item = Full, Mode = "Chests", Weight = 1.0, Bucket = GetPlayerRoutingBucket(source)  }
				SaveObjects[Selected] = Objects[Selected]

				TriggerClientEvent("objects:Adicionar",-1,Selected,Objects[Selected])
			end
		end

		Player(source)["state"]["Buttons"] = false
	end,

	["hotdog"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",5000)
		vRPC.CreateObjects(source,"amb@code_human_wander_eating_donut@male@idle_a","idle_c","prop_cs_hotdog_01",49,28422)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,35)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["sandwich"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",5000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","prop_sandwich_01",49,18905,0.13,0.05,0.02,-50.0,16.0,60.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,35)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["tacos"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",5000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","prop_taco_01",49,18905,0.16,0.06,0.02,-50.0,220.0,60.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,35)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["fries"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",5000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","prop_food_bs_chips",49,18905,0.10,0.0,0.08,150.0,320.0,160.0)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,35)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["milkshake"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Tomando",10000)
		vRPC.CreateObjects(source,"amb@world_human_aa_coffee@idle_a", "idle_a","p_amb_coffeecup_01",49,28422)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,25)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["cappuccino"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Tomando",10000)
		vRPC.CreateObjects(source,"amb@world_human_aa_coffee@idle_a", "idle_a","p_amb_coffeecup_01",49,28422)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeThirst(Passport,25)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Dexterity",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["applelove"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",10000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","prop_choc_ego",49,60309)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,10)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Luck",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["cupcake"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",10000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","prop_choc_ego",49,60309)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,15)

					if vCLIENT.Restaurant(source) then
						TriggerEvent("inventory:BuffServer",source,Passport,"Luck",600)
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["chocolate"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",5000)
		vRPC.CreateObjects(source,"mp_player_inteat@burger","mp_player_int_eat_burger","prop_choc_ego",49,60309)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,4)
					vRP.DowngradeStress(Passport,4)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["donut"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 5
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("Progress",source,"Comendo",5000)
		vRPC.CreateObjects(source,"amb@code_human_wander_eating_donut@male@idle_a","idle_c","prop_amb_donut",49,28422)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source,"one")
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport,Full,1,true,Slot) then
					vRP.UpgradeHunger(Passport,5)
				end
			end

			Wait(100)
		until not Active[Passport]
	end,

	["dismantle"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if vCLIENT.Dismantle(source) and vRP.TakeItem(Passport,Full,1,true,Slot) then
			TriggerClientEvent("inventory:Update",source)
		end
	end,

	["tyres"] = function(source, Passport, Amount, Slot, Full, Item, Split)
    -- não permite dentro do veículo
    if vRP.InsideVehicle(source) then
        TriggerClientEvent("inventory:Notify", source, "Atenção", "Saia do veículo para trocar o <b>pneu</b>.", "amarelo", 4500)
        return false
    end

    -- anti-duplo uso
    if ActiveTyre[Passport] then
        TriggerClientEvent("inventory:Notify", source, "Atenção", "Já estás a trocar um <b>pneu</b>. Aguarda.", "amarelo", 3000)
        return false
    end

    -- ler alvo no client (veículo, pneu, net, placa, modelo)
    local Vehicle, Tyre, NetId, Plate, Model = vCLIENT.Tyres(source)
    if not Vehicle or not NetId then
        TriggerClientEvent("inventory:Notify", source, "Atenção", "Nenhum <b>pneu danificado</b> próximo.", "vermelho", 4500)
        return false
    end

    -- preparar anima/prop e progress
    TriggerClientEvent("inventory:Close", source)
    vRPC.playAnim(source, false, { "amb@medic@standing@kneel@idle_a", "idle_a" }, true)
    vRPC.CreateObjects(source, "anim@heists@box_carry@", "idle", "imp_prop_impexp_tyre_01a", 49, 28422, -0.02, -0.10, 0.20, 10.0, 0.0, 0.0)

    ActiveTyre[Passport] = true
    Player(source)["state"]["Buttons"] = true
    TriggerClientEvent("Progress", source, "A trocar o pneu", 5000)

    SetTimeout(5200, function()
        -- guard de limpeza
        if not ActiveTyre[Passport] then return end
        ActiveTyre[Passport] = nil
        Player(source)["state"]["Buttons"] = false

        -- consome o item do slot (kit/pneu)
        if not vRP.TakeItem(Passport, Full, 1, true, Slot) then
            TriggerClientEvent("inventory:Notify", source, "Atenção", "Faltou o <b>kit de pneu</b>.", "vermelho", 4500)
            pcall(function() vRPC.Destroy(source) end)
            return
        end

        -- se tiveres VehicleMode e for de trabalho, arranja todos
        local tyreToFix = Tyre
        if type(VehicleMode) == "function" and Model and VehicleMode(Model) == "Work" then
            tyreToFix = "All"
        end

        -- aplica reparação em broadcast (compatível com o teu client)
        TriggerClientEvent("inventory:RepairTyres", -1, NetId, tyreToFix, Plate)

        TriggerClientEvent("inventory:Notify", source, "Sucesso", "Pneu <b>substituído</b>.", "verde", 4000)
        pcall(function() vRPC.Destroy(source) end)
    end)

    return true
end,



	["coilover"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if vRP.InsideVehicle(source) then
			TriggerClientEvent("inventory:Close",source)

			local Model,Vehicle,Plate = vRPC.VehicleName(source)
			local Networked = NetworkGetEntityFromNetworkId(Vehicle)
			local Consult = vRP.Query("vehicles/PlateUsers",{ plate = Plate, vehicle = Model })
			if DoesEntityExist(Networked) and Consult[1] and vRP.TakeItem(Passport,Full,1,true,Slot) then
				Entity(Networked)["state"]:set("Drift",true,true)
				vRP.Query("vehicles/CoiloverVehicles",{ vehicle = Model, plate = Plate })
				TriggerClientEvent("Notify",source,"Sucesso","Suspensão Coilover instalada.","verde",5000)
			end
		end
	end,

	["seatbelt"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if vRP.InsideVehicle(source) then
			TriggerClientEvent("inventory:Close",source)

			local Model,Vehicle,Plate = vRPC.VehicleName(source)
			local Networked = NetworkGetEntityFromNetworkId(Vehicle)
			local Consult = vRP.Query("vehicles/PlateUsers",{ plate = Plate, vehicle = Model })
			if DoesEntityExist(Networked) and Consult[1] and vRP.TakeItem(Passport,Full,1,true,Slot) then
				Entity(Networked)["state"]:set("Seatbelt",true,true)
				vRP.Query("vehicles/SeatbeltVehicles",{ vehicle = Model, plate = Plate })
				TriggerClientEvent("Notify",source,"Sucesso","Cinto de Corrida ativado.","verde",5000)
			end
		end
	end,

	["premiumplate"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		if vRP.InsideVehicle(source) then
			TriggerClientEvent("inventory:Close",source)

			local Model,Vehicle,Plate = vRPC.VehicleName(source)
			local Networked = NetworkGetEntityFromNetworkId(Vehicle)
			local Consult = vRP.Query("vehicles/selectVehicles",{ Passport = Passport, vehicle = Model })
			if DoesEntityExist(Networked) and Consult[1] then
				local Keyboard = vKEYBOARD.Primary(source,"Placa")
				if Keyboard then
					local NewPlate = sanitizeString(Keyboard[1],"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

					if string.len(NewPlate) ~= 8 then
						TriggerClientEvent("Notify",source,"Aviso","Nome de definição inválido.","amarelo",5000)
						return
					else
						if vRP.PassportPlate(NewPlate) then
							TriggerClientEvent("Notify",source,"Aviso","Placa escolhida já existe no sistema.","amarelo",5000)
							return
						else
							if vRP.TakeItem(Passport,Full,1,true,Slot) then
								local NewPlate = string.upper(NewPlate)

								vRP.Query("vehicles/plateVehiclesUpdate",{ Passport = Passport, vehicle = Model, plate = string.upper(NewPlate) })
								TriggerClientEvent("Notify",source,"Sucesso","Placa atualizada.","verde",5000)
								TriggerEvent("garages:ChangePlate",Plate,NewPlate)
								SetVehicleNumberPlateText(Networked,NewPlate)
							end
						end
					end
				end
			else
				TriggerClientEvent("Notify",source,"Aviso","Modelo de veículo não encontrado.","amarelo",5000)
			end
		end
	end,

	["radio"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("inventory:Close",source)
		TriggerClientEvent("radio:Open",source)
		vRPC.AnimActive(source)
	end,


	["scuba"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("inventory:Scuba",source)
	end,


	["gasmask"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		TriggerClientEvent("inventory:GasMask",source)
	end,


	["handcuff"] = function(source,Passport,Amount,Slot,Full,Item,Split)
	if not vRP.InsideVehicle(source) then
		local ClosestPed = vRPC.ClosestPed(source)
		if ClosestPed and not vRP.IsEntityVisible(ClosestPed) then
			Player(source)["state"]["Cancel"] = true
			Player(source)["state"]["Buttons"] = true

			if Player(ClosestPed)["state"]["Handcuff"] then
				-- DESALGEMAR
				Player(ClosestPed)["state"]["Handcuff"] = false
				Player(ClosestPed)["state"]["Commands"] = false

				TriggerClientEvent("sounds:Private",source,"uncuff",0.5)
				TriggerClientEvent("sounds:Private",ClosestPed,"uncuff",0.5)

				-- Notificações
				TriggerClientEvent("Notify",source,"SUCESSO","Desalgemaste o jogador.","verde",5000)
				TriggerClientEvent("Notify",ClosestPed,"INFORMAÇÃO","Foste desalgemado.","amarelo",5000)

				vRPC.Destroy(ClosestPed)
				vRPC.Destroy(source)
			else
				-- ALGEMAR
				if vRP.GetHealth(ClosestPed) > 100 then
					TriggerEvent("inventory:ServerCarry",source,Passport,ClosestPed,true)
					vRPC.playAnim(source,false,{"mp_arrest_paired","cop_p2_back_left"},false)
					vRPC.playAnim(ClosestPed,false,{"mp_arrest_paired","crook_p2_back_left"},false)

					SetTimeout(3500,function()
						TriggerEvent("inventory:ServerCarry",source,Passport)
						TriggerClientEvent("sounds:Private",source,"cuff",0.5)
						TriggerClientEvent("sounds:Private",ClosestPed,"cuff",0.5)

						-- Notificações após concluir a animação
						TriggerClientEvent("Notify",source,"SUCESSO","Algemaste o jogador.","verde",5000)
						TriggerClientEvent("Notify",ClosestPed,"INFORMAÇÃO","Foste algemado.","amarelo",5000)

						vRPC.Destroy(ClosestPed)
						vRPC.Destroy(source)
					end)
				else
					TriggerClientEvent("sounds:Private",source,"cuff",0.5)
					TriggerClientEvent("sounds:Private",ClosestPed,"cuff",0.5)

					-- Notificações imediatas (alvo inconsciente/baixa vida)
					TriggerClientEvent("Notify",source,"SUCESSO","Algemaste o jogador.","verde",5000)
					TriggerClientEvent("Notify",ClosestPed,"INFORMAÇÃO","Foste algemado.","amarelo",5000)
				end

				Player(ClosestPed)["state"]["Handcuff"] = true
				Player(ClosestPed)["state"]["Commands"] = true
				TriggerClientEvent("inventory:Close",ClosestPed)
				TriggerClientEvent("radio:RadioClean",ClosestPed)
			end

			Player(source)["state"]["Cancel"] = false
			Player(source)["state"]["Buttons"] = false
		end
	end
end,


	-- Item: Capuz (igual aos outros: procura o mais perto no server)
	["hood"] = function(source, Passport, Amount, Slot, Full, Item, Split)
		if vRP.InsideVehicle(source) then return end

		-- usa o mesmo método que já tens nos outros itens
		local ClosestPed = vRPC.ClosestPed(source)
		if not ClosestPed then
			TriggerClientEvent("Notify", source, "Sistema", "Ninguém por perto para usar o capuz.", "amarelo", 5000)
			return
		end

		if vRP.IsEntityVisible(ClosestPed) then
			TriggerClientEvent("Notify", source, "Sistema", "Não consegues usar o capuz neste jogador.", "amarelo", 5000)
			return
		end

		local targetState = Player(ClosestPed) and Player(ClosestPed)["state"]
		if not (targetState and targetState["Handcuff"]) then
			TriggerClientEvent("Notify", source, "Sistema", "A pessoa precisa estar algemada.", "amarelo", 5000)
			return
		end

		-- toggle: lê o estado atual do capuz no alvo (state bag)
		local hoodOn = targetState["Hood"] == true

		-- Se quiseres consumir item só quando coloca (e não quando tira), ativa o TakeItem aqui
		if not hoodOn then
			-- Ex.: consumo ao colocar (se usa Durability/Repair, podes deixar sem TakeItem)
			-- if not vRP.TakeItem(Passport, Full, 1, true, Slot) then return end
		end

		if not hoodOn then
			-- LIGAR capuz
			Player(ClosestPed)["state"]["Hood"] = true
			TriggerClientEvent("hood:AttachProp", ClosestPed)   -- saco na cabeça + HUD fade escuro
			TriggerClientEvent("inventory:Close", ClosestPed)

			TriggerClientEvent("Notify", source, "Inventário", "Colocaste um <b>capuz</b>.", "verde", 4000)
			TriggerClientEvent("Notify", ClosestPed, "Sistema", "Meteram-te um <b>capuz</b>.", "vermelho", 5000)
		else
			-- DESLIGAR capuz
			Player(ClosestPed)["state"]["Hood"] = false
			TriggerClientEvent("hood:DetachProp", ClosestPed)   -- remove saco + HUD volta a ver

			TriggerClientEvent("Notify", source, "Inventário", "Retiraste o <b>capuz</b>.", "azul", 4000)
			TriggerClientEvent("Notify", ClosestPed, "Sistema", "Tiraram-te o <b>capuz</b>.", "azul", 5000)
		end
	end,



["rope"] = function(source,Passport,Amount,Slot,Full,Item,Split)
	if not vRP.InsideVehicle(source) then
		if not Carry[Passport] then
			local OtherSource = vRPC.ClosestPed(source)
			local OtherPassport = vRP.Passport(OtherSource)

			if OtherSource and not Carry[OtherPassport] and vRP.GetHealth(OtherSource) <= 100 and not vRP.IsEntityVisible(OtherSource) then
				Carry[Passport] = OtherSource
				Player(source)["state"]["Carry"] = true
				Player(OtherSource)["state"]["Carry"] = true

				TriggerClientEvent("inventory:Carry",OtherSource,source,"Attach")

				TriggerClientEvent("Notify",source,"SUCESSO","Agarraste o jogador com uma corda.","verde",5000)
				TriggerClientEvent("Notify",OtherSource,"INFORMAÇÃO","Foste agarrado com uma corda.","amarelo",5000)
			else
				TriggerClientEvent("Notify",source,"ERRO","Não há ninguém elegível por perto para agarrar com a corda.","vermelho",4000)
			end
		else
			-- SOLTAR
			local targetSrc = Carry[Passport]
			-- tenta detach se o alvo ainda estiver online
			if targetSrc and GetPlayerPed(targetSrc) ~= 0 then
				TriggerClientEvent("inventory:Carry",targetSrc,source,"Detach")
				Player(targetSrc)["state"]["Carry"] = false
				TriggerClientEvent("Notify",targetSrc,"INFORMAÇÃO","Foste largado.","amarelo",5000)
			end

			Player(source)["state"]["Carry"] = false
			Carry[Passport] = nil

			TriggerClientEvent("Notify",source,"SUCESSO","Largaste o jogador.","verde",5000)
		end
	end
end,


	["premium"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local Hierarchy = 1
		if not vRP.UserPremium(Passport) then
			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				vRP.SetPremium(source,Passport,Hierarchy,30)
				TriggerClientEvent("inventory:Update",source)
			end
		else
			if vRP.LevelPremium(source) == Hierarchy and vRP.TakeItem(Passport,Full,1,true,Slot) then
				vRP.UpgradePremium(source,Passport,Hierarchy,30)
				TriggerClientEvent("inventory:Update",source)
			end
		end
	end,

	["premium2"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local Hierarchy = 2
		if not vRP.UserPremium(Passport) then
			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				vRP.SetPremium(source,Passport,Hierarchy,30)
				TriggerClientEvent("inventory:Update",source)
			end
		else
			if vRP.LevelPremium(source) == Hierarchy and vRP.TakeItem(Passport,Full,1,true,Slot) then
				vRP.UpgradePremium(source,Passport,Hierarchy,30)
				TriggerClientEvent("inventory:Update",source)
			end
		end
	end,

	["premium3"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local Hierarchy = 3
		if not vRP.UserPremium(Passport) then
			if vRP.TakeItem(Passport,Full,1,true,Slot) then
				vRP.SetPremium(source,Passport,Hierarchy,30)
				TriggerClientEvent("inventory:Update",source)
			end
		else
			if vRP.LevelPremium(source) == Hierarchy and vRP.TakeItem(Passport,Full,1,true,Slot) then
				vRP.UpgradePremium(source,Passport,Hierarchy,30)
				TriggerClientEvent("inventory:Update",source)
			end
		end
	end,

	["pager"] = function(source,Passport,Amount,Slot,Full,Item,Split)
		local ClosestPed = vRPC.ClosestPed(source)
		if ClosestPed and Player(ClosestPed)["state"]["Handcuff"] then
			local OtherPassport = vRP.Passport(ClosestPed)
			if OtherPassport then
				if vRP.HasService(OtherPassport,"Policia") then
					TriggerEvent("Wanted",source,Passport,600)

					if vRP.TakeItem(Passport,Full,1,true,Slot) then
						vRP.ServiceLeave(ClosestPed,OtherPassport,"Policia",true)
						TriggerClientEvent("inventory:Notify",source,"Sucesso","Comunicações foram retiradas.","verde")
					end
				end
			end
		end
	end,

["cellphone"] = function(source, Passport, Amount, Slot, Full, Item, Split)
    TriggerClientEvent("inventory:Close", source)
    TriggerClientEvent("npwd:phone:open", source)
    vRPC.AnimActive(source)
end,
}
--------------------------------------------------------------------------------------------------------------------------------------------
----- BLUEPRINTSTART
--------------------------------------------------------------------------------------------------------------------------------------------
-- for Name,v in pairs(ItemList()) do
-- 	if v["Blueprint"] then
-- 		Use["blueprint_"..Name] = function(source,Passport,Amount,Slot,Full,Item,Split)
-- 			if not Users["Blueprint"][Passport] then
-- 				Users["Blueprint"][Passport] = {}
-- 			end

-- 			if Users["Blueprint"][Passport] and Users["Blueprint"][Passport][Name] then
-- 				TriggerClientEvent("inventory:Notify",source,"Aviso","Já possui este aprendizado.","amarelo")

-- 				return false
-- 			end

-- 			if vRP.TakeItem(Passport,Full,1,true,Slot) then
-- 				TriggerClientEvent("inventory:Notify",source,"Sucesso","Aprendizado adicionado.","verde")
-- 				TriggerClientEvent("inventory:Update",source)
-- 				Users["Blueprint"][Passport][Name] = true
-- 			end
-- 		end
-- 	end
-- end


