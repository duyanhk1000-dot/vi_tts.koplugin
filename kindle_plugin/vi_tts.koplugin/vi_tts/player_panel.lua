local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")

local PlayerPanel = {
    dialog = nil,
    current_volume = 80,
}

function PlayerPanel:show(controller)
    if self.dialog then
        self:close()
    end

    local buttons = {
        {
            {
                text = controller.state == "PLAYING" and "⏸️ Tạm dừng (Pause)" or "▶️ Tiếp tục (Play)",
                callback = function()
                    controller:pauseSession()
                    self:updateTitle(controller)
                end,
            },
            {
                text = "⏹️ Dừng hẳn (Stop)",
                callback = function()
                    controller:stopSession()
                    self:close()
                end,
            },
        },
        {
            {
                text = "🔉 - Âm lượng (" .. tostring(self.current_volume) .. "%)",
                callback = function()
                    self.current_volume = math.max(0, self.current_volume - 20)
                    controller:setVolume(self.current_volume)
                    self:show(controller)
                end,
            },
            {
                text = "🔊 + Âm lượng (" .. tostring(self.current_volume) .. "%)",
                callback = function()
                    self.current_volume = math.min(100, self.current_volume + 20)
                    controller:setVolume(self.current_volume)
                    self:show(controller)
                end,
            },
        },
        {
            {
                text = "⏩ Bỏ qua / Sang trang",
                callback = function()
                    controller:onTrackFinished()
                    self:updateTitle(controller)
                end,
            },
            {
                text = "❌ Đóng bảng (Đọc ngầm)",
                id = "close",
                callback = function()
                    self:close()
                end,
            },
        },
    }

    local page_str = controller.current_page > 0 and (" - Trang " .. tostring(controller.current_page)) or ""
    self.dialog = ButtonDialog:new{
        title = "🎧 Control Panel: Vietnamese TTS" .. page_str,
        buttons = buttons,
    }

    UIManager:show(self.dialog)
end

function PlayerPanel:updateTitle(controller)
    if self.dialog then
        self:show(controller)
    end
end

function PlayerPanel:close()
    if self.dialog then
        pcall(function()
            UIManager:close(self.dialog)
        end)
        self.dialog = nil
    end
end

return PlayerPanel
