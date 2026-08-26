local http = require("socket.http")
local ltn12 = require("ltn12")
local Logger = require("vi_tts/logger")

local NetTTS = {
    proxy_url = "https://vi-tts-koplugin.duyanhk1000.workers.dev/api/v1/tts/page",
    voice = "vi-VN-HoaiMyNeural",
    rate = "+0%",
    pitch = "+0Hz",
    timeout = 8.0,
}

function NetTTS:requestPageAudio(text, target_path, session_token, expected_token_cb, status_cb)
    if not text or #text == 0 or not target_path then
        Logger:log("NET_ERROR", "Invalid arguments for requestPageAudio")
        return false, "Invalid arguments"
    end

    if status_cb then status_cb("🌐 Đang kết nối Server Proxy Cloudflare...") end
    Logger:log("NET_START", "Requesting URL: " .. tostring(self.proxy_url) .. ", target_path: " .. tostring(target_path))

    local escaped_text = text:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '')
    local json_body = string.format(
        '{"text":"%s","voice":"%s","rate":"%s","pitch":"%s"}',
        escaped_text, self.voice, self.rate, self.pitch
    )

    http.TIMEOUT = self.timeout

    local file_handle = io.open(target_path, "w+b")
    if not file_handle then
        Logger:log("NET_ERROR", "Cannot open target file for writing: " .. tostring(target_path))
        return false, "Không thể tạo file đệm trên Kindle"
    end

    local res, code = pcall(function()
        return http.request{
            url = self.proxy_url,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#json_body),
                ["X-Request-ID"] = session_token or "req_" .. tostring(os.time()),
            },
            source = ltn12.source.string(json_body),
            sink = ltn12.sink.file(file_handle)
        }
    end)

    Logger:log("NET_END", "Pcall result: " .. tostring(res) .. ", HTTP Code: " .. tostring(code))

    if expected_token_cb and type(expected_token_cb) == "function" then
        if not expected_token_cb(session_token) then
            Logger:log("NET_DISCARD", "Token changed, discarding file: " .. tostring(target_path))
            os.remove(target_path)
            return false, "Phiên đọc đã bị thay đổi"
        end
    end

    if res and code == 200 then
        local f_size = 0
        local f_check = io.open(target_path, "rb")
        if f_check then
            f_size = f_check:seek("end")
            f_check:close()
        end
        Logger:log("NET_SUCCESS", "Successfully downloaded audio size: " .. tostring(f_size) .. " bytes")
        if status_cb then status_cb("✅ Tải âm thanh xong (" .. math.floor(f_size/1024) .. " KB)") end
        return true, target_path
    else
        os.remove(target_path)
        Logger:log("NET_FAIL", "HTTP Request failed. Code: " .. tostring(code))
        local err_msg = "Lỗi HTTP " .. tostring(code)
        if not res then err_msg = "Mạng yếu / Timeout kết nối" end
        return false, err_msg
    end
end

return NetTTS
