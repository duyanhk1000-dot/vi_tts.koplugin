/**
 * Cloudflare Worker for Vietnamese Text-To-Speech (vi_tts) Proxy v3.5.1
 * - Edge-TTS WebSocket Engine with dynamic SSML Prosody Rate (+30%, -20%, etc.)
 * - Native Google TTS Fallback
 * - Cleans Vietnamese abbreviations (TP.HCM, SĐT, Dr...)
 * - Concatenates raw MP3 byte buffers dynamically
 */

const TRUSTED_TOKEN = "6A5AA1D4EA5E40799C57C69F6B56D665";
const EDGE_WS_URL = `wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=${TRUSTED_TOKEN}`;
const GOOGLE_TTS_BASE = "https://translate.google.com/translate_tts?ie=UTF-8&tl=vi&client=tw-ob&q=";

// Abbreviation replacement dictionary
const ABBREVIATIONS = [
  { pattern: /\bTP\.HCM\b/gi, replacement: "Thành phố Hồ Chí Minh" },
  { pattern: /\bTp\.HCM\b/gi, replacement: "Thành phố Hồ Chí Minh" },
  { pattern: /\bSĐT\b/gi, replacement: "Số điện thoại" },
  { pattern: /\bsđt\b/gi, replacement: "Số điện thoại" },
  { pattern: /\bTS\.\b/gi, replacement: "Tiến sĩ" },
  { pattern: /\bGS\.\b/gi, replacement: "Giáo sĩ" },
  { pattern: /\bBS\.\b/gi, replacement: "Bác sĩ" },
  { pattern: /\bv\.v\.\b/gi, replacement: "vân vân" },
  { pattern: /\bv\.v\b/gi, replacement: "vân vân" }
];

function cleanAndNormalize(text) {
  if (!text) return "";
  let cleaned = text.replace(/<[^>]+>/g, "").trim();
  for (const item of ABBREVIATIONS) {
    cleaned = cleaned.replace(item.pattern, item.replacement);
  }
  return cleaned;
}

function splitSentences(text, maxLen = 140) {
  if (!text) return [];
  const rawParts = text.split(/(?<=[.!?\n])\s+/);
  const sentences = [];
  
  for (let part of rawParts) {
    part = part.trim();
    if (!part) continue;

    if (part.length > maxLen) {
      const words = part.split(" ");
      let current = "";
      for (const word of words) {
        if ((current + " " + word).trim().length > maxLen) {
          if (current.trim()) sentences.push(current.trim());
          current = word;
        } else {
          current = current ? (current + " " + word) : word;
        }
      }
      if (current.trim()) sentences.push(current.trim());
    } else {
      sentences.push(part);
    }
  }
  return sentences;
}

async function synthesizeSentenceEdgeTTS(sentence, voice = "vi-VN-HoaiMyNeural", rate = "+0%") {
  return new Promise((resolve, reject) => {
    try {
      const ws = new WebSocket(EDGE_WS_URL);
      const audioChunks = [];
      const reqId = crypto.randomUUID().replace(/-/g, "");

      const timeoutTimer = setTimeout(() => {
        try { ws.close(); } catch(e) {}
        reject(new Error("Edge-TTS WebSocket timeout"));
      }, 6000);

      ws.addEventListener("open", () => {
        const configMsg = `Path: speech.config\r\nX-RequestId: ${reqId}\r\nContent-Type: application/json; charset=utf-8\r\n\r\n{"context":{"synthesis":{"audio":{"metadataversion":"2020.05.30","format":"audio-24khz-48kbitrate-mono-mp3"}}}}`;
        ws.send(configMsg);

        const ssml = `<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='vi-VN'><voice name='${voice}'><prosody rate='${rate}' pitch='+0Hz'>${sentence}</prosody></voice></speak>`;
        const ssmlMsg = `Path: ssml\r\nX-RequestId: ${reqId}\r\nContent-Type: application/ssml+xml\r\n\r\n${ssml}`;
        ws.send(ssmlMsg);
      });

      ws.addEventListener("message", (event) => {
        if (typeof event.data === "string") {
          if (event.data.includes("Path:turn.end")) {
            clearTimeout(timeoutTimer);
            try { ws.close(); } catch(e) {}
            const totalLen = audioChunks.reduce((acc, c) => acc + c.byteLength, 0);
            const finalBuf = new Uint8Array(totalLen);
            let offset = 0;
            for (const c of audioChunks) {
              finalBuf.set(c, offset);
              offset += c.byteLength;
            }
            resolve(finalBuf);
          }
        } else if (event.data instanceof ArrayBuffer) {
          const view = new DataView(event.data);
          const headerLen = view.getUint16(0);
          if (event.data.byteLength > headerLen + 2) {
            const audioBytes = new Uint8Array(event.data, headerLen + 2);
            audioChunks.push(audioBytes);
          }
        }
      });

      ws.addEventListener("error", (err) => {
        clearTimeout(timeoutTimer);
        reject(err);
      });
    } catch (err) {
      reject(err);
    }
  });
}

