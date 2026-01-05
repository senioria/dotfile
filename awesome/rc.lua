-- {{{ Premable
local argv = ...
local confpath = argv[1] .. "/awesome"
-- Local module paths
package.path = package.path .. ';' .. confpath .. '/?.lua'

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")

-- Widgets library
local battery_widget = require("awesome-wm-widgets.batteryarc-widget.batteryarc")
local volume_widget = require("awesome-wm-widgets.volume-widget.volume")
local brightness_widget = require("awesome-wm-widgets.brightness-widget.brightness")
local touchpad_widget = require("widgets.touchpad")
local notification_widget = require("widgets.notification")
local prompt_widget = require("widgets.prompt")
local media_control = require("lib.media")
local autobt = require("lib.autobt")
-- }}}

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Helper functions
function pcall_notify(...)
    local ok, res = pcall(...)
    if ok then
        return res
    else
        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Error in function call",
                         text = tostring(res) })
    end
    return res
end

function show_value(value, flags)
    if type(value) == "table" then
        local res = ""
        for k, v in pairs(value) do res = res .. show_value(k, flags) .. " = " .. show_value(v, flags) .. ",\n" end
        res = res:gsub("[^\n]-\n", function(s) return "  " .. s end)
        return "{\n" .. res .. "}"
    elseif type(value) == "string" and not (flags and flags:find("s")) then
        return "\"" .. value:gsub("\n", "\\n") .. "\""
    end
    return tostring(value)
end

function notify_info(ctnt)
    naughty.notify({
        preset = naughty.config.presets.info,
        title = "Info",
        text = show_value(ctnt, "s")
    })
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
beautiful.init(loadfile(confpath .. '/theme.lua')(confpath))

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = argv.modkey or "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    --awful.layout.suit.tile.left,
    --awful.layout.suit.tile.bottom,
    --awful.layout.suit.tile.top,
    --awful.layout.suit.fair,
    --awful.layout.suit.fair.horizontal,
    --awful.layout.suit.spiral,
    --awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    --awful.layout.suit.max.fullscreen,
    --awful.layout.suit.magnifier,
    --awful.layout.suit.corner.nw,
    -- awful.layout.suit.corner.ne,
    -- awful.layout.suit.corner.sw,
    -- awful.layout.suit.corner.se,
}
-- }}}

-- {{{ Wibar & Screen
local function set_wallpaper(s)
    -- Wallpaper
    if not beautiful.wallpaper then
        return
    end
    local wallpaper = beautiful.wallpaper
    -- If wallpaper is a function, call it with the screen
    if type(wallpaper) == "function" then
        wallpaper = wallpaper(s)
    end
    gears.wallpaper.maximized(wallpaper, s, true)
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)
screen.connect_signal("request::wallpaper", set_wallpaper)

-- {{{ Wibar controls
-- Create a textclock widget and its calendar
local mytextclock = wibox.widget.textclock("%b %d, %H:%M")
local mycalendar = awful.widget.calendar_popup.month()
local mybrightness_widget = brightness_widget({
    type = "arc",
    path_to_icon = confpath .. "/awesome-wm-widgets/brightness-widget/brightness.svg",
    program = "xbacklight",
    timeout = 4294967,
    tooltip = true,
    percentage = true,
})
local myvolume_widget = volume_widget({
    widget_type = "arc",
    icon_dir = confpath .. "/awesome-wm-widgets/volume-widget/icons/",
    mixer_cmd = "pavucontrol-qt",
    device = "default",
    use_mute_icon = true,
    refresh_rate = 4294967,  -- No other program would refresh the volume
})
local mybattery_widget = battery_widget({
    show_current_level = true,
    font = "Iosevka Custom 5",
    arc_thickness = 1,
    --timeout = 10,  -- This is the default value
})
local mytouchpad_widget = touchpad_widget({
    icon_dir = confpath .. "/widgets/icons/",
})
local mynotification_widget = notification_widget({
    icon_dir = confpath .. "/widgets/icons/",
})
-- Create the widget
prompt_widget({})
mycalendar:attach(mytextclock, 'tr')

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
                )

local tasklist_buttons = gears.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  c:emit_signal(
                                                      "request::activate",
                                                      "tasklist",
                                                      {raise = true}
                                                  )
                                              end
                                          end),
                     awful.button({ }, 3, function()
                                              awful.menu.client_list({ theme = { width = 250 } })
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))
-- }}}

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Each screen has its own tag table.
    awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])

    -- Create an imagebox widget which will contain an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, taglist_buttons)

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, tasklist_buttons)

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            s.mytaglist,
        },
        s.mytasklist, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            spacing = 5,
            wibox.widget.systray(),
            mytouchpad_widget,
            mybrightness_widget,
            myvolume_widget,
            mybattery_widget,
            mytextclock,
            mynotification_widget,
            s.mylayoutbox,
        },
    }
end)
-- }}}

-- Load the bindings
loadfile(confpath .. "/bindings.lua")()

-- Grab notifications
function naughty.config.notify_callback(args)
    return notification_widget:on_notification(args)
end

-- {{{ Post tasks
-- Start some programs
-- Transparency, maybe not needed currently><
awful.spawn.single_instance("picom")
if not argv.nospawn then
    -- Input method and key binding
    awful.spawn.single_instance("fcitx5")
    --awful.spawn("xmodmap " .. confpath .. "/../.Xmodmap")
end
-- Enable media control
media_control.init()
--autobt.init()
-- }}}

-- vim: fdm=marker
