local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")

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

    self.dialog = ButtonDialog:new{
        title = nil,
        width_factor = 0.28,
        buttons = buttons,
    }

    -- Shift dialog position to bottom of the screen
    pcall(function()
        self.dialog:onMovePosition(false)
    end)

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
