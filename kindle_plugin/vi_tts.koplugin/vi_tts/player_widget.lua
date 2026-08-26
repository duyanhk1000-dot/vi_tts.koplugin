local ButtonDialog = require("ui/widget/buttondialog")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local RightContainer = require("ui/widget/container/rightcontainer")
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

    local dlg = ButtonDialog:new{
        title = nil,
        width_factor = 0.28,
        buttons = buttons,
    }

    -- Position strictly at bottom-right corner of screen
    self.dialog = BottomContainer:new{
        RightContainer:new{
            dlg
        }
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
