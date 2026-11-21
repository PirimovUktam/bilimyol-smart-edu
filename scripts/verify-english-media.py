import hashlib
import json
import math
import re
import struct
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT_DIR = ROOT / "content" / "english"
LEVEL_ORDER = ["a1", "a2", "b1", "b2", "c1", "c2"]
REQUIRED_LEVELS = ("a1", "a2", "b1")
CANONICAL_PATH_RE = re.compile(r"^/lesson-media/english/(?:[a-z0-9_-]+/)*[a-z0-9_-]+\.(wav|png)$")
FORBIDDEN_SVG_TEXT_RE = re.compile(r"<(text|tspan|textPath)[\s>]", re.IGNORECASE)
FORBIDDEN_PLACEHOLDER_RE = re.compile(r"\b(TBD|TODO|Lorem ipsum|Coming soon|Placeholder|Tez kunda)\b", re.IGNORECASE)
FORBIDDEN_CERT_CLAIM_RE = re.compile(r"(Official CEFR Certificate|Rasmiy CEFR sertifikati\b(?!.*bermaydi))", re.IGNORECASE)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def discover_manifests_and_curricula() -> tuple[list[Path], list[tuple[str, Path]], list[str]]:
    errors: list[str] = []
    manifest_paths: list[Path] = []
    curriculum_paths: list[tuple[str, Path]] = []

    starter_manifest = CONTENT_DIR / "starter-media.json"
    if not starter_manifest.is_file():
        errors.append(f"Missing required starter manifest: {starter_manifest}")
    else:
        manifest_paths.append(starter_manifest)

    placement_manifest = CONTENT_DIR / "placement-media.json"
    if not placement_manifest.is_file():
        errors.append(f"Missing required placement manifest: {placement_manifest}")
    else:
        manifest_paths.append(placement_manifest)

    for lvl in LEVEL_ORDER:
        m_path = CONTENT_DIR / f"{lvl}-media.json"
        c_path = CONTENT_DIR / f"{lvl}-curriculum.json"
        has_m = m_path.is_file()
        has_c = c_path.is_file()

        if lvl in REQUIRED_LEVELS:
            if not has_m:
                errors.append(f"Missing required media manifest: {m_path}")
            if not has_c:
                errors.append(f"Missing required curriculum document: {c_path}")
        elif has_m != has_c:
            errors.append(f"Unpaired level files for '{lvl}': media={has_m}, curriculum={has_c}")

        if has_m:
            manifest_paths.append(m_path)
        if has_c:
            curriculum_paths.append((lvl, c_path))

    return manifest_paths, curriculum_paths, errors


def verify_audio(
    manifest: dict,
    web_dir: Path,
    flutter_dir: Path,
    approved_media: dict,
    seen_media_ids: set[str],
    approved_audio_ids: set[str],
) -> list[str]:
    errors: list[str] = []
    expected_rate = manifest["sampleRate"]
    expected_channels = manifest["channels"]
    expected_width = manifest["sampleWidthBytes"]

    for item in manifest.get("audio", []):
        fid = item["id"]
        if fid in seen_media_ids:
            errors.append(f"Duplicate media id across manifests: '{fid}'")
        seen_media_ids.add(fid)

        filename = item["filename"]
        src = item["canonicalSource"]
        if src in approved_media:
            errors.append(f"{fid}: duplicate canonicalSource '{src}'")
        if not CANONICAL_PATH_RE.match(src):
            errors.append(f"{fid}: invalid canonicalSource '{src}'")
        if item.get("language", manifest.get("language")) != "en":
            errors.append(f"{fid}: language must be 'en'")
        review_status = item.get("reviewStatus", manifest.get("reviewStatus"))
        if review_status != "approved":
            errors.append(f"{fid}: reviewStatus must be 'approved'")
        if not item.get("transcript", "").strip():
            errors.append(f"{fid}: empty transcript")
        if not item.get("titleUz", "").strip() or not item.get("titleRu", "").strip():
            errors.append(f"{fid}: missing titleUz or titleRu")

        expected_web = ROOT / "public" / src.lstrip("/")
        expected_flutter = ROOT / "mobile" / "assets" / "lesson_media" / src.removeprefix("/lesson-media/")
        web_file = web_dir / filename
        flutter_file = flutter_dir / filename

        if web_file.resolve() != expected_web.resolve():
            errors.append(f"{fid}: webOutputDir/filename mismatch with canonicalSource ({web_file} != {expected_web})")
        if flutter_file.resolve() != expected_flutter.resolve():
            errors.append(f"{fid}: flutterOutputDir/filename mismatch with canonicalSource ({flutter_file} != {expected_flutter})")

        if not web_file.is_file():
            errors.append(f"{fid}: missing Web WAV {web_file}")
            continue
        if not flutter_file.is_file():
            errors.append(f"{fid}: missing Flutter WAV {flutter_file}")
            continue

        web_bytes = web_file.read_bytes()
        flutter_bytes = flutter_file.read_bytes()
        web_hash = sha256_bytes(web_bytes)
        flutter_hash = sha256_bytes(flutter_bytes)
        if web_hash != flutter_hash:
            errors.append(f"{fid}: Web/Flutter SHA-256 mismatch ({web_hash} vs {flutter_hash})")

        if len(web_bytes) < 44 or web_bytes[0:4] != b"RIFF" or web_bytes[8:12] != b"WAVE" or web_bytes[12:16] != b"fmt ":
            errors.append(f"{fid}: invalid RIFF/WAVE/fmt header")
            continue

        declared_riff_size = struct.unpack("<I", web_bytes[4:8])[0]
        if declared_riff_size != len(web_bytes) - 8:
            errors.append(f"{fid}: RIFF size mismatch ({declared_riff_size} != {len(web_bytes) - 8})")

        with wave.open(str(web_file), "rb") as wf:
            nchannels = wf.getnchannels()
            sampwidth = wf.getsampwidth()
            framerate = wf.getframerate()
            comptype = wf.getcomptype()
            nframes = wf.getnframes()
            raw_frames = wf.readframes(nframes)

        if (nchannels, sampwidth, framerate, comptype) != (expected_channels, expected_width, expected_rate, "NONE"):
            errors.append(
                f"{fid}: unexpected audio params ch={nchannels}, width={sampwidth}, rate={framerate}, comp={comptype}"
            )
            continue

        if nframes <= 0:
            errors.append(f"{fid}: zero frames")
            continue

        samples = struct.unpack(f"<{nframes}h", raw_frames)
        sum_sq = sum(s * s for s in samples)
        rms = math.sqrt(sum_sq / nframes)
        peak = max(abs(s) for s in samples)

        if rms < 200.0:
            errors.append(f"{fid}: RMS too low ({rms:.2f} < 200.0)")
        if peak < 1000:
            errors.append(f"{fid}: peak too low ({peak} < 1000)")

        actual_duration = nframes / framerate
        manifest_duration = item.get("durationSeconds")
        if manifest_duration is None or manifest_duration <= 0 or abs(actual_duration - manifest_duration) > 0.001:
            errors.append(
                f"{fid}: durationSeconds mismatch (actual={actual_duration:.6f}, manifest={manifest_duration})"
            )

        if len(item.get("segments", [])) >= 2:
            win = int(0.05 * framerate)  # 50 ms window
            win_rms = []
            for start in range(0, nframes - win + 1, win):
                chunk = samples[start : start + win]
                win_rms.append(math.sqrt(sum(s * s for s in chunk) / win))

            speech_blocks = 0
            in_speech = False
            quiet_run = 0
            max_gap_between_speech = 0
            seen_first_speech = False

            for val in win_rms:
                if val > 300.0:
                    if not in_speech:
                        speech_blocks += 1
                        if seen_first_speech:
                            max_gap_between_speech = max(max_gap_between_speech, quiet_run * 50)
                        in_speech = True
                        seen_first_speech = True
                    quiet_run = 0
                elif val < 50.0:
                    if in_speech:
                        in_speech = False
                    if seen_first_speech:
                        quiet_run += 1
                else:
                    if seen_first_speech and not in_speech:
                        quiet_run = 0

            if speech_blocks < 2 or max_gap_between_speech < 300:
                errors.append(
                    f"{fid}: multi-speaker gap check failed (blocks={speech_blocks}, max_gap_ms={max_gap_between_speech})"
                )

        approved_media[src] = {
            "id": fid,
            "kind": "audio",
            "durationSeconds": manifest_duration,
            "reviewStatus": review_status,
            "transcript": item.get("transcript", ""),
        }
        if review_status == "approved":
            approved_audio_ids.add(fid)

        print(
            f"[OK audio] {src} | dur={manifest_duration:.3f}s | frames={nframes} | "
            f"rate={framerate}Hz | ch={nchannels} | rms={rms:.2f} | peak={peak} | sha256={web_hash}"
        )

    return errors


