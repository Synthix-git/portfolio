-----------------------------------------------------------------------------------------------------------------------------------------
-- JUMPSCARE - SERVER (Syn Network) | Console = SRC | In-game = PASSAPORTE
-----------------------------------------------------------------------------------------------------------------------------------------
-- vRP
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Active = {} -- [src] = true/false

-----------------------------------------------------------------------------------------------------------------------------------------
-- BLACKLIST CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local USE_LICENSE_BLACKLIST  = false   -- bloqueia por license/steam (todos os chars dessa conta)
local USE_PASSPORT_BLACKLIST = true    -- bloqueia por passaporte específico

local BlacklistLicenses = {
    "license:3a61e278f67c966704a19d070ed45aaec630b3ec", --NÃO DAR JUMPSCARE A MIM (SYN)
}
local BlacklistPassports = {
     1, --NÃO DAR JUMPSCARE A MIM (SYN)
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function isConsole(src) return src == 0 end

local function reply(src,title,msg,color,time)
    if isConsole(src) then
        print(("[JUMPSCARE] %s: %s"):format(title,msg))
    else
        TriggerClientEvent("Notify",src,title,msg,color or "azul",time or 3500)
    end
end

local function isAdmin(src)
    if isConsole(src) then return true end
    local passport = vRP.Passport(src)
    return passport and vRP.HasGroup(passport,"Admin") or false
end

local function playerExists(src)
    src = tonumber(src)
    if not src then return false end
    for _, pid in ipairs(GetPlayers()) do
        if tonumber(pid) == src then return true end
    end
    return false
end

local function isBlacklisted(src)
    if USE_PASSPORT_BLACKLIST then
        local p = vRP.Passport(src)
        if p then
            for _, b in ipairs(BlacklistPassports) do
                if p == b then return true end
            end
        end
    end
    if USE_LICENSE_BLACKLIST then
        local ids = GetPlayerIdentifiers(src) or {}
        for _, id in ipairs(ids) do
            for _, b in ipairs(BlacklistLicenses) do
                if id == b then return true end
            end
        end
    end
    return false
end

-- valida SRC apenas pela lista de players (sem GetPlayerPed server)
local function validSrc(src)
    local num = tonumber(src)
    if not num then return nil end
    if not playerExists(num) then return nil end
    return num
end

-- RESOLUÇÃO DE ALVOS:
--  - Console: args[1] é SRC
--  - In-game: args[1] é PASSAPORTE; converte para SRC via vRP.Source(passport)
local function resolveTarget(source, args)
    if isConsole(source) then
        local srcArg = args and args[1]
        if not srcArg then
            print("[JUMPSCARE] Uso: jumpscareon|jumpscareoff|jumpscare <src>")
            return nil
        end
        return validSrc(srcArg)
    else
        local passArg = args and args[1]
        if not passArg then
            reply(source,"Admin","Indica o <b>passaporte</b> do alvo.","amarelo",4000)
            return nil
        end
        local passport = tonumber(passArg)
        if not passport then
            reply(source,"Admin","Passaporte inválido.","amarelo",4000)
            return nil
        end
        local tgtSrc = vRP.Source(passport)
        if not tgtSrc then
            reply(source,"Admin","Jogador offline (por passaporte).","amarelo",4000)
            return nil
        end
        return validSrc(tgtSrc)
    end
end

local function openFor(targetSrc, caller)
    if isBlacklisted(targetSrc) then
        if caller then reply(caller,"Admin","Esse jogador está na blacklist.","amarelo",4000) end
        return false
    end
    TriggerClientEvent("jumpscare:Open",targetSrc)
    Active[targetSrc] = true
    return true
end

local function closeFor(targetSrc)
    TriggerClientEvent("jumpscare:Close",targetSrc)
    Active[targetSrc] = false
    return true
end

local function toggleFor(targetSrc, caller)
    if Active[targetSrc] then
        return closeFor(targetSrc), false
    else
        local ok = openFor(targetSrc, caller)
        return ok, ok and true or false
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- COMMANDS (Console = SRC | In-game = PASSAPORTE)  — nunca aplica em ti
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("jumpscareon",function(source,args)
    if not isAdmin(source) then return reply(source,"Admin","Sem permissão.","vermelho",3500) end
    local target = resolveTarget(source,args)
    if not target then return end
    if openFor(target, source) and not isConsole(source) then
        reply(source,"Admin","Jumpscare <b>ON</b>.","azul",3000)
    end
end)

RegisterCommand("jumpscareoff",function(source,args)
    if not isAdmin(source) then return reply(source,"Admin","Sem permissão.","vermelho",3500) end
    local target = resolveTarget(source,args)
    if not target then return end
    closeFor(target)
    if not isConsole(source) then
        reply(source,"Admin","Jumpscare <b>OFF</b>.","azul",3000)
    end
end)

RegisterCommand("jumpscare",function(source,args)
    if not isAdmin(source) then return reply(source,"Admin","Sem permissão.","vermelho",3500) end
    local target = resolveTarget(source,args)
    if not target then return end
    local ok, state = toggleFor(target, source)
    if ok and not isConsole(source) then
        reply(source,"Admin", state and "Jumpscare <b>ON</b>." or "Jumpscare <b>OFF</b>.","azul",3000)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- EXPORTS (outros scripts — usam SRC)
-----------------------------------------------------------------------------------------------------------------------------------------
exports("DoJumpscare",function(src)
    local num = validSrc(src)
    if not num then return false end
    return openFor(num, nil)
end)

exports("StopJumpscare",function(src)
    local num = validSrc(src)
    if not num then return false end
    return closeFor(num)
end)
