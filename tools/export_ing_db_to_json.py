#!/usr/bin/env python3
import json
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DB_CANDIDATES = [
    ROOT / "ing_base.db",
    ROOT / "mobile_app" / "assets" / "db" / "ing_base.db",
]
OUTPUT_PATH = ROOT / "mobile_app" / "assets" / "db" / "seed.json"


def _table_columns(cursor: sqlite3.Cursor, table: str) -> list[str]:
    columns = cursor.execute(f"PRAGMA table_info({table})").fetchall()
    return [row[1] for row in columns]


def _pick_first(columns: list[str], candidates: list[str]) -> str | None:
    for candidate in candidates:
        if candidate in columns:
            return candidate
    return None


def _load_words(cursor: sqlite3.Cursor) -> list[dict]:
    columns = _table_columns(cursor, "words")
    word_id = _pick_first(columns, ["id", "word_id", "wordId"])
    word_col = _pick_first(columns, ["ingush", "word", "ing"])
    translation_col = _pick_first(columns, ["russian", "translation", "rus"])
    transcription_col = _pick_first(columns, ["transcription"])
    select_cols = [c for c in [word_id, word_col, translation_col, transcription_col] if c]
    if not select_cols:
        return []
    rows = cursor.execute(
        f"SELECT {', '.join(select_cols)} FROM words"
    ).fetchall()
    entries = []
    for row in rows:
        data = dict(zip(select_cols, row))
        entry = {
            "id": data.get(word_id),
            "word": data.get(word_col),
            "translation": data.get(translation_col),
        }
        if transcription_col:
            entry["transcription"] = data.get(transcription_col)
        entries.append(entry)
    return entries


def _load_examples(cursor: sqlite3.Cursor) -> dict:
    if not cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='examples'"
    ).fetchone():
        return {}
    columns = _table_columns(cursor, "examples")
    word_id = _pick_first(columns, ["word_id", "wordId", "wordid", "id"])
    example_ing = _pick_first(columns, ["ing", "ingush", "example"])
    example_rus = _pick_first(columns, ["rus", "russian", "translation"])
    select_cols = [c for c in [word_id, example_ing, example_rus] if c]
    if not select_cols or word_id is None:
        return {}
    rows = cursor.execute(
        f"SELECT {', '.join(select_cols)} FROM examples"
    ).fetchall()
    example_map: dict = {}
    for row in rows:
        data = dict(zip(select_cols, row))
        key = data.get(word_id)
        if key is None or key in example_map:
            continue
        example = {}
        if example_ing:
            example["ing"] = data.get(example_ing)
        if example_rus:
            example["rus"] = data.get(example_rus)
        if example:
            example_map[key] = example
    return example_map


def _select_db_path() -> Path | None:
    for candidate in DB_CANDIDATES:
        if candidate.exists():
            return candidate
    return None


def export_db() -> list[dict]:
    db_path = _select_db_path()
    if db_path is None:
        return []
    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.cursor()
        words = _load_words(cursor)
        examples = _load_examples(cursor)
        for entry in words:
            entry_id = entry.get("id")
            if entry_id in examples:
                entry["example"] = examples[entry_id]
        return words
    finally:
        conn.close()


def main() -> int:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    data = export_db()
    with OUTPUT_PATH.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
