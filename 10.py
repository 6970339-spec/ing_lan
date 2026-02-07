# -*- coding: utf-8 -*-
"""
Ingush trainer (PyQt5 + SQLite).

Изменения по просьбе:
- Статистику (stats.json) храним ТОЛЬКО в пользовательской папке:
  Windows:  %APPDATA%/IngushLanguage/stats.json
  macOS:    ~/Library/Application Support/IngushLanguage/stats.json
  Linux:    ~/.config/IngushLanguage/stats.json
- Убраны: режим "хранить рядом с программой", показ текущего пути и кнопка "Открыть папку данных".
- Оставлены настройки: смена ФИО и "Сбросить прогресс".
- Сохранение прогресса — после каждого шага.
"""
import sys
import os
import json
import sqlite3
from pathlib import Path
from typing import List, Dict, Any, Tuple

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QPushButton, QSpacerItem, QSizePolicy, QTextEdit, QLineEdit, QStackedWidget,
    QDialog, QFrame, QMessageBox, QTextBrowser, QAction, QSlider
)
from PyQt5.QtCore import Qt, pyqtSignal
from PyQt5.QtGui import QClipboard, QIcon

APP_NAME_DIR = "IngushLanguage"  # имя папки в APPDATA

# ---------- Пути к ресурсам (read-only, рядом с exe или в _MEIPASS) ----------
RESOURCE_DIR = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
DB_FILE = RESOURCE_DIR / "ing_base.db"           # или ing_base_encrypted.db
ICON_FILE = RESOURCE_DIR / "12.ico"

# ---------- Пользовательская папка (writeable) для stats.json ----------
def get_user_data_dir() -> Path:
    if sys.platform.startswith("win"):
        base = os.getenv("APPDATA") or os.getenv("LOCALAPPDATA") or str(Path.home() / "AppData" / "Roaming")
        return Path(base) / APP_NAME_DIR
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / APP_NAME_DIR
    else:
        return Path.home() / ".config" / APP_NAME_DIR

DATA_DIR = get_user_data_dir()
DATA_DIR.mkdir(parents=True, exist_ok=True)
STATS_FILE = DATA_DIR / "stats.json"

# ----- Инструкция (увеличенный размер текста) -----
HELP_TEXT = """<div style="font-size:18px; line-height:1.6;">
<b>Как пользоваться программой</b><br><br>
1) Нажмите «Начать», чтобы перейти к тренировке слов.<br>
2) Если знаете слово — жмите «Знаю», если нет — «Не знаю».<br>
3) При «Не знаю» появятся примеры: перепишите их и запомните перевод.<br>
4) Слева сверху отображается ваше имя. Вверху есть поиск по словам (временно отключён).<br><br>
<i>Совет:</i> делайте короткие сессии по 10–15 слов — так прогресс быстрее.
</div>"""

# ======= База данных =======
def get_connection(sqlcipher: bool = False, password: str = None):
    """Если sqlcipher=True и установлен pysqlcipher3 — используется оно; иначе — sqlite3."""
    if sqlcipher:
        try:
            from pysqlcipher3 import dbapi2 as sqlcipher3
            conn = sqlcipher3.connect(str(DB_FILE))
            if password:
                conn.execute("PRAGMA key = ?;", (password,))
            return conn
        except Exception:
            print("SQLCipher requested but pysqlcipher3 not available. Using plain sqlite3.")
    return sqlite3.connect(str(DB_FILE))

def load_all_words() -> List[Dict[str, Any]]:
    if not DB_FILE.exists():
        return []
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, ingush, russian, transcription FROM words ORDER BY id")
    words = []
    for wid, ing, rus, tr in cur.fetchall():
        cur.execute("SELECT ing, rus FROM examples WHERE word_id = ? ORDER BY id", (wid,))
        exs = [{"ing": r[0], "rus": r[1]} for r in cur.fetchall()]
        words.append({"id": wid, "ingush": ing, "russian": rus, "transcription": tr or "", "examples": exs})
    conn.close()
    return words

