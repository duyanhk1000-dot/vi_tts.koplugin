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
end

function Controller:startSession()
    if self.state ~= "IDLE" then
        self:stopSession()
    end

    self.session_id = tostring(os.time())
    self.session_token = "token_" .. self.session_id .. "_" .. tostring(math.random(1000, 9999))
    
    if self.ui and self.ui.document then
        self.current_page = self.ui.document:getCurrentPage()
    end
    
    self.state = "STARTING"
    Daemon:init(self.session_id)
    
    self:loadAndPlayCurrentPage()
end

function Controller:loadAndPlayCurrentPage()
    self.state = "LOADING"
    
    local text = Extractor:getPageText(self.ui, self.current_page)
    if not text then
        self:showToast("Không tìm thấy văn bản trang " .. tostring(self.current_page))
        self:stopSession()
        return
    end

    local curr_file = Daemon:getFilePath("chunk_curr")
    
    local ok, res = NetTTS:requestPageAudio(text, curr_file, self.session_token, function(token)
        return token == self.session_token
    end)

    if ok then
        self.state = "PLAYING"
        Daemon:loadAudio(curr_file)
        self:prefetchNextPage()
    else
        self:showToast("Lỗi tải âm thanh: " .. tostring(res))
        self:safePause()
    end
end

function Controller:prefetchNextPage()
    if self.state ~= "PLAYING" then return end
    
    local next_page = self.current_page + 1
    local total_pages = 1
    if self.ui and self.ui.document then
        total_pages = self.ui.document:getPageCount()
    end
    
    if next_page > total_pages then return end

    self.state = "PREFETCHING"
    local text = Extractor:getPageText(self.ui, next_page)
    if not text then return end

    local next_file = Daemon:getFilePath("chunk_next")
    
    NetTTS:requestPageAudio(text, next_file, self.session_token, function(token)
        return token == self.session_token
    end)
    
    self.state = "PLAYING"
end

function Controller:onTrackFinished()
    if self.state ~= "PLAYING" and self.state ~= "PREFETCHING" then return end

    local next_page = self.current_page + 1
    local total_pages = 1
    if self.ui and self.ui.document then
        total_pages = self.ui.document:getPageCount()
    end

    if next_page > total_pages then
        self:showToast("Đã đọc hết cuốn sách!")
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
    if self.state ~= "IDLE" then
        self:showToast("Dừng đọc TTS do lật trang thủ công")
        self:stopSession()
    end
end

function Controller:pauseSession()
    if self.state == "PLAYING" or self.state == "PREFETCHING" then
        Daemon:pauseAudio()
        self.state = "PAUSED"
        self:showToast("Tạm dừng đọc")
    elseif self.state == "PAUSED" then
        Daemon:pauseAudio()
        self.state = "PLAYING"
        self:showToast("Tiếp tục đọc")
    end
end

function Controller:safePause()
    Daemon:stopAudio()
    self.state = "IDLE"
    self:showToast("Tạm dừng an toàn (Safe Pause)")
end

function Controller:stopSession()
    self.state = "STOPPING"
    Daemon:stopAudio()
    Daemon:stopProcess()
    Daemon:cleanSessionDir()
    self.session_token = nil
    self.state = "IDLE"
    self:showToast("Đã dừng đọc TTS")
end

function Controller:showToast(msg)
    if self.ui and self.ui.handleEvent then
        pcall(function()
            local Event = require("ui/event")
            self.ui:handleEvent(Event:new("Notification", msg))
        end)
    end
end

return Controller
