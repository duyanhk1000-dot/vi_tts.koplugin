local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local Controller = require("controller")

local ViTTS = WidgetContainer:extend{
    name = "vi_tts",
    is_doc_only = true,
}

function ViTTS:onDispatcherRegisterActions()
    Dispatcher:registerAction("vi_tts_toggle", {
        category = "read",
        event = "ViTTSToggle",
        title = _("Vietnamese TTS: Play/Pause"),
        general_page = true,
    })
    Dispatcher:registerAction("vi_tts_stop", {
        category = "read",
        event = "ViTTSStop",
        title = _("Vietnamese TTS: Stop"),
        general_page = true,
    })
end

function ViTTS:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerSubmenu(_("Vietnamese TTS (Tiếng Việt)"), self:getMenuTable())
    Controller:init(self.ui)
end

function ViTTS:getMenuTable()
    return {
        {
            text = _("Phát / Tạm dừng (Play / Pause)"),
            callback = function()
                if Controller.state == "IDLE" then
                    Controller:startSession()
                else
                    Controller:pauseSession()
                end
            end,
        },
        {
            text = _("Dừng hẳn (Stop)"),
            callback = function()
                Controller:stopSession()
            end,
        },
        {
            text = _("Cấu hình Server Proxy"),
            callback = function()
                local InputDialog = require("ui/widget/inputdialog")
                local NetTTS = require("net_tts")
                local dialog
                dialog = InputDialog:new{
                    title = _("Nhập URL Server Proxy"),
                    input = NetTTS.proxy_url,
                    buttons = {
                        {
                            text = _("Hủy"),
                            callback = function()
                                UIManager:close(dialog)
                            end,
                        },
                        {
                            text = _("Lưu"),
                            callback = function()
                                local val = dialog:getInputText()
                                if val and #val > 0 then
                                    NetTTS.proxy_url = val
                                end
                                UIManager:close(dialog)
                            end,
                        },
                    },
                }
                UIManager:show(dialog)
            end,
        },
    }
end

function ViTTS:onViTTSToggle()
    if Controller.state == "IDLE" then
        Controller:startSession()
    else
        Controller:pauseSession()
    end
    return true
end

function ViTTS:onViTTSStop()
    Controller:stopSession()
    return true
end

function ViTTS:onGotoPage(page)
    -- If user manually turned page during TTS session, trigger manual navigation cancel
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
