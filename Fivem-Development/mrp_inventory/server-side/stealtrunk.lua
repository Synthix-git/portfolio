-----------------------------------------------------------------------------------------------------------------------------------------
-- STEALTRUNK
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:StealTrunk")
AddEventHandler("inventory:StealTrunk",function(Entity)
	local source = source
	local Plate = Entity[1]
	local Model = Entity[2]
	local Network = Entity[4]
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] then
		if not vCLIENT.CheckWeapon(source,"WEAPON_CROWBAR") then
			TriggerClientEvent("Notify",source,"Aviso","<b>Pé de Cabra</b> não encontrado.","amarelo",5000)

			return false
		end

		if not vRP.PassportPlate(Plate) then
			if not Trunks[Plate] or os.time() >= Trunks[Plate] then
				vRPC.playAnim(source,false,{"anim@amb@clubhouse@tutorial@bkr_tut_ig3@","machinic_loop_mechandplayer"},true)
				Active[Passport] = os.time() + 100

				if vRP.Task(source,5,5000) then
					Active[Passport] = os.time() + 20
					Player(source)["state"]["Buttons"] = true
					TriggerClientEvent("Progress",source,"Vasculhando",20000)
					TriggerClientEvent("player:Residual",source,"Resíduo de Ferro")

					local Players = vRPC.Players(source)
					for _,v in pairs(Players) do
						async(function()
							TriggerClientEvent("player:VehicleDoors",v,Network,"open")
						end)
					end

					repeat
						if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
							vRPC.Destroy(source)
							Active[Passport] = nil
							Player(source)["state"]["Buttons"] = false

							for _,v in pairs(Players) do
								async(function()
									TriggerClientEvent("player:VehicleDoors",v,Network,"close")
								end)
							end

							if not Trunks[Plate] or os.time() >= Trunks[Plate] then
								Trunks[Plate] = os.time() + 3600

								local Result = RandPercentage(IlegalItens)
								if not vRP.MaxItens(Passport,Result["Item"],Result["Valuation"]) and vRP.InventoryWeight(Passport,Result["Item"],Result["Valuation"]) then
									vRP.GenerateItem(Passport,Result["Item"],Result["Valuation"],true)
								else
									TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","roxo",5000)
									SafeDrop(Passport,source,Result["Item"],Result["Valuation"])
								end
							end
						end

						Wait(100)
					until not Active[Passport]
				else
					TriggerEvent("Wanted",source,Passport,30)
					vRPC.stopAnim(source,false)
					Active[Passport] = nil

					local Coords = vRP.GetEntityCoords(source)
					local Service = vRP.NumPermission("Policia")
					for Passports,Sources in pairs(Service) do
						async(function()
							vRPC.PlaySound(Sources,"ATM_WINDOW","HUD_FRONTEND_DEFAULT_SOUNDSET")
							TriggerClientEvent("NotifyPush",Sources,{ code = 31, title = "Roubo de Veículo", x = Coords["x"], y = Coords["y"], z = Coords["z"], vehicle = VehicleName(Model).." - "..Plate, color = 44 })
						end)
					end
				end
			end
		else
			TriggerClientEvent("Notify",source,"Aviso","Veículo protegido pela seguradora.","amarelo",1000)
		end
	end
end)