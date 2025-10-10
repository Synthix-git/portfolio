Config = Config or {}


Config.itemName = "bodybag"
Config.hospitalCoords = vector3(262.2,-1340.09,25.54)

Config.onlyOnDead = false                 -- true = só mortos; false = também vivos (facilita testar o saco)
Config.requireLineOfSight = false
Config.maxDistance = 3.5

-- Anima rápida (estilo mecânico)
Config.anim = {
  durationMs   = 1200,
  speedMult    = 1.85,
  progressText = "Ensacando..."
}

-- Prop do saco
Config.propModel      = "xm_prop_body_bag"
Config.propDurationMs = 10000

-- Anti-spam (server)
Config.actionCooldownMs = 0
Config.maxPerArea       = 50

-- Logs (recurso 'discord')
Config.logsChannel = "Socorro"

-- Debug
Config.debug = false

-- Notify padrão Syn
Config.notify = {
  ok        = { "Hospital", "Corpo <b>despachado para o hospital</b>.","verde", 5000 },
  need_item = { "Item", "Precisas de <b>bodybag</b>.","amarelo", 5000 },
  busy      = { "Ação", "Sem alvo válido.","amarelo", 5000 },
  cooldown  = { "Ação", "Aguarda antes de usar novamente.","amarelo", 5000 },
  self_block= { "Ação", "Não podes usar em ti próprio.","vermelho", 5000 },
  los_fail  = { "Ação", "Sem linha de visão para o alvo.","vermelho", 5000 },
  not_dead  = { "Ação", "Só podes despachar <b>alvos abatidos</b>.","vermelho", 5000 }
}
