---------------------------------------------------------------------
-- VRP
---------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP  = Proxy.getInterface("vRP")
vRPC = Tunnel.getInterface("vRP")

---------------------------------------------------------------------
-- INTERFACE
---------------------------------------------------------------------
local Creative = {}
Tunnel.bindInterface("autoschool", Creative)
vCLIENT = Tunnel.getInterface("autoschool")

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local function notify(src, title, msg, color, time)
    TriggerClientEvent("Notify", src, title or "Autoescola", msg or "", color or "azul", time or 5000)
end

local function findCategoryByLabelOrId(input)
    for _, c in ipairs(AutoSchool.Categories or {}) do
        if c.label == input or c.id == input then
            return c
        end
    end
    return nil
end

--  Licenças em SrvData (TEMP e FINAL) 
local USE_GROUPS_COMPAT = false -- se true, também dá grupo final quando promove

local function KEY_FINAL(pid) return ("AutoSchool:Licenses:%s"):format(pid) end
local function KEY_TEMP(pid)  return ("AutoSchool:TempLicenses:%s"):format(pid) end

local function GetSrvTable(key)
    local data = vRP.GetSrvData(key) or {}
    if type(data) ~= "table" then data = {} end
    return data
end

local function HasFinal(pid, id) local t = GetSrvTable(KEY_FINAL(pid)); return t[id] == true end
local function HasTemp(pid, id)  local t = GetSrvTable(KEY_TEMP(pid));  return t[id] == true end

local function SaveTemp(pid, id)
    local t = GetSrvTable(KEY_TEMP(pid));  t[id] = true; vRP.SetSrvData(KEY_TEMP(pid), t, true)
end
local function PromoteToFinal(pid, id, group)
    local tmp = GetSrvTable(KEY_TEMP(pid));  tmp[id] = nil; vRP.SetSrvData(KEY_TEMP(pid), tmp, true)
    local fin = GetSrvTable(KEY_FINAL(pid)); fin[id] = true; vRP.SetSrvData(KEY_FINAL(pid), fin, true)
    if USE_GROUPS_COMPAT and group then
        vRP.SetPermission(pid, group, 1)
    end
end

---------------------------------------------------------------------
-- PUBLIC API
---------------------------------------------------------------------
-- Teórico → concede TEMP (com taxa)
function Creative.FinishExam(categoryChosen, score)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return false end

    local cat = findCategoryByLabelOrId(categoryChosen)
    if not cat then
        notify(src, "Autoescola", "Categoria <b>inválida</b>.", "vermelho", 5000); return false
    end

    local threshold = AutoSchool.PassThreshold or 70
    local nscore = tonumber(score) or 0
    if nscore < threshold then
        notify(src, "Autoescola", ("Reprovado. Pontuação: <b>%d%%</b> (mínimo %d%%)."):format(nscore, threshold), "vermelho", 6000)
        return false
    end

    if HasFinal(Passport, cat.id) then
        notify(src, "Autoescola", "Já possuis a licença <b>"..cat.id.."</b> definitiva.", "amarelo", 5000)
        return false
    end
    if HasTemp(Passport, cat.id) then
        notify(src, "Autoescola", "Já tens a licença <b>temporária</b> da categoria <b>"..cat.id.."</b>.", "amarelo", 6000)
        return true
    end

    local price = tonumber(cat.price) or 0
    if price > 0 then
        if not vRP.PaymentFull(Passport, price) then
            notify(src, "Autoescola", "Dinheiro <b>insuficiente</b> para pagar a taxa de <b>$"..price.."</b>.", "vermelho", 6000)
            return false
        end
        if exports["bank"] and exports["bank"].AddTaxs then
            exports["bank"]:AddTaxs(Passport, price, "Taxa de carta "..cat.id.." (teórico)", "Autoescola", false)
        end
    end

    SaveTemp(Passport, cat.id)
    notify(src, "Autoescola", "Teórico <b>aprovado</b>! Recebeste a <b>licença temporária</b> de <b>"..cat.id.."</b>. Faz a <b>aula prática</b> para obter a habilitação definitiva.", "verde", 9000)
    return true
end

-- Gate para iniciar prática (precisa de TEMP e não ter FINAL)
function Creative.CanDoPractice(categoryChosen)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return false end
    local cat = findCategoryByLabelOrId(categoryChosen)
    if not cat then return false end
    if HasFinal(Passport, cat.id) then return false end
    if not HasTemp(Passport, cat.id) then return false end
    return true
end

