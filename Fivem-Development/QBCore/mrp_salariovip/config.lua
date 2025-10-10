Config = {}

Config.PaymentInterval = 15 * 60 * 1000 -- 15 minutes in milliseconds
Config.Salaries = {
    bronze = 500,
    silver = 1000,
    gold = 1500,
    diamond = 1500,
    streamer = 15000,
    staff = 150000,
    default = 0
}

-- List of citizen IDs that are allowed to set VIP status
Config.AllowedVIPSetters = {
    "BUD49989",
    -- Add more citizen IDs as needed
}
