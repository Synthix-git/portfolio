-- server-side/propertys_buckets.lua
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP         = Proxy.getInterface("vRP")

-- Guardamos referência do bind original para apenas “injectar” o Toggle
local OLD = {}
local _bind = Tunnel.bindInterface

-- Função de bucket estável por NOME da propriedade
local function bucketForProperty(propName, altKey)
  -- usa o nome da casa; se vier nil, cai no altKey (ex.: passport/hotel)
  local key = tostring(propName or altKey or "fallback")
  local h = GetHashKey(key)
  if h < 0 then h = h + 0x100000000 end -- unsigned
  -- offset alto para não colidir com outros recursos
  return 12000 + (h % 50000)
end

-- intercepta o bind da interface "propertys"
Tunnel.bindInterface = function(name, tbl)
  if name == "propertys" then
    -- copia métodos antigos (se existirem)
    for k,v in pairs(tbl) do OLD[k] = v end

    -- substitui/injeta Toggle
    tbl.Toggle = function(nameOrInside, action)
      local src = source
      local passport = vRP.Passport(src)

      -- chama lógica antiga (se existir), mas não mexe nos buckets
      if OLD.Toggle then
        local ok, err = pcall(OLD.Toggle, nameOrInside, action)
        if not ok then
          print(("^1[propertys_buckets] OLD.Toggle error: %s^0"):format(tostring(err)))
        end
      end

      -- hotel: cada jogador numa “suíte” própria
      local isHotel = (nameOrInside == "Hotel")

      if action == "Enter" then
        local bucket = isHotel and bucketForProperty(("Hotel:%s"):format(passport), passport)
                               or  bucketForProperty(nameOrInside)
        SetPlayerRoutingBucket(src, bucket)
      else -- "Exit" (ou qualquer outra coisa)
        SetPlayerRoutingBucket(src, 0)
      end
    end
  end

  return _bind(name, tbl)
end

-- segurança extra: garantir reset do bucket ao sair
AddEventHandler("playerDropped", function()
  local src = source
  SetPlayerRoutingBucket(src, 0)
end)
