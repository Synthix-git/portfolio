-- syn_clipboard | client-side
-- Export público: Copy(text)

-- Export: copiar texto via NUI
exports("Copy", function(text)
    if type(text) ~= "string" or text == "" then return false end
    SendNUIMessage({ action = "copy", text = text })
    -- A NUI retorna o resultado via NUI callback "copied"
    return true
end)

-- Também podes usar via evento, se preferires
RegisterNetEvent("syn_clipboard:Copy")
AddEventHandler("syn_clipboard:Copy", function(text)
    if type(text) ~= "string" or text == "" then return end
    SendNUIMessage({ action = "copy", text = text })
end)

-- Recebe confirmação da NUI
RegisterNUICallback("copied", function(data, cb)
    local ok = data and data.ok
    if ok then
        TriggerEvent("Notify","Admin","Copiado para o clipboard: <b>"..(data.text or "").."</b>","verde",4000)
    else
        TriggerEvent("Notify","Admin","Falha ao copiar para o clipboard.","vermelho",5000)
    end
    cb("ok")
end)
