Config = {}
Translation = {}

Translation = {
    ['de'] = {
        ['DJ_interact'] = 'Drücke ~g~E~s~, um auf das DJ Pult zuzugreifen',
        ['title_does_not_exist'] = '~r~Dieser Titel existiert nicht!',
    },

    ['en'] = {
        ['DJ_interact'] = 'Carrega ~g~E~s~ para aceder a mesa de DJ',
        ['title_does_not_exist'] = '~r~Esta musíca não existe!',
    }
}

Config.Locale = 'en'

Config.useESX = false -- can not be disabled without changing the callbacks
Config.enableCommand = false

Config.enableMarker = false -- purple marker at the DJ stations

Config.DJPositions = {
    {
        name = 'test',
        pos = vector3(867.31, -1121.48, 10.85),
        requiredJob = nil, 
        range = 25.0, 
        volume = 1.0 --[[ do not touch the volume! --]]
    }

    --{name = 'bahama', pos = vector3(-1381.01, -616.17, 31.5), requiredJob = 'DJ', range = 25.0}
}