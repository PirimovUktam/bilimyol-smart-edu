import os
import asyncio
import subprocess
import edge_tts
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

# Paths
BASE_DIR = r"d:\projects\Bilimyol"
SCREENS_DIR = os.path.join(BASE_DIR, "public", "images", "desktop_demo_screens")
AUDIO_DIR = os.path.join(BASE_DIR, "public", "videos", "desktop_audio_temp")
OUTPUT_MP4 = os.path.join(BASE_DIR, "public", "videos", "bilimyol-pitch-demo.mp4")
OUTPUT_WEBM = os.path.join(BASE_DIR, "public", "videos", "bilimyol-pitch-demo.webm")
POSTER_PATH = os.path.join(BASE_DIR, "public", "videos", "bilimyol-pitch-demo-poster.jpg")

os.makedirs(AUDIO_DIR, exist_ok=True)

# Canvas 16:9 Full HD Desktop
WIDTH = 1920
HEIGHT = 1080
FPS = 24

FFMPEG_EXE = imageio_ffmpeg.get_ffmpeg_exe()

# Font setup (Windows standard Unicode TrueType fonts)
FONT_LOGO = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 26)
FONT_BADGE = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 18)
FONT_TITLE = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 26)
FONT_TEXT = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 21)
FONT_META = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 16)

