--[[
    ██╗     ██╗  ██╗██████╗        ██████╗██████╗  █████╗ ███████╗████████╗
    ██║     ╚██╗██╔╝██╔══██╗      ██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝
    ██║      ╚███╔╝ ██████╔╝█████╗██║     ██████╔╝███████║█████╗     ██║
    ██║      ██╔██╗ ██╔══██╗╚════╝██║     ██╔══██╗██╔══██║██╔══╝     ██║
    ███████╗██╔╝ ██╗██║  ██║      ╚██████╗██║  ██║██║  ██║██║        ██║
    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝       ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝

    LXR Core - Craft

    Making things. Recipes take catalog items and give catalog items at a
    station — the forge, the tanning rack, the kitchen, the workbench, the
    reloading bench — or in the hands, for the simple things. Every craft
    earns experience in a trade; trades have levels; some recipes need a
    level, some need the trade to be your chosen specialisation. The server
    keeps the clock, the books and the ledger of who made what.

    Brand:       LXRCore — Lux Empire eXperience RedM Core
    Product:     wolves.land / The Land of Wolves
    Developer:   iBoss21 / LXRCore
    Website:     https://www.lxrcore.com
    Discord:     https://discord.gg/GAhk8cgXe9
    GitHub:      https://github.com/LXRCore

    Version: 3.0.0
    Performance Target: 0.00 ms idle (interact points; timers only while a queue runs)

    © 2026 iBoss21 / LXRCore | lxrcore.com | All Rights Reserved
]]

Config = Config or {}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ LANGUAGE ██████████████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
Config.Lang = 'en'

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ TRADES ════════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
-- xp per level: level n needs `base × n^curve`; `max` levels
Config.Trades = {
    smithing   = { max = 10 },
    leatherwork = { max = 10 },
    cooking    = { max = 10 },
    carpentry  = { max = 10 },
    chemistry  = { max = 10 },
    tailoring  = { max = 10 },
}
Config.Levels = { base = 120, curve = 1.6 }

