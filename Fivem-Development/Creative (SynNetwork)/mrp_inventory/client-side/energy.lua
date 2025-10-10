local energyActive = false
local energyEndsAt = 0
local originalRunMult = 1.0

local function resetEnergy()
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    energyActive = false
    energyEndsAt = 0
    LocalPlayer.state:set("EnergyBoost", false, true)
end

RegisterNetEvent("syn:energy:apply")
AddEventHandler("syn:energy:apply", function(Duration, Mult)
    if type(Duration) ~= "number" or Duration <= 0 then Duration = 30000 end
    if type(Mult) ~= "number" or Mult <= 1.0 then Mult = 1.20 end
    if Mult > 1.49 then Mult = 1.49 end

    local now = GetGameTimer()
    local newEnds = now + Duration
    energyEndsAt = math.max(energyEndsAt or 0, newEnds)

    -- primeira aplicação
    if not energyActive then
        energyActive = true
        LocalPlayer.state:set("EnergyBoost", true, true)
        originalRunMult = 1.0
        SetRunSprintMultiplierForPlayer(PlayerId(), Mult)

        -- aviso inicial
        local totalSec = math.ceil((energyEndsAt - now) / 1000)
        TriggerEvent("Notify","Energético","Efeito ativado. Termina em <b>"..totalSec.."s</b>.","azul",2000)

        CreateThread(function()
            local lastShown = -1
            while energyActive do
                local t = GetGameTimer()
                if t >= (energyEndsAt or 0) then
                    resetEnergy()
                    TriggerEvent("Notify","Energético","O efeito do <b>energético</b> acabou.","amarelo",3000)
                    break
                end

                -- manter stamina cheia
                RestorePlayerStamina(PlayerId(), 1.0)

                -- contador regressivo “inteligente”
                local secsLeft = math.max(0, math.ceil((energyEndsAt - t) / 1000))
                if secsLeft ~= lastShown then
                    if secsLeft <= 9 then
                        -- últimos 9s: 1 notify/segundo
                        TriggerEvent("Notify","Energético","A acabar em <b>"..secsLeft.."s</b>.","amarelo",950)
                        lastShown = secsLeft
                        Wait(250) -- pequena folga
                    elseif secsLeft % 5 == 0 then
                        -- a cada 5s quando >=10s
                        TriggerEvent("Notify","Energético","Resta(m) <b>"..secsLeft.."s</b>.","azul",1200)
                        lastShown = secsLeft
                    end
                end

                Wait(200)
            end
        end)
    else
        -- já ativo e foi estendido: avisar novo tempo restante
        local secsLeft = math.ceil((energyEndsAt - now) / 1000)
        TriggerEvent("Notify","Energético","Efeito prolongado. Termina em <b>"..secsLeft.."s</b>.","azul",1500)
    end
end)

AddEventHandler("baseevents:onPlayerDied", resetEnergy)
AddEventHandler("baseevents:onPlayerKilled", resetEnergy)
AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() then resetEnergy() end
end)