-- Prática → promove TEMP → FINAL
function Creative.FinishPractice(categoryChosen)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return false end

    local cat = findCategoryByLabelOrId(categoryChosen)
    if not cat then
        notify(src, "Autoescola", "Categoria <b>inválida</b>.", "vermelho", 5000); return false
    end

    if HasFinal(Passport, cat.id) then
        notify(src, "Autoescola", "Já possuis a licença <b>"..cat.id.."</b> definitiva.", "amarelo", 5000)
        return false
    end

    if not HasTemp(Passport, cat.id) then
        notify(src, "Autoescola", "Precisas de <b>licença temporária</b> para fazer a prática.", "amarelo", 7000)
        return false
    end

    PromoteToFinal(Passport, cat.id, cat.group)
    notify(src, "Autoescola", "Parabéns! Aula prática <b>concluída</b>. Licença <b>"..cat.id.."</b> definitiva atribuída.", "verde", 7000)
    return true
end

---------------------------------------------------------------------
-- POSSE TEMPORÁRIA DO VEÍCULO DE PRÁTICA (sem natives client aqui)
---------------------------------------------------------------------
local function NormalizePlate(p) return tostring(p or ""):upper():gsub("%s+","") end

RegisterNetEvent("autoschool:RegisterPractice", function(plate, netId)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return end

    local up = NormalizePlate(plate)
    if up == "" then return end

    local Plates = GlobalState["Plates"] or {}
    Plates[up] = Passport
    GlobalState.Plates = Plates

    -- avisa o cliente para ligar motor e libertar condução
    TriggerClientEvent("autoschool:PracticeRegistered", src, netId)
end)

RegisterNetEvent("autoschool:UnregisterPractice", function(plate)
    local up = NormalizePlate(plate)
    if up == "" then return end
    local Plates = GlobalState["Plates"] or {}
    if Plates[up] then
        Plates[up] = nil
        GlobalState.Plates = Plates
    end
end)

