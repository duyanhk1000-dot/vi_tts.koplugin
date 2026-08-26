local ButtonDialog = require("ui/widget/buttondialog")
local Device = require("device")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")

local Screen = Device.screen

local PlayerWidget = {
    dialog = nil,
}

function PlayerWidget:show(controller)
    if self.dialog then
        self:close()
    end

    local is_playing = (controller.state == "PLAYING" or controller.state == "LOADING" or controller.state == "STARTING")
    local toggle_icon = is_playing and "⏸" or "▶"

    local buttons = {
        {
            {
                text = "➖",
                font_size = 18,
                font_bold = true,
                callback = function()
                    controller:changeSpeed(-15)
                    self:show(controller)
                end,
            },
            {
                text = "➕",
                font_size = 18,
                font_bold = true,
                callback = function()
                    controller:changeSpeed(15)
                    self:show(controller)
                end,
            },
        },
        {
            {
                text = toggle_icon,
                font_size = 22,
                font_bold = true,
                callback = function()
                    controller:pauseSession()
                    UIManager:scheduleIn(0.15, function()
                        self:show(controller)
                    end)
                end,
            },
            {
                text = "✖",
                font_size = 18,
                id = "close",
                callback = function()
                    controller:stopSession()
                    self:close()
                end,
            },
        },
    }

    local widget_width = math.floor(Screen:getWidth() * 0.20)
    local widget_height = 70

    self.dialog = ButtonDialog:new{
        title = nil,
        width_factor = 0.20,
        buttons = buttons,
        anchor = function()
            return Geom:new{
                x = Screen:getWidth() - widget_width - 6,
                y = Screen:getHeight() - widget_height - 6,
                w = widget_width,
                h = widget_height,
            }
        end,
    }

    UIManager:show(self.dialog)
end

function PlayerWidget:close()
    if self.dialog then
        pcall(function()
            UIManager:close(self.dialog)
        end)
        self.dialog = nil
    end
end

return PlayerWidget
