local beautiful = require("beautiful")
local gears = require("gears")
local awful = require("awful")
local hotkeys_popup = require("awful.hotkeys_popup")
local naughty = require("naughty")
local cairo = require("lgi").cairo
local media_control = require("lib.media")

-- Shared widgets
local prompt_widget = require("widgets.prompt")
local notification_widget = require("widgets.notification")
local volume_widget = require("awesome-wm-widgets.volume-widget.volume")
local brightness_widget = require("awesome-wm-widgets.brightness-widget.brightness")

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({}, 4, awful.tag.viewnext),
    awful.button({}, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
local globalkeys = gears.table.join(
    awful.key({ modkey, }, "s", hotkeys_popup.show_help,
        { description = "show help", group = "awesome" }),
    awful.key({ modkey, "Control" }, "i", function() notify_info(client.focus.class) end,
        { description = "get window class", group = "awesome" }),

    -- Layout manipulation
    awful.key({ modkey, }, "i", function()
        local c = client.focus
        if c then c:raise() end
    end, { description = "raise focused client", group = "client" }),

    awful.key({ modkey, }, "l", function()
        repeat awful.client.focus.byidx(1) until not client.focus or not client.focus.skip_taskbar
    end, { description = "focus next client", group = "client" }),
    awful.key({ modkey, }, "h", function()
        repeat awful.client.focus.byidx(-1) until not client.focus or not client.focus.skip_taskbar
    end, { description = "focus previous client", group = "client" }),
    awful.key({ modkey, "Shift" }, "l", function()
        local i = 1
        while awful.client.next(i).skip_taskbar do i = i + 1 end
        awful.client.swap.byidx(i)
    end, { description = "swap client with next", group = "client" }),
    awful.key({ modkey, "Shift" }, "h", function()
        local i = -1
        while awful.client.next(i).skip_taskbar do i = i - 1 end
        awful.client.swap.byidx(i)
    end, { description = "swap client with previous", group = "client" }),
    awful.key({ modkey, "Control" }, "l", function()
        repeat client.focus = awful.client.next(1) until not client.focus or not client.focus.skip_taskbar
    end, { description = "focus next client without raising", group = "client" }),
    awful.key({ modkey, "Control" }, "h", function()
        repeat client.focus = awful.client.next(-1) until not client.focus or not client.focus.skip_taskbar
    end, { description = "focus previous client without raising", group = "client" }),

    awful.key({ modkey, }, "u", awful.client.urgent.jumpto,
        { description = "jump to urgent client", group = "client" }),

    -- Standard program
    awful.key({ modkey, "Control" }, "Escape", awesome.restart,
        { description = "reload awesome", group = "awesome" }),

    -- Prompt
    awful.key({ modkey }, "r", function()
        prompt_widget:run(awful.screen.focused(), "shell")
    end, { description = "run prompt", group = "launcher" }),
    awful.key({ modkey }, ";", function()
        prompt_widget:run(awful.screen.focused(), "lua")
    end, { description = "run lua command", group = "awesome" }),

    -- Notifications
    awful.key({ modkey, }, "n", function() notification_widget:toggle_list() end,
        { description = "toggle notification list", group = "awesome" }),

    -- Media keys
    awful.key({}, "XF86MonBrightnessUp", function() brightness_widget:inc() end,
        { description = "increase brightness", group = "media" }),
    awful.key({}, "XF86MonBrightnessDown", function() brightness_widget:dec() end,
        { description = "decrease brightness", group = "media" }),

    awful.key({}, "XF86AudioRaiseVolume", function() volume_widget:inc() end,
        { description = "increase volume", group = "media" }),
    awful.key({}, "XF86AudioLowerVolume", function() volume_widget:dec() end,
        { description = "decrease volume", group = "media" }),
    awful.key({}, "XF86AudioMute", function() volume_widget:toggle() end,
        { description = "toggle mute", group = "media" }),

    awful.key({}, "#172", function() media_control.call("PlayPause") end,
        { description = "play/pause media", group = "media" }),
    awful.key({}, "#208", function() media_control.call("Play") end,
        { description = "play media", group = "media" }),
    awful.key({}, "#209", function() media_control.call("Pause") end,
        { description = "pause media", group = "media" }),
    awful.key({}, "XF86AudioNext", function() media_control.call("Next") end,
        { description = "next track", group = "media" }),
    awful.key({}, "XF86AudioPrev", function() media_control.call("Previous") end,
        { description = "previous track", group = "media" })
)

local clientkeys = gears.table.join(
    awful.key({ modkey, }, "f", function(c)
            c.fullscreen = not c.fullscreen; c:raise()
        end,
        { description = "toggle fullscreen", group = "client" }),
    awful.key({ modkey, }, "\\", function(c) c:kill() end,
        { description = "close", group = "client" }),
    awful.key({ modkey, "Control" }, "space", awful.client.floating.toggle,
        { description = "toggle floating", group = "client" }),
    awful.key({ modkey, "Control" }, "Return", function(c) c:swap(awful.client.getmaster()) end,
        { description = "move to master", group = "client" }),
    awful.key({ modkey, }, "o", function(c) c:move_to_screen() end,
        { description = "move to screen", group = "client" }),
    awful.key({ modkey, }, "t", function(c) c.ontop = not c.ontop end,
        { description = "toggle keep on top", group = "client" }),
    awful.key({ modkey, "Shift" }, "s", function(c) c.sticky = not c.sticky end,
        { description = "toggle sticky", group = "client" }),
    awful.key({ modkey, }, "m", function(c)
            c.maximized = not c.maximized; c:raise()
        end,
        { description = "(un)maximize", group = "client" })
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
            function()
                local screen = awful.screen.focused()
                local tag = screen.tags[i]
                if tag then
                    tag:view_only()
                end
            end,
            { description = "view tag #" .. i, group = "tag" }),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
            function()
                local screen = awful.screen.focused()
                local tag = screen.tags[i]
                if tag then
                    awful.tag.viewtoggle(tag)
                end
            end,
            { description = "toggle tag #" .. i, group = "tag" }),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
            function()
                if client.focus then
                    local tag = client.focus.screen.tags[i]
                    if tag then
                        client.focus:move_to_tag(tag)
                    end
                end
            end,
            { description = "move focused client to tag #" .. i, group = "tag" }),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
            function()
                if client.focus then
                    local tag = client.focus.screen.tags[i]
                    if tag then
                        client.focus:toggle_tag(tag)
                    end
                end
            end,
            { description = "toggle focused client on tag #" .. i, group = "tag" })
    )
