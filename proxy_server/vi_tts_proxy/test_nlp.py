import unittest
from app.nlp.token_protector import token_protector
from app.nlp.sentence_splitter import sentence_splitter
from app.nlp.normalizer import normalizer
from app.core.cache_engine import cache_engine

class TestVietnameseNLP(unittest.TestCase):
    def test_token_protection(self):
        text = "Ông A sống ở TP.HCM có SĐT 0908123456."
        protected, pmap = token_protector.protect(text)
        self.assertIn("__TOKEN_TPHCM__", protected)
        self.assertIn("__TOKEN_SDT__", protected)

        restored = token_protector.restore(protected, pmap)
        self.assertIn("Thành phố Hồ Chí Minh", restored)
        self.assertIn("Số điện thoại", restored)

    def test_sentence_splitter(self):
        text = "Câu thứ nhất. Câu thứ hai? Câu thứ ba!"
        sentences = sentence_splitter.split(text)
        self.assertEqual(len(sentences), 3)
        self.assertEqual(sentences[0], "Câu thứ nhất.")
        self.assertEqual(sentences[1], "Câu thứ hai?")
        self.assertEqual(sentences[2], "Câu thứ ba!")

    def test_full_normalizer(self):
        raw_html = "<p>Ông A ở Tp.HCM nói: Hello! sđt là 090123.</p>"
        res = normalizer.normalize(raw_html)
        self.assertTrue(len(res) >= 1)
        self.assertIn("Thành phố Hồ Chí Minh", res[0])

    def test_cache_engine_key(self):
        key1 = cache_engine.generate_key("Xin chào", "vi-VN-HoaiMyNeural", "+0%", "+0Hz")
        key2 = cache_engine.generate_key("Xin chào", "vi-VN-HoaiMyNeural", "+0%", "+0Hz")
        key3 = cache_engine.generate_key("Xin chào khác", "vi-VN-HoaiMyNeural", "+0%", "+0Hz")
        self.assertEqual(key1, key2)
        self.assertNotEqual(key1, key3)

if __name__ == "__main__":
    unittest.main()