---------------------------------------------------------------------
-- /habilitacoes
---------------------------------------------------------------------
RegisterCommand("cartas", function(source)
    local pid = vRP.Passport(source); if not pid then return end
    local finals = GetSrvTable(KEY_FINAL(pid))
    local temps  = GetSrvTable(KEY_TEMP(pid))

    local outF, outT = {}, {}
    if finals["A"] then outF[#outF+1] = "A" end
    if finals["B"] then outF[#outF+1] = "B" end
    if finals["C"] then outF[#outF+1] = "C" end
    if finals["D"] then outF[#outF+1] = "D" end

    if temps["A"] and not finals["A"] then outT[#outT+1] = "A" end
    if temps["B"] and not finals["B"] then outT[#outT+1] = "B" end
    if temps["C"] and not finals["C"] then outT[#outT+1] = "C" end
    if temps["D"] and not finals["D"] then outT[#outT+1] = "D" end

    local msg = {}
    msg[#msg+1] = "Habilitações:"
    if #outF > 0 then msg[#msg+1] = "<b>Definitivas:</b> "..table.concat(outF,", ") end
    if #outT > 0 then msg[#msg+1] = "<b>Temporárias:</b> "..table.concat(outT,", ") end
    if #outF==0 and #outT==0 then
        TriggerClientEvent("Notify", source, "Autoescola", "Não tens habilitações.", "amarelo", 5000)
    else
        TriggerClientEvent("Notify", source, "Autoescola", table.concat(msg, "<br>"), "azul", 9000)
    end
end)

---------------------------------------------------------------------
-- STAFF COMMANDS (Policia/Admin) — logs em "Apreensoes"
---------------------------------------------------------------------
local function isStaffOrPolice(src)
    local pid = vRP.Passport(src)
    if not pid then return false end
    if vRP.HasGroup(pid,"Admin") or vRP.HasGroup(pid,"Policia") then
        return true
    end
    return false
end

-- remove tudo (TEMP + FINAL)
RegisterCommand("apagarcarta", function(source, args)
    if not isStaffOrPolice(source) then
        notify(source, "Autoescola", "Sem permissão.", "vermelho", 4000); return
    end
    local tPid = tonumber(args[1] or "")
    if not tPid then
        notify(source, "Autoescola", "Uso: /apagarcarta <passaporte>", "amarelo", 8000); return
    end

    local finals = GetSrvTable(KEY_FINAL(tPid))
    local temps  = GetSrvTable(KEY_TEMP(tPid))
    finals["A"], finals["B"], finals["C"], finals["D"] = nil, nil, nil, nil
    temps["A"],  temps["B"],  temps["C"],  temps["D"]  = nil, nil, nil, nil
    vRP.SetSrvData(KEY_FINAL(tPid), finals, true)
    vRP.SetSrvData(KEY_TEMP(tPid),  temps,  true)

    notify(source, "Autoescola", "Todas as licenças <b>apagadas</b> do passaporte <b>"..tPid.."</b>.", "azul", 7000)
    local tSrc = vRP.Source(tPid)
    if tSrc then
        TriggerClientEvent("Notify", tSrc, "Autoescola", "As tuas licenças foram <b>apagadas</b>.", "amarelo", 8000)
    end
    if exports["discord"] and exports["discord"].Embed then
        exports["discord"]:Embed("Apreensoes",
            ("📋 **Apagar Carta (todas)**\n• Cidadão: **#%s**\n• Staff: **#%s**"):format(tPid, vRP.Passport(source) or "?"),
            source)
    end
end)

-- apreender categoria(s) (TEMP+FINAL)
RegisterCommand("apreendercarta", function(source, args)
    if not isStaffOrPolice(source) then
        notify(source, "Autoescola", "Sem permissão.", "vermelho", 4000); return
    end
    local tPid = tonumber(args[1] or "")
    local cat  = args[2] and tostring(args[2]) or "ALL"
    if not tPid then
        notify(source, "Autoescola", "Uso: /apreendercarta <passaporte> [A|B|C|D|ALL]", "amarelo", 8000); return
    end

    local finals = GetSrvTable(KEY_FINAL(tPid))
    local temps  = GetSrvTable(KEY_TEMP(tPid))
    local which
    if not cat or cat == "" or cat == "ALL" then
        finals["A"], finals["B"], finals["C"], finals["D"] = nil, nil, nil, nil
        temps["A"],  temps["B"],  temps["C"],  temps["D"]  = nil, nil, nil, nil
        which = "todas"
    else
        local id = string.upper(cat)
        finals[id] = nil
        temps[id]  = nil
        which = id
    end
    vRP.SetSrvData(KEY_FINAL(tPid), finals, true)
    vRP.SetSrvData(KEY_TEMP(tPid),  temps,  true)

    notify(source, "Autoescola", "Licenças <b>"..which.."</b> apreendidas do passaporte <b>"..tPid.."</b>.", "azul", 7000)
    local tSrc = vRP.Source(tPid)
    if tSrc then
        TriggerClientEvent("Notify", tSrc, "Autoescola", "As tuas licenças <b>"..which.."</b> foram <b>apreendidas</b>.", "amarelo", 8000)
    end
    if exports["discord"] and exports["discord"].Embed then
        exports["discord"]:Embed("Apreensoes",
            ("📋 **Apreensão de Carta**\n• Licenças: **%s**\n• Cidadão: **#%s**\n• Staff: **#%s**")
            :format(which, tPid, vRP.Passport(source) or "?"),
        source)
    end
end)

-- devolver FINAL de 1 categoria
RegisterCommand("devolvercarta", function(source, args)
    if not isStaffOrPolice(source) then
        notify(source, "Autoescola", "Sem permissão.", "vermelho", 4000); return
    end
    local tPid = tonumber(args[1] or "")
    local id   = args[2] and string.upper(tostring(args[2])) or nil
    if not tPid or not id or not ({A=true,B=true,C=true,D=true})[id] then
        notify(source, "Autoescola", "Uso: /devolvercarta <passaporte> <A|B|C|D>", "amarelo", 8000); return
    end

    local finals = GetSrvTable(KEY_FINAL(tPid)); finals[id] = true
    vRP.SetSrvData(KEY_FINAL(tPid), finals, true)

    notify(source, "Autoescola", "Licença <b>"..id.."</b> devolvida ao passaporte <b>"..tPid.."</b>.", "verde", 7000)
    local tSrc = vRP.Source(tPid)
    if tSrc then
        TriggerClientEvent("Notify", tSrc, "Autoescola", "A tua licença <b>"..id.."</b> foi <b>devolvida</b>.", "verde", 8000)
    end
    if exports["discord"] and exports["discord"].Embed then
        exports["discord"]:Embed("Apreensoes",
            ("📋 **Devolução de Carta**\n• Licença: **%s**\n• Cidadão: **#%s**\n• Staff: **#%s**")
            :format(id, tPid, vRP.Passport(source) or "?"),
        source)
    end
end)

---------------------------------------------------------------------
-- /cancelarteorica (cancela exame em curso do próprio)
---------------------------------------------------------------------
RegisterCommand("cancelarteorica", function(source)
    TriggerClientEvent("autoschool:CancelTheory", source)
end)
