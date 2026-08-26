local Daemon = {
    process = nil,
    session_dir = nil,
    last_parse_time = 0,
    binary_path = nil,
}

function Daemon:init(session_id)
    self.session_dir = "/tmp/vi_tts/session_" .. tostring(session_id)
    os.execute("mkdir -p " .. self.session_dir)

    local sys_binary = "/usr/bin/mpg123"
    local f = io.open(sys_binary, "r")
    if f then
        f:close()
        self.binary_path = sys_binary
    else
        os.execute("mkdir -p /tmp/vi_tts/bin")
        os.execute("cp ./plugins/vi_tts.koplugin/bin/armv7/mpg123 /tmp/vi_tts/bin/mpg123 2>/dev/null")
        os.execute("chmod +x /tmp/vi_tts/bin/mpg123 2>/dev/null")
        self.binary_path = "/tmp/vi_tts/bin/mpg123"
    end

    return self:startProcess()
end

function Daemon:startProcess()
    if self.process then
        self:stopProcess()
    end

    local cmd = string.format("%s -R -q 2>&1", self.binary_path)
    self.process = io.popen(cmd, "w")
    if not self.process then
        return false
    end
    return true
end

function Daemon:sendCommand(cmd_str)
    if self.process then
        self.process:write(cmd_str .. "\n")
        self.process:flush()
    end
end

function Daemon:loadAudio(file_path)
    if not file_path then return end
    self:sendCommand("L " .. file_path)
end

function Daemon:pauseAudio()
    self:sendCommand("P")
end

function Daemon:stopAudio()
    self:sendCommand("S")
end

function Daemon:stopProcess()
    if self.process then
        self:sendCommand("Q")
        self.process:close()
        self.process = nil
    end
    os.execute("killall -9 mpg123 2>/dev/null")
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