SCENES = [
    {
        "id": "01",
        "screen": "01_landing_hero.png",
        "title": "1. Kirish va Platforma Missiyasi",
        "badge": "PITCH DAY 3.0 • BILIMYO‘L SMART EDU",
        "voiceover": "Har bir o‘quvchining bilim darajasi va qabul qilish sur’ati turlicha. BilimYo‘l Smart Edu — bu shunchaki darslar ro‘yxati emas, balki har bir o‘quvchiga mos shaxsiy ta’lim yo‘lidir."
    },
    {
        "id": "02",
        "screen": "02_course_selection.png",
        "title": "2. Fan Tanlash va Kurslar",
        "badge": "1-BOSQICH • FAN TANLASH",
        "voiceover": "Platformada hozirda Matematika va Ingliz tili fanlari to‘liq integratsiya qilingan bo‘lib, har ikki fan uchun mustaqil ta’lim traektoriyalari shakllantirilgan."
    },
    {
        "id": "03",
        "screen": "03_onboarding_goal.png",
        "title": "3. Shaxsiy Maqsadni Belgilash",
        "badge": "2-BOSQICH • ONBOARDING & PROFIL",
        "voiceover": "O‘quvchi o‘zining sinfi va maqsadini tanlaydi: maktab dasturini mustahkamlash, olimpiada yoki imtihonga tayyorgarlik bo‘yicha platforma individual o‘quv sur’atini moslashtiradi."
    },
    {
        "id": "04",
        "screen": "04_placement_diagnostics.png",
        "title": "4. Adaptiv Diagnostika Testi",
        "badge": "3-BOSQICH • DIAGNOSTIKA TESTI",
        "voiceover": "O‘qish boshlanishidan oldin o‘quvchi adaptiv diagnostika testidan o‘tadi. Sakkizta aqlli savol orqali bilimdagi bo‘shliqlar xolis skanerlanadi va boshlang‘ich daraja aniqlanadi."
    },
    {
        "id": "05",
        "screen": "05_knowledge_map.png",
        "title": "5. Ko‘nikmalar Xaritasi (Knowledge Map)",
        "badge": "4-BOSQICH • BILIM XARITASI",
        "voiceover": "Diagnostika natijasida interaktiv bilim xaritasi shakllanadi. Qaysi mavzular mustahkam o‘zlashtirilgan, qaysilarida esa bo‘shliqlar borligi nol dan yuz foizgacha bo‘lgan shkalada aniq ko‘rinadi."
    },
    {
        "id": "06",
        "screen": "06_adaptive_roadmap.png",
        "title": "6. Shaxsiy O‘quv Yo‘li (Roadmap)",
        "badge": "5-BOSQICH • ADAPTIV YO‘L",
        "voiceover": "Bilim xaritasi asosida o‘quvchining individual yo‘l xaritasi tuziladi. Standart kitobdagi ketma-ketlik emas, aynan shu o‘quvchi o‘rganishi zarur bo‘lgan darslar qadamma-qadam ochiladi."
    },
    {
        "id": "07",
        "screen": "07_lesson_theory.png",
        "title": "7. Interaktiv Nazariya va Tushuncha",
        "badge": "6-BOSQICH • NAZARIYA VA FORMULA",
        "voiceover": "Har bir dars boy nazariya, formulalar va ko‘rgazmali misollar bilan tushuntiriladi. O‘quvchi qoidani shunchaki yodlamaydi, balki uning mantiqiy asosini anglaydi."
    },
    {
        "id": "08",
        "screen": "08_lesson_practice.png",
        "title": "8. Amaliyot va Server-Side Scoring",
        "badge": "7-BOSQICH • AMALIYOT & XAVFSIZLIK",
        "voiceover": "Nazariyadan so‘ng darhol interaktiv amaliyot boshlanadi. Javob serverda xavfsiz baholanadi, anti-cheat mexanizmi ballar soxtalashtirilishining oldini oladi va o‘quvchiga XP beradi."
    },
    {
        "id": "09",
        "screen": "09_yolchi_ai_tutor.png",
        "title": "9. Yo‘lchi AI Pedagogik Mentori",
        "badge": "8-BOSQICH • YO‘LCHI AI AGENTI",
        "voiceover": "Agar o‘quvchi topshiriqda xatoga yo‘l qo‘ysa, Yo‘lchi AI yordamga keladi. U tayyor javobni aytib bermasdan, xatoning asl sababini tushuntiradi va mustahkamlovchi mashq taklif qiladi."
    },
    {
        "id": "10",
        "screen": "10_student_dashboard.png",
        "title": "10. Bosh Sahifa va Doimiy Rivojlanish",
        "badge": "9-BOSQICH • O‘QUVCHI DASHBOARD",
        "voiceover": "O‘quvchi o‘zining boshqaruv panelida kunlik darslarni davom ettiradi, to‘plangan XP, streak va o‘zlashtirish foizini ko‘radi. Ota-onalar esa natijalarni doimiy kuzatishi mumkin."
    },
    {
        "id": "11",
        "screen": "11_progress_analytics.png",
        "title": "11. O‘zlashtirish va Monitoring",
        "badge": "10-BOSQICH • PROGRESS MONITORING",
        "voiceover": "Barcha ko‘nikmalar bo‘yicha o‘zlashtirish dinamikasi real vaqt rejimida yangilanadi va o‘quvchining keyingi o‘rganish yo‘nalishini avtomatik moslashtiradi."
    },
    {
        "id": "12",
        "screen": "12_pitch_outro.png",
        "title": "12. BilimYo‘l — Darslik emas, shaxsiy ta’lim yo‘li",
        "badge": "YAKUN • PITCH DAY 3.0 TAQDIMOTI",
        "voiceover": "BilimYo‘l Smart Edu. Darslik emas — shaxsiy ta’lim yo‘li. Har bir o‘quvchiga o‘z imkoniyatlarini to‘liq ochish uchun eng ishonchli zanjir."
    }
]

async def generate_voiceovers():
    print("Generating Uzbek neural voiceovers (uz-UZ-SardorNeural)...")
    for sc in SCENES:
        af = os.path.join(AUDIO_DIR, f"scene_{sc['id']}.mp3")
        if not os.path.exists(af) or os.path.getsize(af) < 500:
            print(f"  Synthesizing scene {sc['id']}: {sc['title']}")
            comm = edge_tts.Communicate(sc["voiceover"], voice="uz-UZ-SardorNeural", rate="+3%")
            await comm.save(af)
        else:
            print(f"  Using existing audio for scene {sc['id']}")

