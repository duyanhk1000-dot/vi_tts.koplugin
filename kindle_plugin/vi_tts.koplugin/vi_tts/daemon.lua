local Logger = require("vi_tts/logger")

local Daemon = {
    process = nil,
    session_dir = nil,
    player_type = "none",
    binary_path = nil,
}

function Daemon:init(session_id)
    self.session_dir = "/tmp/vi_tts/session_" .. tostring(session_id)
    os.execute("mkdir -p " .. self.session_dir)

    -- Detect available audio player on Kindle Touch / Linux
    if self:checkBinary("/usr/bin/mpg123") or self:checkBinary("mpg123") then
        self.binary_path = "mpg123"
        self.player_type = "mpg123"
    elseif self:checkBinary("/tmp/vi_tts/bin/mpg123") then
        self.binary_path = "/tmp/vi_tts/bin/mpg123"
        self.player_type = "mpg123"
    elseif self:checkBinary("gst-launch-0.10") then
        self.player_type = "gstreamer"
    else
        self.player_type = "cmd"
    end

    Logger:log("DAEMON_INIT", "Detected audio player: " .. tostring(self.player_type))
    return self:startProcess()
end

function Daemon:checkBinary(cmd)
    local res = os.execute("which " .. cmd .. " >/dev/null 2>&1")
    return res == 0
end

function Daemon:isPlaying()
    local res = os.execute("pidof gst-launch-0.10 >/dev/null 2>&1 || pidof mpg123 >/dev/null 2>&1 || pidof mplayer >/dev/null 2>&1 || pidof aplay >/dev/null 2>&1")
    return res == 0
end

function Daemon:startProcess()
    if self.player_type == "mpg123" then
        local cmd = string.format("%s -R -q 2>&1", self.binary_path)
        local ok, proc = pcall(io.popen, cmd, "w")
        if ok and proc then
            self.process = proc
            return true
        end
    end
    return true
end

function Daemon:sendCommand(cmd_str)
    if self.process and self.player_type == "mpg123" then
        pcall(function()
            self.process:write(cmd_str .. "\n")
            self.process:flush()
        end)
    end
end

function Daemon:loadAudio(file_path)
    if not file_path then return end
    Logger:log("DAEMON_LOAD", "Loading audio: " .. tostring(file_path))

    -- Kill any previous audio playback process to prevent overlapping sound
    os.execute("killall -9 gst-launch-0.10 mpg123 mplayer aplay 2>/dev/null")

    if self.player_type == "mpg123" and self.process then
        self:sendCommand("L " .. file_path)
        return
    end

    -- Cascade fallback: GStreamer 0.10 (Kindle Native MP3 Player) -> mpg123 -> mplayer -> aplay
    local play_cmd = string.format(
        "if which gst-launch-0.10 >/dev/null 2>&1; then " ..
        "  gst-launch-0.10 playbin uri=\"file://%s\" >/dev/null 2>&1 & " ..
        "elif which mpg123 >/dev/null 2>&1; then " ..
        "  mpg123 -q \"%s\" >/dev/null 2>&1 & " ..
        "elif which mplayer >/dev/null 2>&1; then " ..
        "  mplayer -quiet \"%s\" >/dev/null 2>&1 & " ..
        "else " ..
        "  aplay -q \"%s\" >/dev/null 2>&1 & " ..
        "fi",
        file_path, file_path, file_path, file_path
    )

    os.execute(play_cmd)
end

function Daemon:pauseAudio()
    Logger:log("DAEMON_PAUSE", "Pausing audio")
    if self.player_type == "mpg123" then
        self:sendCommand("P")
    else
        os.execute("killall -STOP gst-launch-0.10 mpg123 mplayer aplay 2>/dev/null")
    end
end

function Daemon:stopAudio()
    Logger:log("DAEMON_STOP", "Stopping audio")
    if self.player_type == "mpg123" then
        self:sendCommand("S")
    else
        os.execute("killall -KILL gst-launch-0.10 mpg123 mplayer aplay 2>/dev/null")
    end
end

function Daemon:stopProcess()
    if self.process and self.player_type == "mpg123" then
        pcall(function()
            self.process:write("Q\n")
            self.process:flush()
            self.process:close()
        end)
        self.process = nil
    end
    os.execute("killall -9 gst-launch-0.10 mpg123 mplayer aplay 2>/dev/null")
end

function Daemon:cleanSessionDir()
    if self.session_dir then
        os.execute("rm -rf " .. self.session_dir)
    end
end

function Daemon:getFilePath(chunk_name)
    return self.session_dir .. "/" .. chunk_name .. ".mp3"
end

return Daemon
