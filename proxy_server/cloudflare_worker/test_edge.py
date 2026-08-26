import asyncio
import edge_tts

async def main():
    comm = edge_tts.Communicate("Xin chào các bạn", "vi-VN-HoaiMyNeural")
    await comm.save("test_edge.mp3")
    print("Edge-TTS Python test SUCCESS!")

if __name__ == "__main__":
    asyncio.run(main())
