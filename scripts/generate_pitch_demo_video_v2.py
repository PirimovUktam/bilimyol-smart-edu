import os
import asyncio
import subprocess
import edge_tts
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

# Paths
BASE_DIR = r"d:\projects\Bilimyol"
SCREENS_DIR = os.path.join(BASE_DIR, "public", "images", "demo_screens")
AUDIO_DIR = os.path.join(BASE_DIR, "public", "videos", "audio_temp")
OUTPUT_MP4 = os.path.join(BASE_DIR, "public", "videos", "bilimyol-pitch-demo.mp4")
OUTPUT_WEBM = os.path.join(BASE_DIR, "public", "videos", "bilimyol-pitch-demo.webm")
POSTER_PATH = os.path.join(BASE_DIR, "public", "videos", "bilimyol-pitch-demo-poster.jpg")

os.makedirs(AUDIO_DIR, exist_ok=True)

# Canvas 9:16 Full HD
WIDTH = 1080
HEIGHT = 1920
FPS = 24

FFMPEG_EXE = imageio_ffmpeg.get_ffmpeg_exe()

# Font setup (Windows standard Unicode TrueType fonts)
FONT_BOLD = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 36)
FONT_SEMI = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 26)
FONT_TEXT = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 28)
FONT_BADGE = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 20)

