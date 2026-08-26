/**
 * Cloudflare Worker for Vietnamese Text-To-Speech (vi_tts) Proxy
 * - Pure JavaScript / Web API runtime (Zero dependencies, Zero cold start)
 * - Natively calls Microsoft Edge-TTS Neural Speech API via fetch()
 * - Cleans Vietnamese abbreviations (TP.HCM, SĐT, Dr...)
 * - Concatenates raw MP3 byte buffers dynamically
 */

const TRUSTED_TOKEN = "6A5AA1D4EA5E40799C57C69F6B56D665";
const EDGE_REST_URL = `https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/single/v1?TrustedClientToken=${TRUSTED_TOKEN}`;

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

function splitSentences(text) {
  if (!text) return [];
  const rawParts = text.split(/(?<=[.!?\n])\s+/);
  const sentences = [];
  for (let part of rawParts) {
    part = part.trim();
    if (part.length > 0) {
      sentences.push(part);
    }
  }
  return sentences;
}

async function synthesizeSentenceEdgeTTS(sentence, voice = "vi-VN-HoaiMyNeural", rate = "+0%", pitch = "+0Hz") {
  const ssml = `<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='vi-VN'><voice name='${voice}'><prosody rate='${rate}' pitch='${pitch}'>${sentence}</prosody></voice></speak>`;
  const requestId = crypto.randomUUID().replace(/-/g, "");

  const response = await fetch(EDGE_REST_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/ssml+xml",
      "X-RequestId": requestId,
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
    },
    body: ssml
  });

  if (!response.ok) {
    throw new Error(`Edge-TTS REST Error ${response.status}`);
  }

  const audioBuffer = await response.arrayBuffer();
  return new Uint8Array(audioBuffer);
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Health check endpoint
    if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/health")) {
      return new Response(JSON.stringify({ status: "ok", service: "vi_tts_cloudflare_worker", version: "3.2.9" }), {
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
      const pitch = body.pitch || "+0Hz";

      if (!rawText.trim()) {
        return new Response(JSON.stringify({ error: "Text field cannot be empty" }), { status: 400 });
      }

      const cleanedText = cleanAndNormalize(rawText);
      const sentences = splitSentences(cleanedText);

      if (sentences.length === 0) {
        return new Response(JSON.stringify({ error: "No valid text found" }), { status: 422 });
      }

      const audioBuffers = [];
      for (const sentence of sentences) {
        try {
          const audioBytes = await synthesizeSentenceEdgeTTS(sentence, voice, rate, pitch);
          if (audioBytes && audioBytes.byteLength > 0) {
            audioBuffers.push(audioBytes);
          }
        } catch (e) {
          // Continue with remaining sentences
        }
      }

      if (audioBuffers.length === 0) {
        return new Response(JSON.stringify({ error: "Failed to synthesize audio for sentences" }), { status: 500 });
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