def verify_images(
    manifest: dict,
    web_dir: Path,
    flutter_dir: Path,
    approved_media: dict,
    seen_media_ids: set[str],
) -> list[str]:
    errors: list[str] = []
    svg_source_dir = ROOT / manifest.get("svgSourceDir", "content/english")

    for item in manifest.get("images", []):
        fid = item["id"]
        if fid in seen_media_ids:
            errors.append(f"Duplicate media id across manifests: '{fid}'")
        seen_media_ids.add(fid)

        filename = item["filename"]
        svg_filename = item.get("svgFilename")
        src = item["canonicalSource"]
        if src in approved_media:
            errors.append(f"{fid}: duplicate canonicalSource '{src}'")
        if not CANONICAL_PATH_RE.match(src):
            errors.append(f"{fid}: invalid canonicalSource '{src}'")
        review_status = item.get("reviewStatus", manifest.get("reviewStatus"))
        if review_status != "approved":
            errors.append(f"{fid}: reviewStatus must be 'approved'")
        if not item.get("altUz", "").strip() or not item.get("altRu", "").strip():
            errors.append(f"{fid}: missing altUz or altRu")

        expected_web = ROOT / "public" / src.lstrip("/")
        expected_flutter = ROOT / "mobile" / "assets" / "lesson_media" / src.removeprefix("/lesson-media/")
        web_file = web_dir / filename
        flutter_file = flutter_dir / filename

        if web_file.resolve() != expected_web.resolve():
            errors.append(f"{fid}: webOutputDir/filename mismatch with canonicalSource ({web_file} != {expected_web})")
        if flutter_file.resolve() != expected_flutter.resolve():
            errors.append(f"{fid}: flutterOutputDir/filename mismatch with canonicalSource ({flutter_file} != {expected_flutter})")

        if not web_file.is_file():
            errors.append(f"{fid}: missing Web PNG {web_file}")
            continue
        if not flutter_file.is_file():
            errors.append(f"{fid}: missing Flutter PNG {flutter_file}")
            continue

        web_bytes = web_file.read_bytes()
        flutter_bytes = flutter_file.read_bytes()
        web_hash = sha256_bytes(web_bytes)
        flutter_hash = sha256_bytes(flutter_bytes)
        if web_hash != flutter_hash:
            errors.append(f"{fid}: Web/Flutter PNG SHA-256 mismatch ({web_hash} vs {flutter_hash})")

        if len(web_bytes) <= 5000:
            errors.append(f"{fid}: PNG file size too small ({len(web_bytes)} <= 5000 bytes)")
        if web_bytes[:8] != b"\x89PNG\r\n\x1a\n":
            errors.append(f"{fid}: invalid PNG magic bytes")
            continue
        if web_bytes[12:16] != b"IHDR":
            errors.append(f"{fid}: missing IHDR chunk")
            continue

        width, height = struct.unpack(">II", web_bytes[16:24])
        if (width, height) != (item["width"], item["height"]):
            errors.append(f"{fid}: PNG dimensions {width}x{height} != {item['width']}x{item['height']}")

        if svg_filename:
            source_svg = svg_source_dir / svg_filename
            if not source_svg.is_file():
                errors.append(f"{fid}: missing source SVG {source_svg}")
            else:
                svg_text = source_svg.read_text(encoding="utf-8")
                if FORBIDDEN_SVG_TEXT_RE.search(svg_text):
                    errors.append(f"{fid}: source SVG contains forbidden <text>/<tspan>/<textPath> element")
            web_svg = web_dir / svg_filename
            if manifest.get("copySvgToWeb", True):
                if not web_svg.is_file():
                    errors.append(f"{fid}: missing Web SVG {web_svg}")
                else:
                    web_svg_text = web_svg.read_text(encoding="utf-8")
                    if FORBIDDEN_SVG_TEXT_RE.search(web_svg_text):
                        errors.append(f"{fid}: Web SVG contains forbidden <text>/<tspan>/<textPath> element")

        approved_media[src] = {
            "id": fid,
            "kind": "image",
            "durationSeconds": None,
            "reviewStatus": review_status,
        }

        print(
            f"[OK image] {src} | dims={width}x{height} | bytes={len(web_bytes)} | sha256={web_hash}"
        )

    return errors


def verify_pubspec(approved_media: dict) -> list[str]:
    errors: list[str] = []
    pubspec_path = ROOT / "mobile" / "pubspec.yaml"
    if not pubspec_path.is_file():
        return [f"Missing mobile/pubspec.yaml at {pubspec_path}"]
    pubspec_text = pubspec_path.read_text(encoding="utf-8")
    pubspec_asset_lines = {
        line.strip()
        for line in pubspec_text.splitlines()
        if line.strip().startswith("- ")
    }
    if "- assets/lesson_media/english/" not in pubspec_asset_lines:
        errors.append("mobile/pubspec.yaml missing '- assets/lesson_media/english/'")

    subdirs = set(REQUIRED_LEVELS) | {
        match.group(1)
        for src in approved_media
        if (match := re.match(r"^/lesson-media/english/([a-z0-9_-]+)/", src))
    }
    for subdir in sorted(subdirs):
        expected_entry = f"- assets/lesson_media/english/{subdir}/"
        if expected_entry not in pubspec_asset_lines:
            errors.append(f"mobile/pubspec.yaml missing '{expected_entry}'")

    for deferred_lvl in ("b2", "c1", "c2"):
        forbidden_entry = f"- assets/lesson_media/english/{deferred_lvl}/"
        if forbidden_entry in pubspec_asset_lines:
            errors.append(f"mobile/pubspec.yaml must not contain deferred entry '{forbidden_entry}'")
    return errors


