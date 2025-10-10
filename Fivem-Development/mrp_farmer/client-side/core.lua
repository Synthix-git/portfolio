local E_KEY         = 38
local MARKER_TYPE   = 23
local MARKER_SCALE  = vec3(1.2,1.2,1.2)
local MARKER_ALPHA  = 120
local MARKER_COLOR  = {0,122,255}
local MARKER_Z_OFFS = 0.5
local ACTION_DIST   = 1.2
local SHOW_DIST     = 10.0

local isPicking = false
local pickCooldownUntil = 0
local REARM_COOLDOWN = 500
local HARVEST_TIME   = 3000

local locais = {
    vec3(2328.88,5037.48,44.50), vec3(2317.06,5023.74,43.34), vec3(2304.50,4997.42,42.34),
    vec3(2316.42,5008.97,42.55), vec3(2329.84,5022.02,42.93), vec3(2341.58,5035.42,44.35),
    vec3(2343.40,5023.07,43.53), vec3(2330.64,5008.16,42.38), vec3(2316.69,4994.66,42.08),
    vec3(2317.34,4984.96,41.82), vec3(2331.18,4996.83,42.14), vec3(2344.07,5008.24,42.74),
    vec3(2356.67,5021.07,43.89), vec3(2376.12,5017.25,45.43), vec3(2369.10,5011.47,44.35),
    vec3(2360.19,5002.92,43.40), vec3(2349.17,4989.89,43.04), vec3(2335.94,4976.43,42.61),
    vec3(2348.82,4976.08,42.76), vec3(2361.22,4989.10,43.31), vec3(2377.16,5004.32,44.59),
    vec3(2389.36,5004.97,45.74), vec3(2389.64,4992.76,45.17), vec3(2373.69,4989.28,43.99),
    vec3(2361.40,4976.76,43.23)
}

CreateThread(function()
    while true do
        local sleep = 1000
        local ped   = PlayerPedId()
        local pos   = GetEntityCoords(ped)

        for _,pt in ipairs(locais) do
            local d = #(pos - pt)
            if d <= SHOW_DIST then
                sleep = 1
                DrawMarker(
                    MARKER_TYPE, pt.x, pt.y, pt.z - MARKER_Z_OFFS,
                    0.0,0.0,0.0, 0.0,0.0,0.0,
                    MARKER_SCALE.x, MARKER_SCALE.y, MARKER_SCALE.z,
                    MARKER_COLOR[1], MARKER_COLOR[2], MARKER_COLOR[3], MARKER_ALPHA,
                    false,false,2,false,nil,nil,false
                )
                if d <= ACTION_DIST and not isPicking and GetGameTimer() >= pickCooldownUntil then
                    if IsControlJustPressed(0, E_KEY) then
                        isPicking = true
                        FreezeEntityPosition(ped, true)
                        TriggerEvent("Progress","",HARVEST_TIME)
                        RequestAnimDict("amb@prop_human_movie_bulb@base")
                        while not HasAnimDictLoaded("amb@prop_human_movie_bulb@base") do
                            Wait(0)
                        end
                        TaskPlayAnim(ped,"amb@prop_human_movie_bulb@base","base",8.0,8.0,-1,1,0,false,false,false)
                        Wait(HARVEST_TIME)
                        ClearPedTasksImmediately(ped)
                        FreezeEntityPosition(ped, false)
                        isPicking = false
                        pickCooldownUntil = GetGameTimer() + REARM_COOLDOWN
                        TriggerServerEvent("farmer:tryPick")
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Blip da área
CreateThread(function()
    local c = vec3(2344.95, 4998.09, 42.60)
    local r = 50.0
    local area = AddBlipForRadius(c.x,c.y,c.z,r)
    SetBlipColour(area,2)
    SetBlipAlpha(area,120)
    local icon = AddBlipForCoord(c.x,c.y,c.z)
    SetBlipSprite(icon,615)
    SetBlipDisplay(icon,4)
    SetBlipScale(icon,0.5)
    SetBlipAsShortRange(icon,true)
    SetBlipColour(icon,2)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Quinta - Zona de Frutas")
    EndTextCommandSetBlipName(icon)
end)