SCENES = [
    {
        "id": "01",
        "screen": "01_course_selection.png",
        "title": "1. Kirish va Fan Tanlash",
        "badge": "1-QADAM • FAN TANLASH",
        "voiceover": "Har bir o‘quvchining bilim darajasi va qabul qilish sur’ati turlicha. BilimYo‘l Smart Edu — bu bir xil darslik emas, balki har bir o‘quvchiga mos shaxsiy ta’lim yo‘lidir. Platformada hozirda Matematika va Ingliz tili fanlari to‘liq integratsiya qilingan."
    },
    {
        "id": "02",
        "screen": "02_onboarding.png",
        "title": "2. Shaxsiy Maqsadni Belgilash",
        "badge": "2-QADAM • O‘QUV MAQSADI",
        "voiceover": "O‘quvchi o‘zining sinfi va maqsadini tanlaydi: xoh maktab dasturini mustahkamlash, xoh olimpiada yoki imtihonga tayyorgarlik bo‘lsin, platforma har bir maqsad uchun alohida o‘quv rejasini moslashtiradi."
    },
    {
        "id": "03",
        "screen": "03_placement_test.png",
        "title": "3. Adaptiv Diagnostika Testi",
        "badge": "3-QADAM • PLACEMENT TEST",
        "voiceover": "O‘qish boshlanishidan oldin o‘quvchi adaptiv diagnostika testidan o‘tadi. Sakkizta aqlli savol orqali bilimdagi bo‘shliqlar xolis skanerlanadi va haqiqiy bilim darajasi aniqlanadi."
    },
    {
        "id": "04",
        "screen": "04_knowledge_map.png",
        "title": "4. Ko‘nikmalar Xaritasi",
        "badge": "4-QADAM • KNOWLEDGE MAP",
        "voiceover": "Diagnostika natijasida shaxsiy bilim xaritasi shakllanadi. Qaysi mavzularda ko‘nikma mustahkam, qaysi mavzularda esa bo‘shliqlar borligi nol dan yuz foizgacha bo‘lgan shkalada aniq ko‘rinadi."
    },
    {
        "id": "05",
        "screen": "05_roadmap.png",
        "title": "5. Shaxsiy O‘quv Traektoriyasi",
        "badge": "5-QADAM • ROADMAP",
        "voiceover": "Bilim xaritasi asosida o‘quvchining individual o‘quv yo‘li ochiladi. Standart kitobdagi ketma-ketlik emas, aynan shu o‘quvchi o‘rganishi zarur bo‘lgan darslar qadamma-qadam ochilib boradi."
    },
    {
        "id": "06",
        "screen": "06_lesson_theory.png",
        "title": "6. Interaktiv Nazariya va Tushuncha",
        "badge": "6-QADAM • NAZARIYA VA FORMULA",
        "voiceover": "Har bir dars nazariya, formulalar va ko‘rgazmali misollar bilan tushuntiriladi. O‘quvchi qoidani shunchaki yodlamaydi, balki uning mantiqiy asosini anglaydi."
    },
    {
        "id": "07",
        "screen": "07_lesson_practice.png",
        "title": "7. Amaliy Mashq va Test Yechish",
        "badge": "7-QADAM • AMALIYOT",
        "voiceover": "Nazariyadan so‘ng darhol interaktiv amaliyot boshlanadi. O‘quvchi misolni yechadi, to‘g‘ri javob variantini belgilaydi va tekshirish uchun tizimga yuboradi."
    },
    {
        "id": "08",
        "screen": "07_lesson_practice.png",
        "title": "8. Server-Side Scoring va Anti-Cheat",
        "badge": "8-QADAM • SERVERDA BAHOLASH",
        "voiceover": "Baholash PostgreSQL bazasidagi xavfsiz funksiya orqali to‘liq serverda amalga oshiriladi. Soxta ballar qo‘shishning oldi olingan, har bir to‘g‘ri javob uchun yigirma XP beriladi."
    },
    {
        "id": "09",
        "screen": "08_ai_tutor.png",
        "title": "9. Yo‘lchi AI Pedagogik Mentori",
        "badge": "9-QADAM • AI ASSISTANT",
        "voiceover": "Agar o‘quvchi javobda adashsa, Yo‘lchi AI yordamga keladi. U tayyor javobni bermaydi, balki xatoni qayerda qilganini tushuntirib, o‘quvchini to‘g‘ri yechimga yo‘naltiradi."
    },
    {
        "id": "10",
        "screen": "09_dashboard.png",
        "title": "10. Dashboard va Doimiy Rivojlanish",
        "badge": "10-QADAM • DASHBOARD VA NATIJA",
        "voiceover": "O‘quvchi o‘zining boshqaruv panelida kunlik streak, umumiy to‘plangan XP va o‘zlashtirish foizini ko‘rib boradi. Ota-onalar va ustozlar esa natijalarni doimiy kuzatishi mumkin."
    },
    {
        "id": "11",
        "screen": "11_pitch_outro.png",
        "title": "11. BilimYo‘l — Shaxsiy Ta’lim Yo‘li",
        "badge": "YAKUN • PITCH DAY 3.0",
        "voiceover": "BilimYo‘l Smart Edu — bu darslik emas, shaxsiy ta’lim yo‘li. Har bir o‘quvchi o‘z salohiyatini kashf etishi uchun yaratilgan milliy sun’iy intellekt platformasi."
    }
]

# Pre-render the static background gradient canvas once
def create_background():
    bg = Image.new("RGB", (WIDTH, HEIGHT), (11, 14, 23))
    draw = ImageDraw.Draw(bg)
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        r = int(10 * (1 - ratio) + 20 * ratio)
        g = int(13 * (1 - ratio) + 19 * ratio)
        b = int(24 * (1 - ratio) + 59 * ratio)
        draw.line([(0, y), (WIDTH, y)], fill=(r, g, b))
    draw.ellipse([(-100, -100), (500, 500)], fill=(30, 25, 75))
    draw.ellipse([(WIDTH - 400, 300), (WIDTH + 200, 900)], fill=(18, 45, 70))
    return bg

BACKGROUND_TEMPLATE = create_background()

