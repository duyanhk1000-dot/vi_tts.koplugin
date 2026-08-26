import re
from typing import List

class SentenceSplitter:
    def __init__(self, max_chunk_len: int = 150):
        self.max_chunk_len = max_chunk_len

    def split(self, text: str) -> List[str]:
        if not text or not text.strip():
            return []

        # Clean multiple newlines and spaces
        cleaned = re.sub(r"\r\n|\r", "\n", text)
        lines = [line.strip() for line in cleaned.split("\n") if line.strip()]

        sentences = []
        for line in lines:
            # Split line by sentence-ending punctuation
            raw_splits = re.split(r"(?<=[.!?])\s+", line)
            for split in raw_splits:
                split = split.strip()
                if not split:
                    continue

                # Sub-split long chunks if > max_chunk_len
                if len(split) > self.max_chunk_len:
                    sub_chunks = self._sub_split(split)
                    sentences.extend(sub_chunks)
                else:
                    sentences.append(split)

        return sentences

    def _sub_split(self, text: str) -> List[str]:
        words = text.split(" ")
        chunks = []
        current_chunk = []

        for word in words:
            current_len = len(" ".join(current_chunk + [word]))
            if current_len > self.max_chunk_len and current_chunk:
                chunks.append(" ".join(current_chunk))
                current_chunk = [word]
            else:
                current_chunk.append(word)

        if current_chunk:
            chunks.append(" ".join(current_chunk))

        return chunks

sentence_splitter = SentenceSplitter()