-- specialisation: a citizen may choose this many trades to master; recipes marked `special = true` need it
Config.Specialisation = { enabled = true, slots = 1, changeCost = 25.00, changeAccount = 'cash' }

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ STATIONS ══════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
-- kinds: hands (anywhere), forge, tanning, kitchen, workbench, reloading, campfire
-- scenario names below were NOT verified against the game; a name that fails simply plays nothing.
Config.Kinds = {
    hands     = { label = 'By hand',       scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
    forge     = { label = 'The forge',     scenario = 'WORLD_HUMAN_BLACKSMITH' },
    tanning   = { label = 'Tanning rack',  scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
    kitchen   = { label = 'The kitchen',   scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
    workbench = { label = 'Workbench',     scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
    reloading = { label = 'Reloading bench', scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
    campfire  = { label = 'Campfire',      scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
}
Config.Stations = {
    { id = 'val_forge',    kind = 'forge',     label = 'Valentine Blacksmith',        coords = vector3(-292.60, 738.10, 117.20) },
    { id = 'val_tanning',  kind = 'tanning',   label = 'Valentine Tannery',           coords = vector3(-336.20, 766.40, 116.10) },
    { id = 'val_kitchen',  kind = 'kitchen',   label = 'Saints Hotel Kitchen',        coords = vector3(-250.30, 780.90, 121.10) },
    { id = 'val_bench',    kind = 'workbench', label = 'Valentine Workbench',         coords = vector3(-321.80, 803.20, 118.00) },
    { id = 'val_reload',   kind = 'reloading', label = 'Valentine Gunsmith Bench',    coords = vector3(-279.90, 786.10, 119.40) },
    { id = 'rho_forge',    kind = 'forge',     label = 'Rhodes Blacksmith',           coords = vector3(1290.40, -1318.60, 77.40) },
    { id = 'sd_kitchen',   kind = 'kitchen',   label = 'Saint Denis Kitchen',         coords = vector3(2621.40, -1198.30, 53.30) },
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ RECIPES ═══════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
-- kind, trade, level, xp, seconds; input / output lines are core catalog items; tool is required and kept
local function R(id, kind, trade, level, xp, seconds, input, output, opts)
    local r = { id = id, kind = kind, trade = trade, level = level, xp = xp, seconds = seconds, input = input, output = output }
    for k, v in pairs(opts or {}) do r[k] = v end
    return r
end
Config.Recipes = {
    -- by hand
    R('torch',       'hands',     'carpentry',   1, 4,  4,  { { 'wood', 1 }, { 'tar', 1 } },                            { { 'torch', 4 } }),
    R('bandage',     'hands',     'chemistry',   1, 3,  3,  { { 'cloth', 1 } },                                        { { 'bandage', 2 } }),
    R('snare',       'hands',     'carpentry',   1, 4,  4,  { { 'twine', 1 } },                                        { { 'snare', 1 } }),
    R('rope',        'hands',     'carpentry',   2, 6,  6,  { { 'twine', 6 } },                                        { { 'rope', 1 } }),
    R('jerky',       'campfire',  'cooking',     1, 5,  8,  { { 'meat_venison', 1 }, { 'salt', 1 } },                  { { 'jerky', 2 } }),
    R('coffee',      'campfire',  'cooking',     1, 3,  5,  { { 'coffee_beans', 1 } },                                 { { 'coffee', 4 } }),
    -- the forge
    R('iron_bar',    'forge',     'smithing',    1, 8,  10, { { 'iron_ore', 2 }, { 'coal', 1 } },                      { { 'iron_bar', 1 } }, { tool = 'tongs' }),
    R('copper_bar',  'forge',     'smithing',    2, 9,  10, { { 'copper_ore', 2 }, { 'coal', 1 } },                    { { 'copper_bar', 1 } }, { tool = 'tongs' }),
    R('lead_bar',    'forge',     'smithing',    2, 8,  8,  { { 'lead_ore', 2 }, { 'coal', 1 } },                      { { 'lead_bar', 1 } }, { tool = 'tongs' }),
    R('steel_bar',   'forge',     'smithing',    5, 18, 16, { { 'iron_bar', 1 }, { 'charcoal', 2 } },                  { { 'steel_bar', 1 } }, { tool = 'hammer_smith', special = true }),
    R('nails',       'forge',     'smithing',    1, 5,  6,  { { 'iron_bar', 1 } },                                     { { 'nails', 4 } }, { tool = 'hammer_smith' }),
    R('horseshoe',   'forge',     'smithing',    3, 12, 12, { { 'iron_bar', 2 } },                                     { { 'horseshoe', 1 } }, { tool = 'hammer_smith' }),
    R('knife',       'forge',     'smithing',    4, 16, 18, { { 'steel_bar', 1 }, { 'wood', 1 }, { 'leather_strip', 1 } }, { { 'weapon_melee_knife', 1 } }, { tool = 'hammer_smith' }),
    R('skinning_knife', 'forge',  'smithing',    3, 12, 14, { { 'iron_bar', 1 }, { 'wood', 1 } },                      { { 'skinning_knife', 1 } }, { tool = 'hammer_smith' }),
    R('pickaxe',     'forge',     'smithing',    4, 14, 16, { { 'iron_bar', 2 }, { 'wood', 1 } },                      { { 'pickaxe', 1 } }, { tool = 'hammer_smith' }),
    -- tanning
    R('leather',     'tanning',   'leatherwork', 1, 7,  10, { { 'rawhide', 1 }, { 'salt', 1 } },                       { { 'leather', 1 } }),
    R('leather_fine','tanning',   'leatherwork', 5, 18, 18, { { 'pelt_deer', 1 }, { 'salt', 2 } },                     { { 'leather_fine', 1 } }, { special = true }),
    R('leather_strip','tanning',  'leatherwork', 1, 4,  5,  { { 'leather', 1 } },                                      { { 'leather_strip', 10 } }, { tool = 'skinning_knife' }),
    R('rawhide',     'tanning',   'leatherwork', 1, 5,  8,  { { 'pelt_rabbit', 2 } },                                  { { 'rawhide', 1 } }),
    -- the kitchen
    R('bread',       'kitchen',   'cooking',     1, 6,  10, { { 'flour', 1 }, { 'yeast', 1 } },                        { { 'bread', 2 } }),
    R('stew',        'kitchen',   'cooking',     3, 12, 14, { { 'meat_venison', 1 }, { 'potato', 2 }, { 'salt', 1 } }, { { 'stew_venison', 1 } }),
    R('pie',         'kitchen',   'cooking',     4, 14, 16, { { 'flour', 1 }, { 'apple', 2 } },                        { { 'pie_apple', 1 } }),
    R('hardtack',    'kitchen',   'cooking',     1, 4,  8,  { { 'flour', 1 }, { 'salt', 1 } },                         { { 'hardtack', 4 } }),
    R('soap',        'kitchen',   'chemistry',   2, 8,  10, { { 'tallow', 1 }, { 'charcoal', 1 } },                    { { 'soap', 2 } }),
    R('candle',      'kitchen',   'chemistry',   1, 4,  6,  { { 'tallow', 1 }, { 'twine', 1 } },                       { { 'candle', 4 } }),
    R('tallow',      'campfire',  'cooking',     1, 4,  6,  { { 'animal_fat', 1 } },                                   { { 'tallow', 1 } }),
    -- the workbench
    R('plank',       'workbench', 'carpentry',   1, 5,  8,  { { 'log', 1 } },                                          { { 'wood_plank', 3 } }, { tool = 'saw' }),
    R('arrows',      'workbench', 'carpentry',   2, 8,  10, { { 'wood', 1 }, { 'feather_turkey', 2 }, { 'iron_bar', 1 } }, { { 'ammo_arrow', 10 } }),
    R('campfire_kit','workbench', 'carpentry',   2, 8,  10, { { 'wood', 3 }, { 'stone', 2 }, { 'twine', 1 } },        { { 'campfire_kit', 1 } }),
    R('bedroll',     'workbench', 'tailoring',   3, 12, 14, { { 'wool', 2 }, { 'canvas', 1 }, { 'thread', 1 } },       { { 'bedroll', 1 } }, { tool = 'sewing_kit' }),
    R('canvas',      'workbench', 'tailoring',   2, 8,  10, { { 'cloth', 3 }, { 'thread', 1 } },                       { { 'canvas', 1 } }, { tool = 'sewing_kit' }),
    R('charcoal',    'campfire',  'chemistry',   1, 5,  12, { { 'wood', 3 } },                                         { { 'charcoal', 2 } }),
    -- the reloading bench
    R('gunpowder',   'reloading', 'chemistry',   3, 10, 12, { { 'charcoal', 1 }, { 'sulfur', 1 }, { 'saltpeter', 2 } }, { { 'gunpowder', 2 } }),
    R('ammo_revolver','reloading','chemistry',   2, 8,  10, { { 'brass_casing', 12 }, { 'primer', 12 }, { 'lead_bar', 1 }, { 'gunpowder', 1 } }, { { 'ammo_revolver', 24 } }, { tool = 'bullet_mold' }),
    R('ammo_repeater','reloading','chemistry',   3, 9,  10, { { 'brass_casing', 12 }, { 'primer', 12 }, { 'lead_bar', 1 }, { 'gunpowder', 1 } }, { { 'ammo_repeater', 24 } }, { tool = 'bullet_mold' }),
    R('ammo_rifle',  'reloading', 'chemistry',   4, 10, 12, { { 'brass_casing', 12 }, { 'primer', 12 }, { 'lead_bar', 1 }, { 'gunpowder', 2 } }, { { 'ammo_rifle', 24 } }, { tool = 'bullet_mold', special = true }),
}

Config.Queue = { max = 20, cooldownMs = 500 }
Config.Security = { rateLimit = { windowMs = 2000, burst = 8 }, maxDistance = 4.0, promptDistance = 2.0, images = 'nui://lxr-inventory/html/images/' }
Config.Command = { name = 'craft' }   -- /craft: the by-hand recipes anywhere
Config.Debug = { printBanner = true, log = true }