def render_base_scene(scene_info):
    img = BACKGROUND_TEMPLATE.copy()
    draw = ImageDraw.Draw(img)

    # 1. Top Header Bar
    draw.text((60, 35), "BilimYo‘l", font=FONT_BOLD, fill=(255, 255, 255))
    draw.text((230, 42), "SMART EDU", font=FONT_SEMI, fill=(56, 151, 255))

    badge_text = scene_info["badge"]
    badge_w = int(draw.textlength(badge_text, font=FONT_BADGE)) + 28
    badge_x = WIDTH - 60 - badge_w
    draw.rounded_rectangle([(badge_x, 38), (WIDTH - 60, 76)], radius=19, fill=(35, 30, 80), outline=(98, 70, 245), width=2)
    draw.text((badge_x + 14, 46), badge_text, font=FONT_BADGE, fill=(255, 214, 107))

    # 2. Phone Screen Mockup Container
    phone_x = (WIDTH - 880) // 2
    phone_y = 100
    phone_w = 880
    phone_h = 1480

    # Phone drop shadow
    draw.rounded_rectangle([(phone_x - 12, phone_y - 8), (phone_x + phone_w + 12, phone_y + phone_h + 16)], radius=44, fill=(5, 5, 15))
    # Phone Bezel Outer
    draw.rounded_rectangle([(phone_x - 6, phone_y - 6), (phone_x + phone_w + 6, phone_y + phone_h + 6)], radius=40, fill=(30, 26, 65), outline=(98, 70, 245), width=2)
    # Phone Bezel Inner
    draw.rounded_rectangle([(phone_x, phone_y), (phone_x + phone_w, phone_y + phone_h)], radius=36, fill=(0, 0, 0))

    # Load real retina screenshot (860x1720)
    screen_path = os.path.join(SCREENS_DIR, scene_info["screen"])
    if os.path.exists(screen_path):
        screen_img = Image.open(screen_path)
        target_w = phone_w - 8
        target_h = phone_h - 8
        screen_resized = screen_img.resize((target_w, int(target_w * (1720 / 860))), Image.Resampling.LANCZOS)
        screen_cropped = screen_resized.crop((0, 0, target_w, target_h))
        img.paste(screen_cropped, (phone_x + 4, phone_y + 4))

    # Dynamic Island Pill on Phone
    island_w = 160
    island_h = 28
    island_x = (WIDTH - island_w) // 2
    draw.rounded_rectangle([(island_x, phone_y + 12), (island_x + island_w, phone_y + 12 + island_h)], radius=14, fill=(0, 0, 0))

    # 3. Bottom Frosted Subtitle Card
    card_y1 = 1610
    card_y2 = 1870
    card_x1 = 50
    card_x2 = WIDTH - 50

    draw.rounded_rectangle([(card_x1, card_y1), (card_x2, card_y2)], radius=28, fill=(15, 18, 35), outline=(98, 70, 245), width=2)
    draw.text((card_x1 + 30, card_y1 + 20), scene_info["title"], font=FONT_BOLD, fill=(255, 214, 107))

    vo_words = scene_info["voiceover"].split()
    lines = []
    curr = ""
    for w in vo_words:
        test = (curr + " " + w).strip()
        if draw.textlength(test, font=FONT_TEXT) > (card_x2 - card_x1 - 60):
            lines.append(curr)
            curr = w
        else:
            curr = test
    if curr:
        lines.append(curr)

    line_y = card_y1 + 75
    for l in lines[:4]:
        draw.text((card_x1 + 30, line_y), l, font=FONT_TEXT, fill=(240, 244, 255))
        line_y += 38

    return img

