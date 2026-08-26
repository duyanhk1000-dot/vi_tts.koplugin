import io
import tempfile
from pathlib import Path
from typing import List
from pydub import AudioSegment
from app.core.config import settings

class AudioEncoder:
    def __init__(self):
        pass

    def concatenate_and_encode(self, chunk_audios: List[bytes]) -> Path:
        combined = AudioSegment.empty()
        
        for audio_bytes in chunk_audios:
            if not audio_bytes:
                continue
            segment = AudioSegment.from_file(io.BytesIO(audio_bytes), format="mp3")
            combined += segment
            # Add short 150ms silence between sentences
            combined += AudioSegment.silent(duration=150)

        # Re-sample to 24kHz Mono 32kbps
        combined = combined.set_frame_rate(settings.AUDIO_SAMPLE_RATE).set_channels(settings.AUDIO_CHANNELS)

        out_temp = tempfile.NamedTemporaryFile(suffix=".mp3", delete=False)
        out_path = Path(out_temp.name)
        out_temp.close()

        combined.export(
            out_path,
            format=settings.AUDIO_FORMAT,
            bitrate=settings.AUDIO_BITRATE,
            parameters=["-ac", str(settings.AUDIO_CHANNELS), "-ar", str(settings.AUDIO_SAMPLE_RATE)]
        )

        return out_path

audio_encoder = AudioEncoder()
