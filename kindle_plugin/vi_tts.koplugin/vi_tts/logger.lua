local Logger = {
    plugin_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "/tmp/",
}

function Logger:getLogFilePath()
    return self.plugin_dir .. "debug_log.txt"
end

function Logger:log(tag, msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = string.format("[%s] [%s] %s\n", timestamp, tostring(tag), tostring(msg))
    
    -- Write to plugin directory debug_log.txt (Directly accessible via USB on PC)
    local f = io.open(self:getLogFilePath(), "a+")
    if f then
        f:write(line)
        f:flush()
        f:close()
    end

    -- Write to /tmp/vi_tts_debug.log
    local f_tmp = io.open("/tmp/vi_tts_debug.log", "a+")
    if f_tmp then
        f_tmp:write(line)
        f_tmp:flush()
        f_tmp:close()
    end
end

function Logger:clear()
    local f = io.open(self:getLogFilePath(), "w")
    if f then
        f:write("=== VI_TTS DEBUG LOG STARTED ===\n")
        f:close()
    end
end

return Logger
