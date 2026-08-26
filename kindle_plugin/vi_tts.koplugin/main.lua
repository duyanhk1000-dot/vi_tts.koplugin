local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")

local Controller = require("vi_tts/controller")
local NetTTS = require("vi_tts/net_tts")

local ViTTS = WidgetContainer:extend{
    name = "vi_tts",
    is_doc_only = false,
}

function ViTTS:init()
    self.ui.menu:registerToMainMenu(self)

    Dispatcher:registerAction("start_vi_tts", {
        category = "none",
        event = "StartViTTS",
        title = "Vietnamese TTS",
        general = true,
    })

    Controller:init(self.ui)
end

function ViTTS:getMenuTable()
    return {
        {
            text = "▶️ Phát / Tạm dừng (Play / Pause)",
            callback = function()
                if Controller.state == "IDLE" then
                    Controller:startSession()
                    Controller:openWidget()
                else
                    Controller:pauseSession()
                end
            end,
        },
        {
            text = "🎧 Hiện nút điều khiển Mini (Mini Controller)",
            callback = function()
                Controller:openWidget()
            end,
        },
        {
            text = "⏹️ Dừng hẳn (Stop)",
            callback = function()
                Controller:stopSession()
            end,
        },
        {
            text = "🔊 Điều chỉnh Âm lượng (Volume)",
            sub_item_table = {
                { text = "🔊 100% (Lớn nhất)", callback = function() Controller:setVolume(100) end },
                { text = "🔉 80%", callback = function() Controller:setVolume(80) end },
                { text = "🔉 60%", callback = function() Controller:setVolume(60) end },
                { text = "🔈 40%", callback = function() Controller:setVolume(40) end },
                { text = "🔈 20% (Nhỏ nhất)", callback = function() Controller:setVolume(20) end },
            },
        },
        {
            text = "⚙️ Cấu hình Server Proxy",
            callback = function()
                local InputDialog = require("ui/widget/inputdialog")
                local dialog
                dialog = InputDialog:new{
                    title = "Nhập URL Server Proxy",
                    input = NetTTS.proxy_url,
                    buttons = {
                        {
                            {
                                text = "Hủy (Quay lại)",
                                id = "close",
                                callback = function()
                                    UIManager:close(dialog)
                                end,
                            },
                            {
                                text = "Lưu (OK)",
                                is_default = true,
                                callback = function()
                                    local val = dialog:getInputText()
                                    if val and #val > 0 then
                                        NetTTS.proxy_url = val
                                    end
                                    UIManager:close(dialog)
                                end,
                            },
                        },
                    },
                }
                UIManager:show(dialog)
            end,
        },
    }
end

function ViTTS:addToMainMenu(menu_items)
    menu_items.vi_tts = {
        text = "Vietnamese TTS (Tiếng Việt)",
        sorting_hint = "search",
        sub_item_table = self:getMenuTable(),
    }
end

function ViTTS:onStartViTTS()
    if Controller.state == "IDLE" then
        Controller:startSession()
        Controller:openWidget()
    else
        Controller:pauseSession()
    end
end

function ViTTS:onGotoPage(page)
    if Controller.state ~= "IDLE" and not Controller.page_transition_lock then
        Controller:onUserManualPageTurn()
    end
end

function ViTTS:onSuspend()
    if Controller.state ~= "IDLE" then
        Controller:pauseSession()
    end
end

function ViTTS:onCloseReader()
    if Controller.state ~= "IDLE" then
        Controller:stopSession()
    end
end

return ViTTS
