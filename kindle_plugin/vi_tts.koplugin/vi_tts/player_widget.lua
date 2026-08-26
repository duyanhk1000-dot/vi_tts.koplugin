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

    local is_playing = (controller.state == "PLAYING")
    local toggle_icon = is_playing and "⏸️" or "▶️"

    local buttons = {
        {
            {
                text = toggle_icon,
                callback = function()
                    controller:pauseSession()
                    self:show(controller)
                end,
            },
            {
                text = "✖",
                id = "close",
                callback = function()
                    controller:stopSession()
                    self:close()
                end,
            },
        },
    }

    local widget_width = math.floor(Screen:getWidth() * 0.25)
    local widget_height = 50

    self.dialog = ButtonDialog:new{
        title = nil,
        width_factor = 0.25,
        buttons = buttons,
        anchor = function()
            return Geom:new{
                x = Screen:getWidth() - widget_width - 10,
                y = Screen:getHeight() - widget_height - 10,
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
