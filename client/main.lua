--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-CRAFT — Client: the stations, the book, the work
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local N = Citizen.InvokeNative
local open, current, working = false, nil, false

local function toast(key, kind, vars) LXRCore.Notify(Lang:t(key, vars), kind or 'info') end
local function page(action, payload) SendNUIMessage({ action = action, payload = payload, brand = LXRCore.Brand, lang = Config.Lang, locale = Lang.bundle(), images = Config.Security.images }) end
local function close() if not open then return end open = false SetNuiFocus(false, false) page('close') end
local function openBook(station)
    if open then return end
    local ok, data = LXR.RPC.Server('lxr-craft:open', station and station.id or nil)
    if not ok then return toast('error.' .. tostring(data), 'error') end
    open = true current = station
    SetNuiFocus(true, true)
    page('open', data)
end
local function refresh() if open then local ok, data = LXR.RPC.Server('lxr-craft:open', current and current.id or nil) if ok then page('update', data) end end end

local function scenario(kind, on)
    local ped = PlayerPedId()
    if on then
        local s = Config.Kinds[kind] and Config.Kinds[kind].scenario
        if s then N(0x524B54361229154F, ped, joaat(s), -1, true, false, false, false) end
    else ClearPedTasks(ped) end
end

RegisterNUICallback('close', function(_, cb) close() cb({ ok = true }) end)
RegisterNUICallback('start', function(d, cb)
    local ok, res, extra = LXR.RPC.Server('lxr-craft:start', current and current.id or nil, d.id, d.times)
    if not ok then toast('error.' .. tostring(res), 'error', { label = extra }) return cb({ ok = false }) end
    cb({ ok = true, times = res })
end)
RegisterNUICallback('stop', function(_, cb) LXR.RPC.Server('lxr-craft:stop') cb({ ok = true }) end)
RegisterNUICallback('specialise', function(d, cb)
    local ok, res, extra = LXR.RPC.Server('lxr-craft:specialise', d.trade)
    if not ok then toast('error.' .. tostring(res), 'error', { amount = extra and ('%.2f'):format(extra) }) return cb({ ok = false }) end
    refresh() cb({ ok = true })
end)

-- the server drives the queue; the page shows it and the ped works
RegisterNetEvent('lxr-craft:client:queue', function(q, why)
    if q then
        if not working then working = true scenario(current and current.kind or 'hands', true) end
        page('queue', q)
    else
        if working then working = false scenario(nil, false) end
        page('queue', nil)
        if why == 'short' then toast('error.short', 'warning') elseif why == 'walked' then toast('error.walked', 'warning') elseif why == 'done' then toast('info.done', 'success') end
        refresh()
    end
end)

CreateThread(function()
    while GetResourceState('lxr-interact') ~= 'started' do Wait(1000) end
    for _, s in ipairs(Config.Stations) do
        exports['lxr-interact']:AddPoint('lxr-craft:' .. s.id, s.coords, { label = s.label, distance = Config.Security.promptDistance, options = { { label = Lang:t('ui.work_here'), key = 'J', onSelect = function() openBook(s) end } } })
    end
end)
RegisterCommand(Config.Command.name, function() if LocalPlayer.state.isLoggedIn and not working then openBook(nil) end end, false)
-- another resource's station (a camp's fire): it registered the station on the server, this opens the book at it
RegisterNetEvent('lxr-craft:client:openAt', function(id, kind, label) if not working then openBook({ id = id, kind = kind, label = label }) end end)
RegisterNetEvent('lxr:client:unloaded', function() close() end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then close() for _, s in ipairs(Config.Stations) do exports['lxr-interact']:Remove('lxr-craft:' .. s.id) end end end)
exports('IsWorking', function() return working end)
