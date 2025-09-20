-- client/welcome.lua
local hasSentFirstSpawn = false

AddEventHandler("playerSpawned", function()
  if hasSentFirstSpawn then return end
  hasSentFirstSpawn = true
  TriggerServerEvent("welcome:firstSpawn")
end)

CreateThread(function()
  Wait(15000)
  if not hasSentFirstSpawn then
    hasSentFirstSpawn = true
    TriggerServerEvent("welcome:firstSpawn")
  end
end)
