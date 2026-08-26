from abc import ABC, abstractmethod

class BaseTTSProvider(ABC):
    @abstractmethod
    async def synthesize(self, text: str, voice: str, rate: str, pitch: str) -> bytes:
        pass
