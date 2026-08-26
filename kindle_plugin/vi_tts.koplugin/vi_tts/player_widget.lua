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
    local toggle_label = is_playing and "⏸️ Pause" or "▶️ Play"

    local buttons = {
        {
            {
                text = toggle_label,
                callback = function()
                    controller:pauseSession()
                    self:show(controller)
                end,
            },
            {
                text = "✖ Tắt",
                id = "close",
                callback = function()
                    controller:stopSession()
                    self:close()
                end,
            },
        },
    }

    local page_info = controller.current_page > 0 and (" P." .. tostring(controller.current_page)) or ""

    self.dialog = ButtonDialog:new{
        title = "🎧 TTS" .. page_info,
        width_factor = 0.40,
        buttons = buttons,
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
