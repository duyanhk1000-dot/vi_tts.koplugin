import re
from typing import List
from app.nlp.token_protector import token_protector
from app.nlp.sentence_splitter import sentence_splitter

class VietnameseNormalizer:
    def __init__(self):
        pass

    def clean_html(self, text: str) -> str:
        # Remove HTML tags and unescape basic entities
        clean = re.sub(r"<[^>]+>", "", text)
        clean = clean.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
        return clean

    def normalize(self, text: str) -> List[str]:
        cleaned = self.clean_html(text)
        protected_text, pmap = token_protector.protect(cleaned)

        raw_sentences = sentence_splitter.split(protected_text)

        final_sentences = []
        for sentence in raw_sentences:
            restored = token_protector.restore(sentence, pmap)
            restored = re.sub(r"\s+", " ", restored).strip()
            if len(restored) >= 2:
                final_sentences.append(restored)

        return final_sentences

normalizer = VietnameseNormalizer()
