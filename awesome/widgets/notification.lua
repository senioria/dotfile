local wibox = require("wibox")
local base = wibox.widget.base
local beautiful = require("beautiful")
local gears = require("gears")
local gtable = gears.table
local awful = require("awful")

-- {{{ class list_view
local list_view = {}

function list_view:_push_pos(p, h)
    self._private.y_pos[p + 1] = self._private.y_pos[p] + h
end

--- Find the first visible children by binary search.
--- Should prefer `self._private.first_visible_cache` if non-nil, and store the result into it.
function list_view:_first_visible(cx, width)
    local lo, hi = 1, #self._private.widgets
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if self._private.y_pos[mid] == nil then
            for p = #self._private.y_pos, mid - 1 do
                self:_push_pos(p, select(2, base.fit_widget(self, cx, self._private.widgets[p], width, math.huge)))
            end
        end
        if self._private.y_pos[mid] <= self._private.scroll then
            lo = mid
        else
            hi = mid - 1
        end
    end
    if not self._private.y_pos[lo] then
        self:_push_pos(lo - 1, select(2, base.fit_widget(self, cx, self._private.widgets[lo - 1], width, math.huge)))
    end
    return lo
end

function list_view:layout(cx, width, height)
    local res = {}
    local spacing = self._private.spacing or 0
    local spacing_widget = self._private.spacing_widget
    if not self._private.first_visible_cache then
        self._private.first_visible_cache = self:_first_visible(cx, width)
    end
    local first_visible = self._private.first_visible_cache
    local pos = self._private.y_pos[first_visible] - self._private.scroll
    -- From the first visible, until invisible :)
    for p = first_visible, #self._private.widgets do
        local sub = self._private.widgets[p]
        local w, h = base.fit_widget(self, cx, sub, width, math.huge)
        if self._private.y_pos[p + 1] == nil then self:_push_pos(p, h) end
        if spacing_widget and p > first_visible then
            table.insert(res, base.place_widget_at(spacing_widget, 0, pos, width, spacing))
        end
        table.insert(res, base.place_widget_at(sub, 0, pos, w, h))
        pos = pos + h
        if p > first_visible then pos = pos + spacing end
        -- End if no items can be placed
        if pos > height then break end
    end
    return res
end

function list_view:fit(cx, width, height)
    local wa = awful.screen.focused().workarea
    return wa.width * 0.3, wa.height * 0.8
end

--[[function list_view:draw(cx, width, height)
    cx:clip(gears.shape.rectangle(cx, width, height))
end]]

function list_view:add(...)
    for _, sub in ipairs(table.pack(...)) do
        base.check_widget(sub)
        table.insert(self._private.widgets, sub)
    end
    self:emit_signal("widget::layout_changed")
end

function list_view:reset()
    self._private.widgets = {}
    self._private.y_pos = { [1] = 0 }
    self._private.scroll = 0
    self._private.first_visible_cache = nil
    self:emit_signal("widget::layout_changed")
    self:emit_signal("widget::reseted")
end

function list_view:get_children()
    return self._private.widgets
end

function list_view:scroll(step)
    self._private.scroll = self._private.scroll + step
    if self._private.scroll < 0 then self._private.scroll = 0 end
    self._private.first_visible_cache = nil
    self:emit_signal("widget::layout_changed")
    self:emit_signal("widget::redraw_needed")
end

function list_view:set_spacing(spc)
    self._private.spacing = spc
    if self._private.spacing ~= spc then self:emit_signal("widget::layout_changed") end
end

function list_view:get_spacing(spc)
    return self._private.spacing or 0
end

function list_view:set_spacing_widget(widget)
    self._private.spacing_widget = base.make_widget_from_value(widget)
    self:emit_signal("widget::layout_changed")
end

function list_view:get_spacing_widget()
    return self._private.spacing_widget
end

function list_view.new()
    local res = base.make_widget(nil, nil, { enable_properties = true })
    gtable.crush(res, list_view, true)
    res._private.widgets = {}
    res._private.y_pos = { [1] = 0 }
    res._private.scroll = 0
    res._private.first_visible_cache = nil
    return res
end
-- }}} End list_view

local function mk_notification_item(noti)
    if noti.box then
        return noti.box
    elseif noti.icon then
        return wibox.widget {
            {
                image = noti.icon,
                resize = true,
                auto_dpi = true,
                forced_width = awful.screen.focused().workarea.width * 0.05,
                forced_height = awful.screen.focused().workarea.height * 0.05,
                widget = wibox.widget.imagebox,
            },
            {
                markup = (noti.title and "<b>" .. noti.title .. "</b>\n" or "") .. (noti.text or ""),
                widget = wibox.widget.textbox,
            },
            layout = wibox.layout.fixed.horizontal,
        }
    else
        return wibox.widget {
            markup = (noti.title and "<b>" .. noti.title .. "</b>\n" or "") .. (noti.text or ""),
            widget = wibox.widget.textbox,
        }
    end
