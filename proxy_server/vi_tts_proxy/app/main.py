import uuid
from pathlib import Path
from fastapi import FastAPI, HTTPException, Header, Response, BackgroundTask
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Optional

from app.core.config import settings
from app.core.cache_engine import cache_engine
from app.nlp.normalizer import normalizer
from app.tts.edge_provider import edge_tts_provider
from app.audio.encoder import audio_encoder

app = FastAPI(title=settings.PROJECT_NAME, version=settings.VERSION)

class PageTTSRequest(BaseModel):
    text: str
    voice: Optional[str] = settings.DEFAULT_VOICE
    rate: Optional[str] = settings.DEFAULT_RATE
    pitch: Optional[str] = settings.DEFAULT_PITCH

@app.get("/health")
def health_check():
    return {"status": "ok", "project": settings.PROJECT_NAME, "version": settings.VERSION}

@app.post("/api/v1/tts/page")
async def generate_page_tts(
    req: PageTTSRequest,
    x_request_id: Optional[str] = Header(None),
    x_generation_id: Optional[str] = Header(None)
):
    request_id = x_request_id or str(uuid.uuid4())
    
    if not req.text or not req.text.strip():
        raise HTTPException(status_code=400, detail="Text field cannot be empty.")

    voice = req.voice or settings.DEFAULT_VOICE
    rate = req.rate or settings.DEFAULT_RATE
    pitch = req.pitch or settings.DEFAULT_PITCH

    # Generate Cache Key for L2 (Page Level)
    l2_key = cache_engine.generate_key(req.text, voice, rate, pitch)
    cached_file = cache_engine.get_l2_page(l2_key)

    if cached_file:
        return FileResponse(
            path=cached_file,
            media_type="audio/mpeg",
            filename=f"page_{l2_key[:8]}.mp3",
            headers={
                "X-Request-ID": request_id,
                "X-Cache-Status": "HIT_L2",
                "X-Generation-ID": x_generation_id or request_id
            }
        )

    # Cache Miss: Run NLP Normalization
    sentences = normalizer.normalize(req.text)
    if not sentences:
        raise HTTPException(status_code=422, detail="Text contains no readable Vietnamese content.")

    # Synthesize sentence chunks
    chunk_audios = []
    for sentence in sentences:
        l1_key = cache_engine.generate_key(sentence, voice, rate, pitch)
        l1_audio = cache_engine.get_l1_sentence(l1_key)

        if not l1_audio:
            try:
                l1_audio = await edge_tts_provider.synthesize(sentence, voice, rate, pitch)
                if l1_audio:
                    cache_engine.save_l1_sentence(l1_key, l1_audio)
            except Exception as e:
                # Log error and continue with empty chunk
                l1_audio = b""

        if l1_audio:
            chunk_audios.append(l1_audio)

    if not chunk_audios:
        raise HTTPException(status_code=500, detail="Failed to synthesize audio for any sentence.")

    # Concatenate and encode to 32kbps mono MP3
    encoded_temp_file = audio_encoder.concatenate_and_encode(chunk_audios)
    final_l2_file = cache_engine.save_l2_page(l2_key, encoded_temp_file)

    # Cleanup temporary encoded file if needed
    def cleanup():
        if encoded_temp_file.exists() and encoded_temp_file != final_l2_file:
            try:
                encoded_temp_file.unlink()
            except Exception:
                pass

    return FileResponse(
        path=final_l2_file,
        media_type="audio/mpeg",
        filename=f"page_{l2_key[:8]}.mp3",
        background=BackgroundTask(cleanup),
        headers={
            "X-Request-ID": request_id,
            "X-Cache-Status": "MISS_SYNTHESIZED",
            "X-Generation-ID": x_generation_id or request_id
        }
    )
