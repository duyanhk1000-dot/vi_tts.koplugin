import re
from typing import Tuple, Dict

class TokenProtector:
    def __init__(self):
        # Protected abbreviations mapping
        self.abbreviations = {
            r"\bTP\.HCM\b": "__TOKEN_TPHCM__",
            r"\bTp\.HCM\b": "__TOKEN_TPHCM__",
            r"\bTp\. HCM\b": "__TOKEN_TPHCM__",
            r"\bTS\.\b": "__TOKEN_TIENSI__",
            r"\bGS\.\b": "__TOKEN_GIANGSI__",
            r"\bThS\.\b": "__TOKEN_THACSI__",
            r"\bBS\.\b": "__TOKEN_BACSI__",
            r"\bSt\.\b": "__TOKEN_SAINT__",
            r"\bv\.v\.\b": "__TOKEN_VANVAN__",
            r"\bv\.v\b": "__TOKEN_VANVAN__",
            r"\bSĐT\b": "__TOKEN_SDT__",
            r"\bsđt\b": "__TOKEN_SDT__",
        }

    def protect(self, text: str) -> Tuple[str, Dict[str, str]]:
        protected_map: Dict[str, str] = {}
        processed_text = text

        # Protect known abbreviations
        for pattern, placeholder in self.abbreviations.items():
            if re.search(pattern, processed_text):
                processed_text = re.sub(pattern, placeholder, processed_text)

        # Protect decimals and currency (e.g. 3.14, 100.000đ)
        decimal_matches = re.findall(r"\b\d+[\.,]\d+\b", processed_text)
        for idx, match in enumerate(decimal_matches):
            ph = f"__TOKEN_NUM_{idx}__"
            protected_map[ph] = match
            processed_text = processed_text.replace(match, ph, 1)

        return processed_text, protected_map

    def restore(self, text: str, protected_map: Dict[str, str]) -> str:
        restored = text
        # Restore placeholders
        restored = restored.replace("__TOKEN_TPHCM__", "Thành phố Hồ Chí Minh")
        restored = restored.replace("__TOKEN_TIENSI__", "Tiến sĩ")
        restored = restored.replace("__TOKEN_GIANGSI__", "Giáo sĩ")
        restored = restored.replace("__TOKEN_THACSI__", "Thạc sĩ")
        restored = restored.replace("__TOKEN_BACSI__", "Bác sĩ")
        restored = restored.replace("__TOKEN_SAINT__", "Thánh")
        restored = restored.replace("__TOKEN_VANVAN__", "vân vân")
        restored = restored.replace("__TOKEN_SDT__", "Số điện thoại")

        for ph, orig in protected_map.items():
            restored = restored.replace(ph, orig)

        return restored

token_protector = TokenProtector()
