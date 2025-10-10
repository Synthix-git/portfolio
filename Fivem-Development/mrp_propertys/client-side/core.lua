-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
vSERVER = Tunnel.getInterface("propertys")

-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Blips               = {}
local PropertyBlipsActive = false
local Busy                = false
local Interior            = ""
local Inside              = false
local Opened              = false
local Policed             = false
local Stealing            = false

-- Contexto de "chest" Custom (roubo)
local ChestNameOverride   = nil   -- string (SrvData key), quando ativo substitui Name
local ChestModeOverride   = nil   -- "Custom", quando ativo substitui Mode

-- Config tempo do arrombamento (igual estilo registadoras)
local BREAKIN_SECONDS     = 10

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSYSTEM
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local TimeDistance = 999
		local Ped = PlayerPedId()
		if not IsPedInAnyVehicle(Ped) then
			local Coords = GetEntityCoords(Ped)

			if not Inside then
                for Name,v in pairs(Propertys) do
                    if #(Coords - v["Coords"]) <= 0.75 then
                        TimeDistance = 5

						if IsControlJustPressed(1,38) then
							local Consult = vSERVER.Propertys(Name)

							if Consult then
								if Consult == "Nothing" then
									for Line,info in pairs(Informations) do
										if (Propertys[Name]["Armazém"] and Line == "Armazém") or (not Propertys[Name]["Armazém"] and Line ~= "Armazém") then
											exports["dynamic"]:AddMenu(Line,"Informações sobre o interior.",Line)

											if info["Vault"] then
												exports["dynamic"]:AddButton("Baú","Total de <yellow>"..info["Vault"].."Kg</yellow> no compartimento.","","",Line,false)
											end
											if info["Fridge"] then
												exports["dynamic"]:AddButton("Geladeira","Total de <yellow>"..info["Fridge"].."Kg</yellow> no compartimento.","","",Line,false)
											end

											exports["dynamic"]:AddButton("Credenciais","Máximo <yellow>1</yellow> proprietário e <yellow>3</yellow> adicionais.","","",Line,false)
											exports["dynamic"]:AddButton("Comprar com Dinheiro","Custo de <yellow>"..Currency..Dotted(info["Price"]).."</yellow>.","propertys:Buy",Name.."-"..Line.."-Dollar",Line,true)
											exports["dynamic"]:AddButton("Comprar com Diamantes","Custo de <yellow>"..Dotted(info["Gemstone"]).."</yellow>.","propertys:Buy",Name.."-"..Line.."-Gemstone",Line,true)
										end
									end
									exports["dynamic"]:Open()
								else
									if Consult ~= "Hotel" then
										exports["dynamic"]:AddButton("Entrar","Adentrar a propriedade.","propertys:Enter",Name,false,false)
										exports["dynamic"]:AddButton("Credenciais","Reconfigurar os cartões de acesso.","propertys:Credentials",Name,false,true)
										exports["dynamic"]:AddButton("Cartões","Comprar um novo cartão de acesso.","propertys:Item",Name,false,true)
										exports["dynamic"]:AddButton("Fechadura","Trancar/Destrancar a propriedade.","propertys:Lock",Name,false,true)

										if not Propertys[Name]["Armazém"] then
											exports["dynamic"]:AddButton("Garagem","Adicionar/Reajustar a garagem.","garages:Propertys",Name,false,true)
										end

										exports["dynamic"]:AddButton("Vender","Se desfazer da propriedade.","propertys:Sell",Name,false,true)
										exports["dynamic"]:AddButton("Transferência","Mudar proprietário.","propertys:Transfer",Name,false,true)
										exports["dynamic"]:AddButton("Hipoteca",Consult["Tax"],"","",false,false)

										Interior = Consult["Interior"]
										exports["dynamic"]:Open()
									else
										Interior = "Hotel"
										TriggerEvent("propertys:Enter",Name,false)
									end
								end

							elseif not Propertys[Name]["Armazém"] and Name ~= "Hotel" then
								-- INVADIR → client try + anim/progress → server
								exports["dynamic"]:AddButton("Invadir","Forçar a fechadura.","propertys:TryBreakIn",Name,false,true)
								exports["dynamic"]:Open()
                        end
                        -- Encontrou uma propriedade próxima; evitar iterar todas as restantes neste tick.
                        break
						end
					end
				end

			elseif Propertys[Inside] and Internal[Interior] then
				SetPlayerBlipPositionThisFrame(Propertys[Inside]["Coords"]["x"],Propertys[Inside]["Coords"]["y"])

				if Coords["z"] < (Internal[Interior]["Exit"]["z"] - 25.0) then
					SetEntityCoords(Ped,Internal[Interior]["Exit"],false,false,false,false)
				end

				-- barulho: reporta a polícia
				if Internal[Interior]["Furniture"] and Policed and Policed <= GetGameTimer() and (GetPedMovementClipset(Ped) ~= -1155413492 or IsPedSprinting(Ped) or MumbleIsPlayerTalking(PlayerId())) then
					vSERVER.Police(Propertys[Inside]["Coords"],Coords)
					Policed = GetGameTimer() + 15000
				end

				for Line,vec in pairs(Internal[Interior]) do
					if Line ~= "Furniture" and #(Coords - vec) <= 1.0 then
						if Line == "Exit" and IsControlJustPressed(1,38) then
							if Stealing and Internal[Interior]["Furniture"] then
								for Index in pairs(Internal[Interior]["Furniture"]) do
									exports["target"]:RemCircleZone("Robberys:"..Index)
								end
							end

							SetEntityCoords(Ped,Propertys[Inside]["Coords"],false,false,false,false)
							vSERVER.Toggle(Inside,"Exit")
							Stealing = false
							Policed  = false
							Inside   = false

						elseif not Stealing and (Line == "Vault" or Line == "Fridge") and IsControlJustPressed(1,38) and vSERVER.Permission(Inside) then
							vRP.playAnim(false,{"amb@prop_human_bum_bin@base","base"},true)
							Opened = Line
							-- chest padrão do resource propertys
							TriggerEvent("inventory:Open",{ Type = "Chest", Resource = "propertys" })

						elseif not Stealing and Line == "Clothes" and IsControlJustPressed(1,38) then
							ClothesMenu()
						end
					end
				end

				TimeDistance = 1
			end
		end

		Wait(TimeDistance)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- TRY BREAK-IN (client) → animação + progress + validação crowbar → server
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("propertys:TryBreakIn")
AddEventHandler("propertys:TryBreakIn", function(Name)
	if not Name or not Propertys[Name] then return end

	local ped  = PlayerPedId()
	local hash = GetHashKey("WEAPON_CROWBAR")

	-- precisa de pé-de-cabra NA MÃO
	if GetSelectedPedWeapon(ped) ~= hash then
		TriggerEvent("Notify","Propriedades","Precisas de um <b>Pé de Cabra</b>.","amarelo",5000)
		return
	end

	-- helper: minigame "Try" (se existir), senão fallback de progress + prob.
	local function DoTry(seconds)
		if exports["try"] and exports["try"].Skill then
			return exports["try"]:Skill({ difficulty = "medium", attempts = 3, time = seconds * 1000 }) and true or false
		end
		TriggerEvent("Progress","Arrombando", seconds * 1000)
		Wait(seconds * 1000)
		return (math.random(100) <= 65)
	end

	-- bloquear input + anim
	LocalPlayer.state["Buttons"] = true
	vRP.playAnim(false, { "melee@large_wpn@streamed_core", "ground_attack_on_spot" }, true)

	local ok = DoTry(BREAKIN_SECONDS)

	vRP.Destroy()
	LocalPlayer.state["Buttons"] = false

	if not ok then
		TriggerEvent("Notify","Propriedades","Falhaste o arrombamento.","amarelo",5000)
		return
	end

	-- sucesso → pede ao server para validar e entrar
	TriggerServerEvent("propertys:TryBreakIn", Name, BREAKIN_SECONDS * 1000)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLOTHESMENU
-----------------------------------------------------------------------------------------------------------------------------------------
function ClothesMenu()
	exports["dynamic"]:AddButton("Shopping","Abrir a loja de vestimentas.","skinshop:Open","",false,false)
	exports["dynamic"]:AddMenu("Armário","Abrir lista com todas as vestimentas.","wardrobe")
	exports["dynamic"]:AddButton("Guardar","Salvar vestimentas do corpo.","propertys:Clothes","Save","wardrobe",true)

	local Clothes = vSERVER.Clothes()
	if parseInt(#Clothes) > 0 then
		for Index,v in pairs(Clothes) do
			exports["dynamic"]:AddMenu(v,"Informações da vestimenta.",Index,"wardrobe")
			exports["dynamic"]:AddButton("Aplicar","Vestir-se com as vestimentas.","propertys:Clothes","Apply-"..v,Index,true)
			exports["dynamic"]:AddButton("Remover","Deletar a vestimenta do armário.","propertys:Clothes","Delete-"..v,Index,true,true)
		end
	end

	exports["dynamic"]:Open()
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- ENTER (server → client)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("propertys:Enter")
AddEventHandler("propertys:Enter",function(Name,Theft)
	if Theft then
		Stealing = true
		Interior = Theft
		Policed  = GetGameTimer() + 15000
		TriggerEvent("player:Residual","Resquício de Línter")

		if Internal[Interior] and Internal[Interior]["Furniture"] then
			for Number,v in pairs(Internal[Interior]["Furniture"]) do
-- dentro do handler: RegisterNetEvent("propertys:Enter") ... if Theft then ... for Number,v in pairs(Internal[Interior]["Furniture"]) do

				exports["target"]:AddCircleZone("Robberys:"..Number, v, 0.25, {  -- ↑ raio 0.25 p/ facilitar o click
					name = "Robberys:"..Number, heading = 0.0, useZ = true
				},{
					shop = Number,                      -- legacy: alguns targets enviam isto como 1º parâmetro
					service = Name,                     -- legacy: e isto como 2º parâmetro
					params = { shop = Number, service = Name }, -- ✅ novo: envia também num table params
					Distance = 1.25,
					options = {
						{
							event   = "propertys:RobberyItem",
							label   = "Roubar",
							tunnel  = "server",   -- obrigatório
							service = Name,       -- legacy
							shop    = Number,     -- legacy
							params  = { shop = Number, service = Name } -- ✅ novo
						}
					}
				})

			end
		end
	end

	Inside = Name
	local Ped = PlayerPedId()
	TriggerEvent("dynamic:Close")
	vSERVER.Toggle(Inside,"Enter")
	SetEntityCoords(Ped,Internal[Interior]["Exit"],false,false,false,false)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ABRIR COFRE CUSTOM (server → client)  **Plano A**
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("propertys:OpenCustomChest")
AddEventHandler("propertys:OpenCustomChest", function(chestKey, title)
	if type(chestKey) ~= "string" or chestKey == "" then return end
	ChestNameOverride = chestKey
	ChestModeOverride = "Custom"
	TriggerEvent("inventory:Open",{
		Type     = "Chest",
		Resource = "propertys",
		Title    = title or "Espólio"
	})
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ADAPTER: chest:Open -> abre via inventory:Open (resource=propertys) com overrides
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("chest:Open")
AddEventHandler("chest:Open", function(chestKey, mode, _, _)
	if type(chestKey) ~= "string" or chestKey == "" then return end
	if not mode or mode == "Custom" then
		ChestNameOverride = chestKey
		ChestModeOverride = "Custom"
		TriggerEvent("inventory:Open",{
			Type     = "Chest",
			Resource = "propertys",
			Title    = "Espólio"
		})
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Mount",function(Data,Callback)
	local useName = ChestNameOverride or Inside
	local useMode = ChestModeOverride or Opened
	local Primary,Secondary,PrimaryWeight,SecondaryWeight = vSERVER.Mount(useName,useMode)
	if Primary then
		Callback({ Primary = Primary, Secondary = Secondary, PrimaryMaxWeight = PrimaryWeight, SecondaryMaxWeight = SecondaryWeight })
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Close")
AddEventHandler("inventory:Close",function()
	if Opened then
		Opened = false
		vRP.Destroy()
	end
	ChestNameOverride = nil
	ChestModeOverride = nil
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:REMCIRCLEZONE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("propertys:RemCircleZone")
AddEventHandler("propertys:RemCircleZone",function(Index)
	exports["target"]:RemCircleZone("Robberys:"..Index)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- TAKE / STORE / UPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Take",function(Data,Callback)
	if MumbleIsConnected() then
		local useName = ChestNameOverride or Inside
		local useMode = ChestModeOverride or Opened
		vSERVER.Take(Data["slot"],Data["amount"],Data["target"],useName,useMode)
	end
	Callback("Ok")
end)

RegisterNUICallback("Store",function(Data,Callback)
	if MumbleIsConnected() then
		local useName = ChestNameOverride or Inside
		local useMode = ChestModeOverride or Opened
		vSERVER.Store(Data["item"],Data["slot"],Data["amount"],Data["target"],useName,useMode)
	end
	Callback("Ok")
end)

RegisterNUICallback("Update",function(Data,Callback)
	if MumbleIsConnected() then
		local useName = ChestNameOverride or Inside
		local useMode = ChestModeOverride or Opened
		vSERVER.Update(Data["slot"],Data["amount"],Data["target"],useName,useMode)
	end
	Callback("Ok")
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART (hoverfy)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	local Tables = {}
	for Name,v in pairs(Propertys) do
		Tables[#Tables + 1] = { v["Coords"],0.75,"E","Pressione","para acessar" }
	end
	TriggerEvent("hoverfy:Insert",Tables)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:BLIPS
-----------------------------------------------------------------------------------------------------------------------------------------
local function ClearPropertyBlips()
	local count = 0
	for name, blip in pairs(Blips) do
		if blip and DoesBlipExist(blip) then
			RemoveBlip(blip)
		end
		Blips[name] = nil
		count = count + 1
		if count % 50 == 0 then Wait(0) end
	end
end

RegisterNetEvent("propertys:Blips")
AddEventHandler("propertys:Blips", function()
	if Busy then
		TriggerEvent("Notify","Propriedades","Aguarde, a atualizar marcações...","default",3000)
		return
	end

	Busy = true

	CreateThread(function()
		-- Toggle OFF
		if PropertyBlipsActive and next(Blips) then
			ClearPropertyBlips()
			PropertyBlipsActive = false
			Busy = false
			TriggerEvent("Notify","Propriedades","Marcações desativadas.","vermelho",5000)
			return
		end

		-- Toggle ON
		if type(Propertys) ~= "table" then
			Busy = false
			TriggerEvent("Notify","Propriedades","Não foi possível carregar as propriedades.","verde",5000)
			return
		end

		-- limpar
		ClearPropertyBlips()

		local markers = (GlobalState and GlobalState["Markers"]) or {}
		local created = 0

		for name, v in pairs(Propertys) do
			if name ~= "Hotel" and v and v["Coords"] then
				local cx, cy, cz = v["Coords"].x or 0.0, v["Coords"].y or 0.0, v["Coords"].z or 0.0
				local blip = AddBlipForCoord(cx + 0.0, cy + 0.0, cz + 0.0)

				SetBlipSprite(blip, v["Armazém"] and 473 or 374)
				SetBlipScale(blip, 0.5)
				SetBlipAsShortRange(blip, true)
				SetBlipColour(blip, markers[name] and 35 or 43)

				BeginTextCommandSetBlipName("STRING")
				AddTextComponentString(("Propriedade: %s"):format(name))
				EndTextCommandSetBlipName(blip)

				Blips[name] = blip
				created = created + 1
				if created % 50 == 0 then Wait(0) end
			end
		end

		PropertyBlipsActive = next(Blips) ~= nil
		Busy = false

		if PropertyBlipsActive then
			TriggerEvent("Notify","Propriedades","Marcações ativadas.","verde",5000)
		else
			TriggerEvent("Notify","Propriedades","Nenhuma propriedade encontrada para marcar.","vermelho",5000)
		end
	end)
end)



-- loot padrão de gavetas/móveis em propriedades
PropertyRobbery_DropList = {
    -- Comum (sempre útil)
    { Item = "techtrash",           Chance = 70, Min = 1,  Max = 3 },
    { Item = "electroniccomponents",Chance = 65, Min = 1,  Max = 3 },
    { Item = "powercable",          Chance = 60, Min = 1,  Max = 2 },
    { Item = "screws",              Chance = 50, Min = 1,  Max = 3 },
    { Item = "screwnuts",           Chance = 45, Min = 1,  Max = 3 },
    { Item = "scotchtape",          Chance = 40, Min = 1,  Max = 2 },
    { Item = "insulatingtape",      Chance = 40, Min = 1,  Max = 2 },
    { Item = "tarp",                Chance = 35, Min = 1,  Max = 2 },
    { Item = "sheetmetal",          Chance = 35, Min = 1,  Max = 2 },
    { Item = "roadsigns",           Chance = 35, Min = 1,  Max = 2 },
    { Item = "explosives",          Chance = 20, Min = 1,  Max = 2 },
    { Item = "batteryaa",           Chance = 35, Min = 1,  Max = 2 },
    { Item = "batteryaaplus",       Chance = 30, Min = 1,  Max = 2 },

    -- Eletrônicos valiosos
    { Item = "ssddrive",            Chance = 25, Min = 1,  Max = 2 },
    { Item = "safependrive",        Chance = 20, Min = 1,  Max = 1 },
    { Item = "rammemory",           Chance = 25, Min = 1,  Max = 2 },
    { Item = "processor",           Chance = 20, Min = 1,  Max = 1 },
    { Item = "processorfan",        Chance = 20, Min = 1,  Max = 1 },
    { Item = "powersupply",         Chance = 20, Min = 1,  Max = 1 },
    { Item = "videocard",           Chance = 8,  Min = 1,  Max = 1 },
    { Item = "television",          Chance = 4,  Min = 1,  Max = 1 },

    -- Jóias / luxo
    { Item = "goldnecklace",        Chance = 20, Min = 1,  Max = 2 },
    { Item = "silverchain",         Chance = 22, Min = 1,  Max = 2 },
    { Item = "horsefigurine",       Chance = 6,  Min = 1,  Max = 1 },
    { Item = "goldenjug",           Chance = 3,  Min = 1,  Max = 1 },
    { Item = "goldenleopard",       Chance = 2,  Min = 1,  Max = 1 },
    { Item = "goldenlion",          Chance = 1,  Min = 1,  Max = 1 },

    -- “Crime kit” / acessórios
    { Item = "handcuff",            Chance = 8,  Min = 1,  Max = 1 },
    { Item = "rope",                Chance = 10, Min = 1,  Max = 1 },
    { Item = "hood",                Chance = 8,  Min = 1,  Max = 1 },
    { Item = "pager",               Chance = 6,  Min = 1,  Max = 1 },

    -- Dinheiro sujo / papéis
    { Item = "dirtydollar",         Chance = 100, Min = 4575,  Max = 17580 },   -- base
    { Item = "promissory1000",      Chance = 4,   Min = 1,    Max = 1 },
    { Item = "promissory2000",      Chance = 3,   Min = 1,    Max = 1 },
    { Item = "promissory3000",      Chance = 2,   Min = 1,    Max = 1 },
    { Item = "promissory4000",      Chance = 1,   Min = 1,    Max = 1 },
    { Item = "promissory5000",      Chance = 1,   Min = 1,    Max = 1 }
}

