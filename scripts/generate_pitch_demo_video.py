import os
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ARTIFACT_DIR = r"C:\Users\user\.gemini\antigravity-ide\brain\cb37e09c-08c7-4f27-9c9d-64951c13fae7"
OUTPUT_PATH = r"d:\projects\Bilimyol\public\videos\bilimyol-pitch-demo.mp4"
WIDTH = 720
HEIGHT = 1280
FPS = 24

# Storyboard scenes based on user Master Prompt Section 3.3
SCENES = [
    {
        "file": "course_selection_screen_1791726587615.png",
        "duration_sec": 12,
        "title": "BilimYo‘l Smart Edu",
        "chapter": "0:00 - Kirish / Hook",
        "voiceover": "Har bir o‘quvchi bir xil tezlikda o‘rganmaydi. Unda nega hamma uchun bir xil ta’lim yo‘li bo‘lishi kerak?"
    },
    {
        "file": "onboarding_screen_1791726594260.png",
        "duration_sec": 18,
        "title": "Muammo → Yechim",
        "chapter": "0:12 - Shaxsiy Tanlov",
        "voiceover": "BilimYo‘l o‘quvchining maqsadini aniqlab, ta’lim yo‘lini uning ehtiyojiga moslashtiradi."
    },
    {
        "file": "diagnostic_page_1791726618761.png",
        "duration_sec": 25,
        "title": "Adaptiv Diagnostika",
        "chapter": "0:30 - Placement Test",
        "voiceover": "8 ta moslashuvchan savol orqali bilimdagi bo‘shliqlar 0-100% shkalada xolis aniqlanadi."
    },
    {
        "file": "knowledge_map_screen_1791726654921.png",
        "duration_sec": 25,
        "title": "Bilim Xaritasi (Knowledge Map)",
        "chapter": "0:55 - Ko‘nikmalar Tahlili",
        "voiceover": "Diagnostika natijasi bilim xaritasini shakllantirishga va zaif mavzularni topishga yordam beradi."
    },
    {
        "file": "roadmap_screen_1791726661081.png",
        "duration_sec": 20,
        "title": "Shaxsiy Ta’lim Yo‘li (Roadmap)",
        "chapter": "1:20 - Individual Traektoriya",
        "voiceover": "Standart kitob emas — aynan o‘quvchi o‘zlashtirishi kerak bo‘lgan qadamli o‘quv xaritasi."
    },
    {
        "file": "interactive_lesson_screen_1791726669532.png",
        "duration_sec": 20,
        "title": "Interaktiv Dars (Nazariya & Misol)",
        "chapter": "1:40 - Qadamli Tushuntirish",
        "voiceover": "Mavzu nazariyasi, vizual modellar va amaliy misollar bilan bosqichma-bosqich o‘rganiladi."
    },
    {
        "file": "lesson_completion_modal_1791726680238.png",
        "duration_sec": 15,
        "title": "Amaliy Mashq va Savol Yechish",
        "chapter": "2:00 - Interaktiv Mashq",
        "voiceover": "O‘quvchi o‘rgangan qoidasini amalda sinaydi va javobni tekshirish uchun yuboradi."
    },
    {
        "file": "xp_modal_screen_1791726686220.png",
        "duration_sec": 15,
        "title": "Server-Side Scoring & Anti-Cheat",
        "chapter": "2:15 - Xolis Baholash",
        "voiceover": "Baholash va XP hisobi serverda mustaqil bajariladi. Soxta ballar butunlay istisno etilgan."
    },
    {
        "file": "ai_tutor_dashboard_1791726708763.png",
        "duration_sec": 15,
        "title": "Yo‘lchi AI Shaxsiy Mentori",
        "chapter": "2:30 - Sun’iy Intellekt Yordami",
        "voiceover": "Yo‘lchi AI tayyor javobni aytib bermaydi — xatoni tushunishga va qoidani anglashga yo‘naltiradi."
    },
    {
        "file": "ai_tutor_response_1791726715444.png",
        "duration_sec": 15,
        "title": "Pedagogik Tushuntirish & Maslahat",
        "chapter": "2:45 - Gemini Flash Integratsiyasi",
        "voiceover": "Har bir zaif mavzu bo‘yicha maxsus 3 qadamli pedagogik tushuntirish va misol beriladi."
    },
    {
        "file": "natijalar_view_screen_1791726735236.png",
        "duration_sec": 15,
        "title": "O‘quvchi Dashboardi va Natijalar",
        "chapter": "3:00 - Progress va Yutuqlar",
        "voiceover": "Real vaqt statistikasi, streak kunlari va o‘sish ko‘rsatkichlari."
    },
    {
        "file": "demo_page_screen_1791726750238.png",
        "duration_sec": 15,
        "title": "BilimYo‘l Smart Edu — Yakun",
        "chapter": "3:15 - Darslik emas, shaxsiy yo‘l",
        "voiceover": "BilimYo‘l — Darslik emas, shaxsiy ta’lim yo‘li. Bilim bilan o‘z yo‘lingizni toping."
    }
]

