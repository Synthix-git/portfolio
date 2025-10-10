-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRPS         = Tunnel.getInterface("vRP")
vRP          = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("inventory",Creative)
vGARAGE = Tunnel.getInterface("garages")
vSERVER = Tunnel.getInterface("inventory")

-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
Types = ""
Actived = false
local Swimming = false
local ShotDelay = GetGameTimer()
local Weapon = ""                 -- usado no Cleaner/GunShot
local ScubaMask, ScubaTank = nil, nil

-- Util: mapear hash -> nome do item usado no teu inventário
local WeaponHashToItem = {
    [`WEAPON_PISTOL`] = "WEAPON_PISTOL",
    [`WEAPON_COMBATPISTOL`] = "WEAPON_COMBATPISTOL",
    [`WEAPON_HEAVYPISTOL`] = "WEAPON_HEAVYPISTOL",
    [`WEAPON_VINTAGEPISTOL`] = "WEAPON_VINTAGEPISTOL",
    [`WEAPON_SNSPISTOL`] = "WEAPON_SNSPISTOL",
    [`WEAPON_SNSPISTOL_MK2`] = "WEAPON_SNSPISTOL_MK2",
    [`WEAPON_PISTOL_MK2`] = "WEAPON_PISTOL_MK2",
    [`WEAPON_PISTOL50`] = "WEAPON_PISTOL50",

    [`WEAPON_MICROSMG`] = "WEAPON_MICROSMG",
    [`WEAPON_MINISMG`] = "WEAPON_MINISMG",
    [`WEAPON_SMG`] = "WEAPON_SMG",
    [`WEAPON_SMG_MK2`] = "WEAPON_SMG_MK2",
    [`WEAPON_ASSAULTSMG`] = "WEAPON_ASSAULTSMG",
    [`WEAPON_MACHINEPISTOL`] = "WEAPON_MACHINEPISTOL",
    [`WEAPON_GUSENBERG`] = "WEAPON_GUSENBERG",

    [`WEAPON_CARBINERIFLE`] = "WEAPON_CARBINERIFLE",
    [`WEAPON_CARBINERIFLE_MK2`] = "WEAPON_CARBINERIFLE_MK2",
    [`WEAPON_SPECIALCARBINE`] = "WEAPON_SPECIALCARBINE",
    [`WEAPON_SPECIALCARBINE_MK2`] = "WEAPON_SPECIALCARBINE_MK2",
    [`WEAPON_ASSAULTRIFLE`] = "WEAPON_ASSAULTRIFLE",
    [`WEAPON_ASSAULTRIFLE_MK2`] = "WEAPON_ASSAULTRIFLE_MK2",
    [`WEAPON_BULLPUPRIFLE`] = "WEAPON_BULLPUPRIFLE",
    [`WEAPON_BULLPUPRIFLE_MK2`] = "WEAPON_BULLPUPRIFLE_MK2",
    [`WEAPON_HEAVYRIFLE`] = "WEAPON_HEAVYRIFLE",
    [`WEAPON_TACTICALRIFLE`] = "WEAPON_TACTICALRIFLE",
    [`WEAPON_ADVANCEDRIFLE`] = "WEAPON_ADVANCEDRIFLE",
    [`WEAPON_COMPACTRIFLE`] = "WEAPON_COMPACTRIFLE",

    [`WEAPON_PUMPSHOTGUN`] = "WEAPON_PUMPSHOTGUN",
    [`WEAPON_PUMPSHOTGUN_MK2`] = "WEAPON_PUMPSHOTGUN_MK2",
    [`WEAPON_SAWNOFFSHOTGUN`] = "WEAPON_SAWNOFFSHOTGUN",

    [`WEAPON_STUNGUN`] = "WEAPON_STUNGUN",
    [`WEAPON_MUSKET`]   = "WEAPON_MUSKET",
    [`WEAPON_PETROLCAN`] = "WEAPON_PETROLCAN",

    -- VIP / custom
    [`WEAPON_BLACKFLAGAR`]   = "WEAPON_BLACKFLAGAR",
    [`WEAPON_BLUEFLAGAR`]    = "WEAPON_BLUEFLAGAR",
    [`WEAPON_YELLOWFLAGAR`]  = "WEAPON_YELLOWFLAGAR",
    [`WEAPON_WHITEFLAGAR`]   = "WEAPON_WHITEFLAGAR",
    [`WEAPON_REDFLAGAR`]     = "WEAPON_REDFLAGAR",
    [`WEAPON_PURPLEFLAGAR`]  = "WEAPON_PURPLEFLAGAR",
    [`WEAPON_PINKFLAGAR`]    = "WEAPON_PINKFLAGAR",
    [`WEAPON_ORANGEFLAGAR`]  = "WEAPON_ORANGEFLAGAR",
    [`WEAPON_GREENFLAGAR`]   = "WEAPON_GREENFLAGAR",

    [`WEAPON_LIGHTRIFLE`]    = "WEAPON_LIGHTRIFLE",
    [`WEAPON_CHINESEAK`]     = "WEAPON_CHINESEAK",
    [`WEAPON_NEVAAR`]        = "WEAPON_NEVAAR",
    [`WEAPON_PUMPKINAR`]     = "WEAPON_PUMPKINAR",
    [`WEAPON_HUNTINGRIFLE`]  = "WEAPON_HUNTINGRIFLE",
    [`WEAPON_XM117`]         = "WEAPON_XM117",
    [`WEAPON_XM4SHADOW`]     = "WEAPON_XM4SHADOW",
    [`WEAPON_PERFORATOR`]    = "WEAPON_PERFORATOR",
    [`WEAPON_TOYM16`]        = "WEAPON_TOYM16",
    [`WEAPON_LIQUIDRIFLE`]   = "WEAPON_LIQUIDRIFLE",
    [`WEAPON_SURVIVORLR300`] = "WEAPON_SURVIVORLR300",
    [`WEAPON_BOMBINGLR`]     = "WEAPON_BOMBINGLR",

    [`WEAPON_UMPV2NEONOIR`]  = "WEAPON_UMPV2NEONOIR",
    [`WEAPON_DEVILSMG`]      = "WEAPON_DEVILSMG",
    [`WEAPON_BIOMP7`]        = "WEAPON_BIOMP7",
    [`WEAPON_PURPLEYOKAI`]   = "WEAPON_PURPLEYOKAI",

    [`WEAPON_CHINESEMK2`]       = "WEAPON_CHINESEMK2",
    [`WEAPON_THERMPISTOLTR`]    = "WEAPON_THERMPISTOLTR",
    [`WEAPON_CHINESESNS`]       = "WEAPON_CHINESESNS",
    [`WEAPON_CHINESEVINTAGE`]   = "WEAPON_CHINESEVINTAGE",
    [`WEAPON_CAMOPISTOL`]       = "WEAPON_CAMOPISTOL",
}

