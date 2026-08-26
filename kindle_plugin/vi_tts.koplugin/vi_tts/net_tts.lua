local socket_http = require("socket.http")
local ltn12 = require("ltn12")
local Logger = require("vi_tts/logger")

local has_ssl, https = pcall(require, "ssl.https")

local NetTTS = {
    proxy_url = "https://vi-tts-koplugin.duyanhk1000.workers.dev/api/v1/tts/page",
    voice = "vi-VN-HoaiMyNeural",
    rate = "+0%",
    pitch = "+0Hz",
    timeout = 10.0,
}

function NetTTS:requestPageAudio(text, target_path, session_token, expected_token_cb, status_cb)
    if not text or #text == 0 or not target_path then
        Logger:log("NET_ERROR", "Invalid arguments for requestPageAudio")
        return false, "Invalid arguments"
    end

    local is_https = self.proxy_url:match("^https://")
    Logger:log("NET_START", "URL: " .. tostring(self.proxy_url) .. " [HTTPS=" .. tostring(is_https ~= nil) .. ", luasec=" .. tostring(has_ssl) .. "]")

    if is_https and not has_ssl then
        Logger:log("NET_ERROR", "HTTPS requested but luasec (ssl.https) module missing!")
        return false, "KOReader thiếu module SSL/HTTPS (Dùng HTTP thường)"
    end

    if status_cb then status_cb("🌐 Đang kết nối Cloudflare Proxy (" .. (is_https and "HTTPS" or "HTTP") .. ")...") end

    local escaped_text = text:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '')
    local json_body = string.format(
        '{"text":"%s","voice":"%s","rate":"%s","pitch":"%s"}',
        escaped_text, self.voice, self.rate, self.pitch
    )

    local file_handle = io.open(target_path, "w+b")
    if not file_handle then
        Logger:log("NET_ERROR", "Cannot open target file for writing: " .. tostring(target_path))
        return false, "Không thể tạo file đệm trên Kindle"
    end

    local req_fn = is_https and https.request or socket_http.request

    -- Socketutil timeout handling
    local socketutil = pcall(require, "socketutil") and require("socketutil") or nil
    if socketutil then
        pcall(function() socketutil:set_timeout(self.timeout, self.timeout * 2) end)
    end

    local req_tab = {
        url = self.proxy_url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#json_body),
            ["User-Agent"] = "KOReader-vi_tts/3.2.6",
            ["X-Request-ID"] = session_token or "req_" .. tostring(os.time()),
        },
        source = ltn12.source.string(json_body),
        sink = ltn12.sink.file(file_handle)
    }

    local ok, status_code, resp_headers, status_line = pcall(req_fn, req_tab)

    if socketutil then
        pcall(function() socketutil:reset_timeout() end)
    end

    file_handle:close()

    local code = tonumber(status_code) or 0
    Logger:log("NET_RESULT", "Pcall ok: " .. tostring(ok) .. ", Code: " .. tostring(code) .. ", Line: " .. tostring(status_line))

    if expected_token_cb and type(expected_token_cb) == "function" then
        if not expected_token_cb(session_token) then
            Logger:log("NET_DISCARD", "Token changed, discarding file")
            os.remove(target_path)
            return false, "Phiên đọc đã thay đổi"
        end
    end

    if ok and (code == 200 or status_code == 200) then
        local f_check = io.open(target_path, "rb")
        local f_size = 0
        if f_check then
            f_size = f_check:seek("end")
            f_check:close()
        end
        Logger:log("NET_SUCCESS", "Downloaded audio size: " .. tostring(f_size) .. " bytes")
        if status_cb then status_cb("✅ Tải xong (" .. math.floor(f_size/1024) .. " KB)") end
        return true, target_path
    else
        os.remove(target_path)
        local err_detail = "HTTP Error " .. tostring(code)
        if code == 0 then err_detail = "Không thể kết nối Server (Mạng yếu/Timeout)" end
        Logger:log("NET_FAIL", err_detail)
        return false, err_detail
    end
end

return NetTTS
