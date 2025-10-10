-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRPC         = Tunnel.getInterface("vRP")
vRP          = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("trunkchest",Creative)

-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Vehicle = {}                -- [Passport] = { Model, Passport(owner), Weight, Data(key), Plate, PlateKey }
local OpenLocks = {}              -- [DataKey] = Passport (lock por baú)
local DEFAULT_TRUNK_WEIGHT = 50.0 -- peso padrão quando não houver config

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function dprint(...) -- toggle rápido de debug
    if GetConvarInt("trunkchest_debug", 0) == 1 then
        print("[trunkchest]", ...)
    end
end

local function normalizePlate(plate)
    if not plate or plate == "" then return "" end
    return plate:upper():gsub("%s+","")
end

-- Se tiveres uma função global VehicleWeight(model) ela será usada; senão, default.
local function safeWeight(model)
    local w = (type(VehicleWeight) == "function") and VehicleWeight(model) or nil
    if not w or w <= 0 then return DEFAULT_TRUNK_WEIGHT end
    return w
end

local function splitString(str, sep)
    if type(str) ~= "string" then return {} end
    sep = sep or "-"
    local t = {}
    for s in string.gmatch(str, "([^"..sep.."]+)") do
        t[#t+1] = s
    end
    return t
end

local function Notify(src, title, msg, color, time)
    TriggerClientEvent("Notify", src, title, msg, color or "azul", time or 4000)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Mount()
    local source   = source
    local Passport = vRP.Passport(source)

    if not Passport then
        dprint("Mount: Passport nil para source", source)
        return {}, {}, 0, DEFAULT_TRUNK_WEIGHT
    end

    if not Vehicle[Passport] then
        dprint(("Mount: Vehicle[%s] nil (não abriu trunk ainda?)"):format(Passport))
        return {}, {}, vRP.CheckWeight(Passport) or 0, DEFAULT_TRUNK_WEIGHT
    end

    if not Vehicle[Passport]["Data"] then
        dprint(("Mount: Vehicle[%s].Data nil"):format(Passport))
        return {}, {}, vRP.CheckWeight(Passport) or 0, Vehicle[Passport]["Weight"] or DEFAULT_TRUNK_WEIGHT
    end

    local Primary = {}
    local Inv = vRP.Inventory(Passport) or {}
    if type(Inv) ~= "table" then Inv = {} end

    for Index, v in pairs(Inv) do
        if v and type(v) == "table" then
            if (parseInt(v["amount"]) <= 0 or not ItemExist(v["item"])) then
                vRP.RemoveItem(Passport, v["item"], v["amount"] or 0, false)
            else
                v["name"]     = ItemName(v["item"])
                v["weight"]   = ItemWeight(v["item"])
                v["index"]    = ItemIndex(v["item"])
                v["amount"]   = parseInt(v["amount"])
                v["rarity"]   = ItemRarity(v["item"])
                v["economy"]  = ItemEconomy(v["item"])
                v["desc"]     = ItemDescription(v["item"])
                v["key"]      = v["item"]
                v["slot"]     = Index

                local Split = splitString(v["item"],"-")

                if not v["desc"] then
                    if Split[1] == "vehiclekey" and Split[2] then
                        v["desc"] = "Placa do Veículo: <common>"..Split[2].."</common>"
                    elseif (Split[1] == "identity" or Split[1] == "fidentity" or string.sub(v["item"],1,5) == "badge") and Split[2] then
                        v["desc"] = "Passaporte: <rare>"..Dotted(Split[2]).."</rare><br>Nome: <rare>"..(vRP.FullName(Split[2]) or "Indefinido").."</rare><br>Telefone: <rare>"..(vRP.Phone(Split[2]) or "N/D").."</rare>"
                    end
                end

                if Split[2] then
                    local Loaded = ItemLoads(v["item"])
                    if Loaded then v["charges"] = parseInt(Split[2] * (100 / Loaded)) end
                    if ItemDurability(v["item"]) then
                        v["durability"] = parseInt(os.time() - parseInt(Split[2]))
                        v["days"]       = ItemDurability(v["item"])
                    end
                end

                Primary[Index] = v
            end
        end
    end

    local Secondary = {}
    local ChestKey = Vehicle[Passport]["Data"]
    local Result = vRP.GetSrvData(ChestKey, true) or {}
    if type(Result) ~= "table" then Result = {} end

    for Index, v in pairs(Result) do
        if v and type(v) == "table" then
            if (parseInt(v["amount"]) <= 0 or not ItemExist(v["item"])) then
                -- limpa entrada inválida
                Result[Index] = nil
                vRP.SetSrvData(ChestKey, Result, true)
            else
                v["name"]     = ItemName(v["item"])
                v["weight"]   = ItemWeight(v["item"])
                v["index"]    = ItemIndex(v["item"])
                v["amount"]   = parseInt(v["amount"])
                v["rarity"]   = ItemRarity(v["item"])
                v["economy"]  = ItemEconomy(v["item"])
                v["desc"]     = ItemDescription(v["item"])
                v["key"]      = v["item"]
                v["slot"]     = Index

                local Split = splitString(v["item"],"-")

                if not v["desc"] then
                    if Split[1] == "vehiclekey" and Split[2] then
                        v["desc"] = "Placa do Veículo: <common>"..Split[2].."</common>"
                    elseif (Split[1] == "identity" or Split[1] == "fidentity" or string.sub(v["item"],1,5) == "badge") and Split[2] then
                        v["desc"] = "Passaporte: <rare>"..Dotted(Split[2]).."</rare><br>Nome: <rare>"..(vRP.FullName(Split[2]) or "Indefinido").."</rare><br>Telefone: <rare>"..(vRP.Phone(Split[2]) or "N/D").."</rare>"
                    end
                end

                if Split[2] then
                    local Loaded = ItemLoads(v["item"])
                    if Loaded then v["charges"] = parseInt(Split[2] * (100 / Loaded)) end
                    if ItemDurability(v["item"]) then
                        v["durability"] = parseInt(os.time() - parseInt(Split[2]))
                        v["days"]       = ItemDurability(v["item"])
                    end
                end

                Secondary[Index] = v
            end
        end
    end

    local curWeight = vRP.CheckWeight(Passport) or 0
    local trunkCap  = (Vehicle[Passport]["Weight"] and Vehicle[Passport]["Weight"] > 0) and Vehicle[Passport]["Weight"] or DEFAULT_TRUNK_WEIGHT

    return Primary, Secondary, curWeight, trunkCap
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Update(Slot, Target, Amount)
    local source   = source
    local Passport = vRP.Passport(source)
    Amount = parseInt(Amount, true)

    if not Passport then return end
    if not Vehicle[Passport] or not Vehicle[Passport]["Data"] then
        dprint(("Update: Vehicle[%s] ou Data ausente"):format(Passport))
        return
    end

    if vRP.UpdateChest(Passport, Vehicle[Passport]["Data"], Slot, Target, Amount, true) then
        TriggerClientEvent("inventory:Update", source)
    else
        -- mesmo que falhe, garante refresh para não ‘des-sincronizar’
        TriggerClientEvent("inventory:Update", source)
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- STORE
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Store(Item, Slot, Amount, Target)
    local source   = source
    local Passport = vRP.Passport(source)
    Amount = parseInt(Amount)

    if not Passport then return end
    if not Vehicle[Passport] or not Vehicle[Passport]["Data"] or not Vehicle[Passport]["Weight"] then
        dprint(("Store: Vehicle[%s]/Data/Weight ausente"):format(Passport))
        return TriggerClientEvent("inventory:Update", source)
    end

    if not vRP.StoreChest(Passport, Vehicle[Passport]["Data"], Amount, Vehicle[Passport]["Weight"], Slot, Target, true) then
        TriggerClientEvent("inventory:Update", source)

        local FirstName, LastName = vRP.FullName(Passport)
        FirstName = FirstName or "Indefinido"
        LastName  = LastName  or ""

        local OwnerName = "Spawnado"
        if Vehicle[Passport]["Passport"] and vRP.Identity(Vehicle[Passport]["Passport"]) then
            local oFirst, oLast = vRP.FullName(Vehicle[Passport]["Passport"])
            OwnerName = (oFirst or "Indefinido").." "..(oLast or "")
        end

        exports["discord"]:Embed("Malacarro",
            "**🟩 ITEM GUARDADO NO PORTA-MALAS**\n\n"..
            "📦 **Passaporte:** "..Passport..
            "\n👤 **Nome:** "..FirstName.." "..LastName..
            "\n🚗 **Matrícula:** "..(Vehicle[Passport]["Plate"] or "Desconhecida")..
            "\n🧾 **Dono do Veículo:** "..OwnerName..
            "\n📥 **Guardou:** "..Amount.."x "..(ItemName(Item) or Item or "Desconhecido")..
            "\n🕒 **Data & Hora:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M")
        )
    else
        TriggerClientEvent("inventory:Update", source)
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- TAKE
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Take(Item, Slot, Amount, Target)
    local source   = source
    local Passport = vRP.Passport(source)
    Amount = parseInt(Amount, true)

    if not Passport then return end
    if not Vehicle[Passport] or not Vehicle[Passport]["Data"] then
        dprint(("Take: Vehicle[%s] ou Data ausente"):format(Passport))
        return TriggerClientEvent("inventory:Update", source)
    end

    local ItemNameLog = (Item and ItemName(Item)) or "Desconhecido"
    if ItemNameLog == "Desconhecido" then
        local ChestData = vRP.GetSrvData(Vehicle[Passport]["Data"], true) or {}
        if ChestData and ChestData[Slot] and ChestData[Slot]["item"] then
            ItemNameLog = ItemName(ChestData[Slot]["item"]) or "Desconhecido"
        end
    end

    -- vRP.TakeChest retorna FALSE quando deu certo (padrão antigo)
    if not vRP.TakeChest(Passport, Vehicle[Passport]["Data"], Amount, Slot, Target, true) then
        TriggerClientEvent("inventory:Update", source)

        local FirstName, LastName = vRP.FullName(Passport)
        FirstName = FirstName or "Indefinido"
        LastName  = LastName  or ""

        local OwnerName = "Spawnado"
        if Vehicle[Passport]["Passport"] and vRP.Identity(Vehicle[Passport]["Passport"]) then
            local oFirst, oLast = vRP.FullName(Vehicle[Passport]["Passport"])
            OwnerName = (oFirst or "Indefinido").." "..(oLast or "")
        end

        exports["discord"]:Embed("Malacarro",
            "**🟥 ITEM RETIRADO DO PORTA-MALAS**\n\n"..
            "📦 **Passaporte:** "..Passport..
            "\n👤 **Nome:** "..FirstName.." "..LastName..
            "\n🚗 **Matrícula:** "..(Vehicle[Passport]["Plate"] or "Desconhecida")..
            "\n🧾 **Dono do Veículo:** "..OwnerName..
            "\n📤 **Retirou:** "..Amount.."x "..ItemNameLog..
            "\n🕒 **Data & Hora:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M")
        )
    else
        TriggerClientEvent("inventory:Update", source)
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLOSE (liberta o lock do baú)
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Close()
    local source   = source
    local Passport = vRP.Passport(source)
    if Passport and Vehicle[Passport] then
        local dataKey = Vehicle[Passport]["Data"]
        if dataKey and OpenLocks[dataKey] == Passport then
            OpenLocks[dataKey] = nil
        end
        Vehicle[Passport] = nil
        dprint(("Close: limpou estado e lock para %s"):format(Passport))
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- OPEN ENTRY (1 pessoa por vez) — SUPORTA DOIS NOMES DE EVENTO
-----------------------------------------------------------------------------------------------------------------------------------------
local function openTrunkHandler(Entity)
    local source   = source
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if type(Entity) ~= "table" or not Entity[1] or not Entity[2] then
        Notify(source, "Atenção", "Veículo inválido para abrir o porta-malas.", "amarelo", 5000)
        dprint("openTrunk: Entity inválido recebido do client", Entity)
        return
    end

    local rawPlate  = tostring(Entity[1] or "")
    local modelName = tostring(Entity[2] or "")
    local plateKey  = normalizePlate(rawPlate)

    -- Algumas bases guardam pela placa sem espaços, outras com; tenta as duas
    local ownerPassport = vRP.PassportPlate(plateKey) or vRP.PassportPlate(rawPlate) or Passport
    local weight        = safeWeight(modelName)
    local dataKey       = ("Chest:%s:%s:%s"):format(ownerPassport, modelName, plateKey)

    if OpenLocks[dataKey] and OpenLocks[dataKey] ~= Passport then
        Notify(source, "Atenção", "Este porta-malas já está a ser utilizado.", "amarelo", 5000)
        return
    end

    OpenLocks[dataKey] = Passport

    Vehicle[Passport] = {
        ["Model"]    = modelName,
        ["Passport"] = ownerPassport,
        ["Weight"]   = weight,
        ["Data"]     = dataKey,
        ["Plate"]    = rawPlate,
        ["PlateKey"] = plateKey
    }

    dprint(("openTrunk: %s abriu trunk %s (owner %s, cap %.1f)"):format(Passport, dataKey, ownerPassport, weight))

    TriggerClientEvent("trunkchest:Open", source) -- garante que o teu client escuta este evento
end

RegisterServerEvent("trunkchest:openTrunk")
AddEventHandler("trunkchest:openTrunk", openTrunkHandler)

RegisterServerEvent("trunkchest:OpenTrunk") -- alias com maiúscula
AddEventHandler("trunkchest:OpenTrunk", openTrunkHandler)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT (limpa lock ao sair)
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect", function(Passport)
    if Passport and Vehicle[Passport] then
        local dataKey = Vehicle[Passport]["Data"]
        if dataKey and OpenLocks[dataKey] == Passport then
            OpenLocks[dataKey] = nil
        end
        Vehicle[Passport] = nil
        dprint(("Disconnect: limpou estado e lock para %s"):format(Passport))
    end
end)

-- Failsafe: ao parar resource, limpa locks (evita “baú preso” após restart)
AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    for k in pairs(OpenLocks) do OpenLocks[k] = nil end
    for k in pairs(Vehicle)   do Vehicle[k]   = nil end
    dprint("ResourceStop: locks e estado limpos")
end)