async def main():
    print("=== BILIMYO‘L SMART EDU HIGH-PERFORMANCE VIDEO & VOICE GENERATOR ===")

    # Get durations from existing generated audio files
    audio_files = []
    durations = []
    for sc in SCENES:
        af = os.path.join(AUDIO_DIR, f"scene_{sc['id']}.mp3")
        audio_files.append(af)
        probe_cmd = [FFMPEG_EXE, "-i", af]
        res = subprocess.run(probe_cmd, capture_output=True, text=True)
        dur_sec = 10.0
        for line in res.stderr.splitlines():
            if "Duration:" in line:
                try:
                    part = line.split("Duration:")[1].split(",")[0].strip()
                    h, m, s = part.split(":")
                    dur_sec = float(h) * 3600 + float(m) * 60 + float(s)
                except Exception:
                    pass
                break
        dur_sec += 0.4
        durations.append(dur_sec)
        print(f"Scene {sc['id']}: {dur_sec:.2f}s -> {sc['title']}")

    total_duration = sum(durations)
    print(f"\nTotal video duration: {total_duration:.2f}s ({total_duration/60:.2f} min)")

    # Build master audio file
    master_audio = os.path.join(AUDIO_DIR, "master_voiceover.mp3")
    concat_list_path = os.path.join(AUDIO_DIR, "concat_list.txt")
    with open(concat_list_path, "w", encoding="utf-8") as f:
        for af in audio_files:
            safe_af = af.replace("\\", "/")
            f.write(f"file '{safe_af}'\n")

    cmd_cat = [
        FFMPEG_EXE, "-y",
        "-f", "concat",
        "-safe", "0",
        "-i", concat_list_path,
        "-c:a", "libmp3lame",
        "-b:a", "192k",
        master_audio
    ]
    subprocess.run(cmd_cat, check=True)
    print(f"Master audio ready: {master_audio}")

    # Launch FFmpeg pipe
    cmd_video = [
        FFMPEG_EXE, "-y",
        "-f", "rawvideo",
        "-vcodec", "rawvideo",
        "-s", f"{WIDTH}x{HEIGHT}",
        "-pix_fmt", "rgb24",
        "-r", str(FPS),
        "-i", "-",
        "-i", master_audio,
        "-c:v", "libx264",
        "-preset", "faster",
        "-crf", "20",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "192k",
        "-shortest",
        "-movflags", "+faststart",
        OUTPUT_MP4
    ]

    print("Rendering frames and encoding Full HD video...")
    pipe_proc = subprocess.Popen(cmd_video, stdin=subprocess.PIPE)

    for idx, sc in enumerate(SCENES):
        dur = durations[idx]
        num_frames = int(dur * FPS)
        print(f"[{idx+1}/{len(SCENES)}] Processing {sc['title']} ({num_frames} frames)...")

        # Render the base scene ONCE
        base_img = render_base_scene(sc)
        
        # Save poster from scene 1
        if idx == 0:
            base_img.save(POSTER_PATH, quality=95)

        raw_bytes = base_img.tobytes()

        # Fast write to stdin pipe
        for _ in range(num_frames):
            pipe_proc.stdin.write(raw_bytes)

    pipe_proc.stdin.close()
    pipe_proc.wait()

    if pipe_proc.returncode != 0:
        raise RuntimeError("FFmpeg encoding failed!")

    mp4_size_mb = os.path.getsize(OUTPUT_MP4) / (1024 * 1024)
    print(f"\nSUCCESS! 1080x1920 MP4 Video Generated: {OUTPUT_MP4} ({mp4_size_mb:.2f} MB)")

    # Fast WebM VP9 export
    print("Generating WebM VP9 fallback version...")
    cmd_webm = [
        FFMPEG_EXE, "-y",
        "-i", OUTPUT_MP4,
        "-c:v", "libvpx-vp9",
        "-crf", "32",
        "-b:v", "0",
        "-deadline", "realtime",
        "-cpu-used", "8",
        "-threads", "8",
        "-c:a", "libopus",
        OUTPUT_WEBM
    ]
    subprocess.run(cmd_webm, check=True)
    webm_size_mb = os.path.getsize(OUTPUT_WEBM) / (1024 * 1024)
    print(f"SUCCESS! WebM fallback generated: {OUTPUT_WEBM} ({webm_size_mb:.2f} MB)")

if __name__ == "__main__":
    asyncio.run(main())
