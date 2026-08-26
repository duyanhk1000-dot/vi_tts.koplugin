local UIManager = require("ui/uimanager")

local Logger = require("vi_tts/logger")
local Extractor = require("vi_tts/extractor")
local Daemon = require("vi_tts/daemon")
local NetTTS = require("vi_tts/net_tts")
local PlayerWidget = require("vi_tts/player_widget")

local Controller = {
    state = "IDLE",
    current_page = 0,
    session_id = nil,
    session_token = nil,
    page_transition_lock = false,
    last_text = "",
    ui = nil,
}

function Controller:init(ui)
    self.ui = ui
    self.state = "IDLE"
    Logger:clear()
    Logger:log("INIT", "Controller initialized")
end

function Controller:startSession()
    Logger:log("START_SESSION", "State: " .. tostring(self.state))
    if self.state ~= "IDLE" then
        self:stopSession()
    end

    self.session_id = tostring(os.time())
    self.session_token = "token_" .. self.session_id .. "_" .. tostring(math.random(1000, 9999))
    self.last_text = ""
    
    if self.ui and self.ui.document then
        self.current_page = self.ui.document:getCurrentPage()
        Logger:log("START_SESSION", "Current page: " .. tostring(self.current_page))
    end
    
    self.state = "STARTING"
    self:showInfo("📖 Bắt đầu đọc TTS (Trang " .. tostring(self.current_page) .. ")...")

    local init_ok = Daemon:init(self.session_id)
    Logger:log("DAEMON_INIT", "Daemon init result: " .. tostring(init_ok) .. ", player: " .. tostring(Daemon.player_type))
    
    self:loadAndPlayCurrentPage()
end

