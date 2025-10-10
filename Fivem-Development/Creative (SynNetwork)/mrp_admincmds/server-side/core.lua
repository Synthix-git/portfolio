-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRPC = Tunnel.getInterface("vRP")
vRP = Proxy.getInterface("vRP")


local Global = module("vrp", "config/Global")
local Groups = Global.Groups
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("admin",Creative)
vCLIENT = Tunnel.getInterface("admin")
vKEYBOARD = Tunnel.getInterface("keyboard")


-- Helpers seguros
local function splitString(s, sep)
    sep = sep or ","
    local t = {}
    for part in string.gmatch(tostring(s), "([^"..sep.."]+)") do
        t[#t+1] = (part:gsub("^%s+",""):gsub("%s+$","")) -- trim
    end
    return t
end

local function getPedSafe(src)
    if not src or src == 0 then return nil end
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        return ped
    end
    return nil
end

local function getCoordsSafe(srcOrPed)
    local ped = type(srcOrPed)=="number" and getPedSafe(srcOrPed) or srcOrPed
    if not ped then return nil end
    local ok, coords = pcall(GetEntityCoords, ped)
    if ok and coords then return coords end
    return nil
end

local function toNumbers3(a,b,c)
    local x = tonumber(a) or 0.0
    local y = tonumber(b) or 0.0
    local z = tonumber(c) or 0.0
    return x,y,z
end

-- Teleport server-side seguro (usa tua API vRP.Teleport mas protege inputs)
local function TeleportSafe(src, x,y,z)
    if not src or src == 0 then return false end
    x,y,z = toNumbers3(x,y,z)
    if x == 0 and y == 0 and z == 0 then return false end
    local ok = pcall(function()
        vRP.Teleport(src, x + 0.0, y + 0.0, z + 0.0)
    end)
    return ok
end


-----------------------------------------------------------------------------------------------------------------------------------------
-- BUCKET
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("bucket",function(source,Message)
    local Passport = vRP.Passport(source)
    if Passport then
        if vRP.HasGroup(Passport,"Admin",2) and Message[1] then
            local Route = parseInt(Message[1])
            if Message[2] then
                local OtherPassport = parseInt(Message[2])
                local OtherSource = vRP.Source(OtherPassport)
                if OtherSource then
                    if Route > 0 then
                        exports["vrp"]:Bucket(OtherSource,"Enter",Route)
                    else
                        exports["vrp"]:Bucket(OtherSource,"Exit")
                    end
                end
            else
                if Route > 0 then
                    exports["vrp"]:Bucket(source,"Enter",Route)
                else
                    exports["vrp"]:Bucket(source,"Exit")
                end
            end
        end
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYERS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("players",function(source,Message)
	local Passport = vRP.Passport(source)
	if Passport and vRP.HasGroup(Passport,"Admin") then
		local Number = 0
		local Message = ""
		local Players = vRP.Players()
		local Amounts = CountTable(Players)
		for OtherPassport in pairs(Players) do
			Number = Number + 1
			Message = Message..OtherPassport..(Number < Amounts and ", " or "")
		end

		TriggerClientEvent("chat:ClientMessage",source,"JOGADORES CONECTADOS",Message,"OOC")
		TriggerClientEvent("Notify",source,"Listagem","<b>Jogadores Conectados:</b> "..GetNumPlayerIndices(),"verde",5000)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SKINSHOP
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("skinshop", function(source, Message)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") then
        TriggerClientEvent("skinshop:Open", source)
        TriggerClientEvent("Notify", source, "Admin", "Abriste o <b>Skinshop</b>.", "azul", 5000)

        -- 📑 Log Discord
        exports["discord"]:Embed("Admin",
            "🎨 **Comando /skinshop**\n\n👤 Passaporte: **"..Passport.."**\n📂 Ação: **Abriu o skinshop**",
            source
        )
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- BARBERSHOP
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("barbershop", function(source, Message)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") then
        TriggerClientEvent("barbershop:Open", source)
        TriggerClientEvent("Notify", source, "Admin", "Abriste o <b>Barbershop</b>.", "azul", 5000)

        -- 📑 Log Discord
        exports["discord"]:Embed("Admin",
            "🎨 **Comando /barbershop**\n\n👤 Passaporte: **"..Passport.."**\n📂 Ação: **Abriu o barbershop**",
            source
        )
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- TATTOSHOP
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("tattooshop", function(source, Message)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") then
        TriggerClientEvent("tattooshop:Open", source)
        TriggerClientEvent("Notify", source, "Admin", "Abriste o <b>Tattooshop</b>.", "azul", 5000)

        -- 📑 Log Discord
        exports["discord"]:Embed("Admin",
            "🎨 **Comando /tattooshop**\n\n👤 Passaporte: **"..Passport.."**\n📂 Ação: **Abriu o tattooshop**",
            source
        )
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SKINWEAPON
-----------------------------------------------------------------------------------------------------------------------------------------
-- RegisterCommand("skinweapon",function(source,Message)
-- 	local Passport = vRP.Passport(source)
-- 	if Passport and vRP.HasGroup(Passport,"Admin") then
-- 		TriggerClientEvent("skinweapon:Open",source)
-- 	end
-- end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- LSCUSTOMS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("ls", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end
    if vRP.HasGroup(Passport,"Admin",3) or vRP.HasPermission(Passport,"Admin",3) then
        TriggerClientEvent("lscustoms:OpenAdmin", source)
    else
        TriggerClientEvent("Notify", source, "LS Customs", "Sem permissão para usar <b>/ls</b>.", "amarelo", 5000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- UGROUPS
-----------------------------------------------------------------------------------------------------------------------------------------
-- RegisterCommand("ugroups",function(source,Message)
-- 	local Passport = vRP.Passport(source)
-- 	if Passport and parseInt(Message[1]) > 0 then
-- 		local Messages = ""
-- 		local Groups = vRP.Groups()
-- 		local OtherPassport = Message[1]
-- 		for Permission,_ in pairs(Groups) do
-- 			local Data = vRP.DataGroups(Permission)
-- 			if Data[OtherPassport] then
-- 				Messages = Messages..Permission.."<br>"
-- 			end
-- 		end

-- 		if Messages ~= "" then
-- 			TriggerClientEvent("Notify",source,"Grupos Pertencentes",Messages,"verde",10000)
-- 		end
-- 	end
-- end)

RegisterCommand("ugroups", function(source, Message)
	local Passport = vRP.Passport(source)
	if not Passport then return end

	local OtherPassport = parseInt(Message[1])
	if OtherPassport <= 0 then return end

	local Messages = ""

	for groupName, data in pairs(Groups) do
		local datatable = vRP.DataGroups(groupName)
		local level = datatable[tostring(OtherPassport)]

		if level then
			local levelText = "Grau " .. level
			local name = ""

			if data.Hierarchy and data.Hierarchy[level] then
				name = " - " .. data.Hierarchy[level]
			end

			Messages = Messages .. groupName .. " - " .. levelText .. name .. "<br>"
		end
	end

	if Messages ~= "" then
		TriggerClientEvent("Notify", source, "Grupos Pertencentes", Messages, "verde", 10000)
	else
		TriggerClientEvent("Notify", source, "Grupos Pertencentes", "Nenhum grupo encontrado.", "amarelo", 5000)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- USOURCE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("usource",function(source,Message)
	local Passport = vRP.Passport(source)
	local OtherSource = parseInt(Message[1])
	if Passport and OtherSource and OtherSource > 0 and vRP.Passport(OtherSource) and vRP.HasGroup(Passport,"Admin") then
		TriggerClientEvent("Notify",source,"Informações","<b>Passaporte:</b> "..vRP.Passport(OtherSource),"default",5000)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CAM
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("cam",function(source,Message)
	local Passport = vRP.Passport(source)
	if Passport and vRP.HasGroup(Passport,"Admin") then
		TriggerClientEvent("freecam:Active",source,Message)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEARINV
-----------------------------------------------------------------------------------------------------------------------------------------

RegisterCommand("clearinv", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    local targetPassport = parseInt(args[1] or 0)
    if targetPassport <= 0 then return end
    if not vRP.HasGroup(Passport, "Admin") then return end

    -- Capturar itens antes de limpar
    local inv = vRP.Inventory(targetPassport)
    local linhas = {}

    local function itemEmoji(item)
        if ItemType(item, "Armamento") then return "🔫"
        elseif ItemType(item, "Munição") then return "💣"
        elseif ItemType(item, "Consumível") then return "🥤"
        else return "📦"
        end
    end

    if inv and next(inv) then
        for slot, v in pairs(inv) do
            if v and v.item and v.amount and v.amount > 0 then
                local label = ItemName(v.item) or v.item
                table.insert(linhas, string.format("%s **%s** x`%d`", itemEmoji(v.item), label, parseInt(v.amount)))
            end
        end
    end

    local itensTexto = (#linhas > 0) and table.concat(linhas, "\n") or "⚠️ Nenhum item encontrado"

    -- Evitar estourar limite do Discord (descrição do embed ~4096 chars)
    if #itensTexto > 3800 then
        itensTexto = itensTexto:sub(1, 3800) .. "\n…"
    end

    -- Limpar inventário
    vRP.ClearInventory(targetPassport)

    -- Notificar in-game
    TriggerClientEvent("Notify", source, "Sucesso", "Limpeza concluída.", "verde", 5000)

    -- Enviar embed (usa o hook 'ClearInv' do teu logs)
    local msg = string.format(
        "🧹 **Limpeza de Inventário**\n\n👮 **Staff:** %s [%d]\n🎯 **Alvo:** Passaporte `%d`\n\n**Itens Removidos:**\n%s",
        vRP.FullName(Passport), Passport, targetPassport, itensTexto
    )
    exports["discord"]:Embed("ClearInv", msg, source)
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- DIMA
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("dima",function(source,Message)
	local Passport = vRP.Passport(source)
	if Passport then
		if vRP.HasGroup(Passport,"Admin", 2) and parseInt(Message[1]) > 0 and parseInt(Message[2]) > 0 then
			local Amount = parseInt(Message[2])
			local OtherPassport = parseInt(Message[1])
			local Identity = vRP.Identity(OtherPassport)
			if Identity then
				TriggerClientEvent("Notify",source,"Sucesso","Diamantes entregues.","verde",5000)
				vRP.UpgradeGemstone(Message[1],Message[2],true)
				local logMsg = table.concat({
                "💎 **TRANSFERÊNCIA DE GEMAS**",
                "",
                "🆔 **Source:** `" .. source .. "`",
                "👮 **Passaporte (Origem):** `" .. Passport .. "`",
                "👤 **Passaporte (Destino):** `" .. OtherPassport .. "`",
                "🔢 **Quantidade de Gemas:** `" .. Amount .. "`",
                "🌐 **Endereço IP:** `" .. GetPlayerEndpoint(source) .. "`"
            }, "\n")

            exports["discord"]:Embed("Gemstone", logMsg, 3092790)

			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- BLIPS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("blips",function(source)
	local Passport = vRP.Passport(source)
	if Passport then
		if vRP.HasGroup(Passport,"Admin",2) then
			vRPC.BlipAdmin(source)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GOD
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("god",function(source,Message)
	local Passport = vRP.Passport(source)
	if Passport and vRP.HasGroup(Passport,"Admin") then
		if Message[1] then
			local OtherPassport = parseInt(Message[1])
			local OtherSource = vRP.Source(OtherPassport)
			if OtherSource then
				vRP.Revive(OtherSource,200)
				vRP.UpgradeThirst(OtherPassport,100)
				vRP.UpgradeHunger(OtherPassport,100)
				vRP.DowngradeStress(OtherPassport,100)
				TriggerClientEvent("paramedic:Reset",OtherSource)

                    local logMsg = table.concat({
                    "🛡️ **REVIVE / HEAL**",
                    "",
                    "👮 **Admin:** `" .. Passport .. "`",
                    "👤 **Passaporte Alvo:** `" .. OtherPassport .. "`",
                    "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y") .. " às " .. os.date("%H:%M") .. "`"
                }, "\n")

                exports["discord"]:Embed("God", logMsg)
        end
		else
			vRP.Revive(source,200)
			vRP.UpgradeThirst(Passport,100)
			vRP.UpgradeHunger(Passport,100)
			vRP.DowngradeStress(Passport,100)
			TriggerClientEvent("paramedic:Reset",source)

                local logMsg = table.concat({
                "🛡️ **REVIVE / HEAL**",
                "",
                "👮 **Admin:** `" .. Passport .. "`",
                "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y") .. " às " .. os.date("%H:%M") .. "`"
            }, "\n")

            exports["discord"]:Embed("God", logMsg)

		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ITEM
-----------------------------------------------------------------------------------------------------------------------------------------
-- Itens com nível mínimo de Admin exigido
local ItemMinAdmin = {
    gemstone = 2,   -- exige Admin grau 2+
    -- exemplo: ["weaponparts"] = 3,
}

local function canGiveItem(adminPassport, item)
    if not item then return false end
    local req = ItemMinAdmin[string.lower(item)]
    if not req then return true end -- não está na lista → permitido
    return vRP.HasGroup(adminPassport, "Admin", req) -- true se tiver o grau mínimo
end

local function denyItemGive(src, needed)
    TriggerClientEvent("Notify", src, "Permissão",
        "Este item está <b>restrito</b>. Requer <b>Admin</b> grau <b>"..(needed or 2).."</b>.", "vermelho", 6000)
end



RegisterCommand("item",function(source,Message)
    local Passport = vRP.Passport(source)
    if Passport and vRP.HasGroup(Passport,"Admin",3) then
        if not Message[1] then
            local Keyboard = vKEYBOARD.Item(source,"Passaporte","Item","Quantidade",{ "Jogador","Todos","Area" },"Distância")
            if Keyboard and ItemExist(Keyboard[2]) then
                local Item = Keyboard[2]
                local Action = Keyboard[4]
                local OtherPassport = Keyboard[1]
                local Amount = parseInt(Keyboard[3],true)
                local Distance = parseInt(Keyboard[5],true)

                -- 🔒 Bloqueio por nível mínimo de Admin para o item
                if not canGiveItem(Passport, Item) then
                    denyItemGive(source, ItemMinAdmin[string.lower(Item)])
                    return
                end

                if Action == "Jogador" then
                    if vRP.Source(OtherPassport) then
                        vRP.GenerateItem(OtherPassport,Item,Amount,true)
                        TriggerClientEvent("Notify",source,"Sucesso","Entregue ao destinatário.","verde",5000)
                    else
                        local Selected = GenerateString("DDLLDDLL")
                        local Consult = vRP.GetSrvData("Offline:"..OtherPassport,true)
                        repeat
                            Selected = GenerateString("DDLLDDLL")
                        until Selected and not Consult[Selected]
                        TriggerClientEvent("Notify",source,"Sucesso","Adicionado a lista de entregas.","verde",5000)
                        Consult[Selected] = { ["Item"] = Item, ["Amount"] = Amount }
                        vRP.SetSrvData("Offline:"..OtherPassport,Consult,true)
                    end

                elseif Action == "Todos" then
                    local List = vRP.Players()
                    for OtherPlayer,_ in pairs(List) do
                        async(function()
                            vRP.GenerateItem(OtherPlayer,Item,Amount,true)
                        end)
                    end
                    TriggerClientEvent("Notify",source,"Sucesso","Entregue a todos online.","verde",5000)

                elseif Action == "Area" then
                    local PlayerList = GetPlayers()
                    local Coords = vRP.GetEntityCoords(source)
                    local entregues = 0
                    for _,OtherSource in ipairs(PlayerList) do
                        async(function()
                            local OtherSource = parseInt(OtherSource)
                            local OtherPassport = vRP.Passport(OtherSource)
                            local OtherCoords = vRP.GetEntityCoords(OtherSource)
                            if OtherCoords and OtherPassport and #(Coords - OtherCoords) <= Distance then
                                vRP.GenerateItem(OtherPassport,Item,Amount,true)
                                entregues = entregues + 1
                            end
                        end)
                    end
                    TriggerClientEvent("Notify",source,"Sucesso","Entregue a "..entregues.." jogador(es) na área.","verde",5000)
                end

                local logMsg = table.concat({
                    "🎁 **ITEM ADMIN**",
                    "",
                    "👮 **Admin:** `" .. Passport .. "`",
                    "👤 **Passaporte Alvo:** `" .. (OtherPassport or "—") .. "`",
                    "📦 **Item:** `" .. Item .. "`",
                    "🔢 **Quantidade:** `" .. Amount .. "x`",
                    "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y %H:%M") .. "`"
                }, "\n")
                exports["discord"]:Embed("Item", logMsg)
            end

        elseif Message[1] and Message[2] then
            local itemArg = Message[1]
            local amountArg = parseInt(Message[2], true) or 1

            -- 🔒 Bloqueio também quando usa argumentos diretos
            if not canGiveItem(Passport, itemArg) then
                denyItemGive(source, ItemMinAdmin[string.lower(itemArg)])
                return
            end

            vRP.GenerateItem(Passport, itemArg, amountArg, true)

            local logMsg = table.concat({
                "🎁 **ITEM ADMIN**",
                "",
                "👮 **Admin:** `" .. Passport .. "`",
                "📦 **Item:** `" .. itemArg .. "`",
                "🔢 **Quantidade:** `" .. amountArg .. "x`",
                "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y %H:%M") .. "`"
            }, "\n")
            exports["discord"]:Embed("Item", logMsg)
        end
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- NC / Noclip (toggle) com log + coords (sem street)
-----------------------------------------------------------------------------------------------------------------------------------------
local _noclipState = {} -- [Passport] = true/false

RegisterCommand("nc", function(source)
    local Passport = vRP.Passport(source)
    if not Passport or not vRP.HasGroup(Passport, "Admin") then
        if source > 0 then
            TriggerClientEvent("Notify", source, "Permissão", "Não tens permissões.", "vermelho", 5000)
        end
        return
    end

    -- alterna estado local (para log/notify)
    _noclipState[Passport] = not (_noclipState[Passport] or false)
    local enabled = _noclipState[Passport]

    -- ativa/desativa noclip (client)
    vRPC.noClip(source)

    -- avisa o client para forçar stamina
    TriggerClientEvent("hud:NoclipState", source, enabled)

    -- coords atuais (server-safe)
    local ped = GetPlayerPed(source)
    local x, y, z = 0.0, 0.0, 0.0
    local h = 0.0
    if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        x, y, z = c.x + 0.0, c.y + 0.0, c.z + 0.0
        h = GetEntityHeading(ped) + 0.0
    end

    -- LOG DISCORD (webhook: "NoClip")
    local StaffName = vRP.FullName(Passport) or "Indefinido"
    local msg = table.concat({
        "🛸 **NoClip**",
        "",
        ("👮 **Staff:** %s (#%d | %d)"):format(StaffName, source, Passport),
        ("⚙️ **Estado:** %s"):format(enabled and "Ativado" or "Desativado"),
        ("📍 **Local:** `%.2f, %.2f, %.2f` (H: %.1f)"):format(x, y, z, h),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    }, "\n")
    exports["discord"]:Embed("NoClip", msg, source)
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- KICK
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("kick", function(source, Message)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if not vRP.HasGroup(Passport, "Admin", 4) then
        TriggerClientEvent("Notify", source, "Permissão", "Não tens permissões para usar este comando.", "vermelho", 5000)
        return
    end

    local TargetPassport = parseInt(Message[1] or 0)
    if TargetPassport <= 0 then
        TriggerClientEvent("Notify", source, "Kick", "Uso: <b>/kick passaporte [motivo]</b>", "amarelo", 6000)
        return
    end

    local OtherSource = vRP.Source(TargetPassport)
    if not OtherSource then
        TriggerClientEvent("Notify", source, "Kick", "Jogador offline.", "vermelho", 5000)
        return
    end

    local reason = table.concat(Message, " ", 2)
    if reason == "" then reason = "Expulso da cidade." end

    -- Notifys
    TriggerClientEvent("Notify", source, "Sucesso", ("Passaporte <b>%d</b> expulso."):format(TargetPassport), "verde", 5000)
    TriggerClientEvent("Notify", OtherSource, "Kick", ("Foste expulso: <b>%s</b>"):format(reason), "vermelho", 7000)

    -- Log Discord
    local StaffName  = vRP.FullName(Passport) or "Indefinido"
    local TargetName = vRP.FullName(TargetPassport) or "Indefinido"
    local msg = table.concat({
        "🟥 **Kick**",
        "",
        ("👮 **Staff:** %s (#%d | %d)"):format(StaffName, source, Passport),
        ("👤 **Alvo:** %s (#%d | %d)"):format(TargetName, OtherSource, TargetPassport),
        ("📝 **Motivo:** %s"):format(reason),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")
    exports["discord"]:Embed("Kick", msg, source)

    -- Executa kick
    vRP.Kick(OtherSource, reason)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- BAN
-----------------------------------------------------------------------------------------------------------------------------------------
-- RegisterCommand("ban",function(source,Message)
-- 	local Passport = vRP.Passport(source)
-- 	if Passport then
-- 		if vRP.HasGroup(Passport,"Admin",2) and parseInt(Message[1]) > 0 and parseInt(Message[2]) > 0 then
-- 			local Days = parseInt(Message[2])
-- 			local OtherPassport = parseInt(Message[1])
-- 			local Identity = vRP.Identity(OtherPassport)
-- 			if Identity then
-- 				vRP.Query("banneds/InsertBanned",{ license = Identity["license"], time = Days })
-- 				TriggerClientEvent("Notify",source,"Sucesso","Passaporte <b>"..Message[1].."</b> banido por <b>"..Message[2].."</b> dias.","verde",5000)

-- 				local OtherSource = vRP.Source(OtherPassport)
-- 				if OtherSource then
-- 					vRP.Kick(OtherSource,"Banido.")
-- 				end
-- 			end
-- 		end
-- 	end
-- end)

RegisterCommand("ban", function(source, args)
	local Passport = vRP.Passport(source)
	local OtherPassport = parseInt(args[1])
	if not Passport or not vRP.HasGroup(Passport, "Admin", 4) then
		TriggerClientEvent("Notify", source, "Erro", "Apenas staff autorizado.", "vermelho", 5000)
		return
	end

	if OtherPassport <= 0 then
		TriggerClientEvent("Notify", source, "Erro", "Passaporte inválido.", "vermelho", 5000)
		return
	end

	local Keyboard = vKEYBOARD.Secondary(source, "Dias", "Motivo")
	if Keyboard then
		local Dias = parseInt(Keyboard[1])
		local Motivo = Keyboard[2]

		if Dias > 0 and Motivo ~= "" then
			local Identity = vRP.Identity(OtherPassport)
			if Identity then
				vRP.Query("banneds/InsertBanned", { license = Identity["license"], time = Dias })

				TriggerClientEvent("Notify", source, "Sucesso", "Passaporte <b>"..OtherPassport.."</b> banido por <b>"..Dias.."</b> dias.", "verde", 5000)
				TriggerClientEvent("chat:ClientMessage",-1,"BANIMENTO","O passaporte "..OtherPassport.." foi banido por "..Dias.." dia(s) | Motivo: "..Motivo,"OOC")

				local OtherSource = vRP.Source(OtherPassport)
				if OtherSource then
					vRP.Kick(OtherSource, "Banido: " .. Motivo)
				end

                local StaffName = vRP.FullName(Passport)
                local DataHora = os.date("%d/%m/%Y às %H:%M")

                local logMsg = table.concat({
                    "🔨 **BAN ADMIN**",
                    "",
                    "👮 **Admin:** " .. StaffName .. " (📜 Passaporte: `" .. Passport .. "`)",
                    "🚫 **Passaporte Banido:** `" .. OtherPassport .. "`",
                    "⏳ **Dias:** `" .. Dias .. "`",
                    "📄 **Motivo:** " .. Motivo,
                    "🗓️ **Data & Hora:** `" .. DataHora .. "`"
                }, "\n")

                exports["discord"]:Embed("Ban", logMsg, source)

			else
				TriggerClientEvent("Notify", source, "Erro", "Passaporte não encontrado.", "vermelho", 5000)
			end
		else
			TriggerClientEvent("Notify", source, "Erro", "Preenche corretamente os campos.", "amarelo", 5000)
		end
	end
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- HBAN - PERMANENTE - CONSOLA
-----------------------------------------------------------------------------------------------------------------------------------------

RegisterCommand("hban", function(source, args)
	local Passport = vRP.Passport(source)
	if source ~= 0 and (not Passport or not vRP.HasGroup(Passport, "Admin", 4)) then
		TriggerClientEvent("Notify", source, "Erro", "Apenas staff autorizado.", "vermelho", 5000)
		return
	end

	local OtherPassport = parseInt(args[1])
	local Motivo = table.concat(args, " ", 2)

	if OtherPassport <= 0 or Motivo == "" then
		if source ~= 0 then
			TriggerClientEvent("Notify", source, "Erro", "Uso: /hban passaporte motivo", "amarelo", 5000)
		end
		return
	end

	local Identity = vRP.Identity(OtherPassport)
	if Identity then
		vRP.Query("banneds/InsertBanned", { license = Identity["license"], time = 3650 }) -- 10 anos
		TriggerClientEvent("chat:ClientMessage",-1,"BANIMENTO","O passaporte "..OtherPassport.." foi banido por 10 anos. | Motivo: "..Motivo,"OOC")

		local OtherSource = vRP.Source(OtherPassport)
		if OtherSource then
			vRP.Kick(OtherSource, "Banido permanentemente: " .. Motivo)
		end

        local StaffName = (source == 0 and "Console") or vRP.FullName(Passport)
        local StaffId = (source == 0 and "0") or tostring(Passport)
        local DataHora = os.date("%d/%m/%Y às %H:%M")

        local logMsg = table.concat({
            "⛔ **HBAN PERMANENTE**",
            "",
            "👮 **Staff:** " .. StaffName .. " (📜 Passaporte: `" .. StaffId .. "`)",
            "🚫 **Passaporte Banido:** `" .. OtherPassport .. "`",
            "📄 **Motivo:** " .. Motivo,
            "🗓️ **Data & Hora:** `" .. DataHora .. "`"
        }, "\n")

        exports["discord"]:Embed("Ban", logMsg, source)


		if source ~= 0 then
			TriggerClientEvent("Notify", source, "Sucesso", "Passaporte <b>"..OtherPassport.."</b> banido por 10 anos.", "verde", 5000)
		end
	else
		if source ~= 0 then
			TriggerClientEvent("Notify", source, "Erro", "Passaporte inválido.", "vermelho", 5000)
		end
	end
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- UNBAN
-----------------------------------------------------------------------------------------------------------------------------------------
-- RegisterCommand("unban",function(source,Message)
-- 	local Passport = vRP.Passport(source)
-- 	if Passport then
-- 		if vRP.HasGroup(Passport,"Admin",2) and parseInt(Message[1]) > 0 then
-- 			local OtherPassport = parseInt(Message[1])
-- 			local Identity = vRP.Identity(OtherPassport)
-- 			if Identity then
-- 				vRP.Query("banneds/RemoveBanned",{ license = Identity["license"] })
-- 				TriggerClientEvent("Notify",source,"Sucesso","Passaporte <b>"..Message[1].."</b> desbanido.","verde",5000)
-- 			end
-- 		end
-- 	end
-- end)

RegisterCommand("unban", function(source, args)
	local OtherPassport = parseInt(args[1])
	if OtherPassport <= 0 then
		if source == 0 then
			print("[UNBAN] Uso correto: /unban [passaporte]")
		else
			TriggerClientEvent("Notify", source, "Erro", "Uso correto: /unban [passaporte]", "amarelo", 5000)
		end
		return
	end

	local Identity = vRP.Identity(OtherPassport)
	if not Identity then
		if source == 0 then
			print("[UNBAN] Passaporte inválido.")
		else
			TriggerClientEvent("Notify", source, "Erro", "Passaporte inválido ou não existe.", "vermelho", 5000)
		end
		return
	end

	-- Remove ban (qualquer tipo)
	vRP.Query("banneds/RemoveBanned", { license = Identity["license"] })

	-- Mensagem de feedback
	if source == 0 then
		print("[UNBAN] Passaporte "..OtherPassport.." foi desbanido com sucesso.")
	else
		TriggerClientEvent("Notify", source, "Sucesso", "Passaporte <b>"..OtherPassport.."</b> desbanido com sucesso.", "verde", 5000)
	end

        -- Log no Discord (embed via webhook "Ban")
        local StaffName = source == 0 and "Console" or vRP.FullName(vRP.Passport(source))
        local StaffPassport = source == 0 and "Console" or vRP.Passport(source)
        local Coords = source == 0 and "Consola" or vRP.GetEntityCoords(source)
        local DataHora = os.date("%d/%m/%Y às %H:%M")

        local coordText = type(Coords) == "table" and string.format("📍 `X: %.2f | Y: %.2f | Z: %.2f`", Coords.x, Coords.y, Coords.z) or tostring(Coords)

        local logMsg = table.concat({
            "✅ **DESBANIMENTO**",
            "",
            "👮 **Staff:** " .. StaffName .. " (📜 Passaporte: `" .. StaffPassport .. "`)",
            "👤 **Passaporte Desbanido:** `" .. OtherPassport .. "`",
            coordText,
            "🗓️ **Data & Hora:** `" .. DataHora .. "`"
        }, "\n")

        exports["discord"]:Embed("Ban", logMsg, (source ~= 0 and source or nil))

end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- TPCDS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("tpcds", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end
    if not vRP.HasGroup(Passport,"Admin") then
        TriggerClientEvent("Notify", source, "Permissão", "Não tens permissões.", "vermelho", 5000)
        return
    end

    local Keyboard = vKEYBOARD.Primary(source, "Coordenadas (x,y,z):")
    if not Keyboard or not Keyboard[1] then return end

    local parts = splitString(Keyboard[1], ",")
    local x,y,z = toNumbers3(parts[1], parts[2], parts[3])

    -- origem (safe)
    local from = getCoordsSafe(source) or vec3(0.0,0.0,0.0)

    if x == 0 and y == 0 and z == 0 then
        TriggerClientEvent("Notify", source, "Teleporte", "Coordenadas inválidas.", "vermelho", 4000)
        return
    end

    if not TeleportSafe(source, x,y,z) then
        TriggerClientEvent("Notify", source, "Teleporte", "Falha ao teletransportar (entidade inválida).", "vermelho", 4000)
        return
    end

    -- log
    local adminName = vRP.FullName(Passport) or "Indefinido"
    local msg = table.concat({
        "🧭 **Teleport para Coordenadas**",
        "",
        ("👤 **Admin:** %s (#%d | %d)"):format(adminName, source, Passport),
        ("📍 **De:** `%.2f, %.2f, %.2f`"):format(from.x, from.y, from.z),
        ("📌 **Para:** `%.2f, %.2f, %.2f`"):format(x,y,z),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")
    exports["discord"]:Embed("Teleports", msg, source)

    TriggerClientEvent("Notify", source, "Teleporte", "Teletransportado para as coordenadas.", "verde", 3500)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CDS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("cds",function(source)
	local Passport = vRP.Passport(source)
	if Passport then
		if vRP.HasGroup(Passport,"Admin",2) then
			local Ped = GetPlayerPed(source)
			local Coords = GetEntityCoords(Ped)
			local heading = GetEntityHeading(Ped)

			vKEYBOARD.Copy(source,"Cordenadas:",Optimize(Coords["x"])..","..Optimize(Coords["y"])..","..Optimize(Coords["z"])..","..Optimize(heading))
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GROUP
-----------------------------------------------------------------------------------------------------------------------------------------
-- RegisterCommand("group",function(source,Message)
-- 	local Passport = vRP.Passport(source)
-- 	if Passport then
-- 		if vRP.HasGroup(Passport,"Admin") and parseInt(Message[1]) > 0 and Message[2] then
-- 			TriggerClientEvent("Notify",source,"Sucesso","Adicionado <b>"..Message[2].."</b> ao passaporte <b>"..Message[1].."</b>.","verde",5000)
-- 			vRP.SetPermission(Message[1],Message[2],Message[3])
-- 		end
-- 	end
-- end)
RegisterCommand("group", function(source, args)
    local isConsole = (source == 0)
    local Passport  = not isConsole and vRP.Passport(source) or nil
    if not isConsole and not Passport then return end

    local target = tonumber(args[1] or "")
    local group  = args[2]
    local level  = tonumber(args[3] or "")

    local function notify(src, title, msg, color, time)
        if src == 0 then
            print(("[GROUP] %s: %s"):format(title or "Info", (msg or ""):gsub("<b>", ""):gsub("</b>", "")))
        else
            TriggerClientEvent("Notify", src, title or "Grupo", msg or "", color or "azul", time or 5000)
        end
    end

    local function getAdminLevel(passport)
        -- Retorna o MENOR nível (1=mais alto) que o jogador possui em Admin, ou nil se não tiver
        for i=1,5 do
            if vRP.HasPermission(passport, "Admin", i) then
                return i
            end
        end
        return nil
    end

    -- Permissão base: só Admin usa no jogo; CONSOLE sempre pode
    if not isConsole then
        if not vRP.HasGroup(Passport, "Admin") then
            notify(source, "Permissão", "Não tens permissões.", "vermelho", 5000)
            return
        end
    end

    -- Uso
    if not target or target <= 0 or not group then
        local uso = "Formato: /group PASSAPORTE GRUPO [GRAU]"
        notify(source, "Uso", "<b>"..uso.."</b>.", "amarelo", 5000)
        return
    end

    -- Carrega hierarquia (para mostrar cargo)
    local Global = module("vrp", "config/Global")
    local Groups = Global and Global.Groups or {}
    local groupKeyLower = string.lower(group)
    local isAdminGroup = (groupKeyLower == "admin")

    -- Regras especiais para ADMIN
    if isAdminGroup then
        -- Level precisa ser definido para Admin
        if not level or level < 1 or level > 5 then
            notify(source, "Admin", "Define um <b>grau</b> válido (1 a 5) para o grupo <b>Admin</b>.", "amarelo", 6000)
            return
        end

        -- CONSOLE não pode dar Admin 1
        if isConsole and level == 1 then
            notify(source, "Bloqueado", "CONSOLE não pode atribuir o <b>Admin 1</b>.", "vermelho", 6000)
            return
        end

        -- Nível do executor (se não for console)
        local execLevel = isConsole and 0 or getAdminLevel(Passport) -- 0 = super (console)
        if not isConsole then
            if not execLevel then
                notify(source, "Permissão", "Precisas de ter grupo <b>Admin</b>.", "vermelho", 5000)
                return
            end

            -- Só Admin 1 e 2 podem dar Admin
            if execLevel > 2 then
                notify(source, "Bloqueado", "Apenas <b>Admin 1</b> ou <b>Admin 2</b> podem atribuir <b>Admin</b>.", "vermelho", 6000)
                return
            end

            -- Regras do Admin 2
            if execLevel == 2 then
                -- Não pode dar Admin 1 nem 2
                if level <= 2 then
                    notify(source, "Bloqueado", "Como <b>Admin 2</b>, só podes dar <b>Admin 3, 4 ou 5</b>.", "vermelho", 6000)
                    return
                end
            end
        end

        -- Proteção: não alterar alguém superior/igual
        local targetAdminLevel = getAdminLevel(target)
        if targetAdminLevel then
            if isConsole then
                -- Console só bloqueia quando tentaria alterar alguém superior? Console é 0 (super), então só precisa bloquear regra de Admin1 já tratada.
            else
                local execLevel = getAdminLevel(Passport) or 99
                -- Bloqueia mexer em nível <= ao teu (não altera superior nem igual)
                if targetAdminLevel <= execLevel then
                    notify(source, "Bloqueado",
                        ("Não podes alterar um <b>Admin %d</b> (superior/igual ao teu nível)."):format(targetAdminLevel),
                        "vermelho", 7000)
                    return
                end
                -- Como Admin 2, também não podes promover alguém para nível 1/2 (já validado acima)
            end
        end
    end

    -- Montar cargo (se houver)
    local cargo = ""
    if level and level > 0 and Groups[group] and Groups[group].Hierarchy and Groups[group].Hierarchy[level] then
        cargo = Groups[group].Hierarchy[level]
    end

    -- Aplicar permissão
    vRP.SetPermission(target, group, level)

    -- Feedback
    local notifyMsg = ("<b>%s</b> atribuído ao passaporte <b>%d</b>"):format(group, target)
    if level and level > 0 then
        notifyMsg = notifyMsg .. (" (Grau %d%s)"):format(level, cargo ~= "" and " - " .. cargo or "")
    end
    notify(source, "Sucesso", notifyMsg .. ".", "verde", 5000)

    -- Log Discord
    local adminName  = isConsole and "CONSOLE" or (vRP.FullName(Passport) or "Indefinido")
    local targetName = vRP.FullName(target) or "Indefinido"
    local whoLine = isConsole
        and ("👤 **Executor:** CONSOLE")
        or  ("👤 **Admin:** "..adminName..(" (#%d | %d)"):format(source, Passport))

    local msg = table.concat({
        "✅ **Adição/Alteração de Grupo**",
        "",
        whoLine,
        ("🎯 **Alvo:** %s (%d)"):format(targetName, target),
        ("🏷️ **Grupo:** %s"):format(group),
        (level and level > 0) and ("📊 **Grau:** %d%s"):format(level, cargo ~= "" and " - " .. cargo or "") or "",
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")

    exports["discord"]:Embed("Group", msg, source)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- UNGROUP
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("ungroup", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if not vRP.HasGroup(Passport,"Admin") then
        TriggerClientEvent("Notify", source, "Permissão", "Não tens permissões.", "vermelho", 5000)
        return
    end

    local targetPass = tonumber(args[1] or "")
    local groupName  = args[2]

    if not targetPass or targetPass <= 0 or not groupName then
        TriggerClientEvent("Notify", source, "Uso", "Formato: <b>/ungroup PASSAPORTE GRUPO</b>.", "amarelo", 5000)
        return
    end

    vRP.RemovePermission(targetPass, groupName)

    TriggerClientEvent("Notify", source, "Sucesso", ("Removido <b>%s</b> ao passaporte <b>%d</b>."):format(groupName, targetPass), "verde", 5000)

    -- log para Discord
    local adminName  = vRP.FullName(Passport)
    local targetName = vRP.FullName(targetPass) or "Indefinido"

    local msg = table.concat({
        "❌ **Remoção de Grupo**",
        "",
        ("👤 **Admin:** %s (#%d | %d)"):format(adminName or "Indefinido", source, Passport),
        ("🎯 **Alvo:** %s (%d)"):format(targetName, targetPass),
        ("🏷️ **Grupo Removido:** %s"):format(groupName),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")

    exports["discord"]:Embed("Group", msg, source)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- /freezearea <raio> — congela todos no raio (exceto quem tem grupo Admin). Log em 'Freeze'
-- /unfreezearea <raio> — liberta todos no raio.
-- Permissão: Admin 3 ou Console
-----------------------------------------------------------------------------------------------------------------------------------------
local function _toggleFreezeArea(src, radius, state)
    local isConsole = (src == 0)
    local adminPass = not isConsole and vRP.Passport(src) or nil
    local adminPos  = getCoordsSafe(src)
    if not adminPos then
        if not isConsole then TriggerClientEvent("Notify", src, "Falha", "Não foi possível obter a tua posição.", "vermelho", 4000) end
        return
    end

    local affected, skipped = {}, 0
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        local pass = vRP.Passport(s)
        if s ~= src then
            local pos = getCoordsSafe(s)
            if pos then
                local dx,dy,dz = pos.x-adminPos.x, pos.y-adminPos.y, pos.z-adminPos.z
                local dist = math.sqrt(dx*dx+dy*dy+dz*dz)
                if dist <= radius then
                    -- não aplica freeze a quem tem grupo Admin (qualquer nível)
                    if pass and vRP.HasGroup(pass,"Admin") then
                        skipped = skipped + 1
                    else
                        -- ⬇️ usa o teu evento client existente
                        TriggerClientEvent("admin:toggleFreeze", s, state)
                        affected[#affected+1] = { src = s, pass = pass or 0, name = (pass and vRP.FullName(pass)) or "Indefinido" }
                    end
                end
            end
        end
    end

    if state then
        local adminName = isConsole and "CONSOLE" or (vRP.FullName(adminPass) or "Indefinido")
        local lines = {
            "🧊 **Freeze em Área**",
            "",
            isConsole and "👤 **Executor:** CONSOLE" or ("👤 **Admin:** "..adminName..(" (#%d | %d)"):format(src, adminPass)),
            ("🟦 **Raio:** %.1f m"):format(radius),
            ("📌 **Centro:** `%.2f, %.2f, %.2f`"):format(adminPos.x, adminPos.y, adminPos.z),
            ("✅ **Congelados:** %d"):format(#affected),
            ("⛔ **Ignorados (Admin):** %d"):format(skipped)
        }
        for _,p in ipairs(affected) do
            lines[#lines+1] = ("• %s (#%d | %d)"):format(p.name, p.src, p.pass)
        end
        lines[#lines+1] = ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
        exports["discord"]:Embed("Freeze", table.concat(lines,"\n"), src)
    end

    local label = state and "congelaste" or "libertaste"
    if not isConsole then
        TriggerClientEvent("Notify", src, "Freeze", ("<b>%s</b> jogador(es) %s."):format(#affected, label), "azul", 4000)
        if skipped > 0 then
            TriggerClientEvent("Notify", src, "Freeze", ("Ignorados <b>%d</b> com grupo Admin."):format(skipped), "amarelo", 4000)
        end
    else
        print(("[FREEZEAREA] %s %d jogadores; ignorados %d Admin."):format(label, #affected, skipped))
    end
end

RegisterCommand("freezearea", function(source, args)
    local isConsole = (source == 0)
    local Passport  = not isConsole and vRP.Passport(source) or nil
    if not isConsole and not Passport then return end
    if not isConsole and not vRP.HasPermission(Passport,"Admin",3) then
        TriggerClientEvent("Notify", source, "Permissão", "Apenas <b>Admin nível 3</b> pode usar.", "vermelho", 5000)
        return
    end

    local radius = tonumber(args[1] or "")
    if not radius or radius <= 0 then
        local uso = "Formato: /freezearea RAIO"
        if isConsole then print("[FREEZEAREA] "..uso) else TriggerClientEvent("Notify", source, "Uso", "<b>"..uso.."</b>.", "amarelo", 5000) end
        return
    end

    _toggleFreezeArea(source, radius, true)
end)

RegisterCommand("unfreezearea", function(source, args)
    local isConsole = (source == 0)
    local Passport  = not isConsole and vRP.Passport(source) or nil
    if not isConsole and not Passport then return end
    if not isConsole and not vRP.HasPermission(Passport,"Admin",3) then
        TriggerClientEvent("Notify", source, "Permissão", "Apenas <b>Admin nível 3</b> pode usar.", "vermelho", 5000)
        return
    end

    local radius = tonumber(args[1] or "")
    if not radius or radius <= 0 then
        local uso = "Formato: /unfreezearea RAIO"
        if isConsole then print("[UNFREEZEAREA] "..uso) else TriggerClientEvent("Notify", source, "Uso", "<b>"..uso.."</b>.", "amarelo", 5000) end
        return
    end

    _toggleFreezeArea(source, radius, false)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- WARN /warn <pass> <motivo...> — só Console e Admin nível 4 Log no canal "Ban".
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("warn", function(source, args)
    local isConsole = (source == 0)
    local Passport  = not isConsole and vRP.Passport(source) or nil
    if not isConsole and not Passport then return end

    if not isConsole and not vRP.HasPermission(Passport,"Admin",5) then
        TriggerClientEvent("Notify", source, "Permissão", "Sem permissão.", "vermelho", 5000)
        return
    end

    local targetPass = tonumber(args[1] or "")
    if not targetPass or targetPass <= 0 then
        local uso = "Formato: /warn PASSAPORTE MOTIVO"
        if isConsole then print("[WARN] "..uso) else TriggerClientEvent("Notify", source, "Uso", "<b>"..uso.."</b>.", "amarelo", 5000) end
        return
    end

    table.remove(args,1)
    local reason = table.concat(args, " ")
    if reason == "" then
        TriggerClientEvent("Notify", source, "Uso", "Especifica um <b>motivo</b>.", "amarelo", 5000)
        return
    end

    local targetSrc = vRP.Source(targetPass)
    local adminName = isConsole and "CONSOLE" or (vRP.FullName(Passport) or "Indefinido")
    local targetName = vRP.FullName(targetPass) or "Indefinido"

    -- Notificações
    if targetSrc then
        TriggerClientEvent("Notify", targetSrc, "Aviso", ("Recebeste um <b>warn</b> da staff: %s"):format(reason), "amarelo", 7000)
    end
    if not isConsole then
        TriggerClientEvent("Notify", source, "Aviso", ("Warn aplicado a <b>%s</b>."):format(targetName), "verde", 4000)
    end

    -- Log em "Ban"
    local msg = table.concat({
        "⚠️ **WARN aplicado**",
        "",
        isConsole and "👤 **Executor:** CONSOLE" or ("👤 **Admin:** "..adminName..(" (#%d | %d)"):format(source, Passport)),
        ("🎯 **Alvo:** %s (%d)"):format(targetName, targetPass),
        ("📝 **Motivo:** %s"):format(reason),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")
    exports["discord"]:Embed("Warn", msg, source)
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- /bringarea <raio> — puxar jogadores num raio (APENAS Admin nível 3; consola bloqueada)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("bringarea", function(source, args)
    -- bloquear consola
    if source == 0 then
        print("[BRINGAREA] Bloqueado para consola. Usa in-game com Admin nível 3.")
        return
    end

    local Passport = vRP.Passport(source)
    if not Passport then return end

    -- Apenas Admin nível 3
    if not vRP.HasPermission(Passport, "Admin", 3) then
        TriggerClientEvent("Notify", source, "Permissão", "Apenas <b>Admin nível 3</b> pode usar.", "vermelho", 5000)
        return
    end

    local radius = tonumber(args[1] or "")
    if not radius or radius <= 0 then
        TriggerClientEvent("Notify", source, "Uso", "<b>/bringarea RAIO</b>.", "amarelo", 5000)
        return
    end

    local adminPos = getCoordsSafe(source)
    if not adminPos then
        TriggerClientEvent("Notify", source, "Falha", "Não foi possível obter a tua posição.", "vermelho", 4000)
        return
    end

    local moved = {}
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        if s ~= source then
            local pos = getCoordsSafe(s)
            if pos then
                local dx,dy,dz = pos.x-adminPos.x, pos.y-adminPos.y, pos.z-adminPos.z
                local dist = math.sqrt(dx*dx+dy*dy+dz*dz)
                if dist <= radius then
                    if TeleportSafe(s, adminPos.x, adminPos.y, adminPos.z) then
                        local pass = vRP.Passport(s)
                        moved[#moved+1] = {
                            src = s,
                            pass = pass or 0,
                            name = (pass and vRP.FullName(pass)) or "Indefinido",
                            from = pos
                        }
                        TriggerClientEvent("Notify", s, "Teleporte", "Foste puxado por um membro da staff.", "amarelo", 3500)
                    end
                end
            end
        end
    end

    -- Log (sem consola)
    local adminName = vRP.FullName(Passport) or "Indefinido"
    local lines = {
        "📥 **Teleport em Área (bringarea)**",
        "",
        ("👤 **Admin:** %s (#%d | %d)"):format(adminName, source, Passport),
        ("🟦 **Raio:** %.1f m"):format(radius),
        ("📌 **Destino:** `%.2f, %.2f, %.2f`"):format(adminPos.x, adminPos.y, adminPos.z),
        ("👥 **Total puxados:** %d"):format(#moved)
    }
    for _,info in ipairs(moved) do
        lines[#lines+1] = ("• %s (#%d | %d) de `%.2f, %.2f, %.2f`")
            :format(info.name, info.src, info.pass, info.from.x, info.from.y, info.from.z)
    end
    lines[#lines+1] = ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    exports["discord"]:Embed("Teleports", table.concat(lines,"\n"), source)

    TriggerClientEvent("Notify", source, "Teleporte", ("Puxaste <b>%d</b> jogador(es)."):format(#moved), "verde", 4000)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- TPT (teleporta passaporte ORIGEM até passaporte DESTINO)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("tpt", function(source, args)
    local isConsole = (source == 0)
    local Passport  = not isConsole and vRP.Passport(source) or nil
    if not isConsole and not Passport then return end

    -- Só Console ou Admin nível 3
    if not isConsole and not vRP.HasPermission(Passport,"Admin",3) then
        TriggerClientEvent("Notify", source, "Permissão", "Apenas <b>Admin nível 3</b> pode usar.", "vermelho", 5000)
        return
    end

    local passFrom = tonumber(args[1] or "")
    local passTo   = tonumber(args[2] or "")
    if not passFrom or not passTo then
        local uso = "Formato: /tpt PASSAPORTE_ORIGEM PASSAPORTE_DESTINO"
        if isConsole then
            print("[TPT] "..uso)
        else
            TriggerClientEvent("Notify", source, "Uso", "<b>"..uso.."</b>.", "amarelo", 5000)
        end
        return
    end

    local fromSrc = vRP.Source(passFrom)
    local toSrc   = vRP.Source(passTo)
    if not fromSrc or not toSrc then
        TriggerClientEvent("Notify", source, "Falha", "Um dos jogadores está <b>offline</b>.", "vermelho", 5000)
        return
    end

    local from = getCoordsSafe(fromSrc)
    local to   = getCoordsSafe(toSrc)
    if not from or not to then
        TriggerClientEvent("Notify", source, "Falha", "Entidade inválida para teleporte.", "vermelho", 4000)
        return
    end

    if not TeleportSafe(fromSrc, to.x, to.y, to.z) then
        TriggerClientEvent("Notify", source, "Falha", "Não foi possível teleportar o jogador.", "vermelho", 4000)
        return
    end

    -- Logs
    local adminName  = isConsole and "CONSOLE" or (vRP.FullName(Passport) or "Indefinido")
    local fromName   = vRP.FullName(passFrom) or "Indefinido"
    local toName     = vRP.FullName(passTo) or "Indefinido"
    local msg = table.concat({
        "🔁 **Teleport Jogador → Jogador**",
        "",
        isConsole and ("👤 **Executor:** CONSOLE") or  ("👤 **Admin:** "..adminName..(" (#%d | %d)"):format(source, Passport)),
        ("🚹 **Origem:** %s (#%d | %d)"):format(fromName, fromSrc, passFrom),
        ("➡️ **Destino:** %s (#%d | %d)"):format(toName, toSrc, passTo),
        ("📍 **De (origem):** `%.2f, %.2f, %.2f`"):format(from.x, from.y, from.z),
        ("📌 **Para (destino):** `%.2f, %.2f, %.2f`"):format(to.x, to.y, to.z),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")
    exports["discord"]:Embed("Teleports", msg, source)

    -- Feedback
    TriggerClientEvent("Notify", source, "Teleporte", ("Levaste <b>%s</b> até <b>%s</b>."):format(fromName, toName), "verde", 3500)
    TriggerClientEvent("Notify", fromSrc, "Teleporte", ("Foste teleportado até <b>%s</b> por staff."):format(toName), "amarelo", 3500)
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- TPTOME
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("tptome", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport then return end
    if not vRP.HasGroup(Passport,"Admin") then
        TriggerClientEvent("Notify", source, "Permissão", "Não tens permissões.", "vermelho", 5000)
        return
    end

    local targetPass = tonumber(args[1] or "")
    if not targetPass or targetPass <= 0 then
        TriggerClientEvent("Notify", source, "Uso", "Formato: <b>/tptome PASSAPORTE</b>.", "amarelo", 5000)
        return
    end

    local targetSrc = vRP.Source(targetPass)
    if not targetSrc then
        TriggerClientEvent("Notify", source, "Falha", "Jogador alvo está <b>offline</b>.", "vermelho", 5000)
        return
    end

    local to = getCoordsSafe(source)
    local from = getCoordsSafe(targetSrc)
    if not to or not from then
        TriggerClientEvent("Notify", source, "Falha", "Entidade inválida para teleporte.", "vermelho", 4000)
        return
    end

    if not TeleportSafe(targetSrc, to.x, to.y, to.z) then
        TriggerClientEvent("Notify", source, "Falha", "Não foi possível puxar o jogador.", "vermelho", 4000)
        return
    end

    local adminName  = vRP.FullName(Passport) or "Indefinido"
    local targetName = vRP.FullName(targetPass) or "Indefinido"
    local msg = table.concat({
        "📥 **Teleport para Mim**",
        "",
        ("👤 **Admin:** %s (#%d | %d)"):format(adminName, source, Passport),
        ("🎯 **Alvo:** %s (#%d | %d)"):format(targetName, targetSrc, targetPass),
        ("📍 **De (alvo):** `%.2f, %.2f, %.2f`"):format(from.x, from.y, from.z),
        ("📌 **Para (admin):** `%.2f, %.2f, %.2f`"):format(to.x, to.y, to.z),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")
    exports["discord"]:Embed("Teleports", msg, source)

    TriggerClientEvent("Notify", source, "Teleporte", ("Trouxeste <b>%s</b> até ti."):format(targetName), "verde", 3500)
    TriggerClientEvent("Notify", targetSrc, "Teleporte", "Foste puxado por um membro da staff.", "amarelo", 3500)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- TPTO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("tpto", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport then return end
    if not vRP.HasGroup(Passport,"Admin") then
        TriggerClientEvent("Notify", source, "Permissão", "Não tens permissões.", "vermelho", 5000)
        return
    end

    local targetPass = tonumber(args[1] or "")
    if not targetPass or targetPass <= 0 then
        TriggerClientEvent("Notify", source, "Uso", "Formato: <b>/tpto PASSAPORTE</b>.", "amarelo", 5000)
        return
    end

    local targetSrc = vRP.Source(targetPass)
    if not targetSrc then
        TriggerClientEvent("Notify", source, "Falha", "Jogador alvo está <b>offline</b>.", "vermelho", 5000)
        return
    end

    local from = getCoordsSafe(source)
    local to   = getCoordsSafe(targetSrc)
    if not from or not to then
        TriggerClientEvent("Notify", source, "Falha", "Entidade inválida para teleporte.", "vermelho", 4000)
        return
    end

    if not TeleportSafe(source, to.x, to.y, to.z) then
        TriggerClientEvent("Notify", source, "Falha", "Não foi possível ir até ao jogador.", "vermelho", 4000)
        return
    end

    local adminName  = vRP.FullName(Passport) or "Indefinido"
    local targetName = vRP.FullName(targetPass) or "Indefinido"
    local msg = table.concat({
        "🪄 **Teleport para Jogador**",
        "",
        ("👤 **Admin:** %s (#%d | %d)"):format(adminName, source, Passport),
        ("🎯 **Alvo:** %s (#%d | %d)"):format(targetName, targetSrc, targetPass),
        ("📍 **De:** `%.2f, %.2f, %.2f`"):format(from.x, from.y, from.z),
        ("📌 **Para:** `%.2f, %.2f, %.2f`"):format(to.x, to.y, to.z),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")
    exports["discord"]:Embed("Teleports", msg, source)

    TriggerClientEvent("Notify", source, "Teleporte", ("Foste até <b>%s</b>."):format(targetName), "verde", 3500)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- TPWAY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("tpway", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end
    if not vRP.HasGroup(Passport,"Admin") then
        TriggerClientEvent("Notify", source, "Permissão", "Não tens permissões.", "vermelho", 5000)
        return
    end

    TriggerClientEvent("Notify", source, "Teleporte", "A processar TP para o waypoint...", "azul", 2000)

    -- TUNNEL (se existir)
    local ok = false
    local cli = nil
    local s, err = pcall(function()
        cli = Tunnel.getInterface("admin", source)
    end)
    if s and cli and cli.teleportWay then
        local s2 = pcall(function() cli.teleportWay() end)
        ok = s2
    end

    -- FALLBACK NET EVENT
    if not ok then
        TriggerClientEvent("admin:teleportWay", source)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOG (chamado pelo client)
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.LogTeleport(ox,oy,oz,dx,dy,dz)
    local src      = source
    local Passport = vRP.Passport(src)
    if not Passport then return end

    local name = vRP.FullName(Passport)
    local msg = table.concat({
        "🧭 **Teleport para Waypoint**",
        "",
        ("👤 **Jogador:** %s (#%d | %d)"):format(name or "Indefinido", src or 0, Passport or 0),
        ("📍 **De:** `%.2f, %.2f, %.2f`"):format(ox or 0.0, oy or 0.0, oz or 0.0),
        ("📌 **Para:** `%.2f, %.2f, %.2f`"):format(dx or 0.0, dy or 0.0, dz or 0.0),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")

    exports["discord"]:Embed("Teleports", msg, src)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LIMBO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("limbo", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end
    vCLIENT.teleportLimbo(source) -- manda para o client
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- HASH
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("hash",function(source)
	local Passport = vRP.Passport(source)
	if Passport then
		if vRP.HasGroup(Passport,"Admin") then
			local vehicle = vRPC.VehicleHash(source)
			if vehicle then
				vKEYBOARD.Copy(source,"Hash:",vehicle)
			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- TUNING
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("tuning", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") then
        TriggerClientEvent("admin:Tuning", source)
        TriggerClientEvent("Notify", source, "Admin", "Abriste o <b>Tuning</b>.", "azul", 5000)

        -- 📑 Log Discord
        exports["discord"]:Embed("Admin",
            "🔧 **Comando /tuning**\n\n👤 Passaporte: **"..Passport.."**\n📂 Ação: **Abriu o menu de tuning**",
            source
        )
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- FIX
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("fix", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") then
        local Vehicle, Network, Plate = vRPC.VehicleList(source)
        if Vehicle then
            local Players = vRP.Players(source)
            for _, OtherSource in pairs(Players) do
                async(function()
                    TriggerClientEvent("target:RollVehicle", OtherSource, Network)
                    TriggerClientEvent("inventory:RepairAdmin", OtherSource, Network, Plate)
                    TriggerClientEvent("engine:SetFuel", OtherSource, Network, 100.0) -- ⛽ enche combustível
                end)
            end

            TriggerClientEvent("Notify", source, "Admin", "Veículo <b>reparado e abastecido</b>.", "verde", 5000)

            -- 📑 Log Discord
            exports["discord"]:Embed("Admin",
                "🛠️ **Comando /fix**\n\n👤 Passaporte: **"..Passport.."**\n🚗 Veículo: **"..Plate.."**\n⛽ Estado: **Reparado + combustível cheio**",
                source
            )
        else
            TriggerClientEvent("Notify", source, "Admin", "Nenhum veículo encontrado.", "amarelo", 5000)
        end
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ADMIN:COORDS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("admin:Coords")
AddEventHandler("admin:Coords",function(Coords)
	vRP.Archive("coordenadas.txt",Optimize(Coords["x"])..","..Optimize(Coords["y"])..","..Optimize(Coords["z"]))
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CDS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.buttonTxt()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		if vRP.HasGroup(Passport,"Admin") then
			local Ped = GetPlayerPed(source)
			local Coords = GetEntityCoords(Ped)
			local heading = GetEntityHeading(Ped)

			vRP.Archive(Passport..".txt",Optimize(Coords["x"])..","..Optimize(Coords["y"])..","..Optimize(Coords["z"])..","..Optimize(heading))
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ANNOUNCE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("announce", function(source, Message, History)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") and Message[1] then
        local text = History:sub(9)
        TriggerClientEvent("Notify", -1, "Governador", text, "vermelho", 60000)

        -- 📑 Log Discord
        exports["discord"]:Embed("Admin",
            "📢 **Comando /announce**\n\n👤 Passaporte: **"..Passport.."**\n📝 Mensagem: ```"..text.."```",
            source
        )
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões ou mensagem inválida.", "vermelho", 5000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONSOLE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("console", function(source, Message, History)
    if source == 0 then
        local text = History:sub(8)
        TriggerClientEvent("Notify", -1, "Governador", text, "vermelho", 60000)

        -- 📑 Log Discord
        exports["discord"]:Embed("Admin",
            "🖥️ **Comando /console**\n\n📡 Origem: **CONSOLE**\n📝 Mensagem: ```"..text.."```"
        )
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- KICKALL
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("kickall", function(source, args)
    -- Permissão: só Admin (ou console)
    if source ~= 0 then
        local Passport = vRP.Passport(source)
        if not Passport or not vRP.HasGroup(Passport, "Admin") then
            TriggerClientEvent("Notify", source, "KickAll", "Não tens permissões.", "vermelho", 5000)
            return
        end
    end

    local reason = table.concat(args or {}, " ")
    if reason == "" then
        reason = "Desconectado, a cidade reiniciou."
    end

    local kicked, protected = 0, 0
    local lines = {}

    local list = vRP.Players() -- sources online
    for _, sid in pairs(list) do
        local pass = vRP.Passport(sid)
        if pass then
            if vRP.HasGroup(pass, "Admin") then
                protected = protected + 1
                TriggerClientEvent("Notify", sid, "KickAll", "Reinício em curso — estás protegido (staff).", "azul", 7000)
            else
                local name = vRP.FullName(pass) or "Indefinido"
                vRP.Kick(sid, reason)
                kicked = kicked + 1
                lines[#lines+1] = ("• %s (#%d | %d)"):format(name, sid, pass)
                Wait(50)
            end
        end
    end

    TriggerEvent("SaveServer", false)

    if source ~= 0 then
        TriggerClientEvent("Notify", source, "KickAll", ("Kick aplicado a <b>%d</b> jogadores (staff protegido: %d)."):format(kicked, protected), "verde", 7000)
    end

    -- LOG DISCORD (webhook: KickAll)
    local execPass = (source ~= 0 and vRP.Passport(source)) or 0
    local execName = (source ~= 0 and vRP.FullName(execPass)) or "Console"
    local msg = table.concat({
        "🟧 **KickAll**",
        "",
        ("👮 **Executor:** %s (#%d | %d)"):format(execName, source, execPass),
        ("📝 **Motivo:** %s"):format(reason),
        ("👥 **Kicks:** %d"):format(kicked),
        ("🛡️ **Protegidos (staff):** %d"):format(protected),
        (#lines > 0 and ("\n**Lista:**\n"..table.concat(lines, "\n")) or ""),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")
    exports["discord"]:Embed("Kick", msg, source)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SAVE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("save",function(source)
	if source ~= 0 then
		local Passport = vRP.Passport(source)
		if not vRP.HasGroup(Passport,"Admin") then
			return
		end
	end

	TriggerEvent("SaveServer",false)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSAVEAUTO
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		Wait(5 * 60000)
		TriggerEvent("SaveServer",true)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- RACECOORDS
-----------------------------------------------------------------------------------------------------------------------------------------
local Checkpoint = 0
function Creative.raceCoords(vehCoords,leftCoords,rightCoords)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		Checkpoint = Checkpoint + 1

		vRP.Archive("races.txt","["..Checkpoint.."] = {")

		vRP.Archive("races.txt","{ "..Optimize(vehCoords["x"])..","..Optimize(vehCoords["y"])..","..Optimize(vehCoords["z"]).." },")
		vRP.Archive("races.txt","{ "..Optimize(leftCoords["x"])..","..Optimize(leftCoords["y"])..","..Optimize(leftCoords["z"]).." },")
		vRP.Archive("races.txt","{ "..Optimize(rightCoords["x"])..","..Optimize(rightCoords["y"])..","..Optimize(rightCoords["z"]).." }")

		vRP.Archive("races.txt","},")
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SPECTATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Spectate = {}
RegisterCommand("spectate", function(source, Message)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") then
        if Spectate[Passport] then
            local Ped = GetPlayerPed(Spectate[Passport])
            if DoesEntityExist(Ped) then
                SetEntityDistanceCullingRadius(Ped, 0.0)
            end

            TriggerClientEvent("admin:resetSpectate", source)
            Spectate[Passport] = nil
            TriggerClientEvent("Notify", source, "Admin", "Spectate <b>desativado</b>.", "azul", 5000)

            -- 📑 Log Discord
            exports["discord"]:Embed("Admin",
                "👀 **Comando /spectate**\n\n👤 Passaporte: **"..Passport.."**\n🛑 Estado: **Parou de spectar**",
                source
            )
        else
            local OtherPassport = tonumber(Message[1] or 0)
            local OtherSource = vRP.Source(OtherPassport)
            if OtherSource then
                local Ped = GetPlayerPed(OtherSource)
                if DoesEntityExist(Ped) then
                    SetEntityDistanceCullingRadius(Ped, 999999999.0)
                    Wait(1000)
                    TriggerClientEvent("admin:initSpectate", source, OtherSource)
                    Spectate[Passport] = OtherSource
                    TriggerClientEvent("Notify", source, "Admin", "Agora a spectar o passaporte <b>"..OtherPassport.."</b>.", "azul", 5000)

                    -- 📑 Log Discord
                    exports["discord"]:Embed("Admin",
                        "👀 **Comando /spectate**\n\n👤 Admin: **"..Passport.."**\n🎯 Alvo: **"..OtherPassport.."**\n✅ Estado: **Spectate iniciado**",
                        source
                    )
                end
            else
                TriggerClientEvent("Notify", source, "Admin", "Jogador inválido ou offline.", "vermelho", 5000)
            end
        end
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- QUAKE
-----------------------------------------------------------------------------------------------------------------------------------------
GlobalState["Quake"] = false
RegisterCommand("quake",function(source,Message)
	local Passport = vRP.Passport(source)
	if Passport and vRP.HasGroup(Passport,"Admin",1) then
		TriggerClientEvent("Notify",-1,"Terromoto","Os geólogos informaram para nossa unidade governamental que foi encontrado um abalo de magnitude <b>60</b> na <b>Escala Richter</b>, encontrem abrigo até que o mesmo passe.","roxo",60000)
		GlobalState["Quake"] = true
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- LIMPAREA
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("limparea", function(source, Message)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") then
        local Ped    = GetPlayerPed(source)
        local Coords = GetEntityCoords(Ped)
        local Players = vRPC.Players(source)

        for _, Sources in pairs(Players) do
            async(function()
                vCLIENT.Limparea(Sources, Coords)
            end)
        end

        TriggerClientEvent("Notify", source, "Admin", "Área <b>limpa</b> em redor da tua posição.", "verde", 5000)

        -- 📑 Log Discord
        exports["discord"]:Embed("Admin",
            "🧹 **Comando /limparea**\n\n👤 Passaporte: **"..Passport.."**\n📍 Localização: `"
            ..math.floor(Coords.x)..","..math.floor(Coords.y)..","..math.floor(Coords.z).."`",
            source
        )
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- VIDEO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("video",function(source,Message)
	local Passport = vRP.Passport(source)
	if Passport and vRP.HasGroup(Passport,"Admin") then
		local Players = vRPC.Players(source)
		for _,Sources in pairs(Players) do
			async(function()
				TriggerClientEvent("hud:Video",Sources,Message[1])
			end)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- RENAME
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("rename",function(source)
	local Passport = vRP.Passport(source)
	if Passport and vRP.HasGroup(Passport,"Admin", 2) then
		local Keyboard = vKEYBOARD.Tertiary(source,"Passaporte","Nome","Sobrenome")
		if Keyboard then
			vRP.UpgradeNames(Keyboard[1],Keyboard[2],Keyboard[3])
			TriggerClientEvent("Notify",source,"Sucesso","Nome atualizado.","verde",5000)
			local logMsg = table.concat({
                "📝 **ALTERAÇÃO DE NOME (ADMIN)**",
                "",
                "👮 **Admin:** `" .. Passport .. "`",
                "👤 **Passaporte Alvo:** `" .. Keyboard[1] .. "`",
                "📛 **Novo Nome:** `" .. Keyboard[2] .. " " .. Keyboard[3] .. "`",
                "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y") .. " às " .. os.date("%H:%M") .. "`"
            }, "\n")

            exports["discord"]:Embed("Rename", logMsg)
        end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADDCAR
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("addcar", function(source)
    local Passport = vRP.Passport(source)
    if Passport and vRP.HasGroup(Passport, "Admin", 2) then
        local Keyboard = vKEYBOARD.Vehicle(source, "Passaporte", "Modelo", { "Permanente" }, "Adicione com Atenção.")
        if Keyboard and Keyboard[1] and Keyboard[2] and Keyboard[3] and VehicleExist(Keyboard[2]) then
            local TargetPassport = parseInt(Keyboard[1])
            local VehicleModel = string.lower(Keyboard[2]) -- normaliza

            -- Já possui? (usa o teu prepare existente)
            local owned = vRP.Query("vehicles/selectVehicles", { Passport = TargetPassport, vehicle = VehicleModel })
            if owned and owned[1] then
                TriggerClientEvent("Notify", source, "Aviso", "O passaporte <b>" .. TargetPassport .. "</b> já possui um <b>" .. VehicleName(VehicleModel) .. "</b>.", "amarelo", 5000)
                return
            end

            -- Log
            local logMsg = table.concat({
                "🚗 **VEÍCULO ADICIONADO (ADMIN)**",
                "",
                "👮 **Admin:** `" .. Passport .. "`",
                "👤 **Passaporte Alvo:** `" .. TargetPassport .. "`",
                "📦 **Modelo:** `" .. VehicleModel .. "`",
                "🛠️ **Tipo:** `" .. Keyboard[3] .. "`",
                "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y") .. " às " .. os.date("%H:%M") .. "`"
            }, "\n")
            exports["discord"]:Embed("AddCar", logMsg)

            if Keyboard[3] == "Permanente" then
                vRP.Query("vehicles/addVehicles", { Passport = TargetPassport, vehicle = VehicleModel, plate = vRP.GeneratePlate(), work = "false" })
            end

            TriggerClientEvent("Notify", source, "Sucesso", "Veículo <b>" .. VehicleName(VehicleModel) .. "</b> entregue.", "verde", 5000)
        end
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- REMCAR
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("remcar", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if not vRP.HasGroup(Passport, "Admin", 2) then
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
        return
    end

    local Keyboard = vKEYBOARD.Primary(source, "Passaporte")
    if not Keyboard or not Keyboard[1] then return end

    local OtherPassport = parseInt(Keyboard[1])
    if OtherPassport <= 0 then
        TriggerClientEvent("Notify", source, "Admin", "Passaporte <b>inválido</b>.", "vermelho", 5000)
        return
    end

    local Vehicles = {}
    local Consult = vRP.Query("vehicles/UserVehicles", { Passport = OtherPassport })
    for _, v in pairs(Consult or {}) do
        Vehicles[#Vehicles + 1] = v["vehicle"]
    end

    if #Vehicles == 0 then
        TriggerClientEvent("Notify", source, "Admin", "O jogador não possui <b>veículos</b>.", "amarelo", 5000)
        return
    end

    local pick = vKEYBOARD.Instagram(source, Vehicles)
    if not pick or not pick[1] then return end

    local chosen = pick[1]
    -- Limpa dados associados conhecidos (mods e chest do veículo)
    vRP.RemSrvData("LsCustoms:" .. OtherPassport .. ":" .. chosen)
    vRP.RemSrvData("Chest:" .. OtherPassport .. ":" .. chosen)

    -- Remove o veículo da DB
    vRP.Query("vehicles/removeVehicles", { Passport = OtherPassport, vehicle = chosen })

    local pretty = VehicleName(chosen)
    TriggerClientEvent("Notify", source, "Sucesso", "Veículo <b>" .. pretty .. "</b> removido.", "verde", 5000)

    -- 📑 Log Discord
    exports["discord"]:Embed("Admin",
        "🚗 **Comando /remcar**\n\n" ..
        "👮‍♂️ Admin: **" .. Passport .. "**\n" ..
        "🎯 Alvo: **" .. OtherPassport .. "**\n" ..
        "🗂️ Veículo (ID): **" .. chosen .. "**\n" ..
        "🏷️ Nome: **" .. pretty .. "**\n" ..
        "🗑️ Ação: **Removido da garagem**",
        source
    )
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- NITRO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("nitro", function(source, Message)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") and vRP.InsideVehicle(source) then
        local Vehicle, Network, Plate = vRPC.VehicleList(source)
        if Vehicle then
            local Networked = NetworkGetEntityFromNetworkId(Network)
            if DoesEntityExist(Networked) then
                Entity(Networked)["state"]:set("Nitro", 2000, true)
                TriggerClientEvent("Notify", source, "Admin", "Nitro <b>adicionado</b> ao veículo.", "azul", 5000)

                -- 📑 Log Discord
                exports["discord"]:Embed("Admin",
                    "🚀 **Comando /nitro**\n\n👤 Passaporte: **"..Passport.."**\n🚗 Placa: **"..Plate.."**\n⚡ Nitro: **2000**",
                    source
                )
            end
        end
    else
        TriggerClientEvent("Notify", source, "Admin", "Precisas de estar dentro de um veículo.", "vermelho", 5000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DRIFT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("drift", function(source, Message)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") and vRP.InsideVehicle(source) then
        local Vehicle, Network, Plate = vRPC.VehicleList(source)
        if Vehicle then
            local Networked = NetworkGetEntityFromNetworkId(Network)
            if DoesEntityExist(Networked) then
                Entity(Networked)["state"]:set("Drift",true,true)
                TriggerClientEvent("Notify", source, "Admin", "Modulo drift adicinado ao veiculo.", "azul", 5000)

                -- 📑 Log Discord
                exports["discord"]:Embed("Admin",
                    "🚀 **Comando /drift**\n\n👤 Passaporte: **"..Passport.."**\n🚗 Placa: **"..Plate.."**\n⚡ Drift: Ativo!",
                    source
                )
            end
        end
    else
        TriggerClientEvent("Notify", source, "Admin", "Precisas de estar dentro de um veículo.", "vermelho", 5000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- KILL
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("kill", function(source, Message)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin", 5) and Message[1] and parseInt(Message[1]) > 0 then
        local TargetPassport = parseInt(Message[1])
        local ClosestPed = vRP.Source(TargetPassport)
        if ClosestPed then
            vRPC.SetHealth(ClosestPed, 100)
            TriggerClientEvent("Notify", source, "Admin", "Jogador <b>"..TargetPassport.."</b> foi morto.", "vermelho", 5000)

            -- 📑 Log Discord
            exports["discord"]:Embed("Admin",
                "☠️ **Comando /kill**\n\n👮‍♂️ Admin: **"..Passport.."**\n🎯 Alvo: **"..TargetPassport.."**\n💀 Ação: **Morto**",
                source
            )
        else
            TriggerClientEvent("Notify", source, "Admin", "Jogador inválido ou offline.", "amarelo", 5000)
        end
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões ou ID inválido.", "vermelho", 5000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport,source)
	if Spectate[Passport] then
		local Ped = GetPlayerPed(Spectate[Passport])
		if DoesEntityExist(Ped) then
			SetEntityDistanceCullingRadius(Ped,0.0)
		end

		Spectate[Passport] = nil
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SETHTTPHANDLER
-----------------------------------------------------------------------------------------------------------------------------------------
SetHttpHandler(function(Request,Result)
	if Request.headers.Auth == "SEUTOKENAUTH" then
		if Request.path == "/boosteron" then
			Request.setDataHandler(function(Body)
				local Table = json.decode(Body)
				local Account = vRP.Discord(Table.Discord)
				if Account then
					local Consult = vRP.Query("characters/Characters",{ license = Account.license })
					for _,v in pairs(Consult) do
						vRP.SetPermission(v.id,"Booster")
					end

					SendMessageDiscord(Result,200,"Benefícios entregues: <@"..Table.discord..">")
				else
					SendMessageDiscord(Result,404,"Usuário não encontrado.")
				end
			end)
		elseif Request.path == "/boosteroff" then
			Request.setDataHandler(function(Body)
				local Table = json.decode(Body)
				local Account = vRP.Discord(Table.Discord)
				if Account then
					local Consult = vRP.Query("characters/Characters",{ license = Account.license })
					for _,v in pairs(Consult) do
						vRP.RemovePermission(v.id,"Booster")
					end

					SendMessageDiscord(Result,200,"Benefícios removidos: <@"..Table.discord..">")
				else
					SendMessageDiscord(Result,404,"Usuário não encontrado.")
				end
			end)
		else
			SendMessageDiscord(Result,404,"Comando indisponível no momento.")
		end
	else
		SendMessageDiscord(Result,400,"Falha na autenticação.")
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SENDMESSAGEDISCORD
-----------------------------------------------------------------------------------------------------------------------------------------
function SendMessageDiscord(Result,Code,Message)
	Result.writeHead(Code,{ ["Content-Type"] = "application/json" })
	Result.send(json.encode({ message = Message }))
end
----------------------------------------------------------
---- HORA
----------------------------------------------------------
RegisterCommand("hora", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin", 4) then
        local hour   = tonumber(args[1])
        local minute = tonumber(args[2]) or 0

        if hour and hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 then
            GlobalState["Hours"]   = hour
            GlobalState["Minutes"] = minute

            TriggerClientEvent("Notify", source, "Prefeitura", "Hora definida para: <b>"..hour..":"..string.format("%02d", minute).."</b>", "azul", 5000)

            -- 📑 Log Discord
            exports["discord"]:Embed("Admin",
                "⏰ **Comando /hora**\n\n👤 Passaporte: **"..Passport.."**\n🕒 Hora definida: **"..hour..":"..string.format("%02d", minute).."**",
                source
            )
        else
            TriggerClientEvent("Notify", source, "Admin", "Formato inválido. Usa: <b>/hora [0-23] [0-59]</b>", "vermelho", 5000)
        end
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissão.", "vermelho", 5000)
    end
end)

----------------------------------------------------------
---- LIMPAR CARROS
----------------------------------------------------------
local limpezaAtiva = false

RegisterCommand("limparcarros", function(source)
    local staffPass = vRP.Passport(source)
    if not staffPass then return end

    if not vRP.HasGroup(staffPass, "Admin", 4) then
        TriggerClientEvent("Notify", source, "Permissão", "Sem permissão para usar este comando.", "vermelho", 5000)
        return
    end

    if limpezaAtiva then
        TriggerClientEvent("Notify", source, "Limpeza", "Já está uma limpeza em andamento.", "amarelo", 5000)

        -- 📑 Log Discord (tentativa com limpeza já ativa)
        exports["discord"]:Embed("Admin",
            "🧹 **Comando /limparcarros**\n\n" ..
            "👮‍♂️ Admin: **"..staffPass.."**\n" ..
            "⏳ Estado: **Já existe uma limpeza em andamento**",
            source
        )
        return
    end

    limpezaAtiva = true

    -- 📑 Log Discord (início)
    exports["discord"]:Embed("Admin",
        "🧹 **Comando /limparcarros**\n\n" ..
        "👮‍♂️ Admin: **"..staffPass.."**\n" ..
        "⏱️ Contagem: **60 segundos**\n" ..
        "📝 Aviso: *Veículos sem condutor serão removidos.*",
        source
    )

    -- anúncio 60s (de 10 em 10s)
    local totalSeg = 60
    local intervalo = 10
    Citizen.CreateThread(function()
        local restantes = totalSeg
        while restantes > 0 do
            TriggerClientEvent("Notify", -1, "Prefeitura", ("🚗 <b>[LIMPEZA]</b> Veículos sem condutor serão removidos em %d segundos!"):format(restantes), "vermelho", 10000)
            Wait(intervalo * 1000)
            restantes = restantes - intervalo
        end
    end)

    SetTimeout(totalSeg * 1000, function()
        local totalNPC, totalPlayers = 0, 0

        -- helper seguro pra ler statebag (Fuel/Nitro)
        local function readState(ent)
            local fuel, nitro = 0, 0
            local ok, bag = pcall(Entity, ent)
            if ok and bag and bag.state then
                fuel  = bag.state.Fuel  or 0
                nitro = bag.state.Nitro or 0
            end
            return fuel, nitro
        end

        local function parseInt(n) return tonumber(n) or 0 end

        -- percorre todos os veículos no servidor
        for _, veh in pairs(GetAllVehicles()) do
            if DoesEntityExist(veh) then
                local driver = GetPedInVehicleSeat(veh, -1)
                local hasDriver = (driver ~= 0) and IsPedAPlayer(driver)

                if not hasDriver then
                    local plate = (GetVehicleNumberPlateText(veh) or ""):gsub("%s+$","")
                    local isPlayerVeh = false

                    -- se usas Decor no client para veículos de players
                    if DecorExistOn and DecorExistOn(veh, "Player_Vehicle") then
                        isPlayerVeh = true
                    end

                    -- se a tabela Spawn estiver disponível, é a melhor forma de identificar dono/modelo
                    local Passport, VehicleModel
                    if _G.Spawn and plate ~= "" and _G.Spawn[plate] then
                        isPlayerVeh = true
                        Passport     = _G.Spawn[plate][1]
                        VehicleModel = _G.Spawn[plate][2]
                    end

                    if isPlayerVeh and Passport and VehicleModel then
                        -- recolhe estados para guardar
                        local pedHealth = GetEntityHealth(veh)
                        local engine    = GetVehicleEngineHealth(veh)
                        local body      = GetVehicleBodyHealth(veh)
                        if parseInt(engine) <= 100 then engine = 100 end
                        if parseInt(body)   <= 100 then body   = 100 end
                        local fuel, nitro = readState(veh)

                        -- arrays básicos (se algum native não existir server-side, ficam arrays vazios)
                        local Doors, Windows, Tyres = {}, {}, {}
                        for i = 0, 5 do
                            if IsVehicleDoorDamaged then Doors[i] = IsVehicleDoorDamaged(veh, i) end
                            if IsVehicleWindowIntact then Windows[i] = IsVehicleWindowIntact(veh, i) end
                        end
                        for i = 0, 7 do
                            if GetTyreHealth then Tyres[i] = (GetTyreHealth(veh, i) ~= 1000.0) end
                        end

                        -- confirma que o veículo existe na DB e atualiza
                        local row = vRP.Query("vehicles/selectVehicles", { Passport = Passport, vehicle = VehicleModel })
                        if row and row[1] then
                            vRP.Query("vehicles/updateVehicles",{
                                Passport = Passport,
                                vehicle  = VehicleModel,
                                nitro    = parseInt(nitro),
                                engine   = parseInt(engine),
                                body     = parseInt(body),
                                health   = parseInt(pedHealth),
                                fuel     = parseInt(fuel),
                                doors    = json.encode(Doors),
                                windows  = json.encode(Windows),
                                tyres    = json.encode(Tyres)
                            })
                        end

                        -- limpa cache para permitir novo spawn
                        _G.Spawn[plate] = nil

                        -- apaga entidade (server)
                        DeleteEntity(veh)
                        totalPlayers = totalPlayers + 1
                    else
                        -- NPC / sem dono conhecido: só apaga
                        DeleteEntity(veh)
                        totalNPC = totalNPC + 1
                    end
                end
            end
        end

        TriggerClientEvent("Notify", -1, "Prefeitura",
            ("🚗 Limpeza concluída: <b>%d</b> veículos de jogadores guardados e <b>%d</b> veículos sem condutor removidos.")
            :format(totalPlayers, totalNPC),
            "vermelho", 12000)

        print(("[LimparCarros] Guardados: %d | NPC removidos: %d"):format(totalPlayers, totalNPC))
        limpezaAtiva = false

        -- 📑 Log Discord (resumo)
        exports["discord"]:Embed("Admin",
            "🧹 **/limparcarros concluído**\n\n" ..
            "👮‍♂️ Admin: **"..staffPass.."**\n" ..
            "🧾 Guardados (players): **"..totalPlayers.."**\n" ..
            "🗑️ Removidos (NPC/sem dono): **"..totalNPC.."**",
            source
        )
    end)
end)

----------------------------------------------------------
	---- FIX PERMS
----------------------------------------------------------
RegisterCommand("fixperms", function(source)
    if source == 0 then -- Apenas console pode rodar
        -- Passaporte 1 → Admin 1
        vRP.SetPermission(1, "Admin", 1)
        print("Permissão Admin nível 1 atribuída ao passaporte 1")

        -- Passaporte 2 → Admin 2
        vRP.SetPermission(2, "Admin", 2)
        print("Permissão Admin nível 2 atribuída ao passaporte 2")

        -- Passaporte 3 → Admin 1
        vRP.SetPermission(3, "Admin", 1)
        print("Permissão Admin nível 1 atribuída ao passaporte 3")
    end
end)
----------------------------------------------------------
	---- GOD SYN
----------------------------------------------------------
RegisterCommand("fgm", function(source)
    local passport = vRP.Passport(source)
    if passport and vRP.HasGroup(passport, "Admin", 1) then
        TriggerClientEvent("godsyn:toggle", source)
    else
        TriggerClientEvent("Notify", source, "vermelho", "Sem permissão.", 5000)
    end
end)
----------------------------------------------------------
	---- GOD AREA
----------------------------------------------------------
RegisterCommand("godarea", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport or not vRP.HasGroup(Passport, "Admin") then
        TriggerClientEvent("Notify", source, "negado", "Acesso negado.", 3000)
        return
    end

    local range = tonumber(args[1]) or 10
    if range <= 0 then range = 10 end

    local sourceCoords = GetEntityCoords(GetPlayerPed(source))
    local total = 0

    for _, playerSrc in pairs(GetPlayers()) do
        playerSrc = tonumber(playerSrc)
        if playerSrc then
            local ped = GetPlayerPed(playerSrc)
            local pCoords = GetEntityCoords(ped)
            if #(sourceCoords - pCoords) <= range then
                local targetPassport = vRP.Passport(playerSrc)
                if targetPassport then
                    vRP.Revive(playerSrc, 200)
                    vRP.UpgradeThirst(targetPassport, 100)
                    vRP.UpgradeHunger(targetPassport, 100)
                    vRP.DowngradeStress(targetPassport, 100)
                    TriggerClientEvent("paramedic:Reset", playerSrc)

                    local logMsg = table.concat({
                        "🛡️ **GOD MODE (ADMIN)**",
                        "",
                        "👮 **Admin:** `" .. Passport .. "`",
                        "👤 **Passaporte Alvo:** `" .. targetPassport .. "`",
                        "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y") .. " às " .. os.date("%H:%M") .. "`"
                    }, "\n")

                    exports["discord"]:Embed("God", logMsg)

                    total = total + 1
                end
            end
        end
    end

    TriggerClientEvent("Notify", source, "Sucesso", "God aplicado a "..total.." jogador(es) num raio de "..range.." metros.", "verde", 5000)
end)


----------------------------------------------------------
	---- DAR COLETE
----------------------------------------------------------

RegisterCommand("colete", function(source, args)
    local Passport = vRP.Passport(source)
    if Passport and vRP.HasGroup(Passport, "Admin") then
        local TargetPassport = tonumber(args[1])
        if TargetPassport then
            local TargetSource = vRP.Source(TargetPassport)
            if TargetSource then
                TriggerClientEvent("admin:applyArmour", TargetSource, 100)

                TriggerClientEvent("Notify", TargetSource, "Prefeitura", "Recebeste um colete da staff.", 5000)
                TriggerClientEvent("Notify", source, "SUCESSO", "Colete aplicado no passaporte "..TargetPassport..".", 5000)

                -- 📜 Log no Discord
                local logMsg = table.concat({
                    "🛡️ **COLETE (ADMIN)**",
                    "",
                    "👮 **Admin:** `" .. Passport .. "`",
                    "👤 **Passaporte Alvo:** `" .. TargetPassport .. "`",
                    "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y") .. " às " .. os.date("%H:%M") .. "`"
                }, "\n")

                exports["discord"]:Embed("God", logMsg)

            else
                TriggerClientEvent("Notify", source, "ERRO", "Passaporte offline ou inválido.", 3000)
            end
        else
            TriggerClientEvent("Notify", source, "ERRO", "Uso correto: /colete [passaporte]", 3000)
        end
    else
        TriggerClientEvent("Notify", source, "ERRO", "Acesso negado.", 3000)
    end
end)



----------------------------------------------------------
---- GODMODE
----------------------------------------------------------

RegisterCommand("godmode", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin", 4) then
        TriggerClientEvent("admin:toggleGodmode", source)
        TriggerClientEvent("Notify", source, "Admin", "Godmode <b>alternado</b>.", "azul", 5000)

        -- 📑 Log Discord
        exports["discord"]:Embed("Admin",
            "🛡️ **Comando /godmode**\n\n👤 Passaporte: **"..Passport.."**\n⚡ Estado: **Alternado**",
            source
        )
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
    end
end)

----------------------------------------------------------
	---- TAG STAFF BY SYN
----------------------------------------------------------

local playerTags = {}

RegisterCommand("tag", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end
    if not vRP.HasGroup(Passport, "Admin") then
        TriggerClientEvent("Notify", source, "Prefeitura", "Apenas administradores podem usar este comando.", "vermelho", 5000)
        return
    end

    local name = GetPlayerName(source)
    local identifiers = GetPlayerIdentifiers(source)
    local tagType = "staff"
  
    for _, id in pairs(identifiers) do
        if id == "license:fc1ad7eead6a44c1102a1b2e18ae20caffd26fb4" or
           id == "license:64e4e726d0a1431b1b4028186dc2be0c663bc69b" or
           id == "license:3a61e278f67c966704a19d070ed45aaec630b3ec" then
            tagType = id
            break
        end
    end

    if playerTags[source] then
        playerTags[source] = nil
        TriggerClientEvent('admin:removeStaffTag', -1, source)
        TriggerClientEvent("Notify", source, "Prefeitura", "Tag staff removida.", "vermelho", 5000)
    else
        playerTags[source] = { playerName = name, tagType = tagType, infoText = "" }
        TriggerClientEvent('admin:displayStaffTag', -1, source, name, tagType)
        TriggerClientEvent("Notify", source, "Prefeitura", "Tag staff ativada.", "verde", 5000)
    end


    TriggerClientEvent('admin:updateTags', -1, playerTags)
end)

RegisterCommand("info", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport then return end
    if not vRP.HasGroup(Passport, "Admin") then
        TriggerClientEvent("Notify", source, "Prefeitura", "Apenas administradores podem usar este comando.", "vermelho", 5000)
        return
    end

    local infoText = table.concat(args, " ")
    if playerTags[source] then
        playerTags[source].infoText = infoText
        TriggerClientEvent('admin:updateTags', -1, playerTags)
        TriggerClientEvent("Notify", source, "Prefeitura", "Informação personalizada definida.", "verde", 5000)
    else
        TriggerClientEvent("Notify", source, "Prefeitura", "Ativa a tag primeiro com /tag.", "vermelho", 5000)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if playerTags[src] then
        playerTags[src] = nil
        TriggerClientEvent('admin:removeStaffTag', -1, src)
        TriggerClientEvent('admin:updateTags', -1, playerTags)
    end
end)


----------------------------------------------------------
	---- REFRESH GRUPOS - ENTRAR SERVIÇO
----------------------------------------------------------

RegisterNetEvent("servico:entrar")
AddEventHandler("servico:entrar", function(src)
	local source = src or source
	local Passport = vRP.Passport(source)
	if not Passport then return end

	local entrou = false

	for groupName, data in pairs(Groups) do
		-- Verifica se o jogador tem o grupo
		if vRP.HasGroup(Passport, groupName) then
			-- Percorre os graus possíveis do grupo
			for i = 1, #data.Hierarchy or 0 do
				-- Verifica se o jogador tem o grupo exatamente nesse grau
				if vRP.HasPermission(Passport, groupName, i) then
					-- Refaz a permissão no mesmo grau
					vRP.RemovePermission(Passport, groupName)
					vRP.SetPermission(Passport, groupName, i)
					TriggerClientEvent("Notify", source, "Serviço", "<b>Entraste em serviço:</b> " .. groupName .. " (Grau " .. i .. ")", "verde", 5000)
					entrou = true
					break -- próximo grupo
				end
			end
		end
	end

	if not entrou then
		TriggerClientEvent("Notify", source, "Serviço", "<b>Não tens grupo com grau válido.</b>", "amarelo", 5000)
	end
end)


----------------------------------------------------------
	---- GETDISCORD
----------------------------------------------------------

RegisterCommand("getdiscord", function(source, args)
	local Passport = vRP.Passport(source)
	if not Passport or not vRP.HasGroup(Passport, "Admin") then
		TriggerClientEvent("Notify", source, "Erro", "Apenas staff pode usar este comando.", "vermelho", 5000)
		return
	end

	local targetPassport = parseInt(args[1])
	if targetPassport <= 0 then
		TriggerClientEvent("Notify", source, "Erro", "ID inválido.", "amarelo", 5000)
		return
	end

	local targetSource = vRP.Source(targetPassport)
	if not targetSource then
		TriggerClientEvent("Notify", source, "Erro", "Jogador offline ou não encontrado.", "amarelo", 5000)
		return
	end

	local discordId = nil

	for _, id in ipairs(GetPlayerIdentifiers(targetSource)) do
		if string.sub(id, 1, 8) == "discord:" then
			discordId = string.sub(id, 9)
			break
		end
	end

	if not discordId then
		TriggerClientEvent("Notify", source, "Erro", "Discord não encontrado.", "vermelho", 5000)
		return
	end

	local mention = "<@" .. discordId .. ">"

	-- Mostrar na consola
	print("^5[GETDISCORD]^7 Passaporte " .. targetPassport .. " → " .. mention)

	-- Copiar com o teclado
	vKEYBOARD.Copy(source, "Discord:", mention)
end)


----------------------------------------------------------
	---- WALL
----------------------------------------------------------
local wall = {}

RegisterCommand("wall", function(source)
	local Passport = vRP.Passport(source)
	if not Passport or not vRP.HasGroup(Passport, "Admin") then
		TriggerClientEvent("Notify", source, "Acesso negado", "Apenas staff autorizado.", "vermelho", 5000)
		return
	end

	if wall[source] then
		wall[source] = nil
		TriggerClientEvent("wall:toggle", source, false)
		TriggerClientEvent("Notify", source, "WALL", "Desativado", "vermelho", 5000)
	else
		wall[source] = true
		TriggerClientEvent("Notify", source, "WALL", "Ativado", "verde", 5000)
	end


	--LOG
		local Nome = vRP.FullName(Passport)
		local Ped = GetPlayerPed(source)
		local Coords = GetEntityCoords(Ped)
        local logMsg = table.concat({
            "👁‍🗨 **WALL - STAFF**",
            "",
            "⚙️ **Ação:** " .. (wall[source] and "ATIVOU 🟢" or "DESATIVOU 🔴") .. " o modo WALL",
            "👮 **Staff:** " .. Nome .. " (📜 Passaporte: `" .. Passport .. "`)",
            string.format("📍 **Posição:** `vec3(%.2f, %.2f, %.2f)`", Coords.x, Coords.y, Coords.z),
            "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y às %H:%M") .. "`"
        }, "\n")

        exports["discord"]:Embed("Wall", logMsg, source)



	-- Atualizar todos os que têm o wall ativo
	local users = {}
	for _, v in pairs(GetPlayers()) do
		local id = tonumber(v)
		local pass = vRP.Passport(id)
		if pass then
			local identity = vRP.Identity(pass)
			if identity then
				users[id] = {
					passport = pass,
					name = identity.name .. " " .. identity.name2,
					wall = wall[id] ~= nil
				}
			end
		end
	end

	for id, _ in pairs(wall) do
		TriggerClientEvent("wall:toggle", id, true, users)
	end
end)

-- Remover da lista se sair
AddEventHandler("playerDropped", function()
	local source = source
	if wall[source] then
		wall[source] = nil

		-- Atualizar restantes
		local users = {}
		for _, v in pairs(GetPlayers()) do
			local id = tonumber(v)
			local pass = vRP.Passport(id)
			if pass then
				local identity = vRP.Identity(pass)
				if identity then
					users[id] = {
						passport = pass,
						name = identity.name .. " " .. identity.name2,
						wall = wall[id] ~= nil
					}
				end
			end
		end

		for id, _ in pairs(wall) do
			TriggerClientEvent("wall:toggle", id, true, users)
		end
	end
end)

----------------------------------------------------------
	---- PRISÃOADM
----------------------------------------------------------

function SendStaffMessage(Mensagem)
	local Texto = Mensagem:gsub("[<>]", "") -- Remove tags HTML
	TriggerClientEvent("chat:ClientMessage", -1, "STAFF", Texto, "STAFF")
end

RegisterCommand("prisaoadm", function(source, args)
	local Passport = vRP.Passport(source)
	if not Passport or not vRP.HasGroup(Passport, "Admin") then
		TriggerClientEvent("Notify", source, "Erro", "Apenas staff autorizado.", "vermelho", 5000)
		return
	end

	local OtherPassport = parseInt(args[1])
	if OtherPassport <= 0 then
		TriggerClientEvent("Notify", source, "Erro", "Uso correto: /prisaoadm [passaporte]", "amarelo", 5000)
		return
	end

	local Keyboard = vKEYBOARD.Tertiary(source, "Tempo (meses)", "Motivo da prisão", "Multa (opcional)")
	if not Keyboard or not Keyboard[1] or not Keyboard[2] then
		TriggerClientEvent("Notify", source, "Erro", "Preenchimento inválido ou cancelado.", "vermelho", 5000)
		return
	end

	local Tempo = parseInt(Keyboard[1])
	local Motivo = Keyboard[2]
	local Multa = parseInt(Keyboard[3]) or 0

	if Tempo <= 0 or Motivo == "" then
		TriggerClientEvent("Notify", source, "Erro", "Tempo ou motivo inválido.", "vermelho", 5000)
		return
	end

	local OtherSource = vRP.Source(OtherPassport)
	local NomeStaff = vRP.FullName(Passport)
	local NomeAlvo = vRP.FullName(OtherPassport)

	-- Aplicar prisão
	vRP.InsertPrison(OtherPassport, Tempo)
	vRP.ClearInventory(OtherPassport)

	-- Aplicar multa (se houver)
	if Multa > 0 then
		exports["bank"]:AddFines(OtherPassport, Passport, Multa, Motivo)
	end

	-- Notificar jogador preso
	if OtherSource then
		Player(OtherSource)["state"]["Prison"] = true
		TriggerClientEvent("Notify", OtherSource, "Boolingbroke", "Foste preso por <b>" .. Tempo .. " meses</b>.<br>Motivo: <b>" .. Motivo .. "</b>", "amarelo", 10000)
	end

	-- Notificar staff
	TriggerClientEvent("Notify", source, "Sucesso", "Prisão aplicada com sucesso!", "verde", 5000)

	-- Anunciar no chat geral
	TriggerClientEvent("chat:ClientMessage", -1, "STAFF", NomeAlvo .. " foi preso por " .. Motivo .. " por " .. Tempo .. " meses por " .. NomeStaff .. ".", "STAFF")

	-- Log estilo Airport
	local coords = vRP.GetEntityCoords(source)
	local coordText = "X: " .. string.format("%.2f", coords.x) .. " | Y: " .. string.format("%.2f", coords.y) .. " | Z: " .. string.format("%.2f", coords.z)
	local log = "**🚨 [STAFF]:** " .. NomeStaff .. " (Passaporte: " .. Passport .. ")\n" ..
				"**👤 [ALVO]:** " .. NomeAlvo .. " (Passaporte: " .. OtherPassport .. ")\n" ..
				"**⏳ [TEMPO]:** " .. Tempo .. " meses\n" ..
				"**📄 [MOTIVO]:** " .. Motivo .. "\n" ..
				"**💰 [MULTA]:** " .. (Multa > 0 and ("$" .. Multa) or "Sem multa") .. "\n" ..
				"**🗓️ [COORDS]:** " .. coordText .. "\n" ..
				"**⏰ [DATA & HORA]:** " .. os.date("%d/%m/%Y") .. " às " .. os.date("%H:%M")

	exports["discord"]:Embed("Prisoes", log, source)
end)

----------------------------------------------------------
	---- TIRA PRISÃO
----------------------------------------------------------

RegisterCommand("rprisao", function(source, args)
	local Passport = vRP.Passport(source)
	if not Passport or not vRP.HasGroup(Passport, "Admin") then
		TriggerClientEvent("Notify", source, "Erro", "Apenas staff autorizado.", "vermelho", 5000)
		return
	end

	local OtherPassport = parseInt(args[1])
	if OtherPassport <= 0 then
		TriggerClientEvent("Notify", source, "Erro", "Uso correto: /rprisao [passaporte]", "amarelo", 5000)
		return
	end

	local OtherSource = vRP.Source(OtherPassport)
	local NomeStaff = vRP.FullName(Passport)
	local NomeAlvo = vRP.FullName(OtherPassport)

	-- Remover prisão
	vRP.InsertPrison(OtherPassport, 0)

	if OtherSource then
		Player(OtherSource)["state"]["Prison"] = false
		vRP.Teleport(OtherSource, 1850.93, 2586.23, 45.66, 274.97)
		TriggerClientEvent("Notify", OtherSource, "Boolingbroke", "Foste <b>libertado</b> pela administração.", "verde", 8000)
	else
		TriggerClientEvent("Notify", source, "Aviso", "Jogador offline. Prisão removida da base de dados.", "amarelo", 5000)
	end

	TriggerClientEvent("Notify", source, "Sucesso", "Prisão removida com sucesso!", "verde", 5000)

        -- Log estilo Airport (formatado bonito)
        local coords = vRP.GetEntityCoords(source)
        local coordText = string.format("📍 `X: %.2f | Y: %.2f | Z: %.2f`", coords.x, coords.y, coords.z)

        local logMsg = table.concat({
            "🚔 **AÇÃO STAFF: PRISÃO REMOVIDA**",
            "",
            "👮 **Staff:** " .. NomeStaff .. " (📜 Passaporte: `" .. Passport .. "`)",
            "👤 **Alvo:** " .. NomeAlvo .. " (📜 Passaporte: `" .. OtherPassport .. "`)",
            "⚠️ **Ação:** Prisão removida manualmente",
            coordText,
            "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y") .. " às " .. os.date("%H:%M") .. "`"
        }, "\n")

        exports["discord"]:Embed("Prisoes", logMsg, source)

end)


----------------------------------------------------------
	---- ALGEMAR
----------------------------------------------------------

RegisterCommand("algemar", function(source, args)
	local Passport = vRP.Passport(source)
	if not Passport or not vRP.HasGroup(Passport, "Admin") then
		TriggerClientEvent("Notify", source, "Erro", "Sem permissão.", "vermelho", 5000)
		return
	end

	local OtherPassport = parseInt(args[1])
	if not OtherPassport or OtherPassport <= 0 then
		TriggerClientEvent("Notify", source, "Erro", "Uso: /algemar [passaporte]", "amarelo", 5000)
		return
	end

	local OtherSource = vRP.Source(OtherPassport)
	if not OtherSource then
		TriggerClientEvent("Notify", source, "Erro", "Jogador offline ou inválido.", "vermelho", 5000)
		return
	end

	-- estado atual no SERVER
	local current = Player(OtherSource)["state"]["Handcuff"] == true
	local setTo = not current

	-- aplica estado no SERVER (fonte da verdade)
	Player(OtherSource)["state"]["Handcuff"] = setTo
	Player(OtherSource)["state"]["Commands"] = setTo

	if setTo then
		-- algemar
		TriggerClientEvent("inventory:Close", OtherSource)
		TriggerClientEvent("radio:RadioClean", OtherSource)
		TriggerClientEvent("sounds:Private", source, "cuff", 0.5)
		TriggerClientEvent("sounds:Private", OtherSource, "cuff", 0.5)
	else
		-- desalgemar
		TriggerClientEvent("sounds:Private", source, "uncuff", 0.5)
		TriggerClientEvent("sounds:Private", OtherSource, "uncuff", 0.5)
		-- limpa tasks/anims pendentes (igual ao item)
		vRPC.Destroy(OtherSource)
		vRPC.Destroy(source)
	end

	-- agora sincroniza o CLIENT explicitamente (evita toggle cego)
	-- no client, implementa "admin:SetHandcuff(bool)" para aplicar/limpar restrições visuais
	TriggerClientEvent("admin:SetHandcuff", OtherSource, setTo)

        local NomeStaff = vRP.FullName(Passport)
        local NomeAlvo  = vRP.FullName(OtherPassport)
        local EstadoTexto = setTo and "Algemado" or "Desalgemado"

        local logMsg = table.concat({
            "🔗 **AÇÃO STAFF: ALGEMAS**",
            "",
            "⚠️ **Ação:** `" .. EstadoTexto .. "`",
            "👮 **Staff:** " .. NomeStaff .. " (📜 Passaporte: `" .. Passport .. "`)",
            "👤 **Alvo:** " .. NomeAlvo .. " (📜 Passaporte: `" .. OtherPassport .. "`)",
            "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y") .. " às " .. os.date("%H:%M") .. "`"
        }, "\n")

        exports["discord"]:Embed("Algemar", logMsg, source)


	TriggerClientEvent("Notify", source, "Algemas", EstadoTexto .. " <b>" .. NomeAlvo .. "</b>.", "amarelo", 5000)
end)



----------------------------------------------------------
---- CONFIG GRUPOS STATUS
----------------------------------------------------------
local GrupoConfig = {
    Policia       = { "LSPD", "SWAT", "FIB" },
    Medico        = { "Paramedico" },
    Staff         = { "Admin" },
    Mecanico      = { "Mechanic", "AutoExotic", "LSCustoms", "Bennys" },
    Restaurantes  = { "BurgerShot", "Atom", "Hornys" },
    Ammunation    = { "AmmunationSul", "AmmunationNorte" }
}

----------------------------------------------------------
---- COMANDO STATUS
----------------------------------------------------------
RegisterCommand("status", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    local Total, Policia, Medico, Mecanico, Staff, Restaurante, Ammunation = 0,0,0,0,0,0,0

    local Players = vRP.Players()
    for OtherPassport, _ in pairs(Players) do
        Total += 1

        for _, g in pairs(GrupoConfig.Policia) do
            if vRP.HasGroup(OtherPassport, g) then Policia += 1 break end
        end

        for _, g in pairs(GrupoConfig.Staff) do
            if vRP.HasGroup(OtherPassport, g) then Staff += 1 break end
        end

        for _, g in pairs(GrupoConfig.Medico) do
            if vRP.HasGroup(OtherPassport, g) then Medico += 1 break end
        end

        for _, g in pairs(GrupoConfig.Mecanico) do
            if vRP.HasGroup(OtherPassport, g) then Mecanico += 1 break end
        end

        for _, g in pairs(GrupoConfig.Restaurantes or {}) do
            if vRP.HasGroup(OtherPassport, g) then Restaurante += 1 break end
        end

        for _, g in pairs(GrupoConfig.Ammunation or {}) do
            if vRP.HasGroup(OtherPassport, g) then Ammunation += 1 break end
        end
    end

    local Message =
        "👥 <b>Jogadores conectados:</b> " .. Total .. "<br>" ..
        "🛡 <b>Staff:</b> " .. Staff .. "<br>" ..
        "👮‍♂️ <b>Polícias:</b> " .. Policia .. "<br>" ..
        "🚑 <b>Emergência:</b> " .. Medico .. "<br>" ..
        "🛠️ <b>Mecânicos:</b> " .. Mecanico .. "<br>" ..
        "🍴 <b>Restaurantes:</b> " .. Restaurante .. "<br>" ..
        "🔫 <b>Ammunation:</b> " .. Ammunation

    TriggerClientEvent("Notify", source, "Status", Message, "verde", 10000)
end)


---- DAR ITEMS A OUTROS

RegisterCommand("daritem", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport or not vRP.HasGroup(Passport, "Admin", 5) then return end

    local tipo = args[1] and args[1]:lower()
    if not tipo then
        TriggerClientEvent("Notify", source, "Aviso", "Uso: /daritem [jogador|todos|area]", "amarelo", 5000)
        return
    end

    if tipo == "jogador" then
        local Keyboard = vKEYBOARD.Tertiary(source, "Passaporte", "Item", "Quantidade")
        if Keyboard then
            local OtherPassport = parseInt(Keyboard[1])
            local Item = Keyboard[2]
            local Amount = parseInt(Keyboard[3])

            -- 🔒 bloqueio por item
            if not canGiveItem(Passport, Item) then
                denyItemGive(source, ItemMinAdmin[string.lower(Item)])
                return
            end

            if vRP.Source(OtherPassport) then
                vRP.GenerateItem(OtherPassport, Item, Amount, true)
                TriggerClientEvent("Notify", source, "Sucesso", "Item entregue ao jogador online.", "verde", 5000)
            else
                local Selected = GenerateString("DDLLDDLL")
                local Consult = vRP.GetSrvData("Offline:" .. OtherPassport, true)
                repeat Selected = GenerateString("DDLLDDLL") until not Consult[Selected]
                Consult[Selected] = { ["Item"] = Item, ["Amount"] = Amount }
                vRP.SetSrvData("Offline:" .. OtherPassport, Consult, true)
                TriggerClientEvent("Notify", source, "Sucesso", "Item adicionado à entrega offline.", "verde", 5000)
            end

            local logMsg = table.concat({
                "🎁 **DAR ITEM (ADMIN)**",
                "",
                "👮 **Admin:** `" .. Passport .. "`",
                "👤 **Entregue a:** `" .. OtherPassport .. "`",
                "📦 **Item:** `" .. Item .. "`",
                "🔢 **Quantidade:** `" .. Amount .. "x`",
                "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y %H:%M") .. "`"
            }, "\n")
            exports["discord"]:Embed("Item", logMsg)
        end

    elseif tipo == "todos" then
        local Keyboard = vKEYBOARD.Secondary(source, "Item", "Quantidade")
        if Keyboard then
            local Item = Keyboard[1]
            local Amount = parseInt(Keyboard[2])

            -- 🔒 bloqueio por item
            if not canGiveItem(Passport, Item) then
                denyItemGive(source, ItemMinAdmin[string.lower(Item)])
                return
            end

            local entregues = 0
            for OtherPassport, _ in pairs(vRP.Players()) do
                vRP.GenerateItem(OtherPassport, Item, Amount, true)
                entregues = entregues + 1
            end

            TriggerClientEvent("Notify", source, "Sucesso", "Item entregue a " .. entregues .. " jogador(es) online.", "verde", 5000)
            local logMsg = table.concat({
                "🎁 **DAR ITEM (ADMIN)**",
                "",
                "👮 **Admin:** `" .. Passport .. "`",
                "👥 **Entregue a:** **TODOS** (`" .. entregues .. " jogadores`)",
                "📦 **Item:** `" .. Item .. "`",
                "🔢 **Quantidade:** `" .. Amount .. "x`",
                "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y %H:%M") .. "`"
            }, "\n")
            exports["discord"]:Embed("Item", logMsg)
        end

    elseif tipo == "area" then
        local Keyboard = vKEYBOARD.Tertiary(source, "Item", "Quantidade", "Distância")
        if Keyboard then
            local Item = Keyboard[1]
            local Amount = parseInt(Keyboard[2])
            local Distance = parseInt(Keyboard[3])
            local Coords = vRP.GetEntityCoords(source)
            local entregues = 0

            -- 🔒 bloqueio por item
            if not canGiveItem(Passport, Item) then
                denyItemGive(source, ItemMinAdmin[string.lower(Item)])
                return
            end

            for _, OtherSource in ipairs(GetPlayers()) do
                local OtherSource = parseInt(OtherSource)
                local OtherPassport = vRP.Passport(OtherSource)
                local OtherCoords = vRP.GetEntityCoords(OtherSource)
                if OtherCoords and OtherPassport and #(Coords - OtherCoords) <= Distance then
                    vRP.GenerateItem(OtherPassport, Item, Amount, true)
                    entregues = entregues + 1
                end
            end

            TriggerClientEvent("Notify", source, "Sucesso", "Item entregue a " .. entregues .. " jogador(es) na área.", "verde", 5000)
            local logMsg = table.concat({
                "🎁 **DAR ITEM (ÁREA)**",
                "",
                "👮 **Admin:** `" .. Passport .. "`",
                "📍 **Entregue a:** **ÁREA** (`" .. entregues .. " jogadores`)",
                "📦 **Item:** `" .. Item .. "`",
                "🔢 **Quantidade:** `" .. Amount .. "x`",
                "📏 **Distância:** `" .. Distance .. "m`",
                "🗓️ **Data & Hora:** `" .. os.date("%d/%m/%Y %H:%M") .. "`"
            }, "\n")
            exports["discord"]:Embed("Item", logMsg)
        end

    else
        TriggerClientEvent("Notify", source, "Aviso", "Tipo inválido. Use: jogador, todos ou area.", "amarelo", 5000)
    end
end)


------ SAIRTRABALHO

RegisterNetEvent("admin:ExitAllJobs")
AddEventHandler("admin:ExitAllJobs", function()
    local src = source
    if not src then return end

    -- Chama os eventos CLIENT que já existem nos teus jobs:
TriggerClientEvent("bus:ForceEndService",        src)
TriggerClientEvent("taxi:ForceEndService",       src)
TriggerClientEvent("mineracao:ForceEndService",  src)
TriggerClientEvent("washing:ForceEndService", src)
TriggerClientEvent("routes:ForceFinish", src)
TriggerClientEvent("lumberman:ForceEndService", src)
TriggerClientEvent("tractor:ForceLeave", src)
TriggerClientEvent("trucker:ClientForceQuit", src)


    TriggerClientEvent("Notify", src, "Serviço", "Saíste de todos os serviços ativos.", "amarelo", 5000)
end)

RegisterCommand("sairtrabalho", function(source)
    if source > 0 then
        exitAllJobs(source)
    end
end)


-------- GUARDARCOLETE


local PendingArmour = {}

local function newToken(src)
	return tostring(src).."-"..tostring(math.random(100000,999999)).."-"..tostring(os.time())
end

-- /gcolete [passaporte]  -> se não passar, guarda do próprio admin
-- SERVER-SIDE (admin/server-side/core.lua)

RegisterCommand("gcolete", function(source)
    local Passport = vRP.Passport(source)
    if not Passport or not vRP.HasGroup(Passport, "Admin") then
        TriggerClientEvent("Notify", source, "ERRO", "Acesso negado.", 3000)
        return
    end

    -- só o próprio
    local token = newToken(source)
    PendingArmour[token] = {
        adminSource    = source,
        targetSource   = source,
        targetPassport = Passport
    }

    TriggerClientEvent("admin:checkArmourForSave", source, token)

    -- timeout de segurança
    SetTimeout(5000, function()
        if PendingArmour[token] then
            PendingArmour[token] = nil
            TriggerClientEvent("Notify", source, "ERRO", "Sem resposta do cliente.", 3000)
        end
    end)
end)

RegisterNetEvent("admin:checkArmourForSave:response")
AddEventHandler("admin:checkArmourForSave:response", function(token, armour)
    local req = PendingArmour[token]
    if not req then return end
    PendingArmour[token] = nil

    local src            = req.targetSource
    local targetPassport = req.targetPassport
    armour = tonumber(armour) or 0

    if armour >= 100 then
        -- tenta gerar o item; se tua GenerateItem não retorna bool, tratamos nil como sucesso
        local ok = vRP.GenerateItem(targetPassport, "colete", 1, false)
        ok = (ok ~= false)

        if ok then
            -- toca animação e remove armor/visual no client
            TriggerClientEvent("admin:removeArmour", src, true) -- true = tocar animação
            TriggerClientEvent("Notify", src, "Inventário", "Guardaste o <b>colete</b>.", 5000)
        else
            TriggerClientEvent("Notify", src, "ERRO", "Sem espaço no inventário para guardar o colete.", 4000)
        end
    else
        TriggerClientEvent("Notify", src, "ERRO", "O colete precisa estar a <b>100%</b> para guardar.", 4000)
    end
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- COMANDOS LIMPAR PEDS / OBJETOS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("limparpeds", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") then
        local tipo = (args[1] or "area"):lower()

        if tipo == "todos" then
            TriggerClientEvent("staff:ClearPeds", -1, "todos")
            TriggerClientEvent("Notify", source, "Admin", "Todos os <b>peds</b> foram removidos.", "verde", 5000)

            -- 📑 Log Discord
            exports["discord"]:Embed("Admin",
                "🧹 **Comando /limparpeds**\n\n👤 Passaporte: **"..Passport.."**\n🌍 Alcance: **Todos**",
                source
            )
        else
            TriggerClientEvent("staff:ClearPeds", source, "area")
            TriggerClientEvent("Notify", source, "Admin", "Peds <b>próximos</b> foram removidos.", "verde", 5000)

            -- 📑 Log Discord
            exports["discord"]:Embed("Admin",
                "🧹 **Comando /limparpeds**\n\n👤 Passaporte: **"..Passport.."**\n📍 Alcance: **Área**",
                source
            )
        end
    end
end)

RegisterCommand("limparobj", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasGroup(Passport, "Admin") then
        local tipo = (args[1] or "area"):lower()

        if tipo == "todos" then
            TriggerClientEvent("staff:ClearObjects", -1, "todos")
            TriggerClientEvent("Notify", source, "Admin", "Todos os <b>objetos</b> foram removidos.", "verde", 5000)

            -- 📑 Log Discord
            exports["discord"]:Embed("Admin",
                "🧹 **Comando /limparobj**\n\n👤 Passaporte: **"..Passport.."**\n🌍 Alcance: **Todos**",
                source
            )
        else
            TriggerClientEvent("staff:ClearObjects", source, "area")
            TriggerClientEvent("Notify", source, "Admin", "Objetos <b>próximos</b> foram removidos.", "verde", 5000)

            -- 📑 Log Discord
            exports["discord"]:Embed("Admin",
                "🧹 **Comando /limparobj**\n\n👤 Passaporte: **"..Passport.."**\n📍 Alcance: **Área**",
                source
            )
        end
    end
end)

---------------------------------------------------------------------
-- Helpers / Estado
---------------------------------------------------------------------
local function parseInt(v) local n=tonumber(v); return n and math.floor(n) or nil end
local function online(src) return src and GetPlayerPing(src) and GetPlayerPing(src) > 0 end

local function getClothesFromDB(passport)
    local rows = vRP.Query("playerdata/GetData",{ Passport = passport, Name = "Clothings" })
    if rows and rows[1] and rows[1].Information then
        local ok, data = pcall(json.decode, rows[1].Information)
        if ok and type(data)=="table" then return data end
    end
    return nil
end

-- comparação de modelo (sexo)
local HASH_MALE   = GetHashKey("mp_m_freemode_01")
local HASH_FEMALE = GetHashKey("mp_f_freemode_01")
local function sameSex(a,b)
    if not a or not b then return false end
    return (a==HASH_MALE and b==HASH_MALE) or (a==HASH_FEMALE and b==HASH_FEMALE)
end

-- contexto de verificações
local pendingSet  = {} -- [staffSrc] = { targetPass=..., staffModel=nil, targetModel=nil }
local pendingCopy = {} -- [staffSrc] = { targetSrc=..., staffModel=nil, targetModel=nil, clothes=nil }

---------------------------------------------------------------------
-- NET: modelo do ped (client → server)
---------------------------------------------------------------------
RegisterNetEvent("skinshop:ReturnModel", function(staffSrc, who, modelHash)
    if not staffSrc or not online(staffSrc) then return end

    -- fluxo SET (staff -> target)
    if pendingSet[staffSrc] then
        local data = pendingSet[staffSrc]
        if who == "staff"  then data.staffModel  = modelHash end
        if who == "target" then data.targetModel = modelHash end

        if data.staffModel and data.targetModel then
            if not sameSex(data.staffModel, data.targetModel) then
                TriggerClientEvent("Notify", staffSrc, "Aviso", "Modelos diferentes (sexo oposto). Operação bloqueada.", "vermelho", 7000)
                pendingSet[staffSrc] = nil
                return
            end
            -- modelos compatíveis → pede roupa ao vivo do staff e aplica/grava no target
            TriggerClientEvent("skinshop:RequestCustomization", staffSrc, staffSrc, "SET_LIVE_TO_TARGET", tostring(data.targetPass))
            TriggerClientEvent("Notify", staffSrc, "Aguarde", "Modelos compatíveis. A obter a tua roupa (ao vivo)...", "amarelo", 5000)
        end
        return
    end

    -- fluxo COPY (alvo -> staff)
    if pendingCopy[staffSrc] then
        local data = pendingCopy[staffSrc]
        if who == "staff"  then data.staffModel  = modelHash end
        if who == "target" then data.targetModel = modelHash end

        if data.staffModel and data.targetModel then
            if not sameSex(data.staffModel, data.targetModel) then
                TriggerClientEvent("Notify", staffSrc, "Aviso", "Modelos diferentes (sexo oposto). Operação bloqueada.", "vermelho", 7000)
                pendingCopy[staffSrc] = nil
                return
            end
            -- modelos compatíveis → aplica no staff (sem gravar)
            TriggerClientEvent("skinshop:Apply", staffSrc, data.clothes, true)
            TriggerClientEvent("Notify", staffSrc, "Sucesso", "Roupa vestida em ti.", "verde", 5000)
            if exports["discord"] then
                local staffPassport = vRP.Passport(staffSrc) or "N/A"
                local staffName = vRP.FullName(staffPassport) or ("Passaporte "..staffPassport)
                local dataHora = os.date("%d/%m/%Y %H:%M")

                local logMsg = table.concat({
                    "🧥 **COPYPRESET (STAFF)**",
                    "",
                    "👮 **Staff:** " .. staffName .. " (📜 Passaporte: `" .. staffPassport .. "` | 🆔 Src: `" .. staffSrc .. "`)",
                    "🧬 **Modelos:** ✅ Compatíveis (`" .. tostring(data.staffModel) .. "` → `" .. tostring(data.targetModel) .. "`)",
                    "👗 **Ação:** Roupa aplicada no staff (sem gravar)",
                    "🗓️ **Data & Hora:** `" .. dataHora .. "`"
                }, "\n")

    exports["discord"]:Embed("Presets", logMsg, staffSrc)
end
            pendingCopy[staffSrc] = nil
        end
    end
end)

---------------------------------------------------------------------
-- NET: roupa ao vivo do staff (client → server)
---------------------------------------------------------------------
RegisterNetEvent("skinshop:ReturnCustomization", function(requesterSrc, clothes, tag, targetPassport)
    if not requesterSrc or not online(requesterSrc) then return end
    local staffPassport = vRP.Passport(requesterSrc)
    if not staffPassport or not vRP.HasGroup(staffPassport,"Admin") then return end

    if tag == "SET_LIVE_TO_TARGET" then
        if type(clothes) ~= "table" then
            TriggerClientEvent("Notify", requesterSrc, "Aviso", "Não consegui ler a tua roupa (live).", "vermelho", 6000)
            pendingSet[requesterSrc] = nil
            return
        end

        local tgtPass = tonumber(targetPassport or "")
        if not tgtPass then
            TriggerClientEvent("Notify", requesterSrc, "Aviso", "Passaporte alvo inválido.", "vermelho", 5000)
            pendingSet[requesterSrc] = nil
            return
        end

        local tgtSrc = vRP.Source(tgtPass)
        if not online(tgtSrc) then
            TriggerClientEvent("Notify", requesterSrc, "Aviso", "Alvo offline.", "vermelho", 5000)
            pendingSet[requesterSrc] = nil
            return
        end

        -- aplica NO ALVO e GRAVA (Save=false)
        TriggerClientEvent("skinshop:Apply", tgtSrc, clothes, false)
        TriggerClientEvent("Notify", requesterSrc, "Sucesso", "A tua roupa foi aplicada no Passaporte "..tgtPass.." e gravada.", "verde", 5000)

        if exports["discord"] then
            local staffName = vRP.FullName(staffPassport) or ("Passaporte "..staffPassport)
            local dataHora = os.date("%d/%m/%Y %H:%M")

            local logMsg = table.concat({
                "🧥 **SETPRESET (STAFF)**",
                "",
                "👮 **Staff:** " .. staffName .. " (📜 Passaporte: `" .. staffPassport .. "` | 🆔 Src: `" .. requesterSrc .. "`)",
                "👤 **Alvo:** `" .. tgtPass .. "` (🆔 Src: `" .. tgtSrc .. "`)",
                "🎯 **Ação:** Aplicou (LIVE) a própria roupa no alvo",
                "🗓️ **Data & Hora:** `" .. dataHora .. "`"
            }, "\n")

            exports["discord"]:Embed("Presets", logMsg, requesterSrc)
        end


        pendingSet[requesterSrc] = nil

    elseif tag == "SET_FROM_STAFF_FALLBACK" then
        -- mantido se quiseres noutros fluxos
        if type(clothes) ~= "table" then
            TriggerClientEvent("Notify", requesterSrc, "Aviso", "Falha no fallback.", "vermelho", 6000)
            return
        end
        local tgtPass = tonumber(targetPassport or "")
        local tgtSrc = vRP.Source(tgtPass)
        if not online(tgtSrc) then
            TriggerClientEvent("Notify", requesterSrc, "Aviso", "Alvo offline.", "vermelho", 5000)
            return
        end
        TriggerClientEvent("skinshop:Apply", tgtSrc, clothes, false)
        TriggerClientEvent("Notify", requesterSrc, "Sucesso", "A tua roupa (fallback) foi aplicada e gravada.", "verde", 5000)
        if exports["discord"] then
            local staffName = vRP.FullName(staffPassport) or ("Passaporte "..staffPassport)
            local dataHora = os.date("%d/%m/%Y %H:%M")

            local logMsg = table.concat({
                "🧥 **SETPRESET (FALLBACK - STAFF)**",
                "",
                "👮 **Staff:** " .. staffName .. " (📜 Passaporte: `" .. staffPassport .. "` | 🆔 Src: `" .. requesterSrc .. "`)",
                "👤 **Alvo:** `" .. tgtPass .. "` (🆔 Src: `" .. tgtSrc .. "`)",
                "🎯 **Ação:** Aplicou (fallback) a própria roupa no alvo",
                "🗓️ **Data & Hora:** `" .. dataHora .. "`"
            }, "\n")

            exports["discord"]:Embed("Presets", logMsg, requesterSrc)
        end
    end
end)

---------------------------------------------------------------------
-- /copypreset <Passaporte>
-- Veste EM TI a roupa da DB do alvo. Se alvo online, bloqueia sexo oposto.
---------------------------------------------------------------------
RegisterCommand("copypreset", function(source, args)
    local myPass = vRP.Passport(source)
    if not myPass or not vRP.HasGroup(myPass,"Admin") then
        TriggerClientEvent("Notify", source, "Aviso", "Acesso negado.", "vermelho", 5000)
        return
    end

    local targetPass = parseInt(args[1])
    if not targetPass then
        TriggerClientEvent("Notify", source, "Aviso", "Uso: /copypreset <Passaporte>", "amarelo", 6000)
        return
    end

    local clothes = getClothesFromDB(targetPass)
    if not clothes then
        TriggerClientEvent("Notify", source, "Aviso", "Sem roupa gravada na DB para o passaporte "..targetPass..".", "vermelho", 6000)
        return
    end

    local targetSrc = vRP.Source(targetPass)
    if online(targetSrc) then
        -- validar sexo quando conseguimos saber os 2 modelos
        pendingCopy[source] = { targetSrc = targetSrc, staffModel = nil, targetModel = nil, clothes = clothes }
        TriggerClientEvent("skinshop:RequestModel", source,  source, "staff")
        TriggerClientEvent("skinshop:RequestModel", targetSrc, source,  "target")
        TriggerClientEvent("Notify", source, "Aguarde", "A verificar compatibilidade de modelo...", "amarelo", 5000)
        return
    end

    -- alvo offline → não dá para verificar sexo → aplica em ti (sem gravar)
    TriggerClientEvent("skinshop:Apply", source, clothes, true)
    TriggerClientEvent("Notify", source, "Sucesso", "Roupa (offline) do passaporte "..targetPass.." vestida em ti.", "verde", 5000)
        if exports["discord"] then
            local staffName = vRP.FullName(myPass) or ("Passaporte "..myPass)
            local dataHora = os.date("%d/%m/%Y %H:%M")

            local logMsg = table.concat({
                "🧥 **COPYPRESET (OFFLINE - STAFF)**",
                "",
                "👮 **Staff:** " .. staffName .. " (📜 Passaporte: `" .. myPass .. "` | 🆔 Src: `" .. source .. "`)",
                "👤 **Alvo Offline:** `" .. targetPass .. "`",
                "🎯 **Ação:** Vestiu roupa (offline) do alvo",
                "🗓️ **Data & Hora:** `" .. dataHora .. "`"
            }, "\n")

            exports["discord"]:Embed("Presets", logMsg, source)
        end
end)

---------------------------------------------------------------------
-- /setpreset <Passaporte>
-- Usa SEMPRE a tua roupa AO VIVO e GRAVA no alvo. Bloqueia sexo oposto.
---------------------------------------------------------------------
RegisterCommand("setpreset", function(source, args)
    local myPass = vRP.Passport(source)
    if not myPass or not vRP.HasGroup(myPass,"Admin") then
        TriggerClientEvent("Notify", source, "Aviso", "Acesso negado.", "vermelho", 5000)
        return
    end

    local targetPass = tonumber(args[1] or "")
    if not targetPass then
        TriggerClientEvent("Notify", source, "Aviso", "Uso: /setpreset <Passaporte>", "amarelo", 6000)
        return
    end

    local tgtSrc = vRP.Source(targetPass)
    if not online(tgtSrc) then
        TriggerClientEvent("Notify", source, "Aviso", "Jogador offline (passaporte "..targetPass..").", "vermelho", 6000)
        return
    end

    -- guardar contexto e pedir modelos
    pendingSet[source] = { targetPass = targetPass, staffModel = nil, targetModel = nil }
    TriggerClientEvent("skinshop:RequestModel", source,  source, "staff")
    TriggerClientEvent("skinshop:RequestModel", tgtSrc,  source,  "target")
    TriggerClientEvent("Notify", source, "Aguarde", "A verificar compatibilidade de modelo...", "amarelo", 5000)
end)


local vRPC = vRPC or Tunnel.getInterface("vRP")
lastCroupa   = lastCroupa   or {}    -- [source] = os.time()
pendingCroupa = pendingCroupa or {}  -- [reqSrc] = { targetSrc=..., reqModel=nil, tgtModel=nil }

RegisterCommand("croupa", function(source)
    local now = os.time()
    if lastCroupa[source] and (now - lastCroupa[source]) < 10 then
        local left = 10 - (now - lastCroupa[source])
        TriggerClientEvent("Notify", source, "Aviso", "Aguarde "..left.."s para usar novamente.", "amarelo", 5000)
        return
    end
    lastCroupa[source] = now

    local reqPass = vRP.Passport(source)
    if not reqPass then return end

    -- encontra jogador mais próximo (usa o teu vRPC.ClosestPed)
    local targetSrc
    if vRPC and vRPC.ClosestPed then
        targetSrc = vRPC.ClosestPed(source)
    end

    if not targetSrc or not online(targetSrc) or targetSrc == source then
        TriggerClientEvent("Notify", source, "Aviso", "Nenhum jogador próximo para pedir.", "vermelho", 5000)
        return
    end

    -- pedido de autorização (15s)
    local accepted = false
    if vRP.Request then
        accepted = vRP.Request(targetSrc,
            "Copiar Roupa",
            ("O Passaporte %d quer copiar a tua roupa. Aceitas?"):format(reqPass),
            15000)
    end

    if not accepted then
        TriggerClientEvent("Notify", source, "Aviso", "Pedido recusado ou expirado.", "amarelo", 5000)
        return
    end

    -- guarda contexto e verifica compatibilidade de modelo
    pendingCroupa[source] = { targetSrc = targetSrc, reqModel = nil, tgtModel = nil }
    TriggerClientEvent("skinshop:RequestModel", source,    source, "req")     -- modelo do requerente
    TriggerClientEvent("skinshop:RequestModel", targetSrc, source,  "target") -- modelo do alvo

    TriggerClientEvent("Notify", source, "Aguarde", "A verificar compatibilidade de modelo...", "amarelo", 5000)
end)

-- complemento ao handler de modelo: trata o fluxo /croupa
AddEventHandler("skinshop:ReturnModel", function(staffSrc, who, modelHash)
    if not pendingCroupa[staffSrc] then return end
    local data = pendingCroupa[staffSrc]

    if who == "req"    then data.reqModel = modelHash end
    if who == "target" then data.tgtModel = modelHash end

    if data.reqModel and data.tgtModel then
        if not sameSex(data.reqModel, data.tgtModel) then
            TriggerClientEvent("Notify", staffSrc, "Aviso", "Modelos diferentes (sexo oposto). Pedido bloqueado.", "vermelho", 7000)
            pendingCroupa[staffSrc] = nil
            return
        end

        -- modelos compatíveis → pede a roupa AO VIVO do alvo, para aplicar no requerente
        TriggerClientEvent("skinshop:RequestCustomization", data.targetSrc, staffSrc, "CROUPA_TO_REQUESTER", nil)
        TriggerClientEvent("Notify", staffSrc, "Aguarde", "Modelos compatíveis. A obter roupa do jogador...", "amarelo", 5000)
    end
end)

-- complemento ao handler de roupa: trata o fluxo /croupa
AddEventHandler("skinshop:ReturnCustomization", function(requesterSrc, clothes, tag, _)
    if tag ~= "CROUPA_TO_REQUESTER" then return end
    if not requesterSrc or not online(requesterSrc) then return end

    if type(clothes) ~= "table" then
        TriggerClientEvent("Notify", requesterSrc, "Aviso", "Falha ao obter roupa do jogador.", "vermelho", 6000)
        pendingCroupa[requesterSrc] = nil
        return
    end

    -- aplica NO requerente, sem gravar
    TriggerClientEvent("skinshop:Apply", requesterSrc, clothes, true)
    TriggerClientEvent("Notify", requesterSrc, "Sucesso", "Roupa copiada e vestida em ti.", "verde", 5000)

        if exports["discord"] then
            local requesterPass = vRP.Passport(requesterSrc) or "N/A"
            local requesterName = vRP.FullName(requesterPass) or ("Passaporte "..requesterPass)
            local dataHora = os.date("%d/%m/%Y %H:%M")

            local logMsg = table.concat({
                "🧥 **COPIAR ROUPA (STAFF)**",
                "",
                "👮 **Requerente:** " .. requesterName .. " (📜 Passaporte: `" .. requesterPass .. "` | 🆔 Src: `" .. requesterSrc .. "`)",
                "🎯 **Ação:** Pedido concluído — roupa copiada para o requerente",
                "🗓️ **Data & Hora:** `" .. dataHora .. "`"
            }, "\n")

            exports["discord"]:Embed("Presets", logMsg, requesterSrc)
        end


    pendingCroupa[requesterSrc] = nil
end)


---------------------------------------------------------------------
-- PREPARE QUERIES (coloca no load do resource)
---------------------------------------------------------------------
vRP.Prepare("accounts/get_license_by_passport",[[
  SELECT license
  FROM characters
  WHERE id = @id
  LIMIT 1
]])


vRP.Prepare("phones/get_by_license",[[
  SELECT phone_number
  FROM phone_phones
  WHERE id = @license
  LIMIT 1
]])


---------------------------------------------------------------------
-- HELPERS DE FORMATAÇÃO
---------------------------------------------------------------------
local function FormatMoney(n)
    if not n then return "0" end
    local left,num,right = string.match(tostring(n), '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)','%1.'):reverse()) .. right
end

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local function getLicenseFromOnlineSrc(src)
  if not src then return nil end
  for _, id in ipairs(GetPlayerIdentifiers(src)) do
    if id:sub(1,8) == "license:" then
      return id -- já vem no formato "license:xxxx"
    end
  end
  return nil
end

local function GetLicenseByPassport(passport)
  local src = vRP.Source(passport)
  -- Online: lê diretamente dos identifiers do jogador
  local lic = getLicenseFromOnlineSrc(src)
  if lic then return lic end

  -- Offline: busca via DB (characters -> accounts.license)
  local row = vRP.Query("accounts/get_license_by_passport",{ id = passport })
  if row and row[1] and row[1].license and row[1].license ~= "" then
    -- Garante prefixo "license:" se a tua base guardar só o hash
    if not tostring(row[1].license):find("^license:") then
      return "license:" .. row[1].license
    end
    return row[1].license
  end
  return nil
end

local function GetPhoneByPassport(passport)
  local license = GetLicenseByPassport(passport)
  if not license then return "N/A" end
  local p = vRP.Query("phones/get_by_license",{ license = license })
  if p and p[1] and p[1].phone_number and p[1].phone_number ~= "" then
    return tostring(p[1].phone_number)
  end
  return "N/A"
end

-- Normaliza label vindo de outros recursos (evita "Hunter | Licença de Caçador")
local function CleanLicenseLabel(x)
  if type(x) == "table" then
    -- tenta campos comuns
    return x.label or x.Label or x.nome or x.name or x[2] or "Licença"
  end
  if type(x) == "string" then
    local a,b = x:match("^%s*([^|]+)|%s*(.+)$")
    if b and b ~= "" then return b end
    return x
  end
  return "Licença"
end

---------------------------------------------------------------------
-- /rg (staff)
---------------------------------------------------------------------
RegisterCommand("rg", function(source, args)
	local Passport = vRP.Passport(source)
	if not Passport or not vRP.HasGroup(Passport, "Admin") then
		TriggerClientEvent("Notify", source, "Acesso negado", "Apenas staff autorizado.", "vermelho", 5000)
		return
	end

	local OtherPassport = tonumber(args[1])

    if not OtherPassport then
        TriggerClientEvent("Notify", source, "Erro", "O ID precisa ser um número!", "amarelo", 5000)
        return
    end

    if OtherPassport <= 0 then
        TriggerClientEvent("Notify", source, "Erro", "ID inválido.", "amarelo", 5000)
        return
    end

	local SourceTarget = vRP.Source(OtherPassport)
	local IsOnline = SourceTarget ~= nil
	local Result = vRP.Query("characters/Person", { id = OtherPassport })

	if not Result or not Result[1] then
		TriggerClientEvent("Notify", source, "Erro", "Passaporte não encontrado.", "vermelho", 5000)
		return
	end

	local Identity = vRP.Identity(OtherPassport)
	local Name = Identity and Identity.name or "N/A"
	local Name2 = Identity and Identity.name2 or "N/A"
	-- TELEFONE vem da phone_phones (via license)
	local Phone = GetPhoneByPassport(OtherPassport)
	local Bank = parseInt(Result[1].bank or 0)
	local TXID = IsOnline and SourceTarget or "Offline"

	local DiscordID = "Indisponível"
	if IsOnline then
		for _, id in ipairs(GetPlayerIdentifiers(SourceTarget)) do
			if string.sub(id, 1, 8) == "discord:" then
				DiscordID = string.sub(id, 9)
				break
			end
		end
	end

	local GroupsText = ""
	for groupName, data in pairs(Groups) do
		local datatable = vRP.DataGroups(groupName)
		local level = datatable[tostring(OtherPassport)]
		if level then
			local levelText = "Grau " .. level
			local name = ""
			if data.Hierarchy and data.Hierarchy[level] then
				name = " - " .. data.Hierarchy[level]
			end
			GroupsText = GroupsText .. groupName .. " - " .. levelText .. name .. "<br>"
		end
	end

	local statusColor = IsOnline and "verde" or "vermelho"

	local Message = string.format([[
<b>Passaporte:</b> %d<br>
<b>ID:</b> %s<br>
<b>Discord:</b> %s<br>
<b>Nome:</b> %s %s<br>
<b>Telefone:</b> %s<br>
<b>Banco:</b> $%s<br><br>
<b>Grupos:</b><br>%s
]], OtherPassport, TXID, DiscordID, Name, Name2, Phone, Bank, GroupsText)

	TriggerClientEvent("Notify", source, "Informações do Jogador", Message, statusColor, 20000)
end)

---------------------------------------------------------------------
-- /rgp (polícia/admin)
---------------------------------------------------------------------
RegisterCommand("rgp", function(source, args)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport or not (vRP.HasGroup(Passport,"Policia") or vRP.HasGroup(Passport,"Admin")) then
        TriggerClientEvent("Notify", src, "Acesso negado", "Apenas policiais autorizados.", "vermelho", 5000)
        return
    end

    local OtherPassport = parseInt(args[1] or "0")
    if OtherPassport <= 0 then
        TriggerClientEvent("Notify", src, "Erro", "Passaporte inválido.", "amarelo", 5000)
        return
    end

    local Result = vRP.Query("characters/Person", { id = OtherPassport })
    if not Result or not Result[1] then
        TriggerClientEvent("Notify", src, "Erro", "Passaporte não encontrado.", "vermelho", 5000)
        return
    end

    local Identity = vRP.Identity(OtherPassport) or {}
    local Name     = Identity.name  or "N/A"
    local Name2    = Identity.name2 or "N/A"
    -- TELEFONE atualizado
    local Phone    = GetPhoneByPassport(OtherPassport)
    local Bank     = parseInt(Result[1].bank or 0)

    ----------------------------------------------------------------
    -- GRUPOS
    ----------------------------------------------------------------

    local GroupsText = ""
    do
        local lines = {}
        for groupName, data in pairs(Groups) do
            local datatable = vRP.DataGroups(groupName)
            local level = datatable[tostring(OtherPassport)]
            if level then
                local rankName = ""
                if data.Hierarchy and data.Hierarchy[level] then
                    rankName = data.Hierarchy[level]
                end

                if rankName ~= "" then
                    lines[#lines+1] = string.format("<b>%s</b> - %s", groupName, rankName)
                else
                    lines[#lines+1] = string.format("<b>%s</b>", groupName)
                end
            end
        end
        GroupsText = table.concat(lines, "<br>")
        if GroupsText == "" then GroupsText = "Sem grupos" end
    end


    ----------------------------------------------------------------
    -- MULTAS
    ----------------------------------------------------------------
    local FinesData = vRP.Query("fines/List", { Passport = OtherPassport }) or {}
    local FinesText, FinesTotal = "", 0
    if #FinesData > 0 then
        for _, fine in ipairs(FinesData) do
            local msg = fine.Message or fine.message or fine.Mensagem or fine.mensagem or "Sem descrição"
            local val = tonumber(fine.Value or fine.value or fine.Valor or fine.valor or 0) or 0
            FinesTotal = FinesTotal + val
            FinesText = FinesText .. string.format("%s - $%s<br>", msg, FormatMoney(val))
        end
        FinesText = FinesText .. string.format("<b>Total em multas:</b> $%s<br>", FormatMoney(FinesTotal))
    else
        FinesText = "Sem multas pendentes"
    end

    ----------------------------------------------------------------
    -- LICENÇAS (CARTA + GERAIS)
    ----------------------------------------------------------------
    local function join(list) return (#list>0) and table.concat(list, ", ") or "Nenhuma" end

    local DrivingLabelMap = {
        A = "Carta A (Moto)",
        B = "Carta B (Carro)",
        C = "Carta C (Autocarro)",
        D = "Carta D (Camião)"
    }

    local finalKey = "AutoSchool:Licenses:"..OtherPassport
    local tempKey  = "AutoSchool:TempLicenses:"..OtherPassport
    local FinalTbl = vRP.GetSrvData(finalKey) or {}
    local TempTbl  = vRP.GetSrvData(tempKey)  or {}

    local FinalList, TempList = {}, {}
    for k,v in pairs(FinalTbl) do
        if v == true then FinalList[#FinalList+1] = DrivingLabelMap[k] or ("Carta "..tostring(k)) end
    end
    for k,v in pairs(TempTbl) do
        if v == true then TempList[#TempList+1] = (DrivingLabelMap[k] or ("Carta "..tostring(k))).." (TEMP)" end
    end
    table.sort(FinalList)
    table.sort(TempList)

    -- Licenças gerais
    local GeneralLabels = {}
    local ok, labeled = pcall(function()
        if exports["licenses_general"] and exports["licenses_general"].ListLicensesLabeled then
            return exports["licenses_general"]:ListLicensesLabeled(OtherPassport)
        end
        return nil
    end)
    if ok and type(labeled) == "table" and next(labeled) then
        -- Pode vir como { {id=..., label=...}, ... } ou como strings "ID | Label"
        for _,entry in ipairs(labeled) do
            GeneralLabels[#GeneralLabels+1] = CleanLicenseLabel(entry)
        end
    else
        local GenKey = "Licensas:"..OtherPassport
        local GenTbl = vRP.GetSrvData(GenKey) or {}
        local BasicMap = {
            Firearm = "Porte de Arma",
            Hunter  = "Licença de Caçador",
            Fishing  = "Licença de Pesca",
            Lawyer  = "Licença de Advogado",
            Judge  = "Licença de Juiz",
            Homo  = "Licença Homosexual"
        }
        for id,flag in pairs(GenTbl) do
            if flag == true then
                GeneralLabels[#GeneralLabels+1] = BasicMap[id] or tostring(id)
            end
        end
    end
    table.sort(GeneralLabels)

    local CartaFinalText = join(FinalList)
    local CartaTempText  = join(TempList)
    local GeraisText     = join(GeneralLabels)

    ----------------------------------------------------------------
    -- MENSAGEM FINAL
    ----------------------------------------------------------------
    local Message = string.format([[
<b>Passaporte:</b> %d<br>
<b>Nome:</b> %s %s<br>
<b>Telefone:</b> %s<br>
<b>Banco:</b> $%s<br><br>

<b>Grupos:</b><br>%s<br><br>

<b>Carta de Condução:</b><br>
%s<br><br>

<b>Licenças:</b><br>%s<br><br>

<b>Multas:</b><br>%s
    ]],
    OtherPassport, Name, Name2, Phone, FormatMoney(Bank),
    GroupsText,
    CartaFinalText, 
    GeraisText,
    FinesText)

    TriggerClientEvent("Notify", src, "Informações do Jogador", Message, "policia", 20000)
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- DEBUG
-----------------------------------------------------------------------------------------------------------------------------------------


RegisterNetEvent("debug:reqPing", function()
    local src = source
    local ping = GetPlayerPing(src) or 0
    TriggerClientEvent("debug:setPing", src, ping)
end)

RegisterCommand("debug", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if vRP.HasPermission(Passport,"Admin") then
        TriggerClientEvent("debug:toggle",source)
        TriggerClientEvent("Notify",source,"Debug","<b>Modo Debug</b> alternado.", "azul", 3500)
    else
        TriggerClientEvent("Notify",source,"Permissão","Precisas de <b>Admin</b> para usar isto.", "vermelho", 5000)
    end
end)


RegisterNetEvent("debug:requestPlayerInfo", function(targetSrc)
    local src = source
    local Passport = vRP.Passport(targetSrc)
    local name = ""
    if Passport then
        local identity = vRP.Identity(Passport)
        if identity then name = (identity.name or "").." "..(identity.name2 or "") end
    end
    TriggerClientEvent("debug:replyPlayerInfo", src, {
        targetSrc = targetSrc,
        passport  = Passport or 0,
        fullname  = name
    })
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- FREEZE
-----------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------
-- FREEZE / UNFREEZE por PASSAPORTE (ou "all")
-----------------------------------------------------------------------------------------------------------------------------------------
local EXCLUDE_STAFF = true -- true = não afeta quem tem grupo Admin no modo "all"

local function freezeOne(passport, state)
    local src = vRP.Source(passport)
    if not src then return false end
    TriggerClientEvent("admin:toggleFreeze", src, state)
    return true, src
end

local function clearStatesOne(passport)
    local src = vRP.Source(passport)
    if not src then return false end
    TriggerClientEvent("admin:clearPlayerStates", src)
    -- força statebags (se existirem) do lado servidor
    local p = Player(src)
    if p and p.state then
        if p.state.Death ~= false then p.state:set("Death", false, true) end
        if p.state.Crawl ~= false then p.state:set("Crawl", false, true) end
        -- respeita Handcuff: não alteramos no servidor
    end
    return true, src
end

RegisterCommand("freeze", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport or not vRP.HasGroup(Passport,"Admin") then
        if source > 0 then
            TriggerClientEvent("Notify", source, "Permissão", "Não tens permissões para usar este comando.", "vermelho", 5000)
        end
        return
    end

    local targetArg = (args[1] or ""):lower()
    if targetArg == "" then
        TriggerClientEvent("Notify", source, "Freeze", "Uso: <b>/freeze passaporte</b> ou <b>/freeze all</b>.", "amarelo", 6000)
        return
    end

    if targetArg == "all" then
        local count = 0
        for _, sid in ipairs(GetPlayers()) do
            sid = tonumber(sid)
            local pass = vRP.Passport(sid)
            if pass then
                if EXCLUDE_STAFF and vRP.HasGroup(pass,"Admin") then
                    -- salta staff
                else
                    local ok = freezeOne(pass, true)
                    if ok then
                        count = count + 1
                        TriggerClientEvent("Notify", sid, "Freeze", "Foste <b>congelado</b> por um administrador.", "vermelho", 5000)
                    end
                end
            end
        end

        local staffName = vRP.FullName(Passport) or "Indefinido"
        local msg = table.concat({
            "🧊 **Freeze (ALL)**",
            "",
            ("👮 **Staff:** %s (#%d | %d)"):format(staffName, source, Passport),
            ("👥 **Atingidos:** %d"):format(count),
            ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
        },"\n")
        exports["discord"]:Embed("Freeze", msg, source)
        TriggerClientEvent("Notify", source, "Freeze", ("Congelaste <b>%d</b> jogadores."):format(count), "verde", 6000)
        return
    end

    local tgtPass = tonumber(targetArg)
    if not tgtPass then
        TriggerClientEvent("Notify", source, "Freeze", "Passaporte inválido.", "vermelho", 5000)
        return
    end

    local ok, tgtSrc = freezeOne(tgtPass, true)
    if not ok then
        TriggerClientEvent("Notify", source, "Freeze", "Jogador offline.", "vermelho", 5000)
        return
    end

    local staffName = vRP.FullName(Passport) or "Indefinido"
    local tgtName   = vRP.FullName(tgtPass) or "Indefinido"
    local msg = table.concat({
        "🧊 **Freeze**",
        "",
        ("👮 **Staff:** %s (#%d | %d)"):format(staffName, source, Passport),
        ("👤 **Alvo:** %s (#%d | %d)"):format(tgtName, tgtSrc, tgtPass),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")
    exports["discord"]:Embed("Freeze", msg, source)

    TriggerClientEvent("Notify", source, "Freeze", ("Jogador <b>%d</b> congelado."):format(tgtPass), "verde", 5000)
    TriggerClientEvent("Notify", tgtSrc, "Freeze", "Foste <b>congelado</b> por um administrador.", "vermelho", 5000)
end)

RegisterCommand("unfreeze", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport or not vRP.HasGroup(Passport,"Admin") then
        if source > 0 then
            TriggerClientEvent("Notify", source, "Permissão", "Não tens permissões para usar este comando.", "vermelho", 5000)
        end
        return
    end

    local targetArg = (args[1] or ""):lower()
    if targetArg == "" then
        TriggerClientEvent("Notify", source, "Unfreeze", "Uso: <b>/unfreeze passaporte</b> ou <b>/unfreeze all</b>.", "amarelo", 6000)
        return
    end

    if targetArg == "all" then
        local count = 0
        for _, sid in ipairs(GetPlayers()) do
            sid = tonumber(sid)
            local pass = vRP.Passport(sid)
            if pass then
                if EXCLUDE_STAFF and vRP.HasGroup(pass,"Admin") then
                    -- salta staff
                else
                    local ok = freezeOne(pass, false)
                    if ok then
                        clearStatesOne(pass)
                        count = count + 1
                        TriggerClientEvent("Notify", sid, "Unfreeze", "Foste <b>descongelado</b> por um administrador.", "verde", 5000)
                    end
                end
            end
        end

        local staffName = vRP.FullName(Passport) or "Indefinido"
        local msg = table.concat({
            "🧊 **Unfreeze (ALL)**",
            "",
            ("👮 **Staff:** %s (#%d | %d)"):format(staffName, source, Passport),
            ("👥 **Atingidos:** %d"):format(count),
            ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
        },"\n")
        exports["discord"]:Embed("Freeze", msg, source)
        TriggerClientEvent("Notify", source, "Unfreeze", ("Descongelaste e desbugaste <b>%d</b> jogadores."):format(count), "verde", 6000)
        return
    end

    local tgtPass = tonumber(targetArg)
    if not tgtPass then
        TriggerClientEvent("Notify", source, "Unfreeze", "Passaporte inválido.", "vermelho", 5000)
        return
    end

    local ok, tgtSrc = freezeOne(tgtPass, false)
    if not ok then
        TriggerClientEvent("Notify", source, "Unfreeze", "Jogador offline.", "vermelho", 5000)
        return
    end
    clearStatesOne(tgtPass)

    local staffName = vRP.FullName(Passport) or "Indefinido"
    local tgtName   = vRP.FullName(tgtPass) or "Indefinido"
    local msg = table.concat({
        "🧊 **Unfreeze**",
        "",
        ("👮 **Staff:** %s (#%d | %d)"):format(staffName, source, Passport),
        ("👤 **Alvo:** %s (#%d | %d)"):format(tgtName, tgtSrc, tgtPass),
        ("🕒 **Quando:** %s"):format(os.date("%d/%m/%Y %H:%M:%S"))
    },"\n")
    exports["discord"]:Embed("Freeze", msg, source)

    TriggerClientEvent("Notify", source, "Unfreeze", ("Jogador <b>%d</b> descongelado e desbugado."):format(tgtPass), "verde", 5000)
    TriggerClientEvent("Notify", tgtSrc, "Unfreeze", "Foste <b>descongelado</b> por um administrador.", "verde", 5000)
end)

----- FECHAR PERIMETRO

local PERIMETRO = {}
local nextId = 1

local PERIMETRO_SERVER = {}
Tunnel.bindInterface("perimetro", PERIMETRO_SERVER)

-- Para chamar funções do client (ex.: obter nome da localização)
local vCLIENT = Tunnel.getInterface("perimetro")

function PERIMETRO_SERVER.IsPolice()
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return false end
    return vRP.HasGroup(Passport,"Policia") == true
end

local function dist(a,b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end

local function nearestPerimeter(coords, maxd)
    local selId, selData, selDist = nil, nil, maxd or 999999.0
    for id, data in pairs(PERIMETRO) do
        local d = dist(coords, data.coords)
        if d <= selDist then
            selId, selData, selDist = id, data, d
        end
    end
    return selId, selData, selDist
end

RegisterNetEvent("perimetro:requestSync", function()
    local src = source
    TriggerClientEvent("perimetro:syncAll", src, PERIMETRO)
end)

RegisterCommand("perimetro", function(source, args)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return end

    if not vRP.HasGroup(Passport,"Policia") then
        TriggerClientEvent("Notify", src, "🚔 Polícia", "Acesso negado.", "vermelho", 5000)
        return
    end

    local coords = vRP.GetEntityCoords(src)
    if not coords then
        TriggerClientEvent("Notify", src, "🚔 Polícia", "Não foi possível obter a posição.", "vermelho", 5000)
        return
    end

    -- FECHA se existir perímetro ≤ 50m (fecha o mais próximo)
    local id, data = (function()
        local selId, selData, selDist = nil, nil, 50.0
        for pid, pdata in pairs(PERIMETRO) do
            local dx,dy,dz = coords.x - pdata.coords.x, coords.y - pdata.coords.y, coords.z - pdata.coords.z
            local d = math.sqrt(dx*dx+dy*dy+dz*dz)
            if d <= selDist then
                selId, selData, selDist = pid, pdata, d
            end
        end
        return selId, selData
    end)()

    if id ~= nil then
        local nome = (data and data.name) or ("#"..id)
        PERIMETRO[id] = nil
        TriggerClientEvent("perimetro:remove", -1, id)

        TriggerClientEvent("Notify", src, "🚧 Perímetro", ("<b>%s</b> encerrado. ✅"):format(nome), "verde", 7000)

        if exports["discord"] then
            exports["discord"]:Embed("Perimetro",
                ("✅ **Perímetro encerrado: %s**\n👮 Autor: **%s** (Passaporte #%d)\n📍 Local: `%.2f, %.2f, %.2f`"):format(
                    nome, vRP.FullName(Passport) or ("ID "..Passport), Passport, data.coords.x, data.coords.y, data.coords.z
                ), src)
        end
        return
    end

    -- ABRE novo com raio FIXO
    local RADIUS = 150

    -- Evita duplicado muito perto (≤ 150m)
    for pid, pdata in pairs(PERIMETRO) do
        local dx,dy,dz = coords.x - pdata.coords.x, coords.y - pdata.coords.y, coords.z - pdata.coords.z
        if math.sqrt(dx*dx+dy*dy+dz*dz) <= 150.0 then
            TriggerClientEvent("Notify", src, "🚧 Perímetro", "Já existe um perímetro muito próximo. Encerra-o antes de abrir outro.", "amarelo", 7000)
            return
        end
    end

    local newId = nextId
    nextId = nextId + 1

    -- Pedir ao client um rótulo legível (rua / cruzamento / zona)
    local label = nil
    local ok, res = pcall(function()
        return vCLIENT.GetLocationLabel(src, { x = coords.x, y = coords.y, z = coords.z })
    end)
    if ok and res and res ~= "" then label = res end
    if not label then label = ("Perímetro %d"):format(newId) end

    PERIMETRO[newId] = {
        id = newId,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        radius = RADIUS,
        creator = Passport,
        time = os.time(),
        name = label
    }

    TriggerClientEvent("perimetro:add", -1, PERIMETRO[newId])

    -- Notificações
    TriggerClientEvent("Notify", src, "🚧 Perímetro", ("<b>%s</b> aberto — <b>%dm</b> 🔴"):format(label, RADIUS), "azul", 8000)

    local service = vRP.NumPermission("Policia") or {}
    for _,polSrc in pairs(service) do
        TriggerClientEvent("Notify", polSrc, "🚧 Perímetro",
            ("Novo perímetro <b>%s</b> aberto por <b>%s</b> — raio: <b>%dm</b>."):format(label, vRP.FullName(Passport) or ("ID "..Passport), RADIUS),
            "azul", 8000)
    end

    if exports["discord"] then
        exports["discord"]:Embed("Perimetro",
            ("🚨 **Perímetro aberto: %s**\n👮 Autor: **%s** (Passaporte #%d)\n📏 Raio: **%dm** (fixo)\n📍 Local: `%.2f, %.2f, %.2f`\n🕒 %s"):format(
                label, vRP.FullName(Passport) or ("ID "..Passport), Passport, RADIUS, coords.x, coords.y, coords.z, os.date("%d/%m/%Y %H:%M:%S")
            ), src)
    end
end)


---- RGB

RegisterCommand("rgb", function(source)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    -- Apenas staff
    if vRP.HasPermission(Passport,"Admin",1) then
        TriggerClientEvent("rgb:toggle", source)
    else
        TriggerClientEvent("Notify", source, "Permissão", "Apenas staff pode usar este comando.", "vermelho", 5000)
    end
end)

---------- INVIS

RegisterCommand("invis", function(source,args)
    local Passport = vRP.Passport(source)
    if Passport and vRP.HasPermission(Passport,"Admin",1) then
        TriggerClientEvent("staff:ToggleInvis", source)
    else
        TriggerClientEvent("Notify", source, "Admin", "Sem permissão.", "vermelho", 5000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- /skin [PASSAPORTE] [PED]
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("skin", function(source, args)
    local adminPassport = vRP.Passport(source)
    if not adminPassport then return end

    if not vRP.HasPermission(adminPassport, "Admin", 1) then
        TriggerClientEvent("Notify", source, "Sistema", "<b>Sem permissões.</b>", "vermelho", 5000)
        return
    end

    local targetPassport = tonumber(args[1])
    local pedModel = args[2]

    if not targetPassport or not pedModel then
        TriggerClientEvent("Notify", source, "Sistema", "Uso: <b>/skin [PASSAPORTE] [modeloPed]</b>", "amarelo", 6000)
        return
    end

    local targetSrc = vRP.Source(targetPassport)
    if not targetSrc then
        TriggerClientEvent("Notify", source, "Sistema", "Jogador com passaporte <b>"..targetPassport.."</b> não está online.", "amarelo", 6000)
        return
    end

    TriggerClientEvent("staff:SetPedModel", targetSrc, pedModel)
    TriggerClientEvent("Notify", source, "Sistema", "Skin temporária aplicada em <b>"..targetPassport.."</b>.", "verde", 4500)
    TriggerClientEvent("Notify", targetSrc, "Sistema", "Um staff aplicou-te um <b>ped temporário</b>.", "azul", 5000)

    -- LOG DISCORD
    local adminName = vRP.FullName(adminPassport)
    local targetName = vRP.FullName(targetPassport)
    exports["discord"]:Embed("Skin", 
        "👔 **Alteração de Skin**\n\n"..
        "👤 **Staff:** "..adminName.." (#"..adminPassport..")\n"..
        "🎯 **Alvo:** "..targetName.." (#"..targetPassport..")\n"..
        "🧍 **Modelo aplicado:** `"..pedModel.."`",
        source
    )
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- /resetskin [PASSAPORTE]
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("resetskin", function(source, args)
    local adminPassport = vRP.Passport(source)
    if not adminPassport then return end

    if not vRP.HasPermission(adminPassport, "Admin", 1) then
        TriggerClientEvent("Notify", source, "Sistema", "<b>Sem permissões.</b>", "vermelho", 5000)
        return
    end

    local targetPassport = tonumber(args[1])
    if not targetPassport then
        TriggerClientEvent("Notify", source, "Sistema", "Uso: <b>/resetskin [PASSAPORTE]</b>", "amarelo", 6000)
        return
    end

    local targetSrc = vRP.Source(targetPassport)
    if not targetSrc then
        TriggerClientEvent("Notify", source, "Sistema", "Jogador com passaporte <b>"..targetPassport.."</b> não está online.", "amarelo", 6000)
        return
    end

    local identity = vRP.Identity(targetPassport)
    local sex = identity and identity.sex or "M"

    local clothes = vRP.UserData(targetPassport, "Clothings") or {}
    local barber  = vRP.UserData(targetPassport, "Barbershop") or {}
    local tattoos = vRP.UserData(targetPassport, "Tattooshop") or {}

    TriggerClientEvent("staff:ResetPedModel", targetSrc, sex, clothes, barber, tattoos)

    TriggerClientEvent("Notify", source, "Sistema", "Skin resetada em <b>"..targetPassport.."</b> (com presets).", "verde", 4500)
    TriggerClientEvent("Notify", targetSrc, "Sistema", "O teu modelo foi <b>reposto</b> com as tuas roupas e personalização.", "azul", 5000)

    -- LOG DISCORD
    local adminName = vRP.FullName(adminPassport)
    local targetName = vRP.FullName(targetPassport)
    exports["discord"]:Embed("Skin", 
        "🔄 **Reset de Skin**\n\n"..
        "👤 **Staff:** "..adminName.." (#"..adminPassport..")\n"..
        "🎯 **Alvo:** "..targetName.." (#"..targetPassport..")",
        source
    )
end)

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local speedState = {} -- [src] = { mult = number }

---------------------------------------------------------------------
-- /speed [mult | off/reset/0/normal]
---------------------------------------------------------------------
RegisterCommand("speed", function(source, args)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if not vRP.HasPermission(Passport, "Admin", 2) then
        TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
        return
    end

    local a1 = (args[1] or ""):lower()
    if a1 == "off" or a1 == "reset" or a1 == "0" or a1 == "normal" then
        speedState[source] = nil
        TriggerClientEvent("admin:SpeedApply", source, false, 1.0)
        TriggerClientEvent("Notify", source, "Admin", "Velocidade de corrida <b>desativada</b>.", "azul", 5000)

        -- 📑 Log Discord
        exports["discord"]:Embed("Admin",
            "⚡ **Comando /speed**\n\n👤 Passaporte: **"..Passport.."**\n🛑 Estado: **Desativado**",
            source
        )
        return
    end

    local mult = tonumber(args[1]) or (speedState[source] and speedState[source].mult or 1.25)
    if mult < 1.0 then mult = 1.0 end
    if mult > 1.49 then mult = 1.49 end -- limite do GTA

    local enable = mult > 1.0
    if enable then
        speedState[source] = { mult = mult }
    else
        speedState[source] = nil
    end

    TriggerClientEvent("admin:SpeedApply", source, enable, mult)
    if enable then
        TriggerClientEvent("Notify", source, "Admin", "Velocidade de corrida definida para <b>"..string.format("%.2f", mult).."x</b>.", "azul", 5000)

        -- 📑 Log Discord
        exports["discord"]:Embed("Admin",
            "⚡ **Comando /speed**\n\n👤 Passaporte: **"..Passport.."**\n✅ Multiplicador: **"..string.format("%.2f", mult).."x**",
            source
        )
    else
        TriggerClientEvent("Notify", source, "Admin", "Velocidade de corrida <b>normalizada</b>.", "azul", 5000)

        -- 📑 Log Discord
        exports["discord"]:Embed("Admin",
            "⚡ **Comando /speed**\n\n👤 Passaporte: **"..Passport.."**\n🔄 Estado: **Normalizado**",
            source
        )
    end
end)

AddEventHandler("playerDropped", function()
    speedState[source] = nil
end)


---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local function now() return os.time() end

local function nameTag(passport)
    local name = vRP.FullName(passport) or ("Passaporte "..passport)
    local src = vRP.Source(passport)
    local idTxt = src and (" (#"..src..")") or ""
    return string.format("%s #%d%s", name, passport, idTxt)
end

local function resolveTargetPassport(arg1, adminPass)
    local a1 = (arg1 or ""):lower()
    if a1 == "me" or a1 == "self" then return adminPass end
    local n = tonumber(a1); if not n then return nil end
    local maybe = vRP.Passport(n) -- se for source online, devolve passaporte
    return maybe or n             -- senão, assume que já é passaporte
end

---------------------------------------------------------------------
-- HUD INTEGRAÇÃO (evento do teu HUD)
-- SET: TriggerEvent("Wanted", targetSrc, tostring(passport), seconds)
-- GET: exports["hud"]:Wanted(passport)  (server-side)
---------------------------------------------------------------------
local function HudAddWantedSeconds(passport, seconds, adminSrc)
    local src = vRP.Source(passport) or adminSrc or 0
    TriggerEvent("Wanted", src, tostring(passport), math.floor(seconds))
end

-- ⚠️ ATUALIZA isto
local function HudClearWanted(passport, adminSrc)
    local src = vRP.Source(passport)
    -- online: limpa via evento + força UI
    if src and src > 0 then
        TriggerEvent("Wanted", src, tostring(passport), 0) -- limpa
        TriggerClientEvent("hud:Wanted", src, 0)           -- UI {0,0}
    end
    -- offline/garantia: limpa tabelas do HUD (se export existir)
    pcall(function()
        if GetResourceState("hud") == "started" and exports["hud"] and exports["hud"].ClearWanted then
            exports["hud"]:ClearWanted(tostring(passport))
        end
    end)
end

---------------------------------------------------------------------
-- Opcional: passar também pelo pipeline do roubo (consistência global)
---------------------------------------------------------------------
local function CallPoliceWanted(passport, seconds, adminSrc)
    if GetResourceState("vrp") == "started" and exports["vrp"] and exports["vrp"].CallPolice then
        exports["vrp"]:CallPolice({
            ["Source"]     = vRP.Source(passport) or adminSrc or 0,
            ["Passport"]   = passport,
            ["Permission"] = "Policia",
            ["Name"]       = "Admin: Estado de Procura",
            ["Percentage"] = 100,
            ["Wanted"]     = seconds, -- SEGUNDOS
            ["Code"]       = 31,
            ["Color"]      = 46,
            ["Silent"]     = true
        })
    end
end

---------------------------------------------------------------------
-- /SETWANTED <passaporte|me|self|srcId> <minutos>
---------------------------------------------------------------------
RegisterCommand("setwanted", function(source, args)
    local adminPass = vRP.Passport(source); if not adminPass then return end
    if not vRP.HasPermission(adminPass, "Admin", 2) then
        return TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
    end
    if not args[1] then
        return TriggerClientEvent("Notify", source, "Admin", "Uso: <b>/setwanted <passaporte|me|self|srcId> <minutos></b>", "amarelo", 8000)
    end

    local target = resolveTargetPassport(args[1], adminPass)
    if not target or target <= 0 then
        return TriggerClientEvent("Notify", source, "Admin", "Alvo inválido.", "vermelho", 5000)
    end

    local minutes = tonumber(args[2] or "10") or 10
    if minutes < 1 then minutes = 1 end
    if minutes > 180 then minutes = 180 end

    local seconds = minutes * 60

    -- 1) HUD (evento oficial do teu recurso)
    HudAddWantedSeconds(target, seconds, source)

    -- 2) Opcional: pipeline do roubo (mantém consistência com outros scripts)
    CallPoliceWanted(target, seconds, source)

    TriggerClientEvent("Notify", source, "Admin",
        "Wanted aplicado a <b>"..nameTag(target).."</b> por <b>"..minutes.." min</b>.",
        "azul", 6000)

    -- Logs Discord (opcional)
    if exports["discord"] and exports["discord"].Embed then
        local adminName = (vRP.FullName(adminPass) or "Admin").." #"..adminPass
        local msg = string.format(
            "🚨 **WANTED APLICADO**\n\n👤 **Alvo:** %s\n🕒 **Duração:** %d min\n🛡️ **Por:** %s\n📅 **Expira:** %s",
            nameTag(target), minutes, adminName, os.date("%d/%m/%Y %H:%M", now() + seconds)
        )
        exports["discord"]:Embed("Wanted", msg, source)
    end
end)

---------------------------------------------------------------------
-- /CLEARWANTED <passaporte|me|self|srcId>  (limpa HUD 100% - FIX)
---------------------------------------------------------------------
RegisterCommand("clearwanted", function(source, args)
    local adminPass = vRP.Passport(source); if not adminPass then return end
    if not vRP.HasPermission(adminPass, "Admin", 2) then
        return TriggerClientEvent("Notify", source, "Admin", "Sem permissões.", "vermelho", 5000)
    end
    if not args[1] then
        return TriggerClientEvent("Notify", source, "Admin", "Uso: <b>/clearwanted <passaporte|me|self|srcId></b>", "amarelo", 8000)
    end

    local a1 = (args[1] or ""):lower()
    local n  = tonumber(a1)
    local target = (a1 == "me" or a1 == "self") and adminPass or (n and (vRP.Passport(n) or n))
    if not target or target <= 0 then
        return TriggerClientEvent("Notify", source, "Admin", "Alvo inválido.", "vermelho", 5000)
    end

    -- estado anterior (para log)
    local wasWanted = false
    pcall(function()
        if GetResourceState("hud") == "started" and exports["hud"] and exports["hud"].Wanted then
            wasWanted = exports["hud"]:Wanted(tostring(target)) and true or false
        end
    end)

    local tgtSrc = vRP.Source(target)

    -- 1) limpa tabelas do HUD (offline/online)
    pcall(function()
        if GetResourceState("hud") == "started" and exports["hud"] and exports["hud"].ClearWanted then
            exports["hud"]:ClearWanted(tostring(target))
        end
    end)

    -- 2) se ONLINE: dispara evento apenas para o jogador + força UI a {0,0}
    if tgtSrc and tgtSrc > 0 then
        TriggerEvent("Wanted", tgtSrc, tostring(target), 0)      -- limpa no HUD server (sem broadcast)
        TriggerClientEvent("hud:Wanted", tgtSrc, 0)               -- UI recebe {0,0} e esconde
        TriggerClientEvent("hud:Wanted:ForceClear", tgtSrc)       -- (se existir handler) hard reset visual
    end

    TriggerClientEvent("Notify", source, "Admin", "Wanted limpo de <b>#"..target.."</b>.", "azul", 5000)

    -- LOG Discord
    if exports["discord"] and exports["discord"].Embed then
        local nm = vRP.FullName(target) or ("Passaporte "..target)
        local sn = vRP.Source(target)
        local targetTag = string.format("%s #%d%s", nm, target, sn and (" (#"..sn..")") or "")
        local adminName = (vRP.FullName(adminPass) or "Admin").." #"..adminPass
        local whenTxt   = os.date("%d/%m/%Y %H:%M", os.time())
        local msg = wasWanted
            and string.format("✅ **WANTED REMOVIDO**\n\n👤 **Alvo:** %s\n🛡️ **Por:** %s\n📅 **Quando:** %s", targetTag, adminName, whenTxt)
            or  string.format("ℹ️ **CLEARWANTED EXECUTADO**\n\n👤 **Alvo:** %s\n🛡️ **Por:** %s\n📅 **Quando:** %s\n📝 **Nota:** Alvo não tinha Wanted ativo.", targetTag, adminName, whenTxt)
        exports["discord"]:Embed("Wanted", msg, source)
    end
end)


----------------------------------------------------------
	---- SELFBOMB
----------------------------------------------------------

local RADIUS = 50.0

local function IsAdminLevel1(src)
    local passport = vRP.Passport(src)
    if not passport then return false end

    if vRP.HasPermission and type(vRP.HasPermission) == "function" then
        local ok,res = pcall(function() return vRP.HasPermission(passport,"Admin",1) end)
        if ok and res then return true end
    end

    if vRP.HasGroup and vRP.HasGroup(passport,"Admin") then
        return true
    end
    return false
end



RegisterCommand("selfbomb",function(source)
    local passport = vRP.Passport(source)
    if not passport then return end
    if not vRP.HasPermission(passport,"Admin",1) then
        TriggerClientEvent("Notify",source,"Sistema","Sem permissão.","vermelho",4000)
        return
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)

    -- manda evento local só para o suicida (FX mas sem ragdoll nem kill)
    TriggerClientEvent("selfbomb:suicide",source,{x=coords.x,y=coords.y,z=coords.z})

    -- manda blast para todos os outros
    TriggerClientEvent("selfbomb:blast",-1,{x=coords.x,y=coords.y,z=coords.z},RADIUS,source)

    -- LOG opcional (canal "Admin") — descomenta se quiser
    local passport = vRP.Passport(src) or "?"
    local msg = ("**SelfBomb**\n**Admin:** #%s (src %s)\n**Coords:** x=%.2f y=%.2f z=%.2f\n**Raio:** %sm\n**Quando:** %s")
      :format(tostring(passport), tostring(src), x, y, z, tostring(RADIUS), os.date("%Y-%m-%d %H:%M:%S"))
    if exports and exports["discord"] and exports["discord"].Embed then
        exports["discord"].Embed("Admin", msg, src)
    elseif exports and exports["discord"] and exports["discord"].Embed ~= nil then
        exports["discord"]:Embed("Admin", msg, src)
    end
end)

----------------------------------------------------------
	---- TROLL COMMANDS
----------------------------------------------------------

-- permissões
local function IsAdminLevel1(src)
  local passport = vRP.Passport(src)
  if not passport then return false end
  if vRP.HasPermission and type(vRP.HasPermission) == "function" then
    local ok, res = pcall(function() return vRP.HasPermission(passport, "Admin", 1) end)
    if ok and res then return true end
  end
  if vRP.HasGroup and vRP.HasGroup(passport, "Admin") then return true end
  return false
end

local function notify(src, title, msg, color)
  TriggerClientEvent("Notify", src, title or "Sistema", msg or "", color or "amarelo", 4000)
end

-- helpers alvo:
local function playersList()
  local t = {}
  for _,id in ipairs(GetPlayers()) do t[#t+1] = tonumber(id) end
  return t
end

local function playersInRangeFrom(src, radius)
  local t = {}
  if src == 0 then
    for _,id in ipairs(GetPlayers()) do t[#t+1] = tonumber(id) end
    return t
  end
  local ped = GetPlayerPed(src)
  if not ped or ped <= 0 then return t end
  local pcoords = GetEntityCoords(ped)
  for _,sid in ipairs(GetPlayers()) do
    sid = tonumber(sid)
    local ped2 = GetPlayerPed(sid)
    if ped2 and ped2 > 0 then
      local c2 = GetEntityCoords(ped2)
      if #(c2 - pcoords) <= (radius or 50.0) then
        t[#t+1] = sid
      end
    end
  end
  -- inclui o próprio
  t[#t+1] = src
  return t
end

-- aceita "near" além de all/self/id(passaporte)
local NEAR_RADIUS = 50.0
local function resolveTargets(src, arg)
  -- CONSOLE
  if src == 0 then
    if arg == "all" or arg == "todos" then return playersList() end
    if arg == "near" then return playersList() end -- consola não tem coords, devolve todos
    local asrc = tonumber(arg or "")
    if asrc and GetPlayerPing(asrc) > 0 then return { asrc } end
    return {}
  end

  -- IN-GAME
  if arg == "all" or arg == "todos" then return playersList() end
  if arg == "near" then return playersInRangeFrom(src, NEAR_RADIUS) end

  local passport = tonumber(arg or "")
  if not passport then return { src } end -- sem arg = self
  local tgtSrc = vRP.Source(passport)
  if tgtSrc and GetPlayerPing(tgtSrc) > 0 then return { tgtSrc } end
  return {}
end

local function logAdmin(text, src)
  local ok = false
  if exports and exports["discord"] and type(exports["discord"].Embed) == "function" then
    ok = pcall(exports["discord"].Embed, "Admin", text, src)
  end
  if not ok and exports and exports["discord"] then
    pcall(function() exports["discord"]:Embed("Admin", text, src) end)
  end
end

local function SafeFullName(passport)
  if vRP.FullName and type(vRP.FullName) == "function" then
    local ok, name = pcall(vRP.FullName, passport)
    if ok and name then return name end
  end
  return "Jogador"
end

local function logAdminFull(cmd, src, targetsArg, targetsList)
  local mePassport = src ~= 0 and (vRP.Passport(src) or "?") or "CONSOLE"
  local meName = (src ~= 0) and SafeFullName(mePassport) or "Console"

  local targetsStr
  if type(targetsList) == "table" and #targetsList > 0 then
    local parts = {}
    for _,sid in ipairs(targetsList) do
      local p = vRP.Passport(sid)
      local nm = p and SafeFullName(p) or ("src "..sid)
      parts[#parts+1] = (p and ("#"..p.." "..nm)) or nm
    end
    targetsStr = table.concat(parts, ", ")
  else
    targetsStr = tostring(targetsArg or "self")
  end

  local text = ("</b>**/%s** por <b>%s</b> (#%s)</b> → %s"):format(cmd, meName, mePassport, targetsStr)
  logAdmin(text, src)
end

-- /abduct <passaporte|all|near>  (console: <src|all|near>)
RegisterCommand("abduct", function(source, args)
  local src = source
  if src ~= 0 and not IsAdminLevel1(src) then notify(src,"Permissão","Sem permissão.","vermelho"); return end

  local targets = resolveTargets(src, args[1])
  if #targets == 0 then if src ~= 0 then notify(src,"Sistema","Alvo inválido.","amarelo") end; return end

  for _,t in ipairs(targets) do
    TriggerClientEvent("troll:abductCommand", t, true) -- true = OVNI beam
  end

  logAdminFull("abduct", src, args[1], targets)
end, false)

-- /flipcar <passaporte|all|near>
RegisterCommand("flipcar", function(source, args)
  local src = source
  if src ~= 0 and not IsAdminLevel1(src) then notify(src,"Permissão","Sem permissão.","vermelho"); return end

  local targets = resolveTargets(src, args[1])
  if #targets == 0 then if src ~= 0 then notify(src,"Sistema","Alvo inválido.","amarelo") end; return end

  for _,t in ipairs(targets) do
    TriggerClientEvent("troll:flipcarCommand", t)
  end

  logAdminFull("flipcar", src, args[1], targets)
end, false)

-- /spin <passaporte|all|near> [seconds]
RegisterCommand("spin", function(source, args)
  local src = source
  if src ~= 0 and not IsAdminLevel1(src) then notify(src,"Permissão","Sem permissão.","vermelho"); return end

  local targets = resolveTargets(src, args[1])
  local seconds = tonumber(args[2]) or 6
  if #targets == 0 then if src ~= 0 then notify(src,"Sistema","Alvo inválido.","amarelo") end; return end

  for _,t in ipairs(targets) do
    TriggerClientEvent("troll:spinCommand", t, seconds)
  end

  logAdminFull(("spin(%ss)"):format(seconds), src, args[1], targets)
end, false)

-- /launch <passaporte|all|near>
RegisterCommand("launch", function(source, args)
  local src = source
  if src ~= 0 and not IsAdminLevel1(src) then notify(src,"Permissão","Sem permissão.","vermelho"); return end

  local targets = resolveTargets(src, args[1])
  if #targets == 0 then if src ~= 0 then notify(src,"Sistema","Alvo inválido.","amarelo") end; return end

  for _,t in ipairs(targets) do
    TriggerClientEvent("troll:launchCommand", t)
  end

  logAdminFull("launch", src, args[1], targets)
end, false)

-- /invert <passaporte|all|near> [seconds]
RegisterCommand("invert", function(source, args)
  local src = source
  if src ~= 0 and not IsAdminLevel1(src) then notify(src,"Permissão","Sem permissão.","vermelho"); return end

  local targets = resolveTargets(src, args[1])
  local dur = tonumber(args[2]) or 12
  if #targets == 0 then if src ~= 0 then notify(src,"Sistema","Alvo inválido.","amarelo") end; return end

  for _,t in ipairs(targets) do
    TriggerClientEvent("troll:invertCommand", t, dur)
  end

  logAdminFull(("invert(%ss)"):format(dur), src, args[1], targets)
end, false)


----------------------------------------------------------
-- HELPERS
----------------------------------------------------------
local function notify(src, title, msg, color, time)
    if src and src > 0 then
        TriggerClientEvent("Notify", src, title or "Troll", msg or "", color or "amarelo", time or 4000)
    else
        print(("[%s] %s"):format(title or "Troll", msg or ""))
    end
end

local function isAdminLevel1(src)
    if src <= 0 then return true end -- consola pode tudo
    local passport = vRP.Passport(src)
    if not passport then return false end
    return vRP.HasPermission(passport, "Admin", 1)
end

local function isOnline(src) return src and GetPlayerName(src) ~= nil end

-- Resolve alvo:
-- - IN-GAME: arg = passaporte → converte para source
-- - CONSOLA: arg = source → usa diretamente
local function resolveTargetSrc(callerSrc, arg)
    if callerSrc == 0 then
        local tgtSrc = tonumber(arg or "")
        if tgtSrc and isOnline(tgtSrc) then return tgtSrc end
        return nil, "ID inválido/offline (usa SRC na consola)."
    else
        local tgtPassport = tonumber(arg or "")
        if not tgtPassport then return nil, "Uso: <passaporte>" end
        local tgtSrc = vRP.Source(tgtPassport)
        if not isOnline(tgtSrc) then return nil, "Jogador offline." end
        return tgtSrc
    end
end

---------------------------------------------------------------------
-- /tase <passaporte>  (in-game)  |  tase <src> (consola)
---------------------------------------------------------------------
RegisterCommand("tase", function(source, args)
    if not isAdminLevel1(source) then
        notify(source, "Troll", "Sem permissão.", "vermelho"); return
    end

    local targetSrc, err = resolveTargetSrc(source, args[1])
    if not targetSrc then notify(source, "Troll", err or "Alvo inválido.", "amarelo"); return end

    TriggerClientEvent("troll:client:TaseEffect", targetSrc)
    notify(source, "Troll", "Choque aplicado.", "verde")
end)
