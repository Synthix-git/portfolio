---------------------------------------------
-- Throwable -> Controle no CLIENT
-- Autor: Synthix (ajustes: fix duplo consumo)
---------------------------------------------

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

-- loop: detecta uso/consumo de arremessáveis (anti-duplo)
CreateThread(function()
    local lastAmmo, lastWeapon = 0, 0
    local lastName = nil
    local busy = false
    local lastShotAt = 0
    local sleep = 1000

    while true do
        local ped = PlayerPedId()
        local curHash = GetSelectedPedWeapon(ped)
        local name = nameFromHash(curHash)

        if name then
            sleep = 0
            -- ao equipar: sincroniza a “munição” com quantidade do item no inventário
            if curHash ~= lastWeapon then
                lastWeapon = curHash
                lastName = name
                lastAmmo = GetAmmoInPedWeapon(ped, curHash) or 0
                TriggerServerEvent("inventory:requestThrowableAmmo", name)
            end

            local nowAmmo = GetAmmoInPedWeapon(ped, curHash) or 0
            local shooting = IsPedShooting(ped)

            -- Dispara UMA fonte de verdade por lançamento:
            -- 1º preferimos o evento de tiro; só se NÃO estiver a atirar,
            -- usamos o fallback de "queda de munição".
            if not busy then
                if shooting then
                    busy = true
                    lastShotAt = GetGameTimer()
                    TriggerServerEvent("inventory:consumeThrowable", name)
                    SetTimeout(600, function() busy = false end) -- debounce mais folgado
                elseif nowAmmo < lastAmmo then
                    -- evita duplicar se ainda estamos na janela do tiro
                    if GetGameTimer() - lastShotAt > 150 then
                        busy = true
                        TriggerServerEvent("inventory:consumeThrowable", name)
                        SetTimeout(600, function() busy = false end)
                    end
                end
            end

            lastAmmo = nowAmmo
        else
            lastWeapon, lastAmmo, lastName = 0, 0, nil
        end

        Wait(sleep)
    end
end)

-- server -> seta a “munição” do arremessável (quantidade de itens)
RegisterNetEvent("inventory:setThrowableAmmo")
AddEventHandler("inventory:setThrowableAmmo", function(weaponName, amount)
    if type(weaponName) ~= "string" then return end
    local ped  = PlayerPedId()
    local hash = GetHashKey(weaponName)
    if hash == 0 then return end

    if not HasPedGotWeapon(ped, hash, false) then
        GiveWeaponToPed(ped, hash, 0, false, false)
    end

    amount = tonumber(amount) or 0
    if amount < 0 then amount = 0 end

    SetPedAmmo(ped, hash, amount)
    -- opcional: se quiser retirar da mão quando zerar, descomentar:
    -- if amount <= 0 and GetSelectedPedWeapon(ped) == hash then
    --     SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    -- end
end)

-- server -> força 0 e opcionalmente desequipa (anti-exploit)
RegisterNetEvent("inventory:enforceThrowable")
AddEventHandler("inventory:enforceThrowable", function(weaponName, amount, unequip)
    if type(weaponName) ~= "string" then return end
    local ped  = PlayerPedId()
    local hash = GetHashKey(weaponName)
    if hash == 0 then return end

    amount = tonumber(amount) or 0
    if amount < 0 then amount = 0 end

    if HasPedGotWeapon(ped, hash, false) then
        SetPedAmmo(ped, hash, amount)
        if (unequip == true) and GetSelectedPedWeapon(ped) == hash then
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        end
    else
        GiveWeaponToPed(ped, hash, amount, false, false)
        if amount <= 0 and unequip == true and GetSelectedPedWeapon(ped) == hash then
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        end
    end
end)
