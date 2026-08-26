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
    elseif self:checkBinary("/usr/bin/aplay") or self:checkBinary("aplay") then
        self.binary_path = "aplay"
        self.player_type = "aplay"
    else
        self.player_type = "cmd"
    end

    return self:startProcess()
end

function Daemon:checkBinary(cmd)
    local res = os.execute("which " .. cmd .. " >/dev/null 2>&1")
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
    if self.player_type == "mpg123" and self.process then
        self:sendCommand("L " .. file_path)
    else
        -- Standalone command fallback (aplay / background play)
        os.execute(string.format("aplay -q %s 2>/dev/null &", file_path))
    end
end

function Daemon:pauseAudio()
    if self.player_type == "mpg123" then
        self:sendCommand("P")
    else
        os.execute("killall -STOP aplay 2>/dev/null")
    end
end

function Daemon:stopAudio()
    if self.player_type == "mpg123" then
        self:sendCommand("S")
    else
        os.execute("killall -KILL aplay 2>/dev/null")
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
    os.execute("killall -9 mpg123 aplay 2>/dev/null")
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
