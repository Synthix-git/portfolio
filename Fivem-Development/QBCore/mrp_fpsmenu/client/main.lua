QBCore = exports['qb-core']:GetCoreObject()

RegisterCommand('fps', function()
    local menu = {
        {
            header = 'MENU DE FPS',
            isMenuHeader = true
        },
        {
            header = 'ULTRA BAIXO',
            txt = 'CONFIGURAÇÕES ULTRA BAIXAS PARA MÁXIMO FPS',
            params = {
                event = 'synthix:applyUltraLow',
                args = {}
            }
        },
        {
            header = 'BAIXO',
            txt = 'MELHOR FPS COM RENDERIZAÇÃO MÍNIMA',
            params = {
                event = 'synthix:applyLowSettings',
                args = {}
            }
        },
        {
            header = 'BOOST RÁPIDO',
            txt = 'EFEITO INTENSO EM TODAS AS PARTÍCULAS PARA MELHOR FPS',
            params = {
                event = 'synthix:applyRapidBoostSettings',
                args = {}
            }
        },
        {
            header = 'BAIXA TEXTURA',
            txt = 'AJUDA A AUMENTAR O FPS REDUZINDO A QUALIDADE DA TEXTURA',
            params = {
                event = 'synthix:applyLowTextureSettings',
                args = {}
            }
        },
        {
            header = 'SEM GPU',
            txt = 'EU SOU POBRE, ENTÃO NÃO TENHO GPU 😭',
            params = {
                event = 'synthix:applyNoGpuSettings',
                args = {}
            }
        },
        {
            header = 'MELHOR GRÁFICOS',
            txt = 'AUMENTAR A QUALIDADE DOS GRÁFICOS (NÃO RECOMENDADO PARA USUÁRIOS DE BAIXO DESEMPENHO)',
            params = {
                event = 'synthix:applyBetterGraphics',
                args = {}
            }
        },
        {
            header = 'VIGNETTE',
            txt = 'MODO VIGNETTE NORMAL PARA SE CONCENTRAR APENAS NO TEU PERSONAGEM E DEIXAR OUTROS ÂNGULOS PRETOS... APENAS UM FILTRO',
            params = {
                event = 'synthix:applyVignette',
                args = {}
            }
        },
        {
            header = 'PRETO E BRANCO',
            txt = 'APENAS VOLTA AOS VELHOS TEMPOS (SEM COR, APENAS P/B)',
            params = {
                event = 'synthix:applyBlackAndWhite',
                args = {}
            }
        },
        {
            header = 'REDEFINIR GRÁFICOS',
            txt = 'REDEFINIR TODAS AS CONFIGURAÇÕES PARA PADRÃO',
            params = {
                event = 'synthix:resetGraphics',
                args = {}
            }
        }
    }

    exports['qb-menu']:openMenu(menu)
end)

-- Event Handlers
RegisterNetEvent('synthix:applyLowSettings', function()
    local ped = PlayerPedId()
    SetTimecycleModifier('exile1_plane')
    ClearAllBrokenGlass()
    ClearAllHelpMessages()
    LeaderboardsReadClearAll()
    ClearBrief()
    ClearGpsFlags()
    ClearPrints()
    ClearSmallPrints()
    ClearReplayStats()
    LeaderboardsClearCacheData()
    ClearFocus()
    ClearHdArea()
    ClearPedBloodDamage(ped)
    ClearPedWetness(ped)
    ClearPedEnvDirt(ped)
    ResetPedVisibleDamage(ped)
    ClearOverrideWeather()
    DisableScreenblurFade()
    SetRainLevel(0.0)
    SetWindSpeed(0.0)
end)

RegisterNetEvent('synthix:applyRapidBoostSettings', function()
    local ped = PlayerPedId()
    SetTimecycleModifier('yell_tunnel_nodirect')
    ClearAllBrokenGlass()
    ClearAllHelpMessages()
    LeaderboardsReadClearAll()
    ClearBrief()
    ClearGpsFlags()
    ClearPrints()
    ClearSmallPrints()
    ClearReplayStats()
    LeaderboardsClearCacheData()
    ClearFocus()
    ClearHdArea()
    ClearPedBloodDamage(ped)
    ClearPedWetness(ped)
    ClearPedEnvDirt(ped)
    ResetPedVisibleDamage(ped)
    ClearOverrideWeather()
    DisableScreenblurFade()
    SetRainLevel(0.0)
    SetWindSpeed(0.0)
end)

RegisterNetEvent('synthix:applyLowTextureSettings', function()
    local ped = PlayerPedId()
    SetTimecycleModifier('v_janitor')
    ClearAllBrokenGlass()
    ClearAllHelpMessages()
    LeaderboardsReadClearAll()
    ClearBrief()
    ClearGpsFlags()
    ClearPrints()
    ClearSmallPrints()
    ClearReplayStats()
    LeaderboardsClearCacheData()
    ClearFocus()
    ClearHdArea()
    ClearPedBloodDamage(ped)
    ClearPedWetness(ped)
    ClearPedEnvDirt(ped)
    ResetPedVisibleDamage(ped)
    ClearOverrideWeather()
    DisableScreenblurFade()
    SetRainLevel(0.0)
    SetWindSpeed(0.0)
end)

RegisterNetEvent('synthix:applyNoGpuSettings', function()
    local ped = PlayerPedId()
    SetTimecycleModifier('HicksbarNEW')
    ClearAllBrokenGlass()
    ClearAllHelpMessages()
    LeaderboardsReadClearAll()
    ClearBrief()
    ClearGpsFlags()
    ClearPrints()
    ClearSmallPrints()
    ClearReplayStats()
    LeaderboardsClearCacheData()
    ClearFocus()
    ClearHdArea()
    ClearPedBloodDamage(ped)
    ClearPedWetness(ped)
    ClearPedEnvDirt(ped)
    ResetPedVisibleDamage(ped)
    ClearOverrideWeather()
    DisableScreenblurFade()
    SetRainLevel(0.0)
    SetWindSpeed(0.0)
end)

RegisterNetEvent('synthix:applyBetterGraphics', function()
    SetTimecycleModifier('v_torture')
    SetExtraTimecycleModifier('reflection_correct_ambient')
end)

RegisterNetEvent('synthix:applyVignette', function()
    SetTimecycleModifier('rply_vignette')
end)

RegisterNetEvent('synthix:applyBlackAndWhite', function()
    SetTimecycleModifier('NG_filmnoir_BW01')
end)

RegisterNetEvent('synthix:resetGraphics', function()
    SetTimecycleModifier()
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
end)

RegisterNetEvent('synthix:applyUltraLow', function()
    local ped = PlayerPedId()
    SetTimecycleModifier('cinema')
    ClearAllBrokenGlass()
    ClearAllHelpMessages()
    LeaderboardsReadClearAll()
    ClearBrief()
    ClearGpsFlags()
    ClearPrints()
    ClearSmallPrints()
    ClearReplayStats()
    LeaderboardsClearCacheData()
    ClearFocus()
    ClearHdArea()
    ClearPedBloodDamage(ped)
    ClearPedWetness(ped)
    ClearPedEnvDirt(ped)
    ResetPedVisibleDamage(ped)
    ClearOverrideWeather()
    DisableScreenblurFade()
    SetRainLevel(0.0)
    SetWindSpeed(0.0)
end)


