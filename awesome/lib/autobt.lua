-- Automatically connect to disconnected audio devices
local lgi = require("lgi")
local Gio = lgi.Gio
local GLib = lgi.GLib
local utils = require("lib.utils")
local naughty = require("naughty")
local gears = require("gears")

local bus
local res = {}
local dev_status = {}
-- :: List { prod: number, cur: number, accum: number, next_prod: number }
local disconnected_dev = {}

local function prop_get(props, name)
    local res = props:async_call(
        "org.freedesktop.DBus.Properties.Get", GLib.Variant("(ss)", { "org.bluez.Device1", name }),
        Gio.DBusCallFlags.NONE, -1)
    return res and res[1].value
end

local function is_audio_device(props)
    local class = prop_get(props, "Class")
    if class then
        if (class >> 8) & 0x1f == 0x04 then
            return true
        end
    end
    local uuids = prop_get(props, "UUIDs")
    if uuids then
        for _, v in uuids:pairs() do
            if v == "0000110b-0000-1000-8000-00805f9b34fb" then
                return true
            end
        end
    end
    return false
end

local function try_reconnect(objpath, mode)
    dev_status[objpath] = "reconnecting"
    local dev = Gio.DBusProxy.async_new(bus, Gio.DBusProxyFlags.NONE, nil, "org.bluez", objpath, "org.bluez.Device1")
    local _, err = dev:async_call("org.bluez.Device1.Connect", nil, Gio.DBusCallFlags.NONE, -1)
    if err then
        if mode ~= "silent" then
            naughty.notify({
                preset = naughty.config.presets.warn,
                title = "Reconnection error",
                text = show_value(err),
            })
        end
        dev_status[objpath] = "disconnected"
    else
        dev_status[objpath] = nil
    end
    return dev_status[objpath] == nil
end

local reconnect_timer = gears.timer({ timeout = 30 })

reconnect_timer:connect_signal("timeout", function()
    for objpath, info in pairs(disconnected_dev) do
        if dev_status[objpath] == nil then
            disconnected_dev[objpath] = nil
            goto continue
        end
        info.accum = info.accum + 1
        if info.accum == 240 then
            info.next_prod = true
            info.accum = 0
        end
        info.cur = info.cur + 1
        if info.cur == info.prod then
            info.cur = 0
            if info.next_prod then
                info.next_prod = nil
                info.prod = info.prod * 2
            end
            if utils.wrap_async_pcall(try_reconnect)(objpath, "silent") or info.prod >= 32 then
                disconnected_dev[objpath] = nil
            end
        end
        ::continue::
    end
    if next(disconnected_dev) == nil then
        reconnect_timer:stop()
    end
end)

local function on_prop_changed(conn, sender, objpath, ifname, signame, param)
    local props = Gio.DBusProxy.async_new(bus, Gio.DBusProxyFlags.NONE, nil, "org.bluez", objpath, "org.freedesktop.DBus.Properties")
    if not is_audio_device(props) then return end
    local propchg = {}
    for pn, _ in param:get_child_value(1):pairs() do
        propchg[pn] = true
    end
    local connected = prop_get(props, "Connected")
    local name = prop_get(props, "Name")
    if not connected and dev_status[objpath] == "disconnected" and not propchg.Connected then
        try_reconnect(objpath, "warn")
    elseif connected and dev_status[objpath] == "reconnecting" then
        notify_info("Reconnected to " .. name)
        dev_status[objpath] = nil
    elseif connected and dev_status[objpath] then
        notify_info("Connected to " .. name)
        dev_status[objpath] = nil
    elseif not connected and propchg.Connected then
        notify_info("Record disconnected for " .. name)
        dev_status[objpath] = "disconnected"
        disconnected_dev[objpath] = { prod = 1, cur = 0, accum = 0, next_prod = nil }
        if not reconnect_timer.started then
            reconnect_timer:start()
        end
    end
end

local function do_init()
    bus = Gio.async_bus_get(Gio.BusType.SYSTEM)
    bus:signal_subscribe(
        "org.bluez", "org.freedesktop.DBus.Properties", "PropertiesChanged", nil, nil, Gio.DBusSignalFlags.NONE,
        utils.wrap_async_pcall(on_prop_changed)
    )
end
function res.init()
    Gio.Async.start(function() pcall_notify(do_init) end)()
end

return res