def render_desktop_scene(scene_info, index_total):
    # Load 1920x1080 screenshot
    screen_path = os.path.join(SCREENS_DIR, scene_info["screen"])
    if os.path.exists(screen_path):
        base_img = Image.open(screen_path).convert("RGB")
        if base_img.size != (WIDTH, HEIGHT):
            base_img = base_img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
    else:
        base_img = Image.new("RGB", (WIDTH, HEIGHT), (11, 14, 23))

    # Create an overlay layer with alpha for glassmorphism HUD
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # 1. Top HUD Bar (Floating glass pill)
    top_x1, top_y1 = 40, 24
    top_x2, top_y2 = 560, 74
    draw.rounded_rectangle([(top_x1, top_y1), (top_x2, top_y2)], radius=25, fill=(10, 13, 24, 220), outline=(98, 70, 245, 180), width=2)
    # Circle indicator
    draw.ellipse([(top_x1 + 18, top_y1 + 16), (top_x1 + 36, top_y1 + 34)], fill=(83, 214, 176))
    draw.text((top_x1 + 46, top_y1 + 10), "BilimYo‘l", font=FONT_LOGO, fill=(255, 255, 255))
    draw.text((top_x1 + 165, top_y1 + 15), "SMART EDU", font=FONT_BADGE, fill=(56, 151, 255))
    draw.text((top_x1 + 295, top_y1 + 16), "• Real Web Demo", font=FONT_TEXT, fill=(203, 213, 225))

    # Top Right HUD (Step Indicator)
    right_x1, right_y1 = WIDTH - 280, 24
    right_x2, right_y2 = WIDTH - 40, 74
    draw.rounded_rectangle([(right_x1, right_y1), (right_x2, right_y2)], radius=25, fill=(10, 13, 24, 220), outline=(98, 70, 245, 180), width=2)
    draw.text((right_x1 + 25, right_y1 + 14), f"BOSQICH {scene_info['id']} / {index_total}", font=FONT_BADGE, fill=(255, 214, 107))
    draw.text((right_x1 + 160, right_y1 + 15), "• 1080p", font=FONT_META, fill=(148, 163, 184))

    # 2. Lower-Third HUD Subtitle Bar
    hud_x1 = 40
    hud_y1 = HEIGHT - 135
    hud_x2 = WIDTH - 40
    hud_y2 = HEIGHT - 25

    # Shadow
    draw.rounded_rectangle([(hud_x1 - 2, hud_y1 - 2), (hud_x2 + 2, hud_y2 + 2)], radius=24, fill=(5, 5, 15, 160))
    # Glass background
    draw.rounded_rectangle([(hud_x1, hud_y1), (hud_x2, hud_y2)], radius=22, fill=(10, 13, 24, 235), outline=(98, 70, 245, 200), width=2)

    # Badge in lower third
    badge_text = scene_info["badge"]
    badge_w = int(draw.textlength(badge_text, font=FONT_BADGE)) + 24
    badge_x = hud_x1 + 25
    badge_y = hud_y1 + 16
    draw.rounded_rectangle([(badge_x, badge_y), (badge_x + badge_w, badge_y + 32)], radius=16, fill=(35, 30, 80, 255), outline=(98, 70, 245, 255), width=1)
    draw.text((badge_x + 12, badge_y + 4), badge_text, font=FONT_BADGE, fill=(255, 214, 107))

    # Scene Title
    title_x = badge_x + badge_w + 20
    draw.text((title_x, hud_y1 + 18), scene_info["title"], font=FONT_TITLE, fill=(255, 255, 255))

    # Voiceover Subtitle Line(s)
    vo_words = scene_info["voiceover"].split()
    lines = []
    curr = ""
    max_w = hud_x2 - hud_x1 - 50
    for w in vo_words:
        test = (curr + " " + w).strip()
        if draw.textlength(test, font=FONT_TEXT) > max_w:
            lines.append(curr)
            curr = w
        else:
            curr = test
    if curr:
        lines.append(curr)

    sub_y = hud_y1 + 58
    for line in lines[:2]:
        draw.text((hud_x1 + 25, sub_y), line, font=FONT_TEXT, fill=(241, 245, 249))
        sub_y += 26

    # Merge base image with overlay
    final_img = Image.alpha_composite(base_img.convert("RGBA"), overlay)
    return final_img.convert("RGB")

