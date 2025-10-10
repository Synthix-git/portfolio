-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Reserved = {}


-- Decai durabilidade apenas com tempo de jogo (online), não tempo real.
-- Espera que vRP.GetPlayTime(Passport) retorne minutos jogados acumulados.
-- Fallback: se não existir GetPlayTime, usa tempo real (mantém comportamento antigo).
local function ComputeDurabilityOnlineOnly(Passport, forceKey)
    local Split = splitString(forceKey, "-")
    local durabilityDays = ItemDurability(forceKey)
    if not durabilityDays then return nil end

    -- tempo máximo em segundos (X dias)
    local maxSeconds = durabilityDays * 24 * 60 * 60

    -- Caso tenhas playtime acumulado no teu core:
    local getPlayTime = vRP.GetPlayTime
    if type(getPlayTime) == "function" then
        -- Convenção: Split[2] passa a guardar o "baseline" de playtime (minutos) quando o item começou a contar.
        -- Se o item ainda estiver no formato antigo (timestamp grande), fazemos uma conversão suave:
        local baseline = tonumber(Split[2]) or 0

        if baseline > 1000000000 then
            -- É muito provavelmente um timestamp legado. Convertemos para baseline de playtime atual (minutos).
            -- Isto "trava" a durabilidade até o jogador voltar a jogar (decai só a partir de agora).
            local nowPlayMin = tonumber(getPlayTime(Passport) or 0)
            baseline = nowPlayMin
            -- Nota: Se quiseres persistir a migração no item, atualiza a chave do item noutro ponto do teu inventário.
        end

        local nowPlayMin = tonumber(getPlayTime(Passport) or 0)
        local elapsedSeconds = math.max(0, (nowPlayMin - baseline) * 60)

        -- não deixa passar do máximo (só por segurança visual)
        elapsedSeconds = math.min(elapsedSeconds, maxSeconds)
        return parseInt(elapsedSeconds)
    else
        -- Fallback (mantém o comportamento antigo se não houver playtime disponível):
        local createdAt = tonumber(Split[2]) or os.time()
        local elapsedSeconds = math.max(0, os.time() - createdAt)
        elapsedSeconds = math.min(elapsedSeconds, maxSeconds)
        return parseInt(elapsedSeconds)
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SAVESERVER
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("SaveServer",function(Silenced)
	if not Silenced then
		for Route,Table in pairs(Drops) do
			for Number,v in pairs(Table) do
				if Drops[Route] and Drops[Route][Number] then
					if Drops[Route][Number]["key"] and ItemUnique(Drops[Route][Number]["key"]) then
						vRP.RemSrvData(SplitUnique(Drops[Route][Number]["key"]))
					end

					TriggerClientEvent("inventory:DropsRemover",-1,Route,Number)
					Drops[Route][Number] = nil
				end
			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DROPS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Drops(Item,Slot,Amount)
	local source = source
	local Amount = parseInt(Amount,true)
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and Amount >= 1 and not Player(source)["state"]["Handcuff"] and not exports["hud"]:Wanted(Passport) and not vRP.InsideVehicle(source) then
		if vRP.TakeItem(Passport,Item,Amount,false,Slot) then
			exports["inventory"]:Drops(Passport,source,Item,Amount,true)
		else
			TriggerClientEvent("inventory:Update",source)
		end
	else
		TriggerClientEvent("inventory:Update",source)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DROPS
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Drops",function(Passport,source,Item,Amount,Force)
	local Item = Item
	local Force = Force
	local Amount = Amount
	local source = source
	local Passport = Passport
	local Route = GetPlayerRoutingBucket(source)

	Active[Passport] = true

	Force = (Force and Item or vRP.SortNameItem(Passport,Item))

	if not Drops[Route] then
		Drops[Route] = {}
	end

	repeat
	Selected = GenerateString("DDDDDDDDD")
	until Selected and not Reserved[Selected] and not Drops[Route][Selected]
	Reserved[Selected] = true

	local Provisory = {
		["key"] = Force,
		["route"] = Route,
		["id"] = Selected,
		["amount"] = Amount,
		["name"] = ItemName(Force),
		["weight"] = ItemWeight(Force),
		["index"] = ItemIndex(Force),
		["rarity"] = ItemRarity(Force),
		["economy"] = ItemEconomy(Force),
		["desc"] = ItemDescription(Force),
		["coords"] = vRP.GetEntityCoords(source)
	}
	
	local Split = splitString(Force,"-")

	if not Provisory["desc"] then
		if Split[1] == "vehiclekey" and Split[2] then
			Provisory["desc"] = "Placa do Veículo: <common>"..Split[2].."</common>"
		elseif Split[1] == "identity" or Split[1] == "fidentity" or string.sub(Force,1,5) == "badge" and Split[2] then
			Provisory["desc"] = "Propriedade: <common>"..vRP.FullName(Split[2]).."</common>"
		end
	end

	if Split[2] then
		local Loaded = ItemLoads(Force)
		if Loaded then
			Provisory["charges"] = parseInt(Split[2] * (100 / Loaded))
		end

		local Durability = ItemDurability(Force)
		if Durability then
			Provisory["durability"] = ComputeDurabilityOnlineOnly(Passport, Force)
			Provisory["days"] = Durability
		end
	end

	Active[Passport] = nil
	Drops[Route][Selected] = Provisory
	TriggerClientEvent("inventory:DropsAdicionar",-1,Route,Selected,Drops[Route][Selected])
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PICKUP
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Pickup(Number,Route,Target,Amount)
	local source = source
	local Amount = parseInt(Amount,true)
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and Drops[Route] and Drops[Route][Number] and Drops[Route][Number]["key"] then
		Active[Passport] = true

		if (vRP.InventoryWeight(Passport) + ItemWeight(Drops[Route][Number]["key"]) * Amount) <= vRP.CheckWeight(Passport) then
			local Inv = vRP.Inventory(Passport)
			if not Drops[Route] or not Drops[Route][Number] or not Drops[Route][Number]["key"] or not Drops[Route][Number]["amount"] or Drops[Route][Number]["amount"] < Amount or (Inv[Target] and Inv[Target]["item"] ~= Drops[Route][Number]["key"]) or vRP.MaxItens(Passport,Drops[Route][Number]["key"],Amount) then
				TriggerClientEvent("inventory:Update",source)
				Active[Passport] = nil

				return false
			end
				vRP.GiveItem(Passport,Drops[Route][Number]["key"],Amount,false,Target)
				Drops[Route][Number]["amount"] = Drops[Route][Number]["amount"] - Amount
				
				if Drops[Route] and Drops[Route][Number] and Drops[Route][Number]["amount"] then
					if parseInt(Drops[Route][Number]["amount"]) <= 0 then
						TriggerClientEvent("inventory:DropsRemover",-1,Route,Number)
						Drops[Route][Number] = nil
					else
						TriggerClientEvent("inventory:DropsAtualizar",-1,Route,Number,Drops[Route][Number]["amount"])
					end
				end
		else
			TriggerClientEvent("inventory:Notify",source,"Aviso","Mochila Sobrecarregada.","amarelo")
		end

		Active[Passport] = nil
	end

	TriggerClientEvent("inventory:Update",source)
end