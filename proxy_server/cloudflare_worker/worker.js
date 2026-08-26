/**
 * Cloudflare Worker for Vietnamese Text-To-Speech (vi_tts) Proxy
 * - Pure JavaScript / Web API runtime (Zero dependencies, Zero cold start)
 * - Uses Google Translate TTS Vietnamese Endpoint (100% ultra-reliable)
 * - Cleans Vietnamese abbreviations (TP.HCM, SĐT, Dr...)
 * - Concatenates raw MP3 byte buffers dynamically
 */

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

async function synthesizeSentenceTTS(sentence) {
  const encodedText = encodeURIComponent(sentence);
  const url = `${GOOGLE_TTS_BASE}${encodedText}`;

  const response = await fetch(url, {
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Referer": "https://translate.google.com/"
    }
  });

  if (!response.ok) {
    throw new Error(`Google TTS Error ${response.status} ${response.statusText}`);
  }

  const audioBuffer = await response.arrayBuffer();
  return new Uint8Array(audioBuffer);
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Health check endpoint
    if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/health")) {
      return new Response(JSON.stringify({ status: "ok", service: "vi_tts_cloudflare_worker", version: "3.3.1" }), {
        headers: { "Content-Type": "application/json" }
      });
    }

    if (request.method !== "POST" && url.pathname !== "/api/v1/tts/page") {
      return new Response("Not Found", { status: 404 });
    }

    try {
      const body = await request.json();
      const rawText = body.text || "";

      if (!rawText.trim()) {
        return new Response(JSON.stringify({ error: "Text field cannot be empty" }), { status: 400 });
      }

      const cleanedText = cleanAndNormalize(rawText);
      const sentences = splitSentences(cleanedText, 140);

      if (sentences.length === 0) {
        return new Response(JSON.stringify({ error: "No valid text found" }), { status: 422 });
      }

      const audioBuffers = [];
      let lastErr = "Unknown error";

      for (const sentence of sentences) {
        try {
          const audioBytes = await synthesizeSentenceTTS(sentence);
          if (audioBytes && audioBytes.byteLength > 0) {
            audioBuffers.push(audioBytes);
          }
        } catch (e) {
          lastErr = e.message;
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