async def main():
    print("=== BILIMYO‘L SMART EDU 1920x1080 DESKTOP VIDEO GENERATOR ===")

    await generate_voiceovers()

    # Measure durations
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
        dur_sec += 0.5  # comfortable padding between sentences
        durations.append(dur_sec)
        print(f"Scene {sc['id']}: {dur_sec:.2f}s -> {sc['title']}")

    total_duration = sum(durations)
    print(f"\nTotal video duration: {total_duration:.2f}s ({total_duration/60:.2f} min)")

    # Master audio concatenation
    master_audio = os.path.join(AUDIO_DIR, "master_voiceover_desktop.mp3")
    concat_list_path = os.path.join(AUDIO_DIR, "concat_list_desktop.txt")
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
    print(f"Master audio track generated: {master_audio}")

    # Save poster from scene 1
    poster_frame = render_desktop_scene(SCENES[0], len(SCENES))
    poster_frame.save(POSTER_PATH, quality=95)
    print(f"Poster thumbnail saved: {POSTER_PATH}")

    # Launch FFmpeg pipe for 1920x1080 MP4
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
        "-profile:v", "high",
        "-level", "4.1",
        "-preset", "medium",
        "-crf", "20",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "192k",
        "-ar", "44100",
        "-shortest",
        "-movflags", "+faststart",
        OUTPUT_MP4
    ]

    print("Encoding 1920x1080 Full HD MP4 video with FFmpeg...")
    process = subprocess.Popen(cmd_video, stdin=subprocess.PIPE)

    total_frames = 0
    for idx, sc in enumerate(SCENES):
        scene_img = render_desktop_scene(sc, len(SCENES))
        raw_bytes = scene_img.tobytes()
        num_frames = int(durations[idx] * FPS)
        print(f"  Rendering Scene {sc['id']}/{len(SCENES)}: {num_frames} frames ({durations[idx]:.1f}s)...")
        for _ in range(num_frames):
            process.stdin.write(raw_bytes)
            total_frames += 1

    process.stdin.close()
    process.wait()

    if process.returncode != 0:
        raise RuntimeError(f"FFmpeg MP4 encoding failed with code {process.returncode}")

    mp4_size_mb = os.path.getsize(OUTPUT_MP4) / (1024 * 1024)
    print(f"\nSUCCESS! 1920x1080 MP4 Ready: {OUTPUT_MP4} ({mp4_size_mb:.2f} MB, {total_frames} frames)")

    # Transcode WebM fallback
    print("Generating WebM (VP9 + Opus) fallback for maximum browser compatibility...")
    cmd_webm = [
        FFMPEG_EXE, "-y",
        "-i", OUTPUT_MP4,
        "-c:v", "libvpx-vp9",
        "-crf", "30",
        "-b:v", "0",
        "-c:a", "libopus",
        "-b:a", "128k",
        OUTPUT_WEBM
    ]
    subprocess.run(cmd_webm, check=True)
    webm_size_mb = os.path.getsize(OUTPUT_WEBM) / (1024 * 1024)
    print(f"SUCCESS! 1920x1080 WebM Ready: {OUTPUT_WEBM} ({webm_size_mb:.2f} MB)")

if __name__ == "__main__":
    asyncio.run(main())