local function GetWeaponNameFromHash(hash)
    return WeaponHashToItem[hash] or ""
end

-- === SNAPSHOT DE MUNIÇÃO ===
local function BuildWeaponSnapshot()
    local ped = PlayerPedId()
    local snap = {}
    for hash, name in pairs(WeaponHashToItem or {}) do
        if type(hash) == "number" and name and name ~= "" then
            if HasPedGotWeapon(ped, hash, false) then
                local ammo = GetAmmoInPedWeapon(ped, hash) or 0
                snap[name] = ammo
            end
        end
    end
    return snap
end

local function SendAmmoSnapshot(tag)
    local snap = BuildWeaponSnapshot()
    TriggerServerEvent("inventory:SnapshotAmmo", snap, tag or "")
end

CreateThread(function()
    while true do
        Wait(15000)
        SendAmmoSnapshot("periodic")
    end
end)

AddEventHandler("onResourceStop", function(resName)
	if resName ~= GetCurrentResourceName() then return end
    SendAmmoSnapshot("resourceStop")
	TriggerServerEvent("inventory:ForceStateSavePing")
end)

RegisterNetEvent("inventory:ApplySnapshot")
AddEventHandler("inventory:ApplySnapshot", function(saved)
    if type(saved) ~= "table" then return end
    local ped = PlayerPedId()
    for weaponName, ammo in pairs(saved) do
        local hash = GetHashKey(weaponName)
        if hash ~= 0 and HasPedGotWeapon(ped, hash, false) then
            SetPedAmmo(ped, hash, tonumber(ammo) or 0)
        end
    end
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent("inventory:RequestSnapshot")
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADBLOCKBUTTONS
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local TimeDistance = 999
		local Ped = PlayerPedId()
		if LocalPlayer["state"]["Buttons"] then
			DisableControlAction(0,257,true)
			DisableControlAction(0,75,true)
			DisableControlAction(0,47,true)
			DisablePlayerFiring(Ped,true)
			TimeDistance = 1
		end
		Wait(TimeDistance)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CLEARNER
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("inventory:Cleaner",function(Ped)
	TriggerEvent("hud:Weapon",false)
	RemoveAllPedWeapons(Ped,true)
	TriggerEvent("Weapon","")
	Actived = false
	Weapon = ""
	Types = ""
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- OBJECTEXISTS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.ObjectExists(Coords,Hash,Distance)
	return DoesObjectOfTypeExistAtCoords(Coords[1],Coords[2],Coords[3],Distance or 0.35,Hash,true)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKINTERIOR
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.CheckInterior()
	return GetInteriorFromEntity(PlayerPedId()) ~= 0
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKWATER
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.CheckWater()
	return IsPedSwimming(PlayerPedId())
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- ZONAS (polícia/tiros)
-----------------------------------------------------------------------------------------------------------------------------------------
local LosSantos = PolyZone:Create({
	vec2(-2153.08,-3131.33),
	vec2(-1581.58,-2092.38),
	vec2(-3271.05,275.85),
	vec2(-3460.83,967.42),
	vec2(-3202.39,1555.39),
	vec2(-1642.50,993.32),
	vec2(312.95,1054.66),
	vec2(1313.70,341.94),
	vec2(1739.01,-1280.58),
	vec2(1427.42,-3440.38),
	vec2(-737.90,-3773.97)
},{ name = "Santos" })

local SandyShores = PolyZone:Create({
	vec2(-375.38,2910.14),
	vec2(307.66,3664.47),
	vec2(2329.64,4128.52),
	vec2(2349.93,4578.50),
	vec2(1680.57,4462.48),
	vec2(1570.01,4961.27),
	vec2(1967.55,5203.67),
	vec2(2387.14,5273.98),
	vec2(2735.26,4392.21),
	vec2(2512.33,3711.16),
	vec2(1681.79,3387.82),
	vec2(258.85,2920.16)
},{ name = "Sandy" })

local PaletoBay = PolyZone:Create({
	vec2(-529.40,5755.14),
	vec2(-234.39,5978.46),
	vec2(278.16,6381.84),
	vec2(672.67,6434.39),
	vec2(699.56,6877.77),
	vec2(256.59,7058.49),
	vec2(17.64,7054.53),
	vec2(-489.45,6449.50),
	vec2(-717.59,6030.94)
},{ name = "Paleto" })

-----------------------------------------------------------------------------------------------------------------------------------------
-- CEVENTGUNSHOT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("CEventGunShot",function(_,OtherPeds)
	local Ped = PlayerPedId()
	if Ped == OtherPeds and not CheckPolice() and GetGameTimer() >= ShotDelay and Weapon ~= "WEAPON_MUSKET" then
		ShotDelay = GetGameTimer() + 60000
		TriggerEvent("player:Residual","Resíduo de Pólvora")

		local Coords = GetEntityCoords(Ped)
		if not IsPedCurrentWeaponSilenced(Ped) then
			if (LosSantos:isPointInside(Coords) or SandyShores:isPointInside(Coords) or PaletoBay:isPointInside(Coords)) then
				vSERVER.ShotsFired(IsPedInAnyVehicle(Ped))
			end
		else
			if math.random(100) >= 75 and (LosSantos:isPointInside(Coords) or SandyShores:isPointInside(Coords) or PaletoBay:isPointInside(Coords)) then
				vSERVER.ShotsFired(IsPedInAnyVehicle(Ped))
			end
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADLEAVESERVICE
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local Ped = PlayerPedId()
		if not IsPedInAnyVehicle(Ped) then
			if LocalPlayer["state"]["Restaurante"] then
				local Coords = GetEntityCoords(Ped)
				if not Restaurante:isPointInside(Coords) then
					TriggerServerEvent("dynamic:ExitService","Restaurante")
				end
			end

			if IsPedSwimming(Ped) then
				if not Swimming and not ScubaTank and not ScubaMask then
					Swimming = true
					vSERVER.Swimming()
				end
			elseif Swimming then
				Swimming = false
			end
		end
		Wait(10000)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SYN STATE HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Reloading")
AddEventHandler("inventory:Reloading", function(ms)
    LocalPlayer.state:set("Reloading", true, true)
    Wait(ms or 1500)
    LocalPlayer.state:set("Reloading", false, true)
end)

RegisterNetEvent("inventory:RemoveWeapon")
AddEventHandler("inventory:RemoveWeapon", function(weaponName)
    if not weaponName or weaponName == "" then return end
    local ped  = PlayerPedId()
    local hash = GetHashKey(weaponName)
    if hash == 0 or not HasPedGotWeapon(ped, hash, false) then return end

    -- Zera a munição local antes de remover para impedir re-seed/dup drain
    SetPedAmmo(ped, hash, 0)
    Wait(50)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    RemoveWeaponFromPed(ped, hash)

    TriggerEvent("hud:Weapon", false)
    TriggerEvent("Weapon", "")
    Actived = false
    Weapon  = ""
    Types   = ""
end)

function Creative.CurrentAmmo(weaponName)
    if not weaponName or weaponName == "" then return 0 end
    local ped  = PlayerPedId()
    local hash = GetHashKey(weaponName)
    if hash ~= 0 and HasPedGotWeapon(ped, hash, false) then
        local ammo = GetAmmoInPedWeapon(ped, hash)
        return ammo or 0
    end
    return 0
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOOP PREVENT WEAPONS
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(750)
        local ped = PlayerPedId()
        local hash = GetSelectedPedWeapon(ped)
        if hash == `WEAPON_UNARMED` then goto continue end
        if LocalPlayer.state.Reloading or IsPedReloading(ped) then goto continue end
        local wepName = GetWeaponNameFromHash(hash)
        if wepName == "" then goto continue end
        local ammo = GetAmmoInPedWeapon(ped, hash)
        local ok = vSERVER.PreventWeapons(wepName, ammo)
        if not ok then
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
            RemoveWeaponFromPed(ped, hash)
        end
        ::continue::
    end
end)


AddEventHandler("onResourceStop", function(resName)
	if resName ~= GetCurrentResourceName() then return end
	TriggerServerEvent("inventory:ForceStateSavePing")
end)

-- Attachments helpers
RegisterNetEvent("inventory:ClearComponents")
AddEventHandler("inventory:ClearComponents", function(weaponName, components)
    if not weaponName or type(components) ~= "table" then return end
    local ped  = PlayerPedId()
    local hash = GetHashKey(weaponName)
    if hash == 0 or not HasPedGotWeapon(ped, hash, false) then return end
    for _, compHash in ipairs(components) do
        if compHash then RemoveWeaponComponentFromPed(ped, hash, compHash) end
    end
end)

RegisterNetEvent("inventory:ApplyComponents")
AddEventHandler("inventory:ApplyComponents", function(weaponName, components)
    if not weaponName or type(components) ~= "table" then return end
    local ped  = PlayerPedId()
    local hash = GetHashKey(weaponName)
    if hash == 0 or not HasPedGotWeapon(ped, hash, false) then return end
    for _, compHash in ipairs(components) do
        if compHash then GiveWeaponComponentToPed(ped, hash, compHash) end
    end
end)

RegisterNetEvent("inventory:ApplyComponentsBulk")
AddEventHandler("inventory:ApplyComponentsBulk", function(payload)
    if type(payload) ~= "table" then return end
    local ped  = PlayerPedId()
    local hash = GetSelectedPedWeapon(ped)
    if not hash or hash == `WEAPON_UNARMED` then
        for i=1,10 do
            Wait(50)
            ped  = PlayerPedId()
            hash = GetSelectedPedWeapon(ped)
            if hash and hash ~= `WEAPON_UNARMED` then break end
        end
        if not hash or hash == `WEAPON_UNARMED` then return end
    end
    local byHash = (payload.__by == "hash") and (payload.data or {}) or nil
    local comps  = byHash and ( byHash[hash] or byHash[tostring(hash)] )
    if (not comps or #comps == 0) and payload.__by ~= "hash" then
        local name = GetWeaponNameFromHash(hash)
        if name ~= "" then comps = payload[name] end
    end
    if not comps or #comps == 0 then return end
    for _, compHash in ipairs(comps) do
        if compHash and not HasPedGotWeaponComponent(ped, hash, compHash) then
            GiveWeaponComponentToPed(ped, hash, compHash)
        end
    end
end)

-- Reaplicar attachs/ammo no arranque e 1ª vez de cada arma
local AppliedOnce, lastHash = {}, 0
CreateThread(function()
    Wait(1500)
    local ped  = PlayerPedId()
    local hash = GetSelectedPedWeapon(ped)
    if hash and hash ~= `WEAPON_UNARMED` then
        local name = GetWeaponNameFromHash(hash)
        if name ~= "" then
            local ammo = GetAmmoInPedWeapon(ped, hash) or 0
            vSERVER.VerifyWeapon(name, ammo, true)
        end
        vSERVER.ReapplyAttachs()
        AppliedOnce[hash] = true
        lastHash = hash
    end
end)

CreateThread(function()
    while true do
        Wait(200)
        local ped  = PlayerPedId()
        local hash = GetSelectedPedWeapon(ped)
        if hash and hash ~= `WEAPON_UNARMED` and hash ~= lastHash then
            lastHash = hash
            if not AppliedOnce[hash] then
                local name = GetWeaponNameFromHash(hash)
                if name ~= "" then
                    local ammo = GetAmmoInPedWeapon(ped, hash) or 0
                    vSERVER.VerifyWeapon(name, ammo, true)
                end
                vSERVER.ReapplyAttachs()
                SetTimeout(250, function() vSERVER.ReapplyAttachs() end)
                AppliedOnce[hash] = true
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local ped  = PlayerPedId()
        local hash = GetSelectedPedWeapon(ped)
        if hash and hash ~= `WEAPON_UNARMED` then
            local name = GetWeaponNameFromHash(hash)
            if name ~= "" then
                local ammo = GetAmmoInPedWeapon(ped, hash) or 0
                vSERVER.VerifyWeapon(name, ammo, false)
            end
        end
    end
end)

--------------- BUGFIX ARREMESSOS
local THROWABLES = {
    WEAPON_BRICK = true,
    WEAPON_SNOWBALL = true,
    WEAPON_SHOES = true,
    WEAPON_MOLOTOV = true,
    WEAPON_SMOKEGRENADE = true
}

local function nameFromHash(hash)
    for n in pairs(THROWABLES) do
        if GetHashKey(n) == hash then return n end
    end
end

CreateThread(function()
    local lastAmmo, lastWeapon = 0, 0
    local busy = false
    while true do
        local ped = PlayerPedId()
        local cur = GetSelectedPedWeapon(ped)
        local name = nameFromHash(cur)
        if name then
            if cur ~= lastWeapon then
                lastWeapon = cur
                lastAmmo = GetAmmoInPedWeapon(ped, cur) or 0
                TriggerServerEvent("inventory:requestThrowableAmmo", name)
            end
            local nowAmmo = GetAmmoInPedWeapon(ped, cur) or 0
            if not busy and (IsPedShooting(ped) or nowAmmo < lastAmmo) then
                busy = true
                TriggerServerEvent("inventory:consumeThrowable", name)
                SetTimeout(200, function() busy = false end)
            end
            lastAmmo = nowAmmo
        else
            lastWeapon, lastAmmo = 0, 0
        end
        Wait(50)
    end
end)