async function synthesizeSentenceGoogleTTS(sentence) {
  const encodedText = encodeURIComponent(sentence);
  const url = `${GOOGLE_TTS_BASE}${encodedText}`;

  const response = await fetch(url, {
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Referer": "https://translate.google.com/"
    }
  });

  if (!response.ok) {
    throw new Error(`Google TTS Error ${response.status}`);
  }

  const audioBuffer = await response.arrayBuffer();
  return new Uint8Array(audioBuffer);
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Health check endpoint
    if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/health")) {
      return new Response(JSON.stringify({ status: "ok", service: "vi_tts_cloudflare_worker", version: "3.5.1" }), {
        headers: { "Content-Type": "application/json" }
      });
    }

    if (request.method !== "POST" && url.pathname !== "/api/v1/tts/page") {
      return new Response("Not Found", { status: 404 });
    }

    try {
      const body = await request.json();
      const rawText = body.text || "";
      const voice = body.voice || "vi-VN-HoaiMyNeural";
      const rate = body.rate || "+0%";

      if (!rawText.trim()) {
        return new Response(JSON.stringify({ error: "Text field cannot be empty" }), { status: 400 });
      }

      const cleanedText = cleanAndNormalize(rawText);
      const sentences = splitSentences(cleanedText, 140);

      if (sentences.length === 0) {
        return new Response(JSON.stringify({ error: "No valid text found" }), { status: 422 });
      }

      const audioBuffers = [];
      let lastErr = "";

      for (const sentence of sentences) {
        let audioBytes = null;

        -- Try Edge-TTS WebSocket first (supports speed/rate control)
        try {
          audioBytes = await synthesizeSentenceEdgeTTS(sentence, voice, rate);
        } catch (e) {
          lastErr = "Edge-TTS error: " + e.message;
        }

        -- Fallback to Google TTS if Edge-TTS failed
        if (!audioBytes || audioBytes.byteLength === 0) {
          try {
            audioBytes = await synthesizeSentenceGoogleTTS(sentence);
          } catch (e) {
            lastErr = "Google TTS error: " + e.message;
          }
        }

        if (audioBytes && audioBytes.byteLength > 0) {
          audioBuffers.push(audioBytes);
        }
      }

      if (audioBuffers.length === 0) {
        return new Response(JSON.stringify({ error: "Failed to synthesize audio: " + lastErr }), { status: 500 });
      }

      // Concatenate raw MP3 chunks
      const totalLen = audioBuffers.reduce((acc, b) => acc + b.byteLength, 0);
      const finalMp3 = new Uint8Array(totalLen);
      let offset = 0;
      for (const buf of audioBuffers) {
        finalMp3.set(buf, offset);
        offset += buf.byteLength;
      }

      return new Response(finalMp3.buffer, {
        headers: {
          "Content-Type": "audio/mpeg",
          "Cache-Control": "public, max-age=86400",
          "X-Request-ID": crypto.randomUUID()
        }
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), { status: 500 });
    }
  }
};
