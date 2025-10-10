-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local Config = {
	["Register"] = {
		["Timer"] = 15,
		["Wanted"] = 60,
		["Delay"] = 3600,
		["Cooldown"] = {},
		["Percentage"] = 750,
		["Name"] = "Roubo a Registradora",
		["Residual"] = "Resquício de Línter",
		["Payment"] = {
			["Multiplier"] = { ["Min"] = 1, ["Max"] = 1 },
			["List"] = {
				{ ["Item"] = "dirtydollar", ["Chance"] = 100, ["Min"] = 5275, ["Max"] = 15750 }
			}
		}
	},
	["Container"] = {
		["Timer"] = 30,
		["Wanted"] = 120,
		["Delay"] = 3600,
		["Cooldown"] = {},
		["Percentage"] = 750,
		["Name"] = "Roubo a Container",
		["Residual"] = "Resquício de Línter",
		["Payment"] = {
			["Multiplier"] = { ["Min"] = 2, ["Max"] = 3 },
			["List"] = {
				{ ["Item"] = "weedclone", ["Chance"] = 75, ["Min"] = 1, ["Max"] = 5 },
				{ ["Item"] = "cokeclone", ["Chance"] = 75, ["Min"] = 1, ["Max"] = 5 },
				{ ["Item"] = "adrenaline", ["Chance"] = 7, ["Min"] = 5, ["Max"] = 20 },
				{ ["Item"] = "pistolbody", ["Chance"] = 15, ["Min"] = 1, ["Max"] = 5 },
				{ ["Item"] = "smgbody", ["Chance"] = 10, ["Min"] = 1, ["Max"] = 5 },
				{ ["Item"] = "riflebody", ["Chance"] = 5, ["Min"] = 1, ["Max"] = 5 },
				{ ["Item"] = "dismantle", ["Chance"] = 35, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "ration", ["Chance"] = 80, ["Min"] = 1, ["Max"] = 2 },
				{ ["Item"] = "gunpowder", ["Chance"] = 100, ["Min"] = 3, ["Max"] = 15 },
				{ ["Item"] = "platinum", ["Chance"] = 35, ["Min"] = 50, ["Max"] = 75 },
				{ ["Item"] = "treasurebox", ["Chance"] = 3, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "boilies", ["Chance"] = 100, ["Min"] = 4, ["Max"] = 6 },
				{ ["Item"] = "binoculars", ["Chance"] = 75, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "camera", ["Chance"] = 75, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "repairkit01", ["Chance"] = 25, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "races", ["Chance"] = 100, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "postit", ["Chance"] = 100, ["Min"] = 2, ["Max"] = 5 },
				{ ["Item"] = "techtrash", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 3 },
				{ ["Item"] = "tarp", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 3 },
				{ ["Item"] = "sheetmetal", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 3 },
				{ ["Item"] = "roadsigns", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 3 },
				{ ["Item"] = "explosives", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 3 },
				{ ["Item"] = "sulfuric", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 3 },
				{ ["Item"] = "saline", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 3 },
				{ ["Item"] = "alcohol", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 3 },
				{ ["Item"] = "radio", ["Chance"] = 45, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "bandage", ["Chance"] = 80, ["Min"] = 1, ["Max"] = 2 },
				{ ["Item"] = "medkit", ["Chance"] = 25, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "pouch", ["Chance"] = 75, ["Min"] = 2, ["Max"] = 4 },
				{ ["Item"] = "woodlog", ["Chance"] = 75, ["Min"] = 2, ["Max"] = 4 },
				{ ["Item"] = "fishingrod", ["Chance"] = 35, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "pickaxe", ["Chance"] = 25, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "joint", ["Chance"] = 100, ["Min"] = 1, ["Max"] = 2 },
				{ ["Item"] = "cocaine", ["Chance"] = 100, ["Min"] = 1, ["Max"] = 2 },
				{ ["Item"] = "meth", ["Chance"] = 100, ["Min"] = 1, ["Max"] = 2 },
				{ ["Item"] = "crack", ["Chance"] = 60, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "heroin", ["Chance"] = 60, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "metadone", ["Chance"] = 60, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "codeine", ["Chance"] = 60, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "amphetamine", ["Chance"] = 60, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "acetone", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 3 },
				{ ["Item"] = "plate", ["Chance"] = 75, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "circuit", ["Chance"] = 15, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "lockpick", ["Chance"] = 45, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "toolbox", ["Chance"] = 35, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "tyres", ["Chance"] = 55, ["Min"] = 1, ["Max"] = 2 },
				{ ["Item"] = "cellphone", ["Chance"] = 65, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "handcuff", ["Chance"] = 15, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "rope", ["Chance"] = 45, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "hood", ["Chance"] = 15, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "plastic", ["Chance"] = 100, ["Min"] = 6, ["Max"] = 10 },
				{ ["Item"] = "glass", ["Chance"] = 100, ["Min"] = 6, ["Max"] = 10 },
				{ ["Item"] = "rubber", ["Chance"] = 100, ["Min"] = 6, ["Max"] = 10 },
				{ ["Item"] = "aluminum", ["Chance"] = 75, ["Min"] = 3, ["Max"] = 5 },
				{ ["Item"] = "copper", ["Chance"] = 75, ["Min"] = 3, ["Max"] = 5 },
				{ ["Item"] = "ritmoneury", ["Chance"] = 75, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "sinkalmy", ["Chance"] = 45, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "cigarette", ["Chance"] = 100, ["Min"] = 2, ["Max"] = 5 },
				{ ["Item"] = "lighter", ["Chance"] = 60, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "vape", ["Chance"] = 20, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "dirtydollar", ["Chance"] = 100, ["Min"] = 27500, ["Max"] = 375000 },
				{ ["Item"] = "pager", ["Chance"] = 10, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "analgesic", ["Chance"] = 100, ["Min"] = 2, ["Max"] = 3 },
				{ ["Item"] = "gauze", ["Chance"] = 100, ["Min"] = 2, ["Max"] = 4 },
				{ ["Item"] = "soap", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "alliance", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "WEAPON_PISTOL_AMMO", ["Chance"] = 10, ["Min"] = 25, ["Max"] = 50 },
				{ ["Item"] = "blueprint_WEAPON_SNSPISTOL", ["Chance"] = 2, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "scotchtape", ["Chance"] = 25, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "insulatingtape", ["Chance"] = 25, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "rammemory", ["Chance"] = 12, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "powersupply", ["Chance"] = 35, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "processorfan", ["Chance"] = 10, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "processor", ["Chance"] = 5, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "screws", ["Chance"] = 30, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "screwnuts", ["Chance"] = 30, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "videocard", ["Chance"] = 2, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "ssddrive", ["Chance"] = 15, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "safependrive", ["Chance"] = 5, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "powercable", ["Chance"] = 35, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "weaponparts", ["Chance"] = 10, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "electroniccomponents", ["Chance"] = 30, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "batteryaa", ["Chance"] = 50, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "batteryaaplus", ["Chance"] = 40, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "goldnecklace", ["Chance"] = 15, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "silverchain", ["Chance"] = 25, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "horsefigurine", ["Chance"] = 2, ["Min"] = 1, ["Max"] = 1 },
				{ ["Item"] = "toothpaste", ["Chance"] = 35, ["Min"] = 1, ["Max"] = 1 }
			}
		}
	}
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:ROBBERYMULTIPLIER (FIX + LOOT LOCAL)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:RobberyMultiplier")
AddEventHandler("inventory:RobberyMultiplier", function(Number, Mode)
    local src = source
    local Passport = vRP.Passport(src)
	if not (Passport and Config[Mode]) then return end

	-- prevent simultaneous robs on same point
	Config[Mode]["_InProgress"] = Config[Mode]["_InProgress"] or {}
	local inProgress = Config[Mode]["_InProgress"][Number]
	if inProgress then
		TriggerClientEvent("Notify", src, "Atenção", "Este local já está sendo roubado.", "amarelo", 5000)
		return
	end

	if Active[Passport] then return end

    -- polícia online (se configurado)
    if Config[Mode]["Police"] and vRP.AmountService("Policia") < Config[Mode]["Police"] then
        TriggerClientEvent("Notify", src, "Atenção", "Contingente indisponível.", "amarelo", 5000)
        return
    end

    -- Need (item necessário)
    local needCfg = Config[Mode]["Need"]
    local needItem, needAmount, needConsume = nil, 0, false
    if needCfg then
        needItem = needCfg["Item"]
        needAmount = needCfg["Amount"] or 1
        needConsume = needCfg["Consume"] and true or false

        local hasNeed = vRP.ConsultItem(Passport, needItem, needAmount)
        if not hasNeed then
            TriggerClientEvent("Notify", src, "Atenção",
                "Precisa de <b>"..needAmount.."x "..ItemName(needItem).."</b>.", "amarelo", 5000)
            return
        end
    end

    -- cooldown livre?
    local now = os.time()
    local nextReady = Config[Mode]["Cooldown"][Number]
    local isReady = (not nextReady) or (now > nextReady)

    if isReady then
		-- inicia roubo
        Player(src)["state"]["Buttons"] = true
		-- mark point as in progress
		Config[Mode]["_InProgress"][Number] = true
        Active[Passport] = now + Config[Mode]["Timer"]
        TriggerClientEvent("player:Residual", src, Config[Mode]["Residual"])
        vRPC.playAnim(src, false, { "oddjobs@shop_robbery@rob_till", "loop" }, true)
        TriggerClientEvent("Progress", src, "Roubando", Config[Mode]["Timer"] * 1000)

        exports["vrp"]:CallPolice({
            ["Source"] = src,
            ["Passport"] = Passport,
            ["Permission"] = "Policia",
            ["Name"] = Config[Mode]["Name"],
            ["Percentage"] = Config[Mode]["Percentage"],
            ["Wanted"] = Config[Mode]["Wanted"],
            ["Code"] = 31,
            ["Color"] = 22
        })

        -- espera terminar o timer
        repeat
            if Active[Passport] and os.time() >= Active[Passport] then
                vRPC.Destroy(src)
                Active[Passport] = nil
                Player(src)["state"]["Buttons"] = false

                -- valida Need novamente e consome (se configurado)
                local canOpen = true
                if needCfg then
                    if not vRP.ConsultItem(Passport, needItem, needAmount) then
                        canOpen = false
                        TriggerClientEvent("Notify", src, "Atenção",
                            "Você já não possui <b>"..needAmount.."x "..ItemName(needItem).."</b>.", "amarelo", 5000)
                    elseif needConsume then
                        if not vRP.TakeItem(Passport, needItem, needAmount) then
                            canOpen = false
                            TriggerClientEvent("Notify", src, "Atenção",
                                "Falha ao consumir <b>"..needAmount.."x "..ItemName(needItem).."</b>.", "amarelo", 5000)
                        end
                    end
                end

                if canOpen then
                    -- aplica cooldown do ponto
                    Config[Mode]["Cooldown"][Number] = os.time() + Config[Mode]["Delay"]

					-- clear inProgress for this point (robbery finished)
					Config[Mode]["_InProgress"][Number] = nil

                    -- === GERAR LOOT E GRAVAR NO BAÚ (persistente) ===
                    local chestName = Mode..":"..Number
                    local loot = {}
                    local slot = 1

                    local function addLoot(item, amount)
                        amount = parseInt(amount or 0)
                        if not item or amount <= 0 then return end
                        if not ItemExist(item) then return end  -- evita itens inválidos serem limpos no Mount()
                        loot[tostring(slot)] = { item = item, amount = amount }
                        slot = slot + 1
                    end

                    local multMin = (Config[Mode]["Payment"]["Multiplier"]["Min"] or 1)
                    local multMax = (Config[Mode]["Payment"]["Multiplier"]["Max"] or multMin)
                    local multiplier = math.random(multMin, multMax)

                    local drops = Config[Mode]["Payment"]["List"] or {}
                    for _, d in ipairs(drops) do
                        local item = d.Item or d["Item"]
                        local chance = d.Chance or d["Chance"] or 100
                        local minQ = d.Min or d["Min"] or 1
                        local maxQ = d.Max or d["Max"] or minQ
                        if item and math.random(100) <= chance then
                            addLoot(item, math.random(minQ, maxQ) * multiplier)
                        end
                    end

                    -- grava o conteúdo do baú (Save=true para bater com Creative.Permissions)
                    vRP.SetSrvData(chestName, loot, true)

                    -- abre o baú no cliente
                    TriggerClientEvent("chest:Open", src, chestName, "Custom", false, true)
                end
            end
            Wait(100)
        until not Active[Passport]

		-- ensure inProgress cleared if loop ends for any reason
		Config[Mode]["_InProgress"][Number] = nil

    else
        -- janela para reabrir (ex.: últimos 5min do cooldown)
        if (Config[Mode]["Cooldown"][Number] - (Config[Mode]["Delay"] - 300)) >= now then
            TriggerClientEvent("chest:Open", src, Mode..":"..Number, "Custom", false, true)
        else
            TriggerClientEvent("Notify", src, "Atenção",
                "Aguarde "..CompleteTimers(Config[Mode]["Cooldown"][Number] - now)..".", "amarelo", 5000)
        end
    end
end)