def check_no_placeholders(obj: object, path: str, errors: list[str]) -> None:
    if isinstance(obj, str):
        if FORBIDDEN_PLACEHOLDER_RE.search(obj):
            errors.append(f"Placeholder string found at {path}: '{obj}'")
    elif isinstance(obj, list):
        for idx, item in enumerate(obj):
            check_no_placeholders(item, f"{path}[{idx}]", errors)
    elif isinstance(obj, dict):
        for k, v in obj.items():
            check_no_placeholders(v, f"{path}.{k}", errors)


def _normalize_apostrophes(text: str) -> str:
    return text.replace("‘", "'").replace("’", "'").replace("`", "'").replace("ʻ", "'")


def _normalize_prompt(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def _extract_uz_stems(text: str) -> list[str]:
    stopwords = {
        "va", "ham", "bu", "ikki", "narsa", "kam", "bilan", "o'tdi", "o'zi",
        "uch", "yoz", "bor", "deb", "edi", "esa", "har", "kim", "eng", "o'n",
    }
    stems: list[str] = []
    for tok in re.findall(r"[a-z']+", _normalize_apostrophes(text.lower())):
        if tok in stopwords or len(tok) < 4:
            continue
        stem = tok
        for suffix in ("sida", "dagi", "ning", "miz", "ngiz", "siz", "lik", "lar", "dan", "ga", "da", "ni", "si"):
            if stem.endswith(suffix) and len(stem) - len(suffix) >= 4:
                stem = stem[: -len(suffix)]
                break
        stems.append(stem)
    return stems


def _extract_ru_stems(text: str) -> list[str]:
    stopwords = {
        "без", "как", "вас", "всё", "все", "два", "двумя", "для", "при", "или", "это", "что",
    }
    stems: list[str] = []
    for tok in re.findall(r"[а-яё]+", text.lower()):
        if tok in stopwords or len(tok) < 4:
            continue
        stem = tok
        if len(stem) >= 6:
            stem = re.sub(
                r"(иями|ями|ами|ого|его|ому|ему|ими|ыми|ость|ью|ию|ия|ии|ие|ые|ая|яя|ое|ее|ий|ый|ой|ей|ов|ев|ах|ях|ам|ям|ом|ем|у|ю|а|я|ы|и|е|о|ь)$",
                "",
                stem,
            )
        elif len(stem) >= 5:
            stem = re.sub(r"(ов|ев|ь|о|а|я|е|и|ы|у|ю)$", "", stem)
        elif len(stem) >= 4:
            stem = re.sub(r"(а|я|о|е|и|ы|у|ю|ь)$", "", stem)
        if len(stem) >= 3:
            stems.append(stem)
    return stems


def check_flashcard_anti_spoiler(card: dict, errors: list[str]) -> None:
    cid = card.get("id", "")
    front_lower = card.get("front", "").strip().lower().rstrip(".?!")
    for alt_field in ("alt", "altRu"):
        alt_val = card.get(alt_field, "")
        if not alt_val.strip():
            errors.append(f"Flashcard {cid}: missing {alt_field}")
            continue
        alt_lower = alt_val.lower()
        if len(front_lower) < 5:
            spoils = bool(re.search(rf"(?<!\w){re.escape(front_lower)}(?!\w)", alt_lower))
        else:
            spoils = bool(re.search(rf"(?<!\w){re.escape(front_lower)}(?!\w)", alt_lower)) or (
                " " in front_lower and front_lower in alt_lower
            )
        if spoils:
            errors.append(f"Flashcard {cid}: {alt_field} spoils front '{card['front']}'")

    if card.get("partOfSpeech") == "preposition":
        prep_spoiler_patterns = {
            "beside": {
                "alt": (r"yonida",),
                "altRu": (r"рядом\s+с",),
            },
            "between": {
                "alt": (r"orasida", r"o[']rtasida"),
                "altRu": (r"между",),
            },
            "behind": {
                "alt": (r"orqa",),
                "altRu": (r"позади", r"\bза\b"),
            },
        }.get(front_lower, {})
        for alt_field, patterns in prep_spoiler_patterns.items():
            alt_norm = _normalize_apostrophes(card.get(alt_field, "").lower())
            for pattern in patterns:
                if re.search(pattern, alt_norm):
                    errors.append(
                        f"Flashcard {cid}: {alt_field} spoils preposition '{card['front']}' ({pattern})"
                    )

    extra_spoiler_patterns = {
        "quarter to": {
            "alt": (r"chorak", r"15\s+daqiqa"),
            "altRu": (r"четверт", r"пятнадцат"),
        },
        "o'clock": {
            "alt": (r"\baniq\b", r"\bsoat"),
            "altRu": (r"\bровн", r"\bчас"),
        },
        "notebook": {
            "alt": (r"\bdaftar",),
            "altRu": (r"\bтетрад",),
        },
    }.get(front_lower, {})
    for alt_field, patterns in extra_spoiler_patterns.items():
        alt_norm = _normalize_apostrophes(card.get(alt_field, "").lower())
        for pattern in patterns:
            if re.search(pattern, alt_norm):
                errors.append(
                    f"Flashcard {cid}: {alt_field} spoils '{card['front']}' ({pattern})"
                )

    alt_uz_norm = _normalize_apostrophes(card.get("alt", "").lower())
    for stem in _extract_uz_stems(card.get("backUz", "")):
        if re.search(rf"\b{re.escape(stem)}", alt_uz_norm):
            errors.append(
                f"Flashcard {cid}: alt spoils backUz target keyword stem '{stem}' ('{card.get('backUz', '')}')"
            )

    alt_ru_norm = card.get("altRu", "").lower()
    for stem in _extract_ru_stems(card.get("backRu", "")):
        if re.search(rf"\b{re.escape(stem)}", alt_ru_norm):
            errors.append(
                f"Flashcard {cid}: altRu spoils backRu target keyword stem '{stem}' ('{card.get('backRu', '')}')"
            )


def load_placement_question_ids() -> set[str]:
    qts_path = ROOT / "src" / "data" / "datasources" / "questions.ts"
    if not qts_path.is_file():
        return set()
    content = qts_path.read_text(encoding="utf-8")
    return set(re.findall(r"\bid:\s*['\"]([^'\"]+)['\"]", content))


def verify_curriculum_and_skeleton(
    approved_media: dict,
    approved_audio_ids: set[str],
    curriculum_paths: list[tuple[str, Path]],
) -> list[str]:
    errors: list[str] = []
    schema_path = CONTENT_DIR / "curriculum-schema.json"
    skeleton_path = CONTENT_DIR / "cefr-skeleton.json"

    for req_path in (schema_path, skeleton_path):
        if not req_path.is_file():
            errors.append(f"Missing canonical file: {req_path}")
            return errors

    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    if "$schema" not in schema or "2020-12" not in schema["$schema"]:
        errors.append("curriculum-schema.json must declare JSON Schema Draft 2020-12")

    skeleton = json.loads(skeleton_path.read_text(encoding="utf-8"))
    check_no_placeholders(skeleton, "cefr-skeleton", errors)
    expected_levels = ["A1", "A2", "B1", "B2", "C1", "C2"]
    actual_levels = [lvl.get("cefrLevel") for lvl in skeleton.get("levels", [])]
    if actual_levels != expected_levels:
        errors.append(f"cefr-skeleton levels {actual_levels} != {expected_levels}")
    for lvl in skeleton.get("levels", []):
        cefr = lvl.get("cefrLevel")
        mod_count = len(lvl.get("modules", []))
        expected_mod_count = 4 if cefr in ("A1", "A2", "B1", "B2") else 3
        if mod_count != expected_mod_count:
            errors.append(f"cefr-skeleton {cefr}: expected {expected_mod_count} modules, got {mod_count}")

    skeleton_by_cefr = {lvl.get("cefrLevel"): lvl for lvl in skeleton.get("levels", [])}
    placement_question_ids = load_placement_question_ids()

    seen_module_ids: set[str] = set()
    seen_unit_ids: set[str] = set()
    seen_lesson_ids: set[str] = set()
    seen_question_ids: set[str] = set()
    seen_question_prompts_uz: dict[str, str] = {}
    seen_question_prompts_ru: dict[str, str] = {}
    regular_signatures: dict[tuple[str, str, str], str] = {}
    checkpoint_signatures: dict[tuple[str, str, str], str] = {}
    seen_flashcard_ids: set[str] = set()
    all_nodes_by_id: dict[str, dict] = {}
    loaded_docs: list[tuple[str, dict]] = []

    def validate_media_ref(media_obj: dict, owner: str) -> None:
        src = media_obj.get("source")
        if not src or not CANONICAL_PATH_RE.match(src):
            errors.append(f"{owner}: invalid media.source '{src}'")
            return
        if src not in approved_media:
            errors.append(f"{owner}: media.source '{src}' not found in approved English media manifests")
            return
        if media_obj.get("reviewStatus") != "approved":
            errors.append(f"{owner}: media.reviewStatus must be 'approved'")
        if media_obj.get("kind") == "audio":
            if media_obj.get("language") != "en":
                errors.append(f"{owner}: audio media.language must be 'en'")
            expected_dur = approved_media[src]["durationSeconds"]
            if media_obj.get("durationSeconds") != expected_dur:
                errors.append(
                    f"{owner}: media durationSeconds {media_obj.get('durationSeconds')} != manifest {expected_dur}"
                )
        poster = media_obj.get("posterImage")
        if poster and poster not in approved_media:
            errors.append(f"{owner}: posterImage '{poster}' not found in approved manifests")

    def _extract_quoted_substrings(text: str) -> list[str]:
        matches = re.findall(r'«([^»]+)»|"([^"]+)"|“([^”]+)”|(?<!\w)\'([^\']+)\'(?!\w)', text)
        return [next(part for part in m if part) for m in matches]

    def _has_ordered_subsequence(haystack: list[str], needle: list[str], min_count: int) -> bool:
        if not needle or min_count <= 0:
            return False
        matched = 0
        pos = 0
        for item in needle:
            while pos < len(haystack) and haystack[pos] != item:
                pos += 1
            if pos < len(haystack):
                matched += 1
                pos += 1
                if matched >= min_count:
                    return True
        return False

    def validate_question(
        q: dict,
        owner: str,
        is_checkpoint_or_exit: bool,
        lesson_media_list: list[dict],
        lvl: str,
    ) -> None:
        qid = q.get("id", "")
        if qid in seen_question_ids:
            errors.append(f"{owner}: duplicate question id '{qid}'")
        if qid in placement_question_ids:
            errors.append(f"{owner}: question id '{qid}' collides with src/data/datasources/questions.ts")
        seen_question_ids.add(qid)

        qtext_raw = q.get("text", "").strip()
        qtext_ru_raw = q.get("textRu", "").strip()
        qtext_norm = _normalize_prompt(qtext_raw)
        qtext_ru_norm = _normalize_prompt(qtext_ru_raw)

        if qtext_norm in seen_question_prompts_uz:
            errors.append(f"{owner}: duplicate question prompt '{qtext_raw}' (also in {seen_question_prompts_uz[qtext_norm]})")
        seen_question_prompts_uz[qtext_norm] = qid

        if qtext_ru_norm:
            if qtext_ru_norm in seen_question_prompts_ru:
                errors.append(
                    f"{owner}: duplicate question textRu '{qtext_ru_raw}' (also in {seen_question_prompts_ru[qtext_ru_norm]})"
                )
            seen_question_prompts_ru[qtext_ru_norm] = qid

        qtype = q.get("questionType", "")
        if not q.get("explanation", "").strip() or not q.get("explanationRu", "").strip():
            errors.append(f"{owner} ({qid}): missing explanation or explanationRu")
        if not q.get("wrongFeedback", "").strip() or not q.get("wrongFeedbackRu", "").strip():
            errors.append(f"{owner} ({qid}): missing wrongFeedback or wrongFeedbackRu")

        media_alts = " ".join(
            str(m.get(k, ""))
            for m in lesson_media_list
            for k in ("alt", "altUz", "altRu", "posterAlt", "posterAltUz", "posterAltRu")
        ).lower()

        answer_key = ""
        if qtype in ("multiple_choice", "error_correction", "conversation_completion"):
            opts = q.get("options", [])
            cidx = q.get("correctIndex", -1)
            if len(opts) < 3 or not (0 <= cidx < len(opts)):
                errors.append(f"{owner} ({qid}): invalid options/correctIndex")
            else:
                correct_opt = opts[cidx]
                answer_key = _normalize_prompt(correct_opt)
                if qtype == "error_correction":
                    err_sent = q.get("sentenceWithError", "").strip()
                    if err_sent and err_sent == correct_opt.strip():
                        errors.append(f"{owner} ({qid}): error_correction sentenceWithError equals correct option")
                if len(correct_opt.strip()) >= 4:
                    pat = rf"(?<!\w){re.escape(correct_opt.strip().lower())}(?!\w)"
                    for field_name, field_val in (
                        ("text", qtext_raw),
                        ("textRu", qtext_ru_raw),
                        ("wrongFeedback", q.get("wrongFeedback", "")),
                        ("wrongFeedbackRu", q.get("wrongFeedbackRu", "")),
                    ):
                        if re.search(pat, field_val.lower()):
                            errors.append(
                                f"{owner} ({qid}): {field_name} leaks correct option '{correct_opt}' (Gate G5)"
                            )
                if lvl != "a1":
                    opt_norms = [_normalize_apostrophes(o.lower()) for o in opts]
                    for field_name, field_val in (
                        ("text", qtext_raw),
                        ("textRu", qtext_ru_raw),
                        ("wrongFeedback", q.get("wrongFeedback", "")),
                        ("wrongFeedbackRu", q.get("wrongFeedbackRu", "")),
                    ):
                        for qphrase in _extract_quoted_substrings(field_val):
                            phrase_l = _normalize_apostrophes(qphrase.strip().lower())
                            if len(phrase_l) >= 5 and re.search(r"[a-z]", phrase_l):
                                phrase_pat = rf"(?<!\w){re.escape(phrase_l)}(?!\w)"
                                if re.search(phrase_pat, opt_norms[cidx]) and not any(
                                    re.search(phrase_pat, opt_norms[i]) for i in range(len(opts)) if i != cidx
                                ):
                                    errors.append(
                                        f"{owner} ({qid}): {field_name} quotes unique correct-option phrase '{qphrase}' (Gate G5)"
                                    )
            fb_map = q.get("mistakeFeedbackByOption") or {}
            for idx, opt in enumerate(opts):
                if idx == cidx:
                    continue
                entry = fb_map.get(opt)
                if not entry or not entry.get("uz", "").strip() or not entry.get("ru", "").strip():
                    errors.append(f"{owner} ({qid}): missing mistakeFeedbackByOption for distractor '{opt}'")
        elif qtype in ("text_input", "fill_blank"):
            accepted = q.get("acceptedAnswers", [])
            if not accepted:
                errors.append(f"{owner} ({qid}): empty acceptedAnswers")
            else:
                answer_key = _normalize_prompt(accepted[0])
            blank_tmpl = q.get("blankTemplate", "")
            for ans in accepted:
                ans_l = ans.lower()
                for field_name, field_val in (
                    ("text", qtext_raw),
                    ("textRu", qtext_ru_raw),
                    ("wrongFeedback", q.get("wrongFeedback", "")),
                    ("wrongFeedbackRu", q.get("wrongFeedbackRu", "")),
                    ("blankTemplate", blank_tmpl),
                    ("mediaAlt", media_alts),
                ):
                    if ans_l and ans_l in field_val.lower():
                        errors.append(f"{owner} ({qid}): {field_name} leaks accepted answer '{ans}' (Gate G5)")
            if lvl != "a1":
                en_stopwords = {
                    "the", "a", "an", "to", "in", "on", "at", "of", "for", "and", "or",
                    "is", "am", "are", "be", "my", "we", "i", "you", "he", "she", "it",
                    "they", "do", "does", "did", "will", "this", "that",
                }
                for field_name, field_val in (
                    ("wrongFeedback", q.get("wrongFeedback", "")),
                    ("wrongFeedbackRu", q.get("wrongFeedbackRu", "")),
                ):
                    field_norm = _normalize_apostrophes(field_val.lower())
                    quoted_words: set[str] = set()
                    for qphrase in _extract_quoted_substrings(field_val):
                        quoted_words.update(re.findall(r"[a-z']+", _normalize_apostrophes(qphrase.lower())))
                    for ans in accepted:
                        ans_words = re.findall(r"[a-z']+", _normalize_apostrophes(ans.lower()))
                        if len(ans_words) < 2:
                            continue
                        content_words = {w for w in ans_words if len(w) >= 4 and w not in en_stopwords}
                        matched_chunks = {
                            w for w in content_words
                            if re.search(rf"(?<!\w){re.escape(w)}(?!\w)", field_norm)
                        }
                        for w in ans_words:
                            if w in quoted_words and w not in matched_chunks:
                                matched_chunks.add(w)
                        if len(matched_chunks) >= 2:
                            errors.append(
                                f"{owner} ({qid}): {field_name} leaks >=2 answer chunks {sorted(matched_chunks)} from '{ans}' (Gate G5)"
                            )
        elif qtype == "word_match":
            pairs = q.get("matchPairs", [])
            if len(pairs) < 3:
                errors.append(f"{owner} ({qid}): word_match needs >= 3 matchPairs")
            answer_key = "|".join(sorted(f"{p.get('left','')}={p.get('right','')}" for p in pairs)).lower()
        elif qtype == "sentence_order":
            tokens = q.get("orderedTokens", [])
            if len(tokens) < 3:
                errors.append(f"{owner} ({qid}): sentence_order needs >= 3 orderedTokens")
            joined = " ".join(tokens).strip()
            answer_key = _normalize_prompt(joined)
            if len(joined) >= 6:
                for field_name, field_val in (
                    ("text", qtext_raw),
                    ("textRu", qtext_ru_raw),
                    ("wrongFeedback", q.get("wrongFeedback", "")),
                    ("wrongFeedbackRu", q.get("wrongFeedbackRu", "")),
                ):
                    if joined.lower() in field_val.lower():
                        errors.append(f"{owner} ({qid}): {field_name} leaks ordered sentence '{joined}' (Gate G5)")
            if lvl != "a1":
                norm_tokens = [
                    _normalize_apostrophes(t).lower().strip(".,!?;:\"'«»")
                    for t in tokens
                ]
                norm_tokens = [t for t in norm_tokens if t]
                token_words = [w for nt in norm_tokens for w in re.findall(r"[a-z']+", nt)]
                for field_name, field_val in (
                    ("wrongFeedback", q.get("wrongFeedback", "")),
                    ("wrongFeedbackRu", q.get("wrongFeedbackRu", "")),
                ):
                    field_norm = _normalize_apostrophes(field_val.lower())
                    quoted_str = " ".join(
                        _normalize_apostrophes(qp.lower()) for qp in _extract_quoted_substrings(field_val)
                    )
                    quoted_token_hits = {
                        nt for nt in norm_tokens
                        if re.search(rf"(?<!\w){re.escape(nt)}(?!\w)", quoted_str)
                    }
                    pos = 0
                    in_order_hits = 0
                    for nt in norm_tokens:
                        m = re.search(rf"(?<!\w){re.escape(nt)}(?!\w)", field_norm[pos:])
                        if m:
                            in_order_hits += 1
                            pos += m.end()
                    field_words = re.findall(r"[a-z']+", field_norm)
                    min_seq_words = max(2, math.ceil(len(token_words) * 0.5)) if token_words else 999
                    seq_word_hit = _has_ordered_subsequence(field_words, token_words, min_seq_words)
                    if len(quoted_token_hits) >= 2 or in_order_hits >= 2 or seq_word_hit:
                        errors.append(
                            f"{owner} ({qid}): {field_name} leaks ordered sentence tokens/sequence (Gate G5)"
                        )
        elif qtype in ("speaking_prompt", "writing_prompt"):
            if q.get("evaluationMode") != "self_assessed":
                errors.append(f"{owner} ({qid}): communicative prompt must use evaluationMode 'self_assessed'")
            if not q.get("sampleResponse", "").strip() or len(q.get("rubricCriteria", [])) < 3:
                errors.append(f"{owner} ({qid}): missing sampleResponse or rubricCriteria (>=3)")
            notice = q.get("selfAssessmentNoticeUz", "") + " " + q.get("selfAssessmentNoticeRu", "")
            if FORBIDDEN_CERT_CLAIM_RE.search(notice):
                errors.append(f"{owner} ({qid}): forbidden official CEFR certification claim")
            answer_key = _normalize_prompt(q.get("sampleResponse", ""))

        # Gate G6/G5: Ensure listening transcript is not pasted inline into question prompt
        for m in lesson_media_list:
            if m.get("kind") == "audio":
                src = m.get("source", "")
                transcript = (approved_media.get(src, {}).get("transcript") or m.get("transcript") or "").strip()
                stripped_lines = [re.sub(r"^[A-Za-z.\s]+:\s*", "", ln).strip() for ln in transcript.splitlines() if ln.strip()]
                full_speech = " ".join(stripped_lines).strip()
                if len(full_speech) >= 25 and (
                    full_speech.lower() in qtext_raw.lower() or full_speech.lower() in qtext_ru_raw.lower()
                ):
                    errors.append(f"{owner} ({qid}): question prompt leaks full listening transcript inline (Gate G5)")
                if lvl != "a1":
                    for seg_line in stripped_lines:
                        turn_candidates = [seg_line] + [
                            part.strip().rstrip(".!?")
                            for part in re.split(r"[.!?]+(?:\s+|$)", seg_line)
                            if part.strip().rstrip(".!?")
                        ]
                        for candidate in dict.fromkeys(turn_candidates):
                            if len(candidate) >= 25 and (
                                candidate.lower() in qtext_raw.lower()
                                or candidate.lower() in qtext_ru_raw.lower()
                            ):
                                errors.append(
                                    f"{owner} ({qid}): question prompt leaks listening dialogue turn/sentence inline (Gate G5)"
                                )
                                break

        # Gate G7: Checkpoint vs regular lesson deduplication
        ctx_key = _normalize_prompt(
            q.get("contextSnippet", "") or q.get("blankTemplate", "") or q.get("sentenceWithError", "")
        )
        sig = (qtype, ctx_key, answer_key)
        if answer_key:
            if is_checkpoint_or_exit:
                if sig in regular_signatures:
                    errors.append(
                        f"{owner} ({qid}): checkpoint/exit reuses signature {sig} from regular lesson ({regular_signatures[sig]})"
                    )
                if sig in checkpoint_signatures:
                    errors.append(
                        f"{owner} ({qid}): checkpoint/exit reuses signature {sig} from checkpoint ({checkpoint_signatures[sig]})"
                    )
                checkpoint_signatures[sig] = qid
            else:
                if sig in checkpoint_signatures:
                    errors.append(
                        f"{owner} ({qid}): regular lesson shares signature {sig} with checkpoint ({checkpoint_signatures[sig]})"
                    )
                regular_signatures[sig] = qid

    for lvl, c_path in curriculum_paths:
        doc = json.loads(c_path.read_text(encoding="utf-8"))
        loaded_docs.append((lvl, doc))
        check_no_placeholders(doc, f"{lvl}-curriculum", errors)

        expected_cefr = lvl.upper()
        if doc.get("cefrLevel") != expected_cefr:
            errors.append(f"{c_path.name}: cefrLevel '{doc.get('cefrLevel')}' != '{expected_cefr}'")
        if doc.get("starterLessonId") != "lesson_eng_starter":
            errors.append(f"{c_path.name}: starterLessonId MUST be 'lesson_eng_starter'")
        if doc.get("foundationLessonIds") != ["lesson_eng_starter", "lesson_eng_foundation_02"]:
            errors.append(f"{c_path.name}: foundationLessonIds mismatch")

        if lvl == "a1":
            if doc.get("lessonsOrder", [None])[0] != "lesson_eng_listening_01":
                errors.append("a1-curriculum lessonsOrder[0] MUST be 'lesson_eng_listening_01'")

        # Skeleton parity
        skel_lvl = skeleton_by_cefr.get(expected_cefr)
        if not skel_lvl:
            errors.append(f"cefr-skeleton.json missing level '{expected_cefr}'")
        else:
            skel_mods = skel_lvl.get("modules", [])
            doc_mods = doc.get("modules", [])
            if [m.get("id") for m in doc_mods] != [m.get("id") for m in skel_mods]:
                errors.append(f"{c_path.name}: module IDs do not match cefr-skeleton.json")
            else:
                for dm, sm in zip(doc_mods, skel_mods):
                    if dm.get("plannedLessonIds") != sm.get("plannedLessonIds"):
                        errors.append(f"{c_path.name} ({dm.get('id')}): plannedLessonIds mismatch with skeleton")
                    if dm.get("checkpointNodeId") != sm.get("checkpointNodeId"):
                        errors.append(f"{c_path.name} ({dm.get('id')}): checkpointNodeId mismatch with skeleton")
                    if dm.get("prerequisites") != sm.get("prerequisites"):
                        errors.append(f"{c_path.name} ({dm.get('id')}): prerequisites mismatch with skeleton")
                    if [u.get("id") for u in dm.get("units", [])] != [u.get("id") for u in sm.get("units", [])]:
                        errors.append(f"{c_path.name} ({dm.get('id')}): unit IDs mismatch with skeleton")
                    for du, su in zip(dm.get("units", []), sm.get("units", [])):
                        if du.get("plannedLessonIds") != su.get("plannedLessonIds"):
                            errors.append(f"{c_path.name} ({du.get('id')}): unit plannedLessonIds mismatch")
                        if du.get("checkpointNodeId") != su.get("checkpointNodeId"):
                            errors.append(f"{c_path.name} ({du.get('id')}): unit checkpointNodeId mismatch")

        for mod in doc.get("modules", []):
            mid = mod.get("id", "")
            if mid in seen_module_ids:
                errors.append(f"Duplicate module id '{mid}'")
            seen_module_ids.add(mid)
            for unit in mod.get("units", []):
                uid = unit.get("id", "")
                if uid in seen_unit_ids:
                    errors.append(f"Duplicate unit id '{uid}'")
                seen_unit_ids.add(uid)

        level_lesson_ids: set[str] = set()
        for lesson in doc.get("lessons", []):
            lid = lesson.get("id", "")
            if lid in seen_lesson_ids:
                errors.append(f"Duplicate lesson id '{lid}'")
            seen_lesson_ids.add(lid)
            level_lesson_ids.add(lid)

            lref = lesson.get("pedagogy17", {}).get("listeningRef")
            if lref is not None and lref not in approved_audio_ids:
                errors.append(
                    f"{c_path.name} ({lid}): pedagogy17.listeningRef '{lref}' not found in approved audio IDs"
                )

            is_cp_or_exit = lesson.get("communicativeFocus") in ("checkpoint", "exit_assessment")
            lesson_media = [s["media"] for s in lesson.get("steps", []) if s.get("media")]

            for step in lesson.get("steps", []):
                if step.get("media"):
                    validate_media_ref(step["media"], f"{lid}.{step['id']}")
                for card in step.get("flashcards", []):
                    cid = card.get("id", "")
                    if cid in seen_flashcard_ids:
                        errors.append(f"Duplicate flashcard id '{cid}'")
                    seen_flashcard_ids.add(cid)
                    check_flashcard_anti_spoiler(card, errors)
                    for media_key in ("audioSrc", "imageSrc"):
                        mval = card.get(media_key, "")
                        if mval not in approved_media:
                            errors.append(f"Flashcard {cid}: {media_key} '{mval}' not in approved media manifests")
                if step.get("interactiveQuestion"):
                    validate_question(step["interactiveQuestion"], f"{lid}.{step['id']}", is_cp_or_exit, lesson_media, lvl)
            if "reinforcementExercise" in lesson:
                validate_question(lesson["reinforcementExercise"], f"{lid}.reinforcement", is_cp_or_exit, lesson_media, lvl)
            if "alternateExercise" in lesson:
                validate_question(lesson["alternateExercise"], f"{lid}.alternate", is_cp_or_exit, lesson_media, lvl)

        lessons_order = doc.get("lessonsOrder", [])
        if len(lessons_order) != len(set(lessons_order)):
            errors.append(f"{c_path.name}: lessonsOrder contains duplicates")
        if set(lessons_order) != level_lesson_ids:
            errors.append(f"{c_path.name}: lessonsOrder does not match lessons[].id set")
        if skel_lvl:
            skel_planned = skel_lvl.get("plannedLessonIds", [])
            if not set(skel_planned).issubset(level_lesson_ids):
                missing = sorted(set(skel_planned) - level_lesson_ids)
                errors.append(f"{c_path.name}: missing skeleton plannedLessonIds {missing}")

        level_node_ids: set[str] = set()
        for node in doc.get("roadmapNodes", []):
            nid = node.get("id", "")
            if nid in all_nodes_by_id:
                errors.append(f"Duplicate node id '{nid}'")
            all_nodes_by_id[nid] = node
            level_node_ids.add(nid)
            if node.get("targetLessonId") not in level_lesson_ids:
                errors.append(
                    f"{c_path.name} Node {nid}: targetLessonId '{node.get('targetLessonId')}' not found in {lvl} lessons"
                )

        if skel_lvl:
            exit_nid = skel_lvl.get("exitAssessmentNodeId")
            if exit_nid and exit_nid not in level_node_ids:
                errors.append(f"{c_path.name}: missing skeleton exitAssessmentNodeId '{exit_nid}' in roadmapNodes")

        if lvl == "a1":
            list_lesson = next((l for l in doc.get("lessons", []) if l["id"] == "lesson_eng_listening_01"), None)
            if list_lesson:
                q_list = list_lesson["steps"][2]["interactiveQuestion"]
                if not any("03:15" in opt for opt in q_list.get("options", [])):
                    errors.append("lesson_eng_listening_01 missing 03:15 AM/PM distractor for T2-F4-03")

        if lvl != "a1" and skel_lvl:
            prev_exit = (skel_lvl.get("prerequisites") or [None])[0]
            m1_id = (doc.get("modules") or [{}])[0].get("id")
            if prev_exit and m1_id:
                m1_nodes = [n for n in doc.get("roadmapNodes", []) if n.get("moduleId") == m1_id]
                if not any(prev_exit in n.get("prerequisites", []) for n in m1_nodes):
                    errors.append(
                        f"{c_path.name}: {m1_id} entry node must reference '{prev_exit}' in prerequisites"
                    )
            exit_nid = skel_lvl.get("exitAssessmentNodeId")
            exit_node = all_nodes_by_id.get(exit_nid) if exit_nid else None
            if not exit_node or exit_node.get("nodeKind") != "level_assessment":
                errors.append(
                    f"{c_path.name}: {exit_nid} must exist with nodeKind 'level_assessment'"
                )
            for node in doc.get("roadmapNodes", []):
                if node.get("nodeKind") in ("unit_checkpoint", "level_assessment") and not node.get("prerequisites"):
                    errors.append(
                        f"{c_path.name}: checkpoint/exit '{node.get('id')}' must have prerequisites"
                    )

        print(
            f"[OK curriculum] {expected_cefr} lessons={len(level_lesson_ids)} | nodes={len(level_node_ids)}"
        )

    # Cross-level prerequisite resolution & cycle check
    for lvl, doc in loaded_docs:
        for node in doc.get("roadmapNodes", []):
            for prereq in node.get("prerequisites", []):
                if prereq not in all_nodes_by_id:
                    errors.append(
                        f"{lvl}-curriculum Node {node['id']}: prerequisite '{prereq}' not found in loaded roadmapNodes"
                    )
        for lesson in doc.get("lessons", []):
            for prereq in lesson.get("prerequisites", []):
                if prereq not in all_nodes_by_id and prereq not in seen_lesson_ids:
                    errors.append(
                        f"{lvl}-curriculum Lesson {lesson['id']}: prerequisite '{prereq}' not found in loaded roadmapNodes or lessons"
                    )

    # DFS cycle detection across node prerequisites
    visit_state: dict[str, int] = {}  # 0=unvisited, 1=visiting, 2=done

    def has_cycle(nid: str) -> bool:
        state = visit_state.get(nid, 0)
        if state == 1:
            return True
        if state == 2:
            return False
        visit_state[nid] = 1
        node = all_nodes_by_id.get(nid)
        if node:
            for prereq in node.get("prerequisites", []):
                if prereq in all_nodes_by_id and has_cycle(prereq):
                    return True
        visit_state[nid] = 2
        return False

    for nid in all_nodes_by_id:
        if visit_state.get(nid, 0) == 0 and has_cycle(nid):
            errors.append(f"Prerequisite cycle detected involving node '{nid}'")
            break

    print(
        f"[OK curriculum total] levels={len(loaded_docs)} | lessons={len(seen_lesson_ids)} | "
        f"nodes={len(all_nodes_by_id)} | questions={len(seen_question_ids)} | flashcards={len(seen_flashcard_ids)}"
    )

    # Verify canonical A1-B1 placement bank and media linkage
    placement_path = CONTENT_DIR / "placement-questions.json"
    placement_media_path = CONTENT_DIR / "placement-media.json"
    if not placement_path.is_file():
        errors.append(f"Missing required placement bank: {placement_path}")
        return errors
    if not placement_media_path.is_file():
        errors.append(f"Missing required placement media manifest: {placement_media_path}")
        return errors

    placement_doc = json.loads(placement_path.read_text(encoding="utf-8"))
    placement_media_doc = json.loads(placement_media_path.read_text(encoding="utf-8"))
    check_no_placeholders(placement_doc, "placement-questions", errors)

    if placement_doc.get("documentType") != "placement_bank":
        errors.append("placement-questions.json documentType must be 'placement_bank'")
    if placement_doc.get("courseId") != "course_eng_01":
        errors.append("placement-questions.json courseId must be 'course_eng_01'")
    if placement_doc.get("cefrRange") != ["A1", "A2", "B1"]:
        errors.append("placement-questions.json cefrRange must be ['A1', 'A2', 'B1']")

    placement_audio_by_src = {
        item.get("canonicalSource"): item
        for item in placement_media_doc.get("audio", [])
        if item.get("kind") == "audio"
    }
    if len(placement_audio_by_src) != 3:
        errors.append(f"placement-media.json must define 3 audio items, got {len(placement_audio_by_src)}")

    placement_qs = placement_doc.get("questions", [])
    if len(placement_qs) != 12:
        errors.append(f"placement-questions.json must contain 12 items, got {len(placement_qs)}")

    expected_skills = ("skill_eng_vocab", "skill_eng_grammar", "skill_eng_listening", "skill_eng_reading")
    expected_diff_by_cefr = {"A1": "easy", "A2": "medium", "B1": "hard"}
    skill_levels: dict[str, set[str]] = {s: set() for s in expected_skills}
    placement_ids: set[str] = set()
    placement_prompts_uz: dict[str, str] = {}
    placement_prompts_ru: dict[str, str] = {}
    distinct_correct_indices: set[int] = set()
    placement_audio_count = 0

    for q in placement_qs:
        qid = q.get("id", "")
        owner = f"placement.{qid}"
        if not re.match(r"^q_eng_place_[a-z0-9_]+$", qid):
            errors.append(f"{owner}: invalid placement question id '{qid}'")
        if qid in placement_ids:
            errors.append(f"{owner}: duplicate placement question id '{qid}'")
        if qid in seen_question_ids:
            errors.append(f"{owner}: collides with M1-M3 lesson question id '{qid}'")
        placement_ids.add(qid)

        if q.get("courseId") != "course_eng_01":
            errors.append(f"{owner}: courseId must be 'course_eng_01'")
        if q.get("isPlacement") is not True:
            errors.append(f"{owner}: isPlacement must be true")
        if q.get("questionType") != "multiple_choice":
            errors.append(f"{owner}: questionType must be 'multiple_choice'")

        cefr = q.get("cefrLevel", "")
        diff = q.get("difficulty", "")
        if cefr not in ("A1", "A2", "B1"):
            errors.append(f"{owner}: invalid placement cefrLevel '{cefr}' (A1-B1 only)")
        elif expected_diff_by_cefr[cefr] != diff:
            errors.append(f"{owner}: cefrLevel '{cefr}' must pair with difficulty '{expected_diff_by_cefr[cefr]}', got '{diff}'")

        skill_id = q.get("skillId", "")
        if skill_id not in expected_skills:
            errors.append(f"{owner}: invalid skillId '{skill_id}'")
        else:
            skill_levels[skill_id].add(cefr)

        qtext_raw = q.get("text", "").strip()
        qtext_ru_raw = q.get("textRu", "").strip()
        if not qtext_raw or not qtext_ru_raw:
            errors.append(f"{owner}: missing text or textRu")
        if re.search(r"audio\s*context:", qtext_raw, re.IGNORECASE) or re.search(r"audio\s*context:", qtext_ru_raw, re.IGNORECASE):
            errors.append(f"{owner}: forbidden 'Audio context:' text in prompt (Gate G5)")

        p_uz = _normalize_prompt(qtext_raw)
        p_ru = _normalize_prompt(qtext_ru_raw)
        if p_uz in placement_prompts_uz or p_uz in seen_question_prompts_uz:
            errors.append(f"{owner}: duplicate prompt '{qtext_raw}'")
        placement_prompts_uz[p_uz] = qid
        if p_ru in placement_prompts_ru or p_ru in seen_question_prompts_ru:
            errors.append(f"{owner}: duplicate textRu '{qtext_ru_raw}'")
        placement_prompts_ru[p_ru] = qid

        for req_field in ("explanation", "explanationRu", "wrongFeedback", "wrongFeedbackRu"):
            if not str(q.get(req_field, "")).strip():
                errors.append(f"{owner}: missing {req_field}")

        opts = q.get("options", [])
        cidx = q.get("correctIndex", -1)
        if len(opts) != 4 or len(set(opts)) != 4 or not (0 <= cidx < 4):
            errors.append(f"{owner}: must have 4 unique options and valid correctIndex 0..3")
        else:
            distinct_correct_indices.add(cidx)
            correct_opt = opts[cidx]
            if len(correct_opt.strip()) >= 4:
                pat = rf"(?<!\w){re.escape(correct_opt.strip().lower())}(?!\w)"
                for fname, fval in (
                    ("text", qtext_raw),
                    ("textRu", qtext_ru_raw),
                    ("wrongFeedback", q.get("wrongFeedback", "")),
                    ("wrongFeedbackRu", q.get("wrongFeedbackRu", "")),
                ):
                    if re.search(pat, str(fval).lower()):
                        errors.append(f"{owner}: {fname} leaks correct option '{correct_opt}' (Gate G5)")

            opt_norms = [_normalize_apostrophes(o.lower()) for o in opts]
            for fname, fval in (
                ("text", qtext_raw),
                ("textRu", qtext_ru_raw),
                ("wrongFeedback", q.get("wrongFeedback", "")),
                ("wrongFeedbackRu", q.get("wrongFeedbackRu", "")),
            ):
                for qphrase in _extract_quoted_substrings(str(fval)):
                    phrase_l = _normalize_apostrophes(qphrase.strip().lower())
                    if len(phrase_l) >= 5 and re.search(r"[a-z]", phrase_l):
                        phrase_pat = rf"(?<!\w){re.escape(phrase_l)}(?!\w)"
                        if re.search(phrase_pat, opt_norms[cidx]) and not any(
                            re.search(phrase_pat, opt_norms[i]) for i in range(4) if i != cidx
                        ):
                            errors.append(f"{owner}: {fname} quotes unique correct-option phrase '{qphrase}' (Gate G5)")

        fb_map = q.get("mistakeFeedbackByOption") or {}
        for opt in opts:
            entry = fb_map.get(opt)
            if not entry or not str(entry.get("uz", "")).strip() or not str(entry.get("ru", "")).strip():
                errors.append(f"{owner}: missing uz/ru mistakeFeedbackByOption for option '{opt}'")

        if skill_id == "skill_eng_listening":
            media_obj = q.get("media")
            if not media_obj:
                errors.append(f"{owner}: listening placement item requires media")
            else:
                placement_audio_count += 1
                validate_media_ref(media_obj, owner)
                expected_src = f"/lesson-media/english/placement/{qid}.wav"
                if media_obj.get("source") != expected_src:
                    errors.append(f"{owner}: media.source '{media_obj.get('source')}' != '{expected_src}'")
                manifest_audio = placement_audio_by_src.get(media_obj.get("source"))
                if not manifest_audio:
                    errors.append(f"{owner}: media.source '{media_obj.get('source')}' missing from placement-media.json")
                else:
                    if media_obj.get("id") != manifest_audio.get("id"):
                        errors.append(f"{owner}: media.id mismatch with placement-media.json")
                    if media_obj.get("transcript") != manifest_audio.get("transcript"):
                        errors.append(f"{owner}: media.transcript mismatch with placement-media.json")
                transcript = str(media_obj.get("transcript", "")).strip()
                stripped_lines = [re.sub(r"^[A-Za-z.\s]+:\s*", "", ln).strip() for ln in transcript.splitlines() if ln.strip()]
                for seg_line in stripped_lines:
                    if len(seg_line) >= 20 and (
                        seg_line.lower() in qtext_raw.lower() or seg_line.lower() in qtext_ru_raw.lower()
                    ):
                        errors.append(f"{owner}: prompt leaks listening transcript turn inline (Gate G5)")
        else:
            if q.get("media") or q.get("audioSimText"):
                errors.append(f"{owner}: non-listening placement item must not include media or audioSimText")

    for skill_id in expected_skills:
        if skill_levels[skill_id] != {"A1", "A2", "B1"}:
            errors.append(f"placement-questions.json skill '{skill_id}' must cover A1/A2/B1, got {sorted(skill_levels[skill_id])}")
    if len(distinct_correct_indices) < 3:
        errors.append(f"placement-questions.json correctIndex must span >= 3 positions, got {sorted(distinct_correct_indices)}")

    print(f"[OK placement] questions={len(placement_qs)} | audio={placement_audio_count}")
    return errors


def main() -> int:
    all_errors: list[str] = []
    approved_media: dict = {}
    seen_media_ids: set[str] = set()
    approved_audio_ids: set[str] = set()

    manifest_paths, curriculum_paths, discovery_errors = discover_manifests_and_curricula()
    all_errors.extend(discovery_errors)

    for manifest_path in manifest_paths:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if (
            manifest.get("courseId") != "course_eng_01"
            or manifest.get("language") != "en"
            or manifest.get("reviewStatus") != "approved"
        ):
            all_errors.append(f"Invalid manifest header metadata in {manifest_path.name}")
            continue

        web_dir = ROOT / manifest["webOutputDir"]
        flutter_dir = ROOT / manifest["flutterOutputDir"]

        all_errors.extend(
            verify_audio(manifest, web_dir, flutter_dir, approved_media, seen_media_ids, approved_audio_ids)
        )
        all_errors.extend(verify_images(manifest, web_dir, flutter_dir, approved_media, seen_media_ids))

    all_errors.extend(verify_pubspec(approved_media))
    all_errors.extend(verify_curriculum_and_skeleton(approved_media, approved_audio_ids, curriculum_paths))

    if all_errors:
        for err in all_errors:
            print(f"ERROR: {err}", file=sys.stderr)
        return 1

    print("ALL ENGLISH MEDIA & CURRICULUM VERIFICATION CHECKS PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
