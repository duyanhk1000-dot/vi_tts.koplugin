local plugin_dir = debug.getinfo(1, "S").source:match("@?(.*/)")
if plugin_dir then
    package.path = plugin_dir .. "?.lua;" .. package.path
end

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local Dispatcher = require("dispatcher")
local InputDialog = require("ui/widget/inputdialog")
local _ = require("gettext")

local Controller = require("vi_tts_controller")
local NetTTS = require("vi_tts_net")

local ViTTS = WidgetContainer:extend{
    name = "vi_tts",
    is_doc_only = false,
}

function ViTTS:onDispatcherRegisterActions()
    Dispatcher:registerAction("vi_tts_toggle", {
        category = "none",
        event = "ViTTSToggle",
        title = _("Vietnamese TTS: Play/Pause"),
        general = true,
    })
    Dispatcher:registerAction("vi_tts_stop", {
        category = "none",
        event = "ViTTSStop",
        title = _("Vietnamese TTS: Stop"),
        general = true,
    })
end

function ViTTS:init()
    self:onDispatcherRegisterActions()

    if self.ui and self.ui.menu then
        pcall(function() self.ui.menu:registerToMainMenu(self) end)
    end

    Controller:init(self.ui)
end

function ViTTS:getMenuTable()
    return {
        {
            text = _("▶️ Phát / Tạm dừng (Play / Pause)"),
            callback = function()
                if Controller.state == "IDLE" then
                    Controller:startSession()
                else
                    Controller:pauseSession()
                end
            end,
        },
        {
            text = _("⏹️ Dừng hẳn (Stop)"),
            callback = function()
                Controller:stopSession()
            end,
        },
        {
            text = _("⚙️ Cấu hình Server Proxy"),
            callback = function()
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

function ViTTS:addToMainMenu(menu_items)
    menu_items.vi_tts = {
        sorting_hint = "tools",
        text = _("Vietnamese TTS (Tiếng Việt)"),
        sub_item_table = self:getMenuTable(),
    }
end

function ViTTS:addToReaderMenu(menu_items)
    menu_items.vi_tts = {
        sorting_hint = "tools",
        text = _("Vietnamese TTS (Tiếng Việt)"),
        sub_item_table = self:getMenuTable(),
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
