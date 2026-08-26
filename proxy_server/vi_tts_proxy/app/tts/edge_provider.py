import asyncio
import edge_tts
from app.tts.base import BaseTTSProvider
from app.core.config import settings

class EdgeTTSProvider(BaseTTSProvider):
    async def synthesize(self, text: str, voice: str = settings.DEFAULT_VOICE, rate: str = settings.DEFAULT_RATE, pitch: str = settings.DEFAULT_PITCH) -> bytes:
        if not text or not text.strip():
            return b""
        
        communicate = edge_tts.Communicate(text=text, voice=voice, rate=rate, pitch=pitch)
        audio_buffer = bytearray()

        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_buffer.extend(chunk["data"])

        return bytes(audio_buffer)

edge_tts_provider = EdgeTTSProvider()
