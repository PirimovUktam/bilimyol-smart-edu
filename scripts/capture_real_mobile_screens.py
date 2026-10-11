import os
import time
from playwright.sync_api import sync_playwright

OUTPUT_DIR = r"d:\projects\Bilimyol\public\images\demo_screens"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def capture():
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome", headless=True)
        # Mobile viewport: 430x860 with DPR=2.0 -> 860x1720 crisp retina
        context = browser.new_context(
            viewport={"width": 430, "height": 860},
            device_scale_factor=2,
            user_agent="Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        )
        page = context.new_page()

        print("1. Capturing Course Selection...")
        page.goto("http://localhost:5173/courses")
        page.wait_for_timeout(1000)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "01_course_selection.png"))

        print("2. Capturing Onboarding / Goal Selection...")
        # Click Matematika or start onboarding
        math_btn = page.locator("text=Matematika").first
        if math_btn.is_visible():
            math_btn.click()
            page.wait_for_timeout(1000)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "02_onboarding.png"))

        print("3. Capturing Diagnostic Placement Test...")
        page.goto("http://localhost:5173/placement")
        page.wait_for_timeout(1200)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "03_placement_test.png"))

        print("4. Capturing Knowledge Map...")
        page.goto("http://localhost:5173/knowledge-map")
        page.wait_for_timeout(1200)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "04_knowledge_map.png"))

        print("5. Capturing Roadmap...")
        page.goto("http://localhost:5173/roadmap")
        page.wait_for_timeout(1200)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "05_roadmap.png"))

        print("6. Capturing Interactive Lesson...")
        page.goto("http://localhost:5173/lesson")
        page.wait_for_timeout(1200)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "06_lesson_theory.png"))

        print("7. Capturing Lesson Practice Question...")
        # Click through step to reach question or scroll down
        next_btn = page.locator("button:has-text('Keyingisi')").first
        if next_btn.is_visible():
            next_btn.click()
            page.wait_for_timeout(800)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "07_lesson_practice.png"))

        print("8. Capturing Yo'lchi AI Tutor...")
        page.goto("http://localhost:5173/ai-tutor")
        page.wait_for_timeout(1200)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "08_ai_tutor.png"))

        print("9. Capturing Student Dashboard...")
        page.goto("http://localhost:5173/dashboard")
        page.wait_for_timeout(1200)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "09_dashboard.png"))

        print("10. Capturing Progress Analytics...")
        page.goto("http://localhost:5173/progress")
        page.wait_for_timeout(1200)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "10_progress.png"))

        print("11. Capturing Pitch Outro...")
        page.goto("http://localhost:5173/pitch")
        page.wait_for_timeout(1200)
        page.screenshot(path=os.path.join(OUTPUT_DIR, "11_pitch_outro.png"))

        browser.close()
        print("ALL REAL MOBILE SCREENS CAPTURED SUCCESSFULLY!")

if __name__ == "__main__":
    capture()