end

local clientbuttons = gears.table.join(
    awful.button({}, 1, function(c)
        client.focus = c; c:raise()
    end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey, "Shift" }, 1, awful.mouse.client.resize),
    awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    {
        rule = {},
        properties = {
            border_width = beautiful.border_width,
            border_color = beautiful.border_normal,
            focus = awful.client.focus.filter,
            raise = true,
            keys = clientkeys,
            buttons = clientbuttons,
            screen = awful.screen.preferred,
            placement = awful.placement.no_overlap + awful.placement.no_offscreen
        }
    },
    -- Floating clients.
    {
        rule_any = {
            instance = {
                "DTA",   -- Firefox addon DownThemAll.
                "copyq", -- Includes session name in class.
            },
            class = {
                "XTerm",
                "Arandr",
                "Gpick",
                "Kruler",
                "MessageWin", -- kalarm.
                "Sxiv",
                "Wpa_gui",
                "pinentry",
                "veromix",
                "xtightvncviewer" },

            name = {
                "Event Tester", -- xev.
            },
            role = {
                "AlarmWindow", -- Thunderbird's calendar.
                "pop-up",      -- e.g. Google Chrome's (detached) Developer Tools.
            }
        },
        properties = { floating = true }
    },

    -- Disable titlebars to all
    {
        rule_any = { type = { "normal", "dialog" } },
        properties = { titlebars_enabled = false }
    },

    -- Specified configuration to some programs
    {
        rule = { class = "Waylyrics" },
        properties = {
            border_width = 0,
            ontop = true,
            sticky = true,
            floating = true,
            skip_taskbar = true,
            placement = awful.placement.top_right,
        },
        -- Minify it at startup
        callback = function(c)
            c.width = c.size_hints.min_width
            c.height = c.size_hints.min_height
        end,
    },
    -- I'm not a good student :)
    {
        rule = { class = "mpv" },
        properties = {
            ontop = true,
            floating = true,
            width = function() return 0.3 * awful.screen.focused().workarea.width end
        },
        callback = function(c)
            c.x = awful.screen.focused().geometry.width - c.width;
            c.y = awful.screen.focused().geometry.height - c.height - 30
        end,
    },
    -- Terminal
    {
        rule_any = { class = { "kitty" } },
        callback = function(c)
            c:connect_signal("focus", function() c.opacity = 0.9 end)
            c:connect_signal("unfocus", function() c.opacity = 0.7 end)
        end,
    },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function(c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
        and not c.size_hints.user_position
        and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", { raise = false })
end)

client.connect_signal("request::activate", function(c, ctxt, hint)
    if not c:isvisible() and hint.raise then
        awful.tag.viewtoggle(c.first_tag)
    end
end)
client.connect_signal("focus", function(c)
    c.border_color = beautiful.border_focus
    if c.above then c.above = false end
    if c.below then c.below = false end
end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

-- vim: fdm=marker