# ======= Статистика =======
def load_stats(filepath: Path) -> Dict[str, Any]:
    try:
        if filepath.exists():
            with open(filepath, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception as e:
        print("Error loading stats:", e)
    return {"current_index": 0, "known_count": 0, "unknown_count": 0, "user_name": "", "example_font_size": 16}

def save_stats(filepath: Path, stats: Dict[str, Any]) -> None:
    try:
        filepath.parent.mkdir(parents=True, exist_ok=True)
        tmp = str(filepath) + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(stats, f, ensure_ascii=False, indent=2)
        os.replace(tmp, str(filepath))
    except Exception as e:
        QMessageBox.critical(None, "Ошибка записи", f"Не удалось сохранить статистику:\n{e}")

# ========================= UI =========================
class TopBar(QWidget):
    def __init__(self, left_text=""):
        super().__init__()
        lay = QHBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(12)
        self.left = QLabel(left_text or "")
        self.left.setObjectName("TopLeft")
        self.search = QLineEdit()
        self.search.setPlaceholderText("Поиск временно отключён")
        self.search.setFixedWidth(280)
        self.search.setObjectName("Search")
        self.search.setReadOnly(True)
        self.ach = QPushButton("Достижения ⚙️")
        self.ach.setObjectName("Ghost")
        lay.addWidget(self.left)
        lay.addSpacerItem(QSpacerItem(20, 20, QSizePolicy.Expanding, QSizePolicy.Minimum))
        lay.addWidget(self.search)
        lay.addSpacerItem(QSpacerItem(20, 20, QSizePolicy.Expanding, QSizePolicy.Minimum))
        lay.addWidget(self.ach)

    def set_user_name(self, name: str):
        self.left.setText(f"Пользователь: {name}")

class InstructionDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("HelpDialog")
        self.setModal(True)
        self.setWindowTitle("Инструкция")
        self.resize(760, 520)
        root = QVBoxLayout(self)
        root.setContentsMargins(16, 16, 16, 16)
        title = QLabel("Инструкция"); title.setObjectName("H2"); title.setAlignment(Qt.AlignCenter)
        root.addWidget(title)
        text = QTextBrowser(); text.setObjectName("Card"); text.setOpenExternalLinks(True); text.setHtml(HELP_TEXT)
        root.addWidget(text, 1)
        row = QHBoxLayout(); row.addStretch(1)
        btn = QPushButton("Закрыть"); btn.setObjectName("PrimaryPill"); btn.clicked.connect(self.accept)
        row.addWidget(btn); root.addLayout(row)

class SupportDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("HelpDialog"); self.setModal(True)
        self.setWindowTitle("Поддержать проект"); self.resize(520, 380)
        root = QVBoxLayout(self); root.setContentsMargins(16, 16, 16, 16)
        title = QLabel("Поддержать проект"); title.setObjectName("H2"); title.setAlignment(Qt.AlignCenter)
        root.addWidget(title)
        self.browser = QTextBrowser(); self.browser.setObjectName("Card"); self.browser.setOpenExternalLinks(True)
        html = """
        <div style="text-align:center; line-height:1.7;">
            <div><b>1) Разработчик:</b> Дзармотов Бекхан Иссаевич, ЧПОУ «Солво»</div>
            <div><b>Email:</b> <a href="mailto:7497299@mail.ru">7497299@mail.ru</a></div><br/>
            <div><b>2) Перевод на Сбер (СПБ)</b></div>
            <div><b>Номер счета:</b> 4081 7810 9603 5059 0499</div><br/>
            <div><b>3) Перевод на Сбер (СПБ)</b></div>
            <div><b>Номер карты:</b> 2202 2013 3605 9767</div>
        </div>"""
        self.browser.setHtml(html); root.addWidget(self.browser, 1)
        row = QHBoxLayout(); row.addStretch(1)
        self.btn_copy = QPushButton("Копировать реквизиты"); self.btn_copy.setObjectName("OutlinePill"); self.btn_copy.clicked.connect(self.copy_all)
        self.btn_close = QPushButton("Закрыть"); self.btn_close.setObjectName("PrimaryPill"); self.btn_close.clicked.connect(self.accept)
        row.addWidget(self.btn_copy); row.addSpacing(8); row.addWidget(self.btn_close); root.addLayout(row)
        self.plain_text = (
            "1) Разработчик: Дзармотов Бекхан Иссаевич, ЧПОУ «Солво»\n"
            "Email: 7497299@mail.ru\n\n"
            "2) Перевод на Сбер (СПБ)\nНомер счета: 4081 7810 9603 5059 0499\n\n"
            "3) Перевод на Сбер (СПБ)\nНомер карты: 2202 2013 3605 9767"
        )
    def copy_all(self):
        QApplication.clipboard().setText(self.plain_text, mode=QClipboard.Clipboard)
        self.btn_copy.setText("Скопировано!")

class SettingsDialog(QDialog):
    """Настройки: ФИО и сброс прогресса (без выбора места хранения и без показа пути)."""
    def __init__(self, parent, user_name: str):
        super().__init__(parent)
        self.setObjectName("HelpDialog")
        self.setModal(True)
        self.setWindowTitle("Настройки")
        self.resize(520, 260)
        self.reset_requested = False

        root = QVBoxLayout(self); root.setContentsMargins(16,16,16,16); root.setSpacing(10)
        title = QLabel("Настройки"); title.setObjectName("H2"); title.setAlignment(Qt.AlignCenter)
        root.addWidget(title)

        # Имя
        row = QHBoxLayout()
        row.addWidget(QLabel("ФИО / ник:"))
        self.input_name = QLineEdit(); self.input_name.setText(user_name); self.input_name.setPlaceholderText("Например: Магомед")
        row.addWidget(self.input_name)
        root.addLayout(row)

        # Кнопка сброса
        actions = QHBoxLayout()
        btn_reset = QPushButton("Сбросить прогресс"); btn_reset.setObjectName("OutlinePill")
        def ask_reset():
            if QMessageBox.question(self, "Сброс", "Обнулить прогресс (знаю/не знаю и позицию)?",
                                    QMessageBox.Yes | QMessageBox.No, QMessageBox.No) == QMessageBox.Yes:
                self.reset_requested = True
        btn_reset.clicked.connect(ask_reset)
        actions.addWidget(btn_reset); actions.addStretch(1)
        root.addLayout(actions)

        # OK/Cancel
        bottom = QHBoxLayout(); bottom.addStretch(1)
        btn_ok = QPushButton("Сохранить"); btn_ok.setObjectName("PrimaryPill"); btn_ok.clicked.connect(self.accept)
        btn_cancel = QPushButton("Отмена"); btn_cancel.setObjectName("OutlinePill"); btn_cancel.clicked.connect(self.reject)
        bottom.addWidget(btn_ok); bottom.addSpacing(8); bottom.addWidget(btn_cancel)
        root.addLayout(bottom)

    def get_values(self) -> Tuple[str, bool]:
        return self.input_name.text().strip(), self.reset_requested

class StartPage(QWidget):
    start_clicked = pyqtSignal()
    def __init__(self, user_name: str):
        super().__init__()
        self.user_name = user_name
        self._ui()
    def _ui(self):
        root = QVBoxLayout(self); root.setContentsMargins(24,24,24,24); root.setSpacing(16)
        self.tb = TopBar(left_text=f"Пользователь: {self.user_name}"); self.tb.left.setObjectName("TopLeft")
        root.addWidget(self.tb)
        hero = QVBoxLayout(); hero.addStretch(1)
        title = QLabel("Марша доаг1алда шо!"); title.setObjectName("WordDisplay"); title.setAlignment(Qt.AlignCenter)
        subtitle = QLabel("Добро пожаловать в тренажёр-словарь ингушского языка"); subtitle.setAlignment(Qt.AlignCenter); subtitle.setObjectName("Subtle")
        hint = QLabel("Чтобы начать нажмите кнопку:"); hint.setAlignment(Qt.AlignCenter); hint.setObjectName("Subtle")
        btn = QPushButton("Начать"); btn.setObjectName("PrimaryPill"); btn.setFixedWidth(168); btn.clicked.connect(self.start_clicked.emit)
        hero.addWidget(title); hero.addWidget(subtitle); hero.addWidget(hint)
        row = QHBoxLayout(); row.addStretch(1); row.addWidget(btn); row.addStretch(1)
        hero.addSpacing(8); hero.addLayout(row); hero.addStretch(1); root.addLayout(hero)
    def set_user_name(self, name: str):
        self.user_name = name; self.tb.set_user_name(name)

class HowPage(QWidget):
    next_clicked = pyqtSignal()
    def __init__(self, user_name: str):
        super().__init__()
        self.user_name = user_name
        self._ui()
    def _ui(self):
        root = QVBoxLayout(self); root.setContentsMargins(24,24,24,24); root.setSpacing(16)
        self.tb = TopBar(left_text=f"Пользователь: {self.user_name}"); self.tb.left.setObjectName("TopLeft")
        root.addWidget(self.tb)
        wrap = QVBoxLayout(); wrap.addStretch(1)
        h2 = QLabel("Как работает тренажёр?"); h2.setAlignment(Qt.AlignCenter); h2.setObjectName("H2")
        text = QLabel("Благодаря технике в данном приложении вы сможете\nзапомнить больше ингушских слов и использовать их\nкак в устной, так и в письменной форме.")
        text.setAlignment(Qt.AlignCenter); text.setObjectName("Subtle")
        btn = QPushButton("Далее"); btn.setObjectName("OutlinePill"); btn.setFixedWidth(168); btn.clicked.connect(self.next_clicked.emit)
        wrap.addWidget(h2); wrap.addSpacing(8); wrap.addWidget(text)
        r = QHBoxLayout(); r.addStretch(1); r.addWidget(btn); r.addStretch(1)
        wrap.addSpacing(10); wrap.addLayout(r); wrap.addStretch(1); root.addLayout(wrap)
    def set_user_name(self, name: str):
        self.user_name = name; self.tb.set_user_name(name)

class TrainerPage(QWidget):
    def __init__(self, words: List[Dict[str, Any]], stats: Dict[str, Any], user_name: str, save_cb):
        super().__init__()
        self.words, self.stats, self.user_name = words, stats, user_name
        self.total = len(words)
        self.idx = max(0, min(stats.get("current_index", 0), self.total-1 if self.total else 0))
        self.known = stats.get("known_count", 0)
        self.unknown = stats.get("unknown_count", 0)
        self.example_font_size = stats.get("example_font_size", 16)
        self._locked = False
        self._save_cb = save_cb
        self._ui(); self._load()
    def _ui(self):
        root = QVBoxLayout(self); root.setContentsMargins(24, 24, 24, 24); root.setSpacing(12)
        self.tb = TopBar(left_text=f"Пользователь: {self.user_name}"); self.tb.left.setObjectName("TopLeft")
        root.addWidget(self.tb)
        root.addSpacing(100)
        self.h_word = QLabel(""); self.h_word.setObjectName("WordDisplay"); self.h_word.setAlignment(Qt.AlignCenter); self.h_word.setStyleSheet("font-size: 44px;")
        self.h_rus = QLabel(""); self.h_rus.setObjectName("Subtle"); self.h_rus.setAlignment(Qt.AlignCenter); self.h_rus.setStyleSheet("font-size: 16px;")
        self.h_tr = QLabel(""); self.h_tr.setObjectName("Transc"); self.h_tr.setAlignment(Qt.AlignCenter); self.h_tr.setStyleSheet("font-size: 16px;")
        root.addSpacing(4); root.addWidget(self.h_word); root.addWidget(self.h_rus); root.addWidget(self.h_tr); root.addSpacing(4)
        row = QHBoxLayout()
        self.btn_prev = QPushButton("«"); self.btn_prev.setObjectName("Arrow"); self.btn_prev.setFixedSize(44,44)
        self.btn_yes = QPushButton("Знаю"); self.btn_yes.setObjectName("YesPill"); self.btn_yes.setFixedHeight(44)
        self.btn_no  = QPushButton("Не знаю"); self.btn_no.setObjectName("NoPill"); self.btn_no.setFixedHeight(44)
        self.btn_next= QPushButton("»"); self.btn_next.setObjectName("Arrow"); self.btn_next.setFixedSize(44,44)
        row.addStretch(1); row.addWidget(self.btn_prev); row.addSpacing(12); row.addWidget(self.btn_yes); row.addSpacing(12); row.addWidget(self.btn_no); row.addSpacing(12); row.addWidget(self.btn_next); row.addStretch(1)
        root.addLayout(row)
        self.hint = QLabel("Запишите предложения ниже. Прочитайте перевод и постарайтесь запомнить.")
        self.hint.setObjectName("HintBig"); self.hint.setAlignment(Qt.AlignCenter); self.hint.setStyleSheet("font-size: 14px;")
        root.addSpacing(8); root.addWidget(self.hint)
        ex_wrap = QHBoxLayout(); ex_wrap.addStretch(1)
        self.examples = QTextEdit(); self.examples.setReadOnly(True); self.examples.setObjectName("Card"); self.examples.setFixedWidth(760); self.examples.setStyleSheet(f"font-size: {self.example_font_size}px;")
        ex_wrap.addWidget(self.examples, 0, Qt.AlignCenter); ex_wrap.addStretch(1); root.addLayout(ex_wrap)
        self.lbl_stats = QLabel(""); self.lbl_stats.setObjectName("Stats"); self.lbl_stats.setAlignment(Qt.AlignCenter); self.lbl_stats.setStyleSheet("font-size: 13px;")
        root.addWidget(self.lbl_stats)
        slider_wrap = QHBoxLayout(); slider_wrap.addStretch(1)
        self.font_slider = QSlider(Qt.Horizontal); self.font_slider.setRange(10, 30); self.font_slider.setValue(self.example_font_size); self.font_slider.setFixedWidth(200); self.font_slider.valueChanged.connect(self.update_example_font_size)
        slider_wrap.addWidget(self.font_slider); slider_wrap.addStretch(1); root.addLayout(slider_wrap)
        self.btn_prev.clicked.connect(self._prev); self.btn_next.clicked.connect(self._next); self.btn_yes.clicked.connect(self._know); self.btn_no.clicked.connect(self._dont)
    def _load(self):
        if not self.words:
            self.h_word.setText("Нет данных"); self.h_rus.setText(""); self.h_tr.setText(""); self.examples.clear(); return
        if self.idx >= self.total: self._finish(); return
        self._locked = False; self.btn_yes.setEnabled(True); self.btn_no.setEnabled(True); self.examples.clear()
        d = self.words[self.idx]
        self.h_word.setText(str(d.get("ingush", ""))); self.h_rus.setText(str(d.get("russian", ""))); tr = d.get("transcription", "")
        self.h_tr.setText(f"[ {tr} ]" if tr else ""); self._update_stats()
    def _know(self):
        if not self._locked:
            self.known += 1; self._locked = True; self.idx += 1; self._save_cb(); self._load()
    def _dont(self):
        if not self._locked:
            self.unknown += 1; self._locked = True; self.btn_yes.setEnabled(False)
            d = self.words[self.idx]; ex = d.get("examples", [])
            if not ex:
                self.examples.setHtml("<div class='excard' style='text-align:center;'><p>Нет примеров</p></div>")
            else:
                parts = []
                for i, e in enumerate(ex):
                    margin_top, margin_bottom = (12, 18)
                    if i == 2: margin_top = 50
                    parts.append(f"""
                    <div class='item' style='margin-top:{margin_top}px; margin-bottom:{margin_bottom}px;'>
                        <div class='ing' style='font-weight:700; margin-bottom:14px;'>{e.get('ing','')}</div>
                        <div class='rus' style='color:#6B7280; line-height:1.55;'>{e.get('rus','')}</div>
                    </div>""")
                self.examples.setHtml("<div class='excard' style='text-align:center;'>{}</div>".format("".join(parts)))
            self._save_cb(); self._update_stats()
    def _next(self):
        self.idx += 1; self._save_cb(); self._load()
    def _prev(self):
        self.idx = max(0, self.idx - 1); self._save_cb(); self._load()
    def _update_stats(self):
        total_done = self.known + self.unknown; remaining = max(0, self.total - total_done)
        self.lbl_stats.setText(f"Всего: {self.total} | Осталось: {remaining} | Пройдено: {total_done} | Знаю: {self.known} | Не знаю: {self.unknown}")
    def _finish(self):
        self.h_word.setText("Конец"); self.h_rus.setText(f"Знаю: {self.known} | Не знаю: {self.unknown}")
        for b in (self.btn_yes, self.btn_no, self.btn_next, self.btn_prev): b.setEnabled(False)
        self.examples.clear()
    def export_stats(self) -> Dict[str, Any]:
        return {"current_index": self.idx, "known_count": self.known, "unknown_count": self.unknown, "example_font_size": self.example_font_size}
    def update_example_font_size(self, value):
        self.example_font_size = value; self.examples.setStyleSheet(f"font-size: {self.example_font_size}px;"); self._save_cb()
    def set_user_name(self, name: str):
        self.user_name = name; self.tb.set_user_name(name)

class NameDialog(QDialog):
    def __init__(self, initial_text: str = ""):
        super().__init__()
        self.setObjectName("NameDialog"); self.setModal(True); self.setWindowTitle("Добро пожаловать"); self.resize(520, 260)
        root = QVBoxLayout(self); root.setContentsMargins(24, 24, 24, 24); root.setSpacing(12)
        card = QFrame(); card.setObjectName("NameCard")
        card_l = QVBoxLayout(card); card_l.setContentsMargins(24,24,24,24); card_l.setSpacing(12)
        title = QLabel("Как к вам обращаться?"); title.setObjectName("H2"); title.setAlignment(Qt.AlignCenter)
        subtitle = QLabel("Введите ваше имя или никнейм — мы покажем его в верхней панели."); subtitle.setObjectName("Subtle"); subtitle.setAlignment(Qt.AlignCenter)
        self.input = QLineEdit(); self.input.setObjectName("NameInput"); self.input.setPlaceholderText("Например: Магомед")
        if initial_text: self.input.setText(initial_text)
        btn = QPushButton("Продолжить"); btn.setObjectName("PrimaryPill"); btn.setFixedWidth(180); btn.clicked.connect(self.accept)
        card_l.addWidget(title); card_l.addWidget(subtitle); card_l.addSpacing(6); card_l.addWidget(self.input)
        row = QHBoxLayout(); row.addStretch(1); row.addWidget(btn); row.addStretch(1); card_l.addSpacing(6); card_l.addLayout(row)
        root.addStretch(1); root.addWidget(card); root.addStretch(1)
    def accept(self):
        text = self.input.text().strip()
        if not text:
            self.input.setProperty("error", True); self.input.style().unpolish(self.input); self.input.style().polish(self.input); self.input.setFocus(); return
        self.user_name = text; super().accept()

class MainWindow(QMainWindow):
    def __init__(self, words, stats, user_name):
        super().__init__()
        self.words, self.stats, self.user_name = words, stats, user_name
        self.setWindowTitle("Изучаем ингушский язык"); self.setGeometry(100,100,960,640)
        self._build_menu()
        self.stack = QStackedWidget(); self.setCentralWidget(self.stack)
        self.p_start = StartPage(user_name); self.p_how = HowPage(user_name)
        self.p_train = TrainerPage(words, stats, user_name, save_cb=self._save_progress)
        self.p_start.start_clicked.connect(lambda: self.stack.setCurrentWidget(self.p_how))
        self.p_how.next_clicked.connect(lambda: self.stack.setCurrentWidget(self.p_train))
        for w in (self.p_start, self.p_how, self.p_train): self.stack.addWidget(w)
        self.stack.setCurrentWidget(self.p_start)
    def _build_menu(self):
        m = self.menuBar().addMenu("Программа")
        act_support = QAction("Поддержать проект", self); act_support.triggered.connect(self.show_support); m.addAction(act_support)
        act_instr = QAction("Инструкция", self); act_instr.triggered.connect(self.show_instructions); m.addAction(act_instr)
        act_settings = QAction("Настройки…", self); act_settings.triggered.connect(self.show_settings); m.addAction(act_settings)
        m.addSeparator()
        act_about = QAction("О программе", self); act_about.triggered.connect(self.show_about); m.addAction(act_about)
    def _save_progress(self):
        self.stats.update(self.p_train.export_stats())
        save_stats(STATS_FILE, self.stats)
    def show_about(self):
        html = ("<div style='line-height:1.6;'>"
                "<b>Изучаем ингушский язык</b><br>"
                "Версия: 1.0<br><br>"
                "<b>Разработчик:</b> Дзармотов Бекхан Иссаевич<br>"
                "ЧПОУ «Солво»<br>"
                "Email: <a href='mailto:7497299@mail.ru'>7497299@mail.ru</a>"
                "</div>")
        QMessageBox.about(self, "О программе", html)
    def show_instructions(self): InstructionDialog(self).exec_()
    def show_support(self): SupportDialog(self).exec_()
    def show_settings(self):
        dlg = SettingsDialog(self, self.user_name)
        if dlg.exec_() == QDialog.Accepted:
            new_name, reset = dlg.get_values()
            # имя
            if new_name and new_name != self.user_name:
                self.user_name = new_name
                self.stats["user_name"] = new_name
                self.p_start.set_user_name(new_name); self.p_how.set_user_name(new_name); self.p_train.set_user_name(new_name)
            # сброс
            if reset:
                self.p_train.idx = 0; self.p_train.known = 0; self.p_train.unknown = 0
                self.p_train._save_cb(); self.p_train._load()
            else:
                save_stats(STATS_FILE, self.stats)
    def closeEvent(self, e):
        try:
            self._save_progress()
        except Exception as ex:
            print("Error saving stats on close:", ex)
        super().closeEvent(e)

# ----------------- QSS -----------------
QSS = """
QMainWindow { background: #F3F4F6; }
QLabel#TopLeft { color:#6B7280; font-size:14px; }
QLineEdit#Search { background:#FFFFFF; border:1px solid #E5E7EB; border-radius:12px; padding:8px 12px; color:#111827; selection-background-color:#BFDBFE; }
QLineEdit#Search:focus { border:1px solid #60A5FA; }
QPushButton#Ghost { background:#EFF1F5; color:#4B5563; border:none; border-radius:12px; padding:8px 12px; }
QPushButton#Ghost:hover { background:#E5E7EB; }
QLabel#WordDisplay { font-family:"Helvetica"; font-weight:800; font-size:44px; color:#111827; }
QLabel#H2 { font-family:"Helvetica"; font-weight:800; font-size:30px; color:#111827; }
QLabel#Subtle { color:#9CA3AF; font-size:16px; }
QLabel#Transc { color:#9CA3AF; font-size:16px; font-style:italic; }
QLabel#Hint { color:#4B5563; font-size:14px; }
QLabel#HintBig{ color:#111827; font-size:14px; font-weight:400; }
QLabel#Stats { color:#6B7280; font-size:13px; }
QPushButton#PrimaryPill { background:#2563EB; color:#FFFFFF; border:none; border-radius:22px; padding:10px 24px; font-weight:700; font-size:16px; }
QPushButton#PrimaryPill:hover { filter:brightness(1.06); }
QPushButton#OutlinePill { background:transparent; color:#2563EB; border:2px solid #2563EB; border-radius:22px; padding:8px 22px; font-weight:700; font-size:16px; }
QPushButton#OutlinePill:hover { background:#F0F5FF; }
QPushButton#YesPill { background:#22C55E; color:#FFFFFF; border:none; border-radius:22px; padding:0 24px; font-weight:700; font-size:16px; }
QPushButton#YesPill:hover { filter:brightness(1.06); }
QPushButton#NoPill { background:#F59E0B; color:#FFFFFF; border:none; border-radius:22px; padding:0 24px; font-weight:700; font-size:16px; }
QPushButton#NoPill:hover { filter:brightness(1.06); }
QPushButton#Arrow { background:#EEF0F4; color:#4B5563; border:none; border-radius:22px; font-size:18px; font-weight:700; }
QPushButton#Arrow:hover { background:#E5E7EB; }
QTextEdit#Card, QTextBrowser#Card { background:#FFFFFF; border:1px solid #E5E7EB; border-radius:16px; padding:16px; }
QTextEdit#Card *, QTextBrowser#Card * { font-family:"Helvetica"; font-size:16px; color:#111827; }
QDialog#NameDialog, QDialog#HelpDialog { background:#F3F4F6; }
QFrame#NameCard { background:#FFFFFF; border:1px solid #E5E7EB; border-radius:16px; }
QLineEdit#NameInput { background:#FFFFFF; border:1px solid #E5E7EB; border-radius:12px; padding:10px 12px; font-size:16px; color:#111827; selection-background-color:#BFDBFE; }
QLineEdit#NameInput:focus { border:1px solid #60A5FA; }
QLineEdit#NameInput[error="true"] { border:1px solid #F43F5E; background:#FEF2F2; }
"""

# ========================= RUN =========================
def main():
    app = QApplication(sys.argv)
    if ICON_FILE.exists():
        app.setWindowIcon(QIcon(str(ICON_FILE)))
    app.setStyleSheet(QSS)

    stats = load_stats(STATS_FILE)
    words = load_all_words()

    current = (stats.get("user_name") or "").strip()
    if not current:
        dlg = NameDialog()
        user_name = dlg.user_name if dlg.exec_() == QDialog.Accepted else "Гость"
        stats["user_name"] = user_name
        save_stats(STATS_FILE, stats)
    else:
        user_name = current

    w = MainWindow(words, stats, user_name)
    w.show()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