def create_scene_frame(img_path, scene_info, progress=0.0):
    # Base background: Dark navy gradient
    canvas = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    
    # Gradient background
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        # From #0B0E17 to #17164B
        b = int(23 * (1 - ratio) + 75 * ratio)
        g = int(14 * (1 - ratio) + 22 * ratio)
        r = int(11 * (1 - ratio) + 23 * ratio)
        canvas[y, :] = (b, g, r)

    # Load UI image
    full_path = os.path.join(ARTIFACT_DIR, img_path)
    if os.path.exists(full_path):
        ui_img = cv2.imread(full_path)
    else:
        ui_img = np.zeros((800, 390, 3), dtype=np.uint8)

    # Phone mockup container dimensions in 720x1280
    phone_w = 460
    phone_h = 920
    phone_x = (WIDTH - phone_w) // 2
    phone_y = 90

    # Resize UI to fit phone mockup
    if ui_img is not None:
        ui_resized = cv2.resize(ui_img, (phone_w - 20, phone_h - 40))
        # Add phone shadow & bezel
        cv2.rectangle(canvas, (phone_x - 4, phone_y - 4), (phone_x + phone_w + 4, phone_y + phone_h + 4), (50, 45, 90), -1)
        cv2.rectangle(canvas, (phone_x, phone_y), (phone_x + phone_w, phone_y + phone_h), (20, 20, 35), -1)
        
        # Place UI inside bezel
        canvas[phone_y + 20 : phone_y + 20 + ui_resized.shape[0], phone_x + 10 : phone_x + 10 + ui_resized.shape[1]] = ui_resized
        
        # Draw phone speaker notch
        notch_w = 120
        notch_h = 14
        notch_x = (WIDTH - notch_w) // 2
        cv2.rectangle(canvas, (notch_x, phone_y + 4), (notch_x + notch_w, phone_y + 4 + notch_h), (10, 10, 15), -1)

    # Convert to PIL for anti-aliased text rendering
    pil_img = Image.fromarray(cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(pil_img)

    # Top Chapter Badge
    badge_text = f"PITCH DAY 3.0  •  {scene_info['chapter']}"
    draw.rectangle([(phone_x, 35), (phone_x + phone_w, 75)], fill=(30, 25, 75, 230))
    draw.text((phone_x + 15, 45), badge_text, fill=(83, 214, 176))

    # Bottom Subtitle Overlay Card
    card_y = phone_y + phone_h + 20
    draw.rectangle([(40, card_y), (WIDTH - 40, HEIGHT - 40)], fill=(18, 17, 45, 245), outline=(98, 70, 245))
    
    # Title
    draw.text((60, card_y + 15), scene_info['title'], fill=(255, 214, 107))
    
    # Voiceover text (wrapped)
    vo_text = scene_info['voiceover']
    # Simple word wrap
    words = vo_text.split()
    lines = []
    curr = ""
    for w in words:
        if len(curr + " " + w) > 38:
            lines.append(curr)
            curr = w
        else:
            curr = (curr + " " + w).strip()
    if curr:
        lines.append(curr)

    line_y = card_y + 55
    for l in lines[:3]:
        draw.text((60, line_y), l, fill=(240, 240, 255))
        line_y += 30

    # Convert back to OpenCV
    frame_bgr = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
    return frame_bgr

def main():
    print("Generating official Pitch Day 3.0 Demo Video from real app recording...")
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    temp_raw = OUTPUT_PATH.replace(".mp4", "_raw.mp4")
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    writer = cv2.VideoWriter(temp_raw, fourcc, FPS, (WIDTH, HEIGHT))

    total_scenes = len(SCENES)
    for idx, sc in enumerate(SCENES):
        safe_title = sc['title'].encode('ascii', 'replace').decode('ascii')
        print(f"[{idx+1}/{total_scenes}] Processing {safe_title} ({sc['duration_sec']}s)...")
        num_frames = sc['duration_sec'] * FPS
        base_frame = create_scene_frame(sc['file'], sc)

        for f in range(num_frames):
            writer.write(base_frame)

    writer.release()
    print("Transcoding to universal web-standard H.264 (avc1) + AAC audio with faststart...")
    
    try:
        import imageio_ffmpeg
        import subprocess
        exe = imageio_ffmpeg.get_ffmpeg_exe()
        
        # 1. H.264 MP4
        cmd_mp4 = [
            exe, '-y',
            '-i', temp_raw,
            '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
            '-c:v', 'libx264',
            '-profile:v', 'main',
            '-level', '4.0',
            '-pix_fmt', 'yuv420p',
            '-crf', '24',
            '-preset', 'fast',
            '-c:a', 'aac',
            '-b:a', '128k',
            '-shortest',
            '-movflags', '+faststart',
            OUTPUT_PATH
        ]
        subprocess.run(cmd_mp4, check=True)
        if os.path.exists(temp_raw):
            os.remove(temp_raw)

        # 2. WebM Fallback
        webm_path = OUTPUT_PATH.replace(".mp4", ".webm")
        cmd_webm = [
            exe, '-y',
            '-i', OUTPUT_PATH,
            '-c:v', 'libvpx-vp9',
            '-crf', '32',
            '-b:v', '0',
            '-deadline', 'realtime',
            '-cpu-used', '8',
            '-threads', '8',
            '-c:a', 'libopus',
            webm_path
        ]
        subprocess.run(cmd_webm, check=True)
        
        file_size_mb = os.path.getsize(OUTPUT_PATH) / (1024 * 1024)
        print(f"SUCCESS! Web-compliant H.264 video written to {OUTPUT_PATH} ({file_size_mb:.2f} MB)")
        print(f"SUCCESS! WebM fallback written to {webm_path}")
    except Exception as e:
        print(f"Notice: ffmpeg transcode error ({e}), keeping raw file.")
        if os.path.exists(temp_raw):
            if os.path.exists(OUTPUT_PATH):
                os.remove(OUTPUT_PATH)
            os.rename(temp_raw, OUTPUT_PATH)

if __name__ == "__main__":
    main()
