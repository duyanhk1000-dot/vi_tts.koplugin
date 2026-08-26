local http = require("socket.http")
local ltn12 = require("ltn12")
local socket = require("socket")

local NetTTS = {
    proxy_url = "http://192.168.1.100:8000/api/v1/tts/page",
    voice = "vi-VN-HoaiMyNeural",
    rate = "+0%",
    pitch = "+0Hz",
    timeout = 3.0,
}

function NetTTS:requestPageAudio(text, target_path, session_token, expected_token_cb)
    if not text or #text == 0 or not target_path then
        return false, "Invalid arguments"
    end

    -- Construct JSON payload string manually (Lua 5.1 safe)
    local escaped_text = text:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '')
    local json_body = string.format(
        '{"text":"%s","voice":"%s","rate":"%s","pitch":"%s"}',
        escaped_text, self.voice, self.rate, self.pitch
    )

    local response_body = {}
    http.TIMEOUT = self.timeout

    local res, code, headers = http.request{
        url = self.proxy_url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#json_body),
            ["X-Request-ID"] = session_token or "req_" .. tostring(os.time()),
        },
        source = ltn12.source.string(json_body),
        sink = ltn12.sink.file(io.open(target_path, "w+b"))
    }

    -- Token Guard Validation
    if expected_token_cb and type(expected_token_cb) == "function" then
        if not expected_token_cb(session_token) then
            -- Token changed while fetching, discard output
            os.remove(target_path)
            return false, "Token expired/discarded"
        end
    end

    if code == 200 then
        return true, target_path
    else
        os.remove(target_path)
        return false, "HTTP Error " .. tostring(code)
    end
end

return NetTTS
