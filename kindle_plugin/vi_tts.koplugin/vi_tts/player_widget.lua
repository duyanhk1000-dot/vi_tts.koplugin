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

    -- Show widget first to calculate dimensions
    UIManager:show(self.dialog)

    -- Move widget to bottom of screen AFTER showing
    pcall(function()
        if self.dialog and self.dialog.onMovePosition then
            self.dialog:onMovePosition(false)
        end
    end)
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
