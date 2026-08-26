local http = require("socket.http")
local ltn12 = require("ltn12")

local NetTTS = {
    proxy_url = "https://vi-tts-koplugin.duyanhk1000.workers.dev/api/v1/tts/page",
    voice = "vi-VN-HoaiMyNeural",
    rate = "+0%",
    pitch = "+0Hz",
    timeout = 5.0,
}

function NetTTS:requestPageAudio(text, target_path, session_token, expected_token_cb)
    if not text or #text == 0 or not target_path then
        return false, "Invalid arguments"
    end

    local escaped_text = text:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '')
    local json_body = string.format(
        '{"text":"%s","voice":"%s","rate":"%s","pitch":"%s"}',
        escaped_text, self.voice, self.rate, self.pitch
    )

    http.TIMEOUT = self.timeout

    local res, code = http.request{
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

    if expected_token_cb and type(expected_token_cb) == "function" then
        if not expected_token_cb(session_token) then
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
