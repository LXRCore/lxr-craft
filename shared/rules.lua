--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-CRAFT — Shared rules: levels, what may be made, what it costs
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

LXRCraft = LXRCraft or {}
local C = LXRCraft

---XP needed to reach `level` (level 1 = 0).
function C.XPFor(level)
    if level <= 1 then return 0 end
    return math.floor(Config.Levels.base * (level - 1) ^ Config.Levels.curve)
end

---Level for an xp total, capped at the trade's max.
function C.Level(trade, xp)
    local max = (Config.Trades[trade] or {}).max or 10
    local lvl = 1
    while lvl < max and xp >= C.XPFor(lvl + 1) do lvl = lvl + 1 end
    return lvl
end

---Progress inside the current level, 0..1.
function C.Progress(trade, xp)
    local lvl = C.Level(trade, xp)
    local a, b = C.XPFor(lvl), C.XPFor(lvl + 1)
    if b <= a then return 1 end
    return math.max(0, math.min(1, (xp - a) / (b - a)))
end

function C.Recipe(id) for _, r in ipairs(Config.Recipes) do if r.id == id then return r end end end
function C.Station(id) for _, s in ipairs(Config.Stations) do if s.id == id then return s end end end

---Recipes a station kind offers ('hands' always included).
function C.ForKind(kind)
    local out = {}
    for _, r in ipairs(Config.Recipes) do if r.kind == kind or r.kind == 'hands' then out[#out + 1] = r end end
    return out
end

---May a citizen with `levels` (trade → level) and `specials` (list) make this recipe? Returns true or false, reason.
function C.May(recipe, levels, specials)
    if (levels[recipe.trade] or 1) < (recipe.level or 1) then return false, 'level' end
    if recipe.special and Config.Specialisation.enabled then
        local has = false
        for _, s in ipairs(specials or {}) do if s == recipe.trade then has = true end end
        if not has then return false, 'special' end
    end
    return true
end

---How many times the inputs cover the recipe; count(name) → n. Also reports the tool.
function C.Covers(recipe, count)
    local times = math.huge
    for _, l in ipairs(recipe.input) do times = math.min(times, math.floor((count(l[1]) or 0) / l[2])) end
    if times == math.huge then times = 0 end
    local tool = recipe.tool == nil or (count(recipe.tool) or 0) > 0
    return times, tool
end

---Every item the recipes touch.
function C.Items()
    local set, out = {}, {}
    for _, r in ipairs(Config.Recipes) do
        for _, l in ipairs(r.input) do set[l[1]] = true end
        for _, l in ipairs(r.output) do set[l[1]] = true end
        if r.tool then set[r.tool] = true end
    end
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

---Problems in the recipe book (empty = healthy).
function C.Validate()
    local p, seen = {}, {}
    for _, r in ipairs(Config.Recipes) do
        if seen[r.id] then p[#p + 1] = 'recipe twice: ' .. r.id end seen[r.id] = true
        if not Config.Kinds[r.kind] then p[#p + 1] = r.id .. ': unknown kind ' .. tostring(r.kind) end
        if not Config.Trades[r.trade] then p[#p + 1] = r.id .. ': unknown trade ' .. tostring(r.trade) end
        if #r.input == 0 or #r.output == 0 then p[#p + 1] = r.id .. ': needs input and output' end
        if (r.seconds or 0) <= 0 then p[#p + 1] = r.id .. ': seconds' end
    end
    for _, s in ipairs(Config.Stations) do if not Config.Kinds[s.kind] then p[#p + 1] = s.id .. ': unknown kind' end end
    return p
end
