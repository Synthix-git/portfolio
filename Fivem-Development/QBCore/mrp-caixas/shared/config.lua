Config = {}

Config.Rewards = {
    ['illegal_case'] = {
        [1] = {
            item = 'weapon_chinesevintage',
            image = 'img/chinesevintage.png',
            weight = 25,
            quantity = 1,  -- Quantidade aleatória entre 1 e 5
        },
        [2] = {
            item = 'weapon_chinesesns',
            image = 'img/chinesesns.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [3] = {
            item = 'weapon_lucy',
            image = 'img/lucy.png',
            weight = 10,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [4] = {
            item = 'weapon_chinesemk2',
            image = 'img/chinesemk2.png',
            weight = 20,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [5] = {
            item = 'cash',
            image = 'img/cash.png',
            weight = 25,
            amount = 150000,  -- Valor fixo de dinheiro
            isMoney = true,
        },
        [6] = {
            item = 'coins',
            image = 'img/mcoins.png',
            weight = 10,
            amount = 4,  -- Valor fixo de coins
            isCoins = true,
        },
        [7] = {
            item = 'coke1',
            image = 'img/coke.png',
            weight = 50,
            randomQuantity = {min = 150, max = 300},  -- Quantidade aleatória
        },
        [8] = {
            item = 'meth1',
            image = 'img/meth1.png',
            weight = 50,
            randomQuantity = {min = 150, max = 300},  -- Quantidade aleatória
        },
        [9] = {
            item = 'weed1',
            image = 'img/weed1.png',
            weight = 50,
            randomQuantity = {min = 150, max = 300},  -- Quantidade aleatória
        },
    },
    ['pistol_case'] = {
        [1] = {
            item = 'coins',
            image = 'img/mcoins.png',
            weight = 10,
            amount = 4,  -- Valor fixo de coins
            isCoins = true,
        },
        [2] = {
            item = 'weapon_chinesemk2',
            image = 'img/chinesemk2.png',
            weight = 10,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [3] = {
            item = 'weapon_chinesevintage',
            image = 'img/chinesevintage.png',
            weight = 5,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [4] = {
            item = 'weapon_chinesesns',
            image = 'img/chinesesns.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [5] = {
            item = 'weapon_camopistol',
            image = 'img/camoglock.png',
            weight = 15,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [6] = {
            item = 'weapon_snspistol',
            image = 'img/weapon_snspistol.png',
            weight = 90,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [7] = {
            item = 'weapon_combatpistol',
            image = 'img/weapon_combatpistol.png',
            weight = 70,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [8] = {
            item = 'weapon_appistol',
            image = 'img/weapon_appistol.png',
            weight = 20,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [9] = {
            item = 'weapon_pistol',
            image = 'img/weapon_pistol.png',
            weight = 90,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [10] = {
            item = 'weapon_revolver',
            image = 'img/weapon_revolver.png',
            weight = 10,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [11] = {
            item = 'weapon_vintagepistol',
            image = 'img/weapon_vintagepistol.png',
            weight = 70,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [12] = {
            item = 'weapon_pistol50',
            image = 'img/weapon_pistol50.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [13] = {
            item = 'weapon_thermpistoltr',
            image = 'img/thermpistoltr.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [14] = {
            item = 'cash',
            image = 'img/cash.png',
            weight = 35,
            randomQuantity = {min = 50000, max = 100000},  -- Valor aleatório de dinheiro
            isMoney = true,
        },
    },
    ['katana_case'] = {
        [1] = {
            item = 'coins',
            image = 'img/mcoins.png',
            weight = 10,
            amount = 6,  -- Valor fixo de coins
            isCoins = true,
        },
        [2] = {
            item = 'weapon_nichirin',
            image = 'img/nichirin.png',
            weight = 10,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [3] = {
            item = 'weapon_sakaikatana',
            image = 'img/sakaikatana.png',
            weight = 5,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [4] = {
            item = 'weapon_katana',
            image = 'img/weapon_katanas.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [5] = {
            item = 'weapon_lucy',
            image = 'img/lucy.png',
            weight = 15,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [6] = {
            item = 'weapon_cherrykatana',
            image = 'img/cherrykatana.png',
            weight = 10,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [7] = {
            item = 'weapon_knife',
            image = 'img/weapon_knife.png',
            weight = 70,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [8] = {
            item = 'weapon_bat',
            image = 'img/weapon_bat.png',
            weight = 70,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [9] = {
            item = 'weapon_switchblade',
            image = 'img/weapon_switchblade.png',
            weight = 90,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [10] = {
            item = 'weapon_machete',
            image = 'img/weapon_machete.png',
            weight = 70,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [11] = {
            item = 'weapon_knuckle',
            image = 'img/weapon_knuckle.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [12] = {
            item = 'weapon_sledgehammer',
            image = 'img/weapon_sledgehammer.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [13] = {
            item = 'cash',
            image = 'img/cash.png',
            weight = 35,
            randomQuantity = {min = 50000, max = 100000},  -- Valor aleatório de dinheiro
            isMoney = true,
        },
    },
    ['smg_case'] = {
        [1] = {
            item = 'coins',
            image = 'img/mcoins.png',
            weight = 10,
            amount = 6,  -- Valor fixo de coins (10)
            isCoins = true,
        },
        [2] = {
            item = 'weapon_biomp7',
            image = 'img/biomp7.png',
            weight = 20,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [3] = {
            item = 'weapon_umpv2neonoir',
            image = 'img/umpv2neonoir.png',
            weight = 5,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [4] = {
            item = 'weapon_devilsmg',
            image = 'img/devilsmg.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [5] = {
            item = 'weapon_microsmg',
            image = 'img/weapon_microsmg.png',
            weight = 60,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [6] = {
            item = 'weapon_machinepistol',
            image = 'img/weapon_machinepistol.png',
            weight = 60,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [7] = {
            item = 'weapon_minismg',
            image = 'img/weapon_minismg.png',
            weight = 70,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [8] = {
            item = 'weapon_combatpdw',
            image = 'img/weapon_combatpdw.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [9] = {
            item = 'weapon_smg',
            image = 'img/weapon_smg.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [10] = {
            item = 'cash',
            image = 'img/cash.png',
            weight = 35,
            randomQuantity = {min = 100000, max = 150000},  -- Valor aleatório de dinheiro
            isMoney = true,
        },
    },
    ['rifle_case'] = {
        [1] = {
            item = 'coins',
            image = 'img/mcoins.png',
            weight = 10,
            amount = 7,  -- Valor fixo de coins (10)
            isCoins = true,
        },
        [2] = {
            item = 'weapon_chineseak',
            image = 'img/chineseak.png',
            weight = 20,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [3] = {
            item = 'weapon_toym16',
            image = 'img/toym16.png',
            weight = 20,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [4] = {
            item = 'weapon_xm4shadow',
            image = 'img/xm4shadow.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [5] = {
            item = 'weapon_lightrifle',
            image = 'img/lightrifle.png',
            weight = 60,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [6] = {
            item = 'weapon_purpleyokai',
            image = 'img/purpleyokai.png',
            weight = 60,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [7] = {
            item = 'weapon_nevaar',
            image = 'img/nevaar.png',
            weight = 70,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [8] = {
            item = 'weapon_xm117',
            image = 'img/xm117.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [9] = {
            item = 'weapon_bombinglr',
            image = 'img/bombinglr.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [10] = {
            item = 'weapon_ar15',
            image = 'img/ar15.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [11] = {
            item = 'weapon_liquidrifle',
            image = 'img/liquidrifle.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [12] = {
            item = 'weapon_survivorlr300',
            image = 'img/survivorlr300.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [13] = {
            item = 'weapon_assaultrifle',
            image = 'img/weapon_assaultrifle.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [14] = {
            item = 'weapon_specialcarbine',
            image = 'img/weapon_specialcarbine.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [15] = {
            item = 'weapon_carbinerifle',
            image = 'img/weapon_carbinerifle.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [16] = {
            item = 'weapon_bullpuprifle',
            image = 'img/weapon_bullpuprifle.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [17] = {
            item = 'weapon_compactrifle',
            image = 'img/weapon_compactrifle.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [18] = {
            item = 'cash',
            image = 'img/cash.png',
            weight = 35,
            randomQuantity = {min = 200000, max = 250000},  -- Valor aleatório de dinheiro
            isMoney = true,
        },
    },
    ['gangrifle_case'] = {
        [1] = {
            item = 'coins',
            image = 'img/mcoins.png',
            weight = 10,
            amount = 7,  -- Valor fixo de coins (10)
            isCoins = true,
        },
        [2] = {
            item = 'weapon_blackflagar',
            image = 'img/blackflagar.png',
            weight = 20,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [3] = {
            item = 'weapon_blueflagar',
            image = 'img/blueflagar.png',
            weight = 20,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [4] = {
            item = 'weapon_greenflagar',
            image = 'img/greenflagar.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [5] = {
            item = 'weapon_orangeflagar',
            image = 'img/orangeflagar.png',
            weight = 60,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [6] = {
            item = 'weapon_pinkflagar',
            image = 'img/pinkflagar.png',
            weight = 60,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [7] = {
            item = 'weapon_purpleflagar',
            image = 'img/purpleflagar.png',
            weight = 70,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [8] = {
            item = 'weapon_redflagar',
            image = 'img/redflagar.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [9] = {
            item = 'weapon_whiteflagar',
            image = 'img/whiteflagar.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [10] = {
            item = 'weapon_yellowflagar',
            image = 'img/yellowflagar.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [11] = {
            item = 'weapon_assaultrifle',
            image = 'img/weapon_assaultrifle.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [12] = {
            item = 'weapon_specialcarbine',
            image = 'img/weapon_specialcarbine.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [13] = {
            item = 'weapon_carbinerifle',
            image = 'img/weapon_carbinerifle.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [14] = {
            item = 'weapon_bullpuprifle',
            image = 'img/weapon_bullpuprifle.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [15] = {
            item = 'weapon_compactrifle',
            image = 'img/weapon_compactrifle.png',
            weight = 50,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [16] = {
            item = 'cash',
            image = 'img/cash.png',
            weight = 35,
            randomQuantity = {min = 50000, max = 100000},  -- Valor aleatório de dinheiro
            isMoney = true,
        },
    },
    ['shotgun_case'] = {
        [1] = {
            item = 'coins',
            image = 'img/mcoins.png',
            weight = 10,
            amount = 10,  -- Valor fixo de coins
            isCoins = true,
        },
        [2] = {
            item = 'weapon_pumpshotgun',
            image = 'img/weapon_pumpshotgun.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [3] = {
            item = 'weapon_sawnoffshotgun',
            image = 'img/weapon_sawnoffshotgun.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [4] = {
            item = 'weapon_combatshotgun',
            image = 'img/weapon_combatshotgun.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [5] = {
            item = 'weapon_dbshotgun',
            image = 'img/weapon_dbshotgun.png',
            weight = 25,
            quantity = 1,  -- Quantidade fixa de 1 item
        },
        [6] = {
            item = 'cash',
            image = 'img/cash.png',
            weight = 35,
            randomQuantity = {min = 100000, max = 150000},  -- Valor aleatório de dinheiro
            isMoney = true,
        },
    },
    ['presente'] = {
        [1] = {
            item = 'coins',
            image = 'img/mcoins.png',
            weight = 10,
            randomQuantity = {min = 2, max = 10},
            isCoins = true,
        },
        [2] = {
            item = 'cash',
            image = 'img/cash.png',
            weight = 35,
            randomQuantity = {min = 100000, max = 700000},  -- Valor aleatório de dinheiro
            isMoney = true,
        },
    },
    ['bau_tesouro'] = {
        [1] = {
            item = 'coins',
            image = 'img/mcoins.png',
            weight = 10,
            randomQuantity = {min = 2, max = 20},
            isCoins = true,
        },
        [2] = {
            item = 'cash',
            image = 'img/cash.png',
            weight = 35,
            randomQuantity = {min = 100000, max = 1500000},  -- Valor aleatório de dinheiro
            isMoney = true,
        },
    },
    ['coins_case'] = {
        [1] = {
            item = 'coins',
            image = 'img/mcoins.png',
            weight = 10,
            randomQuantity = {min = 4, max = 25},
            isCoins = true,
        },
    },
    ['moneybag'] = {
        [1] = {
            item = 'cash',
            image = 'img/cash.png',
            weight = 35,
            randomQuantity = {min = 50000, max = 700000},  -- Valor aleatório de dinheiro
            isMoney = true,
        },
    },
}
