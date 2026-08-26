local Logger = {
    log_file = "/tmp/vi_tts_debug.log",
}

function Logger:log(tag, msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = string.format("[%s] [%s] %s\n", timestamp, tostring(tag), tostring(msg))
    
    -- Write to file immediately and flush
    local f = io.open(self.log_file, "a+")
    if f then
        f:write(line)
        f:flush()
        f:close()
    end

    -- Also print to KOReader system log
    pcall(function()
        local logger = require("logger")
        logger.info(string.format("vi_tts [%s]: %s", tostring(tag), tostring(msg)))
    end)
end

function Logger:clear()
    local f = io.open(self.log_file, "w")
    if f then
        f:write("=== VI_TTS DEBUG LOG STARTED ===\n")
        f:close()
    end
end

return Logger
