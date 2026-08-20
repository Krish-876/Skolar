"""
batch_upload.py

Uploads every supported file in a local directory (recursively) through the
same pipeline the Flutter app's upload button hits — without touching the
UI, one file at a time.

USAGE
    python batch_upload.py D:\\PYQs\\CS_F372 --subject "Compiler Construction" \
        --college "BITS Pilani Hyderabad" --exam-type compre --doc-type pyq

    # Year is auto-detected from the filename if it contains a 4-digit
    # year (e.g. "CS_F372_2023_compre.pdf" -> 2023). Override with --year
    # if your files aren't named that way, or if you want one year applied
    # to the whole batch.

RESUMABILITY
    Every attempt (success or failure) is recorded in a manifest file
    (<directory>/.upload_manifest.json) keyed by content hash — not
    filename — so renaming a file doesn't cause a re-upload, and re-running
    the script after a crash skips everything already done.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import re
import sys
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

SUPPORTED_EXTENSIONS = {".pdf", ".docx", ".doc", ".jpg", ".jpeg", ".png", ".tif", ".tiff"}
YEAR_PATTERN = re.compile(r"(20\d{2}|19\d{2})")

# Extensions eligible for page-merging (Part 2) — scanned photo/screenshot pages
# of the same document, never .pdf/.docx/.doc which are already whole documents.
IMAGE_MERGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".tif", ".tiff"}

# Trailing page-number suffix on an image filename stem, e.g. "...p1", "...page 2",
# "..._1", "...-2". Requires an explicit separator (space/underscore/hyphen)
# before the optional "p"/"page" word, so it doesn't fire on unrelated digits.
PAGE_SUFFIX_PATTERN = re.compile(
    r"^(?P<base>.+?)[\s_-]+(?:p(?:age)?)?[\s_-]*(?P<num>\d+)$",
    re.IGNORECASE,
)

MANIFEST_NAME = ".upload_manifest.json"


def _hash_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _load_manifest(directory: Path) -> dict:
    manifest_path = directory / MANIFEST_NAME
    if manifest_path.exists():
        return json.loads(manifest_path.read_text())
    return {}


def _save_manifest(directory: Path, manifest: dict) -> None:
    manifest_path = directory / MANIFEST_NAME
    manifest_path.write_text(json.dumps(manifest, indent=2))


def _guess_year(filename: str, fallback: int | None) -> int | None:
    match = YEAR_PATTERN.search(filename)
    if match:
        return int(match.group(1))
    return fallback


def _guess_exam_type(filename: str) -> str | None:
    name = filename.lower()
    if "compre" in name:
        return "compre"
    if "mid-sem" in name or "mid sem" in name or "midsem" in name:
        return "midsem"
    if "test1" in name or "quiz1" in name:
        return "quiz1"
    if "test2" in name or "quiz2" in name:
        return "quiz2"
    if "test3" in name:
        # BITS convention: Test 3 is typically the comprehensive exam, but
        # confirm this matches this specific course before trusting it.
        return "compre"
    return None


def collect_files(directory: Path) -> list[Path]:
    return sorted(
        p for p in directory.rglob("*")
        if p.is_file()
        and p.suffix.lower() in SUPPORTED_EXTENSIONS
        and p.name != MANIFEST_NAME
    )


class UploadItem:
    """One logical document to upload — either a single original file, or
    several split page-image files merged into one in-memory PDF."""

    def __init__(self, paths: list[Path], filename: str):
        self.paths = paths          # source file(s), in page order for merged groups
        self.filename = filename    # name used for year/exam-type guessing, logging, storage_path

    @property
    def is_merged(self) -> bool:
        return len(self.paths) > 1


def _group_image_pages(files: list[Path]) -> list[UploadItem]:
    """Group image files (.jpg/.jpeg/.png/.tif/.tiff) that look like split pages
    of the same scanned document — e.g. "2018_Compre p1.jpg" + "...p2.jpg" + ...
    — into one UploadItem per document, pages sorted in order. .pdf/.docx/.doc
    files, and images with no detectable page-number suffix, are never grouped
    — each stays its own single-file UploadItem, uploaded exactly as before.
    """
    page_groups: dict[tuple[str, str], list[tuple[int, Path]]] = {}
    group_order: list[tuple[str, str]] = []
    items: list[UploadItem] = []

    for path in files:
        if path.suffix.lower() not in IMAGE_MERGE_EXTENSIONS:
            items.append(UploadItem(paths=[path], filename=path.name))
            continue

        match = PAGE_SUFFIX_PATTERN.match(path.stem)
        if not match:
            items.append(UploadItem(paths=[path], filename=path.name))
            continue

        key = (str(path.parent), match.group("base").strip().lower())
        if key not in page_groups:
            page_groups[key] = []
            group_order.append(key)
        page_groups[key].append((int(match.group("num")), path))

    for key in group_order:
        pages = sorted(page_groups[key])
        if len(pages) == 1:
            items.append(UploadItem(paths=[pages[0][1]], filename=pages[0][1].name))
            continue

        ordered_paths = [p for _, p in pages]
        lowest_page_path = ordered_paths[0]
        base_match = PAGE_SUFFIX_PATTERN.match(lowest_page_path.stem)
        base_name = base_match.group("base").strip() if base_match else lowest_page_path.stem
        merged_filename = f"{base_name}.pdf"
        logger.info(
            f"grouping {len(ordered_paths)} files into {merged_filename} "
            f"({len(ordered_paths)} pages): {', '.join(p.name for p in ordered_paths)}"
        )
        items.append(UploadItem(paths=ordered_paths, filename=merged_filename))

    return items


def _item_hash(item: UploadItem) -> str:
    if len(item.paths) == 1:
        return _hash_file(item.paths[0])
    h = hashlib.sha256()
    for p in item.paths:
        h.update(_hash_file(p).encode())
    return h.hexdigest()


def _merge_images_to_pdf(paths: list[Path]) -> bytes:
    """Combine page-image files into one in-memory multi-page PDF via Pillow."""
    import io
    from PIL import Image

    images = [Image.open(p).convert("RGB") for p in paths]
    try:
        buf = io.BytesIO()
        images[0].save(buf, format="PDF", save_all=True, append_images=images[1:])
        return buf.getvalue()
    finally:
        for img in images:
            img.close()


def _load_item_bytes(item: UploadItem) -> bytes:
    if item.is_merged:
        return _merge_images_to_pdf(item.paths)
    return item.paths[0].read_bytes()


def _upload_with_exam_type_resolution(
    run_upload_pyq,
    exam_type_undetermined_error: type[Exception],
    *,
    file_bytes: bytes,
    filename: str,
    subject: str,
    paper_year: int,
    college: str,
    subject_id: str | None,
    doc_type: str,
    storage_path: str,
    filename_guess: str | None,
    cli_exam_type: str | None,
) -> tuple[dict, str]:
    """Resolve exam_type in order: (1) filename-based guess, (2) content-based
    detection — attempted internally by run_upload_pyq when passed exam_type=None
    — (3) the --exam-type CLI flag. Only one extraction happens in the common
    case (filename_guess or content detection succeeding); the CLI flag is only
    retried as a second call when both of those come up empty, since it's the
    lowest-confidence source.

    Returns (result, method) where method is "filename", "content", or "flag".
    Raises exam_type_undetermined_error if all three sources come up empty.
    """
    try:
        result = run_upload_pyq(
            pdf_bytes=file_bytes,
            filename=filename,
            subject=subject,
            paper_year=paper_year,
            exam_type=filename_guess,
            college=college,
            subject_id=subject_id,
            doc_type=doc_type,
            storage_path=storage_path,
        )
        return result, ("filename" if filename_guess else "content")
    except exam_type_undetermined_error:
        if not cli_exam_type:
            raise
        result = run_upload_pyq(
            pdf_bytes=file_bytes,
            filename=filename,
            subject=subject,
            paper_year=paper_year,
            exam_type=cli_exam_type,
            college=college,
            subject_id=subject_id,
            doc_type=doc_type,
            storage_path=storage_path,
        )
        return result, "flag"


def run_batch(
    directory: Path,
    subject: str,
    subject_id: str | None,
    college: str,
    exam_type: str | None,
    doc_type: str,
    year: int | None,
    dry_run: bool,
) -> None:
    # Import here, not at module top, so this script can be dropped anywhere
    # without failing at import time if the pipeline module isn't on the path.
    try:
        rag_llms_dir = Path(__file__).resolve().parents[2] / "lib" / "core" / "ai" / "rag_llms"
        if str(rag_llms_dir) not in sys.path:
            sys.path.insert(0, str(rag_llms_dir))
        from pipeline import run_upload_pyq, ExamTypeUndeterminedError
    except ImportError:
        logger.error(
            "Could not import run_upload_pyq. Update the import in run_batch() "
            "to point at your actual pipeline module (e.g. `from questions_extraction import run_upload_pyq`)."
        )
        sys.exit(1)

    files = collect_files(directory)
    if not files:
        logger.warning(f"No supported files found in {directory} (looked for {sorted(SUPPORTED_EXTENSIONS)})")
        return

    items = _group_image_pages(files)

    manifest = _load_manifest(directory)
    logger.info(f"Found {len(files)} candidate files ({len(items)} documents after page-merging). "
                f"{len(manifest)} already recorded in manifest.")

    added_total = 0
    skipped = 0
    failed = 0
    succeeded = 0

    for i, item in enumerate(items, start=1):
        item_hash = _item_hash(item)

        if item_hash in manifest and manifest[item_hash].get("status") == "succeeded":
            skipped += 1
            logger.info(f"[{i}/{len(items)}] SKIP (already uploaded) {item.filename}")
            continue

        file_year = _guess_year(item.filename, fallback=year)
        if file_year is None:
            logger.warning(f"[{i}/{len(items)}] no year found in filename and no --year given, skipping {item.filename}")
            manifest[item_hash] = {"file": item.filename, "status": "skipped_no_year"}
            continue

        filename_guess = _guess_exam_type(item.filename)

        if dry_run:
            exam_type_note = filename_guess or exam_type or "would attempt content-based detection at upload time"
            logger.info(f"[{i}/{len(items)}] DRY RUN would upload {item.filename} "
                        f"(year={file_year}, exam_type={exam_type_note})")
            continue

        logger.info(f"[{i}/{len(items)}] uploading {item.filename} (year={file_year})")

        # Exam type isn't resolved upfront — filename guess failing no longer
        # skips the file. It's passed through to run_upload_pyq (None if the
        # filename guess is empty), which tries content-based detection
        # internally; only if that also comes up empty do we fall back to the
        # --exam-type flag, and only skip if all three sources are empty.
        try:
            file_bytes = _load_item_bytes(item)
            result, exam_type_method = _upload_with_exam_type_resolution(
                run_upload_pyq,
                ExamTypeUndeterminedError,
                file_bytes=file_bytes,
                filename=item.filename,
                subject=subject,
                paper_year=file_year,
                college=college,
                subject_id=subject_id,
                doc_type=doc_type,
                storage_path=f"batch_upload/{item.filename}",
                filename_guess=filename_guess,
                cli_exam_type=exam_type,
            )
            added = result.get("added", 0)
            added_total += added
            succeeded += 1
            manifest[item_hash] = {
                "file": item.filename,
                "status": "succeeded",
                "questions_added": added,
                "exam_type": result.get("exam_type"),
                "exam_type_source": exam_type_method,
            }
            logger.info(f"[{i}/{len(items)}] done — +{added} questions "
                        f"(exam_type={result.get('exam_type')}, determined via {exam_type_method})")

        except ExamTypeUndeterminedError:
            skipped += 1
            logger.warning(
                f"[{i}/{len(items)}] no exam type in filename, none detectable from document "
                f"content, and no --exam-type given, skipping {item.filename}"
            )
            manifest[item_hash] = {"file": item.filename, "status": "skipped_no_exam_type"}

        except Exception as e:
            failed += 1
            manifest[item_hash] = {"file": item.filename, "status": "failed", "error": str(e)}
            logger.error(f"[{i}/{len(items)}] FAILED {item.filename}: {e}")

        # Save after every file, not just at the end — a crash halfway
        # through a 200-file batch shouldn't lose progress.
        _save_manifest(directory, manifest)

    logger.info(
        f"Batch complete. succeeded={succeeded} failed={failed} skipped={skipped} "
        f"total_questions_added={added_total}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Batch-upload PYQ files from a local directory.")
    parser.add_argument("directory", type=Path, help="Directory to scan recursively")
    parser.add_argument("--subject", required=True)
    parser.add_argument("--subject-id", default=None)
    parser.add_argument("--college", required=True)
    parser.add_argument("--exam-type", default=None, choices=[None, "quiz1", "midsem", "quiz2", "compre", "generated"])
    parser.add_argument("--doc-type", default="pyq", choices=["pyq", "tutorial", "solution", "lab", "misc"])
    parser.add_argument("--year", type=int, default=None, help="Fallback year if not found in filename")
    parser.add_argument("--dry-run", action="store_true", help="List what would be uploaded without uploading")
    args = parser.parse_args()

    if not args.directory.is_dir():
        logger.error(f"{args.directory} is not a directory")
        sys.exit(1)

    run_batch(
        directory=args.directory,
        subject=args.subject,
        subject_id=args.subject_id,
        college=args.college,
        exam_type=args.exam_type,
        doc_type=args.doc_type,
        year=args.year,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()