function Controller:loadAndPlayCurrentPage()
    self.state = "LOADING"
    Logger:log("LOAD_PAGE", "Loading page " .. tostring(self.current_page))
    
    -- Schedule text extraction after KOReader page render completes
    UIManager:scheduleIn(0.35, function()
        local text = Extractor:getPageText(self.ui, self.current_page)
        
        if not text then
            Logger:log("LOAD_PAGE_ERROR", "No text found for page " .. tostring(self.current_page))
            self:showInfo("❌ Trang " .. tostring(self.current_page) .. " không có chữ!")
            self:stopSession()
            return
        end

        -- Check duplicate text guard to ensure we never read the previous page again
        if text == self.last_text and #text > 20 then
            Logger:log("LOAD_PAGE_DUP", "Extracted duplicate text of previous page. Retrying extraction...")
            UIManager:scheduleIn(0.4, function()
                self:loadAndPlayCurrentPage()
            end)
            return
        end

        self.last_text = text
        Logger:log("LOAD_PAGE_TEXT", "Page " .. tostring(self.current_page) .. " text extracted, length: " .. tostring(#text))

        local curr_file = Daemon:getFilePath("chunk_curr")
        
        local ok, res = NetTTS:requestPageAudio(
            text, 
            curr_file, 
            self.session_token, 
            function(token) return token == self.session_token end,
            function(status_text) self:showInfo(status_text) end
        )

        Logger:log("LOAD_PAGE_NET_RES", "Net request result: " .. tostring(ok) .. ", msg: " .. tostring(res))

        if ok then
            self.state = "PLAYING"
            self:showInfo("🔊 Đang đọc trang " .. tostring(self.current_page) .. " (" .. NetTTS:getRateStr() .. ")...")
            Logger:log("PLAYING", "Loading audio for page " .. tostring(self.current_page))
            Daemon:loadAudio(curr_file)
            self:schedulePlaybackCheck()
        else
            self.state = "IDLE"
            Logger:log("PLAY_ERROR", "Net error: " .. tostring(res))
            self:showInfo("⚠️ Không thể tải âm thanh:\n" .. tostring(res))
        end
    end)
end

function Controller:schedulePlaybackCheck()
    if self.state ~= "PLAYING" then return end
    
    UIManager:scheduleIn(1.0, function()
        if self.state ~= "PLAYING" then return end
        
        if Daemon:isPlaying() then
            -- Still playing current page audio
            self:schedulePlaybackCheck()
        else
            Logger:log("PLAYBACK_CHECK", "Page " .. tostring(self.current_page) .. " finished. Turning page...")
            self:onTrackFinished()
        end
    end)
end

function Controller:onTrackFinished()
    Logger:log("TRACK_FINISHED", "Track finished for page " .. tostring(self.current_page))
    if self.state ~= "PLAYING" and self.state ~= "PREFETCHING" then return end

    local next_page = self.current_page + 1
    local total_pages = 1
    if self.ui and self.ui.document then
        total_pages = self.ui.document:getPageCount()
    end

    if next_page > total_pages then
        Logger:log("BOOK_END", "Reached end of book")
        self:showInfo("🎉 Đã đọc xong cuốn sách!")
        self:stopSession()
        return
    end

    self.page_transition_lock = true
    self.current_page = next_page

    -- Turn page on KOReader screen
    if self.ui and self.ui.handleEvent then
        pcall(function()
            local Event = require("ui/event")
            self.ui:handleEvent(Event:new("GotoPage", next_page))
        end)
    end

    -- Allow KOReader 0.35s to complete rendering next_page before extracting text
    UIManager:scheduleIn(0.35, function()
        self.page_transition_lock = false
        self:loadAndPlayCurrentPage()
    end)
end

function Controller:onUserManualPageTurn()
    Logger:log("MANUAL_PAGE_TURN", "User manually turned page")
    if self.state ~= "IDLE" then
        self:showInfo("⏹️ Dừng đọc do lật trang thủ công")
        self:stopSession()
    end
end

function Controller:pauseSession()
    Logger:log("PAUSE", "State: " .. tostring(self.state))
    if self.state == "PLAYING" or self.state == "LOADING" or self.state == "STARTING" then
        Daemon:stopAudio()
        self.state = "PAUSED"
        self:showInfo("⏸️ Đã tạm dừng")
    elseif self.state == "PAUSED" then
        self.state = "STARTING"
        self.last_text = "" -- Reset last_text so resuming current page is not blocked by duplicate guard
        self:showInfo("▶️ Tiếp tục đọc trang " .. tostring(self.current_page) .. "...")
        self:loadAndPlayCurrentPage()
    end
end

function Controller:changeSpeed(delta)
    NetTTS.rate_val = math.max(-40, math.min(100, NetTTS.rate_val + delta))
    local rate_str = NetTTS:getRateStr()
    self:showInfo("⚡ Tốc độ đọc: " .. rate_str)
    Logger:log("SPEED_CHANGE", "New speed rate: " .. rate_str)

    if self.state == "PLAYING" or self.state == "LOADING" then
        Daemon:stopAudio()
        self.state = "STARTING"
        self.last_text = ""
        self:loadAndPlayCurrentPage()
    end
end

function Controller:stopSession()
    Logger:log("STOP", "Stopping session...")
    self.state = "STOPPING"
    Daemon:stopAudio()
    Daemon:stopProcess()
    Daemon:cleanSessionDir()
    PlayerWidget:close()
    self.session_token = nil
    self.state = "IDLE"
    self:showInfo("⏹️ Đã dừng hẳn đọc TTS")
end

function Controller:setVolume(volume_percent)
    local cmd = string.format("amixer set Master %d%% 2>/dev/null; amixer set PCM %d%% 2>/dev/null", volume_percent, volume_percent)
    os.execute(cmd)
    self:showInfo("🔊 Âm lượng: " .. tostring(volume_percent) .. "%")
end

function Controller:openWidget()
    PlayerWidget:show(self)
end

function Controller:showInfo(msg)
    if self.ui then
        pcall(function()
            local InfoMessage = require("ui/widget/info_message") or require("ui/widget/infomessage")
            UIManager:show(InfoMessage:new{
                text = msg,
                timeout = 1.5,
            })
        end)
    end
end

return Controller
