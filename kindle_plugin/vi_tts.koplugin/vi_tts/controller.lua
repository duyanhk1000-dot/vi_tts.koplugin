local UIManager = require("ui/uimanager")

local Logger = require("vi_tts/logger")
local Extractor = require("vi_tts/extractor")
local Daemon = require("vi_tts/daemon")
local NetTTS = require("vi_tts/net_tts")

local Controller = {
    state = "IDLE",
    current_page = 0,
    session_id = nil,
    session_token = nil,
    page_transition_lock = false,
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
    
    if self.ui and self.ui.document then
        self.current_page = self.ui.document:getCurrentPage()
        Logger:log("START_SESSION", "Current page: " .. tostring(self.current_page))
    end
    
    self.state = "STARTING"
    self:showInfo("📖 Bắt đầu phiên đọc TTS (Trang " .. tostring(self.current_page) .. ")...")

    local init_ok = Daemon:init(self.session_id)
    Logger:log("DAEMON_INIT", "Daemon init result: " .. tostring(init_ok) .. ", player: " .. tostring(Daemon.player_type))
    
    self:loadAndPlayCurrentPage()
end

function Controller:loadAndPlayCurrentPage()
    self.state = "LOADING"
    Logger:log("LOAD_PAGE", "Loading page " .. tostring(self.current_page))
    self:showInfo("🔍 Đang trích xuất chữ trang " .. tostring(self.current_page) .. "...")
    
    UIManager:scheduleIn(0.1, function()
        local text = Extractor:getPageText(self.ui, self.current_page)
        
        if not text then
            Logger:log("LOAD_PAGE_ERROR", "No text found for page " .. tostring(self.current_page))
            self:showInfo("❌ Trang " .. tostring(self.current_page) .. " không có chữ để đọc!")
            self:stopSession()
            return
        end

        Logger:log("LOAD_PAGE_TEXT", "Text extracted, length: " .. tostring(#text))
        self:showInfo("🌐 Đang gửi " .. tostring(#text) .. " ký tự lên Cloudflare Edge-TTS...")

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
            self:showInfo("🔊 Đang phát ra loa/tai nghe (Trang " .. tostring(self.current_page) .. ")...")
            Logger:log("PLAYING", "Loading audio into daemon...")
            Daemon:loadAudio(curr_file)
            self:prefetchNextPage()
        else
            self.state = "IDLE"
            Logger:log("PLAY_ERROR", "Net error: " .. tostring(res))
            self:showInfo("⚠️ Không thể tải âm thanh:\n" .. tostring(res) .. "\n(Kiểm tra lại Wi-Fi hoặc URL Proxy)")
        end
    end)
end

function Controller:prefetchNextPage()
    if self.state ~= "PLAYING" then return end
    
    local next_page = self.current_page + 1
    local total_pages = 1
    if self.ui and self.ui.document then
        total_pages = self.ui.document:getPageCount()
    end
    
    if next_page > total_pages then return end

    local text = Extractor:getPageText(self.ui, next_page)
    if not text then return end

    local next_file = Daemon:getFilePath("chunk_next")
    
    UIManager:scheduleIn(0.2, function()
        if self.state == "PLAYING" then
            Logger:log("PREFETCH_NET", "Requesting prefetch audio for page " .. tostring(next_page))
            NetTTS:requestPageAudio(text, next_file, self.session_token, function(token)
                return token == self.session_token
            end)
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
    
    local curr_file = Daemon:getFilePath("chunk_curr")
    local next_file = Daemon:getFilePath("chunk_next")
    
    os.remove(curr_file)
    os.rename(next_file, curr_file)

    if self.ui and self.ui.handleEvent then
        local Event = require("ui/event")
        self.ui:handleEvent(Event:new("GotoPage", next_page))
    end

    Daemon:loadAudio(curr_file)
    self.page_transition_lock = false
    self.state = "PLAYING"

    self:prefetchNextPage()
end

function Controller:onUserManualPageTurn()
    Logger:log("MANUAL_PAGE_TURN", "User manually turned page")
    if self.state ~= "IDLE" then
        self:showInfo("⏹️ Dừng đọc TTS do lật trang thủ công")
        self:stopSession()
    end
end

function Controller:pauseSession()
    Logger:log("PAUSE", "State: " .. tostring(self.state))
    if self.state == "PLAYING" or self.state == "PREFETCHING" then
        Daemon:pauseAudio()
        self.state = "PAUSED"
        self:showInfo("⏸️ Tạm dừng đọc")
    elseif self.state == "PAUSED" then
        Daemon:pauseAudio()
        self.state = "PLAYING"
        self:showInfo("▶️ Tiếp tục đọc trang " .. tostring(self.current_page))
    end
end

function Controller:stopSession()
    Logger:log("STOP", "Stopping session...")
    self.state = "STOPPING"
    Daemon:stopAudio()
    Daemon:stopProcess()
    Daemon:cleanSessionDir()
    self.session_token = nil
    self.state = "IDLE"
    self:showInfo("⏹️ Đã dừng hẳn đọc TTS")
end

function Controller:setVolume(volume_percent)
    local cmd = string.format("amixer set Master %d%% 2>/dev/null; amixer set PCM %d%% 2>/dev/null", volume_percent, volume_percent)
    os.execute(cmd)
    self:showInfo("🔊 Đã chỉnh âm lượng: " .. tostring(volume_percent) .. "%")
end

function Controller:showInfo(msg)
    if self.ui then
        pcall(function()
            local InfoMessage = require("ui/widget/infomessage")
            UIManager:show(InfoMessage:new{
                text = msg,
                timeout = 2.5,
            })
        end)
    end
end

return Controller
