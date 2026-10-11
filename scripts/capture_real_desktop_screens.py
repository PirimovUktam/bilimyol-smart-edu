import os
import time
from playwright.sync_api import sync_playwright

OUTPUT_DIR = r"d:\projects\Bilimyol\public\images\desktop_demo_screens"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def capture_desktop_screens():
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome", headless=True)
        # 1920x1080 Desktop Viewport (16:9 Full HD)
        context = browser.new_context(
            viewport={"width": 1920, "height": 1080},
            device_scale_factor=1,
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
        )
        page = context.new_page()

        print("1. Capturing 01_landing_hero.png (Pitch Day / Platform Landing)...")
        page.goto("http://localhost:5173/pitch", wait_until="networkidle")
        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "01_landing_hero.png"))

        print("2. Capturing 02_course_selection.png (Fan tanlash)...")
        page.goto("http://localhost:5173/?view=course-selection", wait_until="networkidle")
        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "02_course_selection.png"))

        print("3. Capturing 03_onboarding_goal.png (Onboarding & Shaxsiy maqsad)...")
        page.goto("http://localhost:5173/?view=onboarding", wait_until="networkidle")
        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "03_onboarding_goal.png"))

        print("4. Capturing 04_placement_diagnostics.png (Diagnostik Placement Test)...")
        page.goto("http://localhost:5173/?view=placement", wait_until="networkidle")
        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "04_placement_diagnostics.png"))

        print("5. Capturing 05_knowledge_map.png (Bilim xaritasi - Knowledge Map)...")
        page.goto("http://localhost:5173/?view=knowledge-map", wait_until="networkidle")
        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "05_knowledge_map.png"))

        print("6. Capturing 06_adaptive_roadmap.png (Shaxsiy ta'lim yo'li - Roadmap)...")
        page.goto("http://localhost:5173/?view=roadmap", wait_until="networkidle")
        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "06_adaptive_roadmap.png"))

        print("7. Capturing 07_lesson_theory.png (Interaktiv dars nazariyasi & formulalar)...")
        page.goto("http://localhost:5173/?view=lesson&lessonId=lesson_math_functions_01", wait_until="networkidle")
        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "07_lesson_theory.png"))

        print("8. Capturing 08_lesson_practice.png (Amaliyot va savol tekshirish)...")
        # Click through step to reach question step
        for _ in range(3):
            next_btn = page.locator("button:has-text('Keyingisi')").first
            if next_btn.is_visible():
                next_btn.click()
                page.wait_for_timeout(600)
        # Select first option if available
        opt = page.locator("button:has-text('7')").first
        if opt.is_visible():
            opt.click()
            page.wait_for_timeout(500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "08_lesson_practice.png"))

        print("9. Capturing 09_yolchi_ai_tutor.png (Yo'lchi AI maslahatchisi)...")
        page.goto("http://localhost:5173/?view=ai-tutor", wait_until="networkidle")
        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "09_yolchi_ai_tutor.png"))

        print("10. Capturing 10_student_dashboard.png (O'quvchi bosh sahifasi - Dashboard)...")
        page.goto("http://localhost:5173/?view=dashboard", wait_until="networkidle")
        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "10_student_dashboard.png"))

        print("11. Capturing 11_progress_analytics.png (O'zlashtirish va progress tahlili)...")
        page.goto("http://localhost:5173/?view=progress", wait_until="networkidle")
        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "11_progress_analytics.png"))

        print("12. Capturing 12_pitch_outro.png (Pitch Day taqdimot va xulosa)...")
        page.goto("http://localhost:5173/pitch", wait_until="networkidle")
        page.evaluate("window.scrollTo(0, document.body.scrollHeight / 3)")
        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "12_pitch_outro.png"))

        browser.close()
        print("ALL 12 REAL 1920x1080 DESKTOP SCREENS CAPTURED SUCCESSFULLY!")

if __name__ == "__main__":
    capture_desktop_screens()
