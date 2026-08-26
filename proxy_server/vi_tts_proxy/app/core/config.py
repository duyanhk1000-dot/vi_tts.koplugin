import os
from pathlib import Path

class Settings:
    PROJECT_NAME: str = "vi_tts_proxy"
    VERSION: str = "3.2.0"
    
    # Cache settings
    CACHE_DIR: Path = Path(os.getenv("CACHE_DIR", "/tmp/vi_tts_cache"))
    
    # Default TTS Voice settings
    DEFAULT_VOICE: str = "vi-VN-HoaiMyNeural"
    DEFAULT_RATE: str = "+0%"
    DEFAULT_PITCH: str = "+0Hz"
    
    # Audio output specifications (Kindle Touch optimized)
    AUDIO_FORMAT: str = "mp3"
    AUDIO_SAMPLE_RATE: int = 24000
    AUDIO_BITRATE: str = "32k"
    AUDIO_CHANNELS: int = 1  # Mono

settings = Settings()
settings.CACHE_DIR.mkdir(parents=True, exist_ok=True)
