CreateThread(function()
    local APP_ID = 1400903079515127949
    local ASSET_BIG = "embedded_cover"  -- tem de existir nos Art Assets
    -- local ASSET_SMALL = "tnr_icon" -- opcional

    SetDiscordAppId(APP_ID)
    SetDiscordRichPresenceAsset(ASSET_BIG)
    SetDiscordRichPresenceAssetText("Medusa Roleplay")
    -- SetDiscordRichPresenceAssetSmall(ASSET_SMALL)
    -- SetDiscordRichPresenceAssetSmallText("TNRP")

    -- Função para (re)aplicar botões
    local function applyButtons()
        -- 0 e 1 são os únicos índices válidos
        SetDiscordRichPresenceAction(0, "DISCORD", "https://discord.gg/35XmeNXEDR")
        SetDiscordRichPresenceAction(1, "JOGAR",   "fivem://connect/playmedusa.ovh:30120")
        -- Alternativa se preferires:
        -- SetDiscordRichPresenceAction(1, "JOGAR", "https://cfx.re/join/TEU_CODIGO")
    end

    while true do
        local players = #GetActivePlayers()
        local maxPlayers = GetConvarInt("sv_maxclients", 2048)

        SetRichPresence(("MedusaRP | Jogadores: %d/%d"):format(players, maxPlayers))
        applyButtons() -- reaplica botões em cada ciclo

        Wait(60000) -- 60s
    end
end)
