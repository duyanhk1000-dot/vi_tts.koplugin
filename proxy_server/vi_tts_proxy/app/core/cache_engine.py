import hashlib
import os
from pathlib import Path
from typing import Optional
from app.core.config import settings

class CacheEngine:
    def __init__(self, cache_dir: Path = settings.CACHE_DIR):
        self.cache_dir = cache_dir
        self.l1_dir = self.cache_dir / "l1_sentences"
        self.l2_dir = self.cache_dir / "l2_pages"
        self.l1_dir.mkdir(parents=True, exist_ok=True)
        self.l2_dir.mkdir(parents=True, exist_ok=True)

    def generate_key(self, text: str, voice: str, rate: str, pitch: str, bitrate: str = settings.AUDIO_BITRATE) -> str:
        raw_key = f"v3.2_{text}_{voice}_{rate}_{pitch}_{bitrate}"
        return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()

    def get_l2_page(self, key: str) -> Optional[Path]:
        target = self.l2_dir / f"{key}.mp3"
        if target.exists() and target.stat().st_size > 0:
            return target
        return None

    def save_l2_page(self, key: str, file_path: Path) -> Path:
        target = self.l2_dir / f"{key}.mp3"
        if file_path != target:
            target.write_bytes(file_path.read_bytes())
        return target

    def get_l1_sentence(self, key: str) -> Optional[bytes]:
        target = self.l1_dir / f"{key}.mp3"
        if target.exists() and target.stat().st_size > 0:
            return target.read_bytes()
        return None

    def save_l1_sentence(self, key: str, audio_data: bytes) -> Path:
        target = self.l1_dir / f"{key}.mp3"
        target.write_bytes(audio_data)
        return target

cache_engine = CacheEngine()
