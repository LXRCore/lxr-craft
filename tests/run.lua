--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-CRAFT — Offline tests: the recipe book against the catalog, levels, gates, coverage, locale parity
     Usage (from the lxr-craft folder):  lua tests/run.lua [--mock out.js en|ka]
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local CORE = os.getenv('LXR_CORE_PATH') or '../lxr-core'
package.path = CORE .. '/?.lua;' .. package.path
local ok = pcall(function() require('tests.lib.fxshim') end)
if not ok then print('lxr-core shim not found at ' .. CORE) os.exit(2) end
local Shim = require('tests.lib.fxshim')
for _, f in ipairs({ 'shared/main.lua', 'shared/locale.lua', 'locales/en.lua', 'config.lua', 'shared/catalog.lua', 'shared/items.lua', 'shared/prices.lua', 'shared/weapons.lua' }) do Shim.load(CORE .. '/' .. f) end
Config = nil Locale = nil
Shim.load('shared/locale.lua') Shim.load('locales/en.lua') Shim.load('locales/ka.lua') Shim.load('config.lua') Shim.load('shared/rules.lua')
local C = LXRCraft

local passed, failed = 0, 0
local function test(name, fn) local okT, err = xpcall(fn, debug.traceback) if okT then passed = passed + 1 print('  ^ ok   ' .. name) else failed = failed + 1 print('  x FAIL ' .. name .. '\n' .. err) end end
local function eq(a, b, msg) if a ~= b then error((msg or 'eq') .. ': expected ' .. tostring(b) .. ' got ' .. tostring(a), 2) end end

print('lxr-craft offline tests')
test('the recipe book is valid and every item is in the catalog', function()
    eq(#C.Validate(), 0, table.concat(C.Validate(), '; '))
    for _, n in ipairs(C.Items()) do assert(LXRShared.Items[n], n) end
    assert(#Config.Recipes >= 30)
    for k in pairs(Config.Kinds) do assert(Locale.Bundles.en['kind.' .. k], 'kind label ' .. k) end
    for k in pairs(Config.Trades) do assert(Locale.Bundles.en['trade.' .. k], 'trade label ' .. k) end
    for _, r in ipairs(Config.Recipes) do
        local cost, worth = 0, 0
        for _, l in ipairs(r.input) do cost = cost + LXRShared.ItemValue(l[1]) * l[2] end
        for _, l in ipairs(r.output) do worth = worth + LXRShared.ItemValue(l[1]) * l[2] end
        assert(worth >= cost * 0.9, r.id .. ' loses money: ' .. worth .. ' vs ' .. cost)
    end
end)
test('levels climb with xp and cap at the trade max', function()
    eq(C.XPFor(1), 0) assert(C.XPFor(2) > 0) assert(C.XPFor(3) > C.XPFor(2))
    eq(C.Level('smithing', 0), 1) eq(C.Level('smithing', C.XPFor(2)), 2) eq(C.Level('smithing', 10 ^ 9), Config.Trades.smithing.max)
    assert(C.Progress('smithing', 0) == 0) assert(C.Progress('smithing', C.XPFor(2) - 1) > 0.9)
end)
test('gates: level and mastery', function()
    local r = C.Recipe('steel_bar')
    local may, why = C.May(r, { smithing = 1 }, {}) assert(not may) eq(why, 'level')
    may, why = C.May(r, { smithing = 9 }, {}) assert(not may) eq(why, 'special')
    assert(C.May(r, { smithing = 9 }, { 'smithing' }))
    assert(C.May(C.Recipe('torch'), {}, {}))
    eq(#C.ForKind('forge') > #C.ForKind('hands'), true)
    for _, r2 in ipairs(C.ForKind('hands')) do eq(r2.kind, 'hands') end
end)
test('coverage counts how many times the satchel covers a recipe, and the tool', function()
    local r = C.Recipe('nails')
    local times, tool = C.Covers(r, function(n) return ({ iron_bar = 3, hammer_smith = 1 })[n] or 0 end)
    eq(times, 3) assert(tool)
    local t2, tool2 = C.Covers(r, function(n) return ({ iron_bar = 1 })[n] or 0 end)
    eq(t2, 1) assert(not tool2)
end)
test('locale parity', function()
    local en, ka = Locale.Bundles.en, Locale.Bundles.ka
    local missing = {}
    for k in pairs(en) do if ka[k] == nil then missing[#missing + 1] = k end end
    eq(#missing, 0, 'ka missing: ' .. table.concat(missing, ', '))
end)
print(('%d passed, %d failed'):format(passed, failed))
if arg and arg[1] == '--mock' and arg[2] then
    Config.Lang = arg[3] or 'en'
    local have = { iron_ore = 7, coal = 4, iron_bar = 2, tongs = 1, hammer_smith = 1, wood = 3, cloth = 2, tar = 1, twine = 5, steel_bar = 0, leather_strip = 1 }
    local count = function(n) return have[n] or 0 end
    local lv, specials = { smithing = 4, leatherwork = 1, cooking = 2, carpentry = 3, chemistry = 1, tailoring = 1 }, { 'smithing' }
    local xp = { smithing = C.XPFor(4) + 60, cooking = C.XPFor(2) + 10, carpentry = C.XPFor(3) + 5 }
    local recipes = {}
    for _, r in ipairs(C.ForKind('forge')) do
        local may, why = C.May(r, lv, specials)
        local times, tool = C.Covers(r, count)
        local input, output = {}, {}
        for _, l in ipairs(r.input) do input[#input + 1] = { name = l[1], label = LXRShared.Items[l[1]].label, need = l[2], have = count(l[1]) } end
        for _, l in ipairs(r.output) do output[#output + 1] = { name = l[1], label = LXRShared.Items[l[1]].label, amount = l[2] } end
        recipes[#recipes + 1] = { id = r.id, kind = r.kind, trade = r.trade, level = r.level, xp = r.xp, seconds = r.seconds, special = r.special == true, tool = r.tool and { name = r.tool, label = LXRShared.Items[r.tool].label, have = tool } or nil, input = input, output = output, may = may, why = why, times = times, label = LXRShared.Items[r.output[1][1]].label }
    end
    local trades = {}
    for trade, def in pairs(Config.Trades) do trades[#trades + 1] = { id = trade, level = lv[trade], max = def.max, xp = xp[trade] or 0, progress = C.Progress(trade, xp[trade] or 0), special = trade == 'smithing' } end
    table.sort(trades, function(a, b) return a.id < b.id end)
    local f = assert(io.open(arg[2], 'w'))
    f:write('window.__LXR_MOCK__ = ' .. json.encode({ action = 'open', images = '/lxr-inventory/html/images/', payload = { kind = 'forge', station = { id = 'val_forge', label = 'Valentine Blacksmith' }, kindLabel = 'The forge', recipes = recipes, trades = trades, specials = specials, slots = 1, changeCost = 25, made = 143, queue = { id = 'horseshoe', left = 2, total = 3, seconds = 12, label = 'Horseshoes', endsAt = os.time() + 7 }, maxQueue = 20 }, lang = Config.Lang, locale = Lang.bundle(), brand = { name = 'The Land of Wolves', theme = 'night' } }) .. ';\n')
    f:close()
    print('mock written to ' .. arg[2])
end
os.exit(failed == 0 and 0 or 1)
