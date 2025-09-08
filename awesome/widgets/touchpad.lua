local wibox = require("wibox")
local naughty = require("naughty")
local spawn = require("awful.spawn")
local awful = require("awful")

local function notify_msg(msg)
    naughty.notify({
        preset = naughty.config.presets.normal,
        title = "Touchpad",
        text = msg,
    })
end

local touchpad_widget = {}
local touchpad_id = nil

local function worker(args)
    local icon_dir = args.icon_dir or ""

    touchpad_widget.enabled = true
    spawn.easy_async_with_shell("xinput list-props $(xinput list --id-only)", function(out)
        out:gsub("Device%s-'([^']-Touchpad[^']-)':", function (id)
            touchpad_id = id
        end)
    end)

    touchpad_widget.widget = wibox.widget {
        {
            image = icon_dir .. "touchpad-disabled.svg",
            resize = true,
            widget = wibox.widget.imagebox,
        },
        forced_height = 18,
        forced_width = 18,
        widget = wibox.container.place,
        visible = false,
    }

    function touchpad_widget:toggle()
        if not touchpad_id then
            notify_msg("Touchpad not found")
            return
        end
        spawn.easy_async({ "xinput", self.enabled and "disable" or "enable", touchpad_id }, function()
            self.widget:set_visible(self.enabled)
            notify_msg(("Touchpad(%s) %s"):format(touchpad_id, self.enabled and "disabled" or "enabled"))
            self.enabled = not self.enabled
        end)
    end

    touchpad_widget.widget:buttons(
            awful.util.table.join(
                    awful.button({}, 1, function() touchpad_widget:toggle() end)
            )
    )

    awful.tooltip {
        objects        = { touchpad_widget.widget },
        timer_function = function()
            return "Touchpad disabled, click to enable"
        end,
    }

    return touchpad_widget.widget
end

-- Use function to explicitly toggle
function ToggleTouchpad()
    if not touchpad_id then
        notify_msg("Touchpad not found!")
    else
        touchpad_widget:toggle()
    end
end

return setmetatable(touchpad_widget, {
    __call = function(_, ...)
        return worker(...)
    end,
})