end

local notification_widget = {}
local during_notification = false

local function worker(args)
    local icon_dir = args.icon_dir or ""
    local scroll_step = args.scroll_step or awful.screen.focused().workarea.height * 0.04

    notification_widget.systray = wibox.widget {
        {
            {
                image = icon_dir .. "notifications.svg",
                resize = true,
                forced_width = 24,
                forced_height = 18,
                widget = wibox.widget.imagebox,
            },
            {
                id = "mycount",
                text = "0",
                widget = wibox.widget.textbox,
            },
            spacing = 2,
            widget = wibox.layout.fixed.horizontal,
        },
        widget = wibox.container.place,
    }

    local popup_header = {
        {
            id = "mycount",
            text = "0 notification(s)",
            widget = wibox.widget.textbox,
        },
        {
            widget = wibox.widget.textbox,
        },
        {
            id = "myclearbut",
            image = icon_dir .. "trash.svg",
            resize = true,
            forced_width = 23,
            forced_height = 23,
            widget = wibox.widget.imagebox,
        },
        widget = wibox.layout.align.horizontal,
    }
    notification_widget.popup = awful.popup {
        widget = wibox.widget {
            {
                popup_header,
                {
                    id = "mynotilist",
                    spacing = 1,
                    spacing_widget = {
                        color = beautiful.border_marked,
                        widget = wibox.widget.separator,
                    },
                    layout = list_view.new,
                    --layout = layout_fixed.vertical,
                },
                spacing = 1,
                spacing_widget = {
                    color = beautiful.border_marked,
                    widget = wibox.widget.separator,
                },
                layout = wibox.layout.fixed.vertical,
            },
            left = 4, right = 4, top = 4, bottom = 4,
            widget = wibox.container.margin,
        },
        ontop = true,
        visible = false,
        placement = function (c) awful.placement.top_right(c, { honor_workarea = true }) end,
        shape = gears.shape.rounded_rect,
    }

    notification_widget.noti_list = notification_widget.popup.widget:get_children_by_id("mynotilist")[1]
    notification_widget.systray_count = notification_widget.systray:get_children_by_id("mycount")[1]
    notification_widget.popup_count = notification_widget.popup.widget:get_children_by_id("mycount")[1]
    function notification_widget:_update_count(cnt)
        self.systray_count.text = tostring(cnt)
        self.popup_count.text = ("%d notification(s)"):format(cnt)
    end
    function notification_widget:add_notification(noti)
        self.noti_list:add(mk_notification_item(noti))
        self:_update_count(#self.noti_list:get_children())
    end
    function notification_widget:clear_notification()
        self.noti_list:reset()
        self:_update_count(0)
    end

    function notification_widget:toggle_list()
        self.popup.visible = not notification_widget.popup.visible
    end

    notification_widget.systray:buttons(gears.table.join(
        awful.button({}, 1, function() notification_widget:toggle_list() end)
    ))
    notification_widget.popup:buttons(gears.table.join(
        awful.button({}, 4, function() notification_widget.noti_list:scroll(-scroll_step) end),
        awful.button({}, 5, function() notification_widget.noti_list:scroll(scroll_step) end)
    ))
    notification_widget.popup.widget:get_children_by_id("myclearbut")[1]:buttons(gears.table.join(
        awful.button({}, 1, function()
            notification_widget:clear_notification()
            notification_widget:toggle_list()
        end)
    ))

    notification_widget.traffic = 0
    notification_widget.traffic_timer = gears.timer {
        timeout = 1,
        callback = function ()
            notification_widget.traffic = math.max(0, notification_widget.traffic * 0.7 - 3)
            if notification_widget.traffic <= 0 then
                notification_widget.traffic_timer:stop()
            end
        end
    }
    function notification_widget:on_notification(noti)
        if during_notification then return noti end
        during_notification = true
        self:add_notification(noti)
        during_notification = false
        self.traffic = self.traffic + 1
        if not self.traffic_timer.started then self.traffic_timer:start() end
        if self.traffic >= 3 then
            return nil
        end
        return noti
    end

    return notification_widget.systray
end

return setmetatable(notification_widget, {
    __call = function(_, ...)
        return worker(...)
    end,
})

-- vim: fdm=marker
