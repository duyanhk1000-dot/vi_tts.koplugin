local Logger = require("vi_tts/logger")

local Daemon = {
    session_id = nil,
    session_dir = "/tmp/vi_tts",
    player_type = nil,
}

function Daemon:init(session_id)
    self.session_id = session_id or tostring(os.time())
    self.session_dir = "/tmp/vi_tts/session_" .. self.session_id
    
    os.execute("mkdir -p " .. self.session_dir)
    Logger:log("DAEMON_INIT", "Created session dir: " .. self.session_dir)

    -- Auto-detect available audio player on Kindle OS
    if os.execute("which gst-launch-0.10 >/dev/null 2>&1") == 0 then
        self.player_type = "gst-launch-0.10"
    elseif os.execute("which mpg123 >/dev/null 2>&1") == 0 then
        self.player_type = "mpg123"
    elseif os.execute("which aplay >/dev/null 2>&1") == 0 then
        self.player_type = "aplay"
    else
        self.player_type = "none"
    end

    Logger:log("DAEMON_INIT", "Detected audio player: " .. tostring(self.player_type))
    return self.player_type ~= "none"
end

function Daemon:getFilePath(filename)
    return self.session_dir .. "/" .. filename .. ".mp3"
end

function Daemon:loadAudio(file_path)
    self:stopAudio()
    
    if self.player_type == "gst-launch-0.10" then
        local uri = "file://" .. file_path
        local cmd = string.format("gst-launch-0.10 playbin uri='%s' >/dev/null 2>&1 &", uri)
        os.execute(cmd)
        Logger:log("DAEMON_LOAD", "Playing via gst-launch-0.10 playbin: " .. file_path)
    elseif self.player_type == "mpg123" then
        local cmd = string.format("mpg123 -q '%s' >/dev/null 2>&1 &", file_path)
        os.execute(cmd)
        Logger:log("DAEMON_LOAD", "Playing via mpg123: " .. file_path)
    else
        local cmd = string.format("aplay -q '%s' >/dev/null 2>&1 &", file_path)
        os.execute(cmd)
        Logger:log("DAEMON_LOAD", "Playing via aplay: " .. file_path)
    end
end

function Daemon:stopAudio()
    if self.player_type == "gst-launch-0.10" then
        os.execute("killall -9 gst-launch-0.10 >/dev/null 2>&1")
    elseif self.player_type == "mpg123" then
        os.execute("killall -9 mpg123 >/dev/null 2>&1")
    elseif self.player_type == "aplay" then
        os.execute("killall -9 aplay >/dev/null 2>&1")
    end
    Logger:log("DAEMON_STOP", "Stopping audio")
end

function Daemon:isPlaying()
    if self.player_type == "gst-launch-0.10" then
        return os.execute("pgrep gst-launch-0.10 >/dev/null 2>&1") == 0
    elseif self.player_type == "mpg123" then
        return os.execute("pgrep mpg123 >/dev/null 2>&1") == 0
    elseif self.player_type == "aplay" then
        return os.execute("pgrep aplay >/dev/null 2>&1") == 0
    end
    return false
end

function Daemon:stopProcess()
    self:stopAudio()
end

function Daemon:cleanSessionDir()
    if self.session_dir and #self.session_dir > 10 then
        os.execute("rm -rf " .. self.session_dir)
        Logger:log("DAEMON_CLEAN", "Cleaned session dir: " .. self.session_dir)
    end
end

return Daemon
