--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-CRAFT — Server: the books, the clock, the ledger
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local C = LXRCraft
local RES = GetCurrentResourceName()
local books, queues, buckets = {}, {}, {}   -- cid → { xp = { trade = n }, specials = {} } ; src → running queue
local dynamic = {}   -- stations other resources add at runtime (a camp's fire): id → { id, kind, label, coords }
local function station(id) return C.Station(id) or dynamic[id] end

local function limited(src)
    local b = buckets[src]
    local now = GetGameTimer()
    if not b or now - b.at > Config.Security.rateLimit.windowMs then b = { at = now, n = 0 } buckets[src] = b end
    b.n = b.n + 1
    return b.n > Config.Security.rateLimit.burst
end
local function player(src) return LXRCore.Functions.GetPlayer(src) end
local function near(src, c)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) <= Config.Security.maxDistance
end

LXRCore.DB.RegisterMigration(RES, '0001_craft', [[
CREATE TABLE IF NOT EXISTS `lxr_craft_books` (
  `citizenid` VARCHAR(50) NOT NULL,
  `xp` TEXT NOT NULL,
  `specials` TEXT NOT NULL,
  `made` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]])

local function book(cid)
    if books[cid] then return books[cid] end
    local row = LXRCore.DB.Single('SELECT xp, specials, made FROM lxr_craft_books WHERE citizenid = ?', { cid })
    local b = { xp = {}, specials = {}, made = 0, dirty = false }
    if row then b.xp = json.decode(row.xp or '{}') or {} b.specials = json.decode(row.specials or '[]') or {} b.made = row.made or 0 end
    books[cid] = b
    return b
end
local function saveBook(cid)
    local b = books[cid]
    if not b or not b.dirty then return end
    b.dirty = false
    LXRCore.DB.UpdateAsync('INSERT INTO lxr_craft_books (citizenid, xp, specials, made) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE xp = VALUES(xp), specials = VALUES(specials), made = VALUES(made)', { cid, json.encode(b.xp), json.encode(b.specials), b.made })
end
local function levels(b) local out = {} for trade in pairs(Config.Trades) do out[trade] = C.Level(trade, b.xp[trade] or 0) end return out end

local function view(src, kind, station)
    local P = player(src)
    local cid = P.PlayerData.citizenid
    local b = book(cid)
    local lv = levels(b)
    local count = function(n) return LXRCore.Inventory.GetItemCount(src, n) end
    local recipes = {}
    for _, r in ipairs(C.ForKind(kind)) do
        local may, why = C.May(r, lv, b.specials)
        local times, tool = C.Covers(r, count)
        local input, output = {}, {}
        for _, l in ipairs(r.input) do input[#input + 1] = { name = l[1], label = LXRShared.Items[l[1]].label, need = l[2], have = count(l[1]) } end
        for _, l in ipairs(r.output) do output[#output + 1] = { name = l[1], label = LXRShared.Items[l[1]].label, amount = l[2] } end
        recipes[#recipes + 1] = { id = r.id, kind = r.kind, trade = r.trade, level = r.level, xp = r.xp, seconds = r.seconds, special = r.special == true, tool = r.tool and { name = r.tool, label = LXRShared.Items[r.tool].label, have = tool } or nil, input = input, output = output, may = may, why = why, times = times, label = LXRShared.Items[r.output[1][1]].label }
    end
    local trades = {}
    for trade, def in pairs(Config.Trades) do trades[#trades + 1] = { id = trade, level = lv[trade], max = def.max, xp = b.xp[trade] or 0, progress = C.Progress(trade, b.xp[trade] or 0), special = (function() for _, s in ipairs(b.specials) do if s == trade then return true end end return false end)() } end
    table.sort(trades, function(a, c) return a.id < c.id end)
    local q = queues[src]
    return { kind = kind, station = station and { id = station.id, label = station.label } or nil, kindLabel = Config.Kinds[kind].label, recipes = recipes, trades = trades, specials = b.specials, slots = Config.Specialisation.enabled and Config.Specialisation.slots or 0, changeCost = Config.Specialisation.changeCost, made = b.made, queue = q and { id = q.recipe, left = q.left, total = q.total, endsAt = q.endsAt } or nil, maxQueue = Config.Queue.max }
end

LXR.RPC.Register('lxr-craft:open', function(src, stationId)
    if limited(src) then return false, 'rate' end
    local P = player(src)
    if not P then return false, 'invalid' end
    if stationId then
        local st = station(stationId)
        if not st then return false, 'invalid' end
        if not near(src, st.coords) then return false, 'too_far' end
        return true, view(src, st.kind, st)
    end
    return true, view(src, 'hands', nil)
end)

---one unit: take inputs, wait, give outputs, xp; the loop runs while the queue has units
local function runQueue(src)
    local q = queues[src]
    if not q then return end
    local P = player(src)
    local r = C.Recipe(q.recipe)
    if not P or not r then queues[src] = nil return end
    while q.left > 0 and queues[src] == q do
        local count = function(n) return LXRCore.Inventory.GetItemCount(src, n) end
        local times, tool = C.Covers(r, count)
        if times < 1 or not tool then TriggerClientEvent('lxr-craft:client:queue', src, nil, 'short') break end
        if q.station and not near(src, q.station.coords) then TriggerClientEvent('lxr-craft:client:queue', src, nil, 'walked') break end
        for _, l in ipairs(r.input) do P.Functions.RemoveItem(l[1], l[2], nil, 'craft:' .. r.id) end
        q.endsAt = os.time() + r.seconds
        TriggerClientEvent('lxr-craft:client:queue', src, { id = r.id, left = q.left, total = q.total, seconds = r.seconds, label = LXRShared.Items[r.output[1][1]].label })
        Wait(r.seconds * 1000)
        if queues[src] ~= q then break end
        for _, l in ipairs(r.output) do
            if not P.Functions.AddItem(l[1], l[2], nil, nil, 'craft:' .. r.id) then LXRCore.Notify(src, Lang:t('error.too_heavy', { label = LXRShared.Items[l[1]].label }), 'warning') end
        end
        local b = book(P.PlayerData.citizenid)
        local before = C.Level(r.trade, b.xp[r.trade] or 0)
        b.xp[r.trade] = (b.xp[r.trade] or 0) + r.xp
        b.made = b.made + 1
        b.dirty = true
        local after = C.Level(r.trade, b.xp[r.trade])
        if after > before then LXRCore.Notify(src, Lang:t('info.level_up', { trade = Lang:t('trade.' .. r.trade), level = after }), 'success', 8000) end
        LXRCore.Emit('lxr:craft:made', nil, src, r.id, r.trade, r.xp)
        q.left = q.left - 1
    end
    if queues[src] == q then queues[src] = nil TriggerClientEvent('lxr-craft:client:queue', src, nil, 'done') end
    saveBook(P.PlayerData.citizenid)
end

LXR.RPC.Register('lxr-craft:start', function(src, stationId, recipeId, times)
    if limited(src) then return false, 'rate' end
    local P, r = player(src), C.Recipe(recipeId)
    if not P or not r then return false, 'invalid' end
    if queues[src] then return false, 'busy' end
    local st = stationId and station(stationId) or nil
    if r.kind ~= 'hands' then
        if not st or st.kind ~= r.kind then return false, 'wrong_station' end
        if not near(src, st.coords) then return false, 'too_far' end
    end
    local b = book(P.PlayerData.citizenid)
    local may, why = C.May(r, levels(b), b.specials)
    if not may then return false, why end
    local count = function(n) return LXRCore.Inventory.GetItemCount(src, n) end
    local canDo, tool = C.Covers(r, count)
    if not tool then return false, 'no_tool', LXRShared.Items[r.tool].label end
    times = math.max(1, math.min(Config.Queue.max, math.floor(tonumber(times) or 1)))
    if canDo < 1 then return false, 'short' end
    times = math.min(times, canDo)
    queues[src] = { recipe = r.id, left = times, total = times, station = st, endsAt = 0 }
    CreateThread(function() runQueue(src) end)
    if Config.Debug.log then LXRCore.Log.info('craft', ('%dx %s at %s'):format(times, r.id, st and st.id or 'hands'), { source = src }) end
    return true, times
end)

LXR.RPC.Register('lxr-craft:stop', function(src)
    queues[src] = nil
    return true
end)

LXR.RPC.Register('lxr-craft:specialise', function(src, trade)
    if limited(src) then return false, 'rate' end
    local P = player(src)
    if not P or not Config.Specialisation.enabled or not Config.Trades[trade] then return false, 'invalid' end
    local b = book(P.PlayerData.citizenid)
    for i, s in ipairs(b.specials) do if s == trade then table.remove(b.specials, i) b.dirty = true saveBook(P.PlayerData.citizenid) return true, b.specials end end
    if #b.specials >= Config.Specialisation.slots then
        if Config.Specialisation.changeCost > 0 and not P.Functions.RemoveMoney(Config.Specialisation.changeAccount, Config.Specialisation.changeCost, 'craft:specialise') then return false, 'no_money', Config.Specialisation.changeCost end
        table.remove(b.specials, 1)
    end
    b.specials[#b.specials + 1] = trade
    b.dirty = true
    saveBook(P.PlayerData.citizenid)
    return true, b.specials
end)

CreateThread(function()
    for _, p in ipairs(C.Validate()) do print('^3[lxr-craft]^7 recipes: ' .. p) end
    if Config.Debug.printBanner then local n = 0 for _ in pairs(Config.Trades) do n = n + 1 end print(('^1[lxr-craft]^7 v%s — %d recipes, %d stations, %d trades'):format(GetResourceMetadata(RES, 'version', 0), #Config.Recipes, #Config.Stations, n)) end
    while true do Wait(120000) for cid in pairs(books) do saveBook(cid) end end
end)
AddEventHandler('playerDropped', function() queues[source] = nil buckets[source] = nil local P = player(source) if P then saveBook(P.PlayerData.citizenid) end end)
AddEventHandler('lxr:character:deleted', function(_, cid) books[cid] = nil end)

exports('AddStation', function(id, kind, label, coords) if not Config.Kinds[kind] then return false end dynamic[id] = { id = id, kind = kind, label = label, coords = coords } return true end)
exports('RemoveStation', function(id) dynamic[id] = nil end)
exports('Level', function(cid, trade) return C.Level(trade, book(cid).xp[trade] or 0) end)
exports('AddXP', function(cid, trade, n) local b = book(cid) if not Config.Trades[trade] then return false end b.xp[trade] = (b.xp[trade] or 0) + (tonumber(n) or 0) b.dirty = true return true end)
exports('Specials', function(cid) return book(cid).specials end)
