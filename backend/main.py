import os
import glob
import re
import json
import logging
import asyncio
from typing import List, Dict, Any, Optional
from contextlib import asynccontextmanager

import urllib.request
import urllib.error
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
try:
    import pymupdf as fitz
except ImportError:
    try:
        import fitz
    except ImportError:
        fitz = None
from openai import AsyncOpenAI

# -----------------------------------------------------------------------------
# 1. LOGGING VE ORTAM DEĞİŞKENLERİ
# -----------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s"
)
logger = logging.getLogger("oneiro_rag")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "AQ.Ab8RN6JFrUWAiBHz_NBxYykebA8XaAHR1DDN87boRiY6ywrm5g").strip()
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "").strip()
RENDER_EXTERNAL_URL = os.getenv("RENDER_EXTERNAL_URL", "https://oneiro-app.onrender.com").strip()

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
BOOKS_DIR = os.getenv("BOOKS_DIR", os.path.join(BACKEND_DIR, "books"))

# 1. Motor: Google Gemini API (Birincil / Ücretsiz ve Hızlı / 5s Zaman Aşımı)
if GEMINI_API_KEY:
    logger.info("✅ Google Gemini Flash API (Birincil Motor) hazır.")
else:
    logger.warning("⚠️ GEMINI_API_KEY bulunamadı.")

# 2. Motor: DeepSeek Async Client (İkincil / Güçlü Yedek Motor)
deepseek_client: Optional[AsyncOpenAI] = None
if DEEPSEEK_API_KEY:
    deepseek_client = AsyncOpenAI(
        api_key=DEEPSEEK_API_KEY,
        base_url="https://api.deepseek.com"
    )
    logger.info("✅ DeepSeek API Client (Yedek Motor) başarıyla yapılandırıldı.")
else:
    logger.warning("⚠️ DEEPSEEK_API_KEY bulunamadı! Yedek LLM çağrıları yapılamayabilir.")


# -----------------------------------------------------------------------------
# 2. METADATA DESTEKLİ GELENEKLER VE ARAMA MOTORU
# -----------------------------------------------------------------------------
TRADITIONS: Dict[str, Dict[str, str]] = {
    "islam_dogu": {
        "id": "islam_dogu",
        "title": "Doğu ve İslam Geleneği",
        "scholar": "İbn-i Sîrîn & Nablusî",
        "icon": "scroll",
        "accent_color": "#D4AF37"  # Ancient Gold / Amber
    },
    "antik_akdeniz": {
        "id": "antik_akdeniz",
        "title": "Antik Akdeniz Bilgeliği",
        "scholar": "Artemidorus (Oneirocritica)",
        "icon": "temple",
        "accent_color": "#0284C7"  # Mediterranean Azure / Deniz Mavisi
    },
    "psikoloji": {
        "id": "psikoloji",
        "title": "Derinlik Psikolojisi",
        "scholar": "Carl G. Jung & Sigmund Freud",
        "icon": "brain",
        "accent_color": "#6366F1"  # Deep Subconscious Indigo
    }
}

TRADITIONS_I18N: Dict[str, Dict[str, Dict[str, str]]] = {
    "islam_dogu": {
        "tr": {"title": "Doğu ve İslam Geleneği", "scholar": "İbn-i Sîrîn & Nablusî"},
        "en": {"title": "Eastern & Islamic Tradition", "scholar": "Ibn Sirin & Al-Nabulsi"},
        "ru": {"title": "Восточная и Исламская традиция", "scholar": "Ибн Сирин и Ан-Набулси"},
        "de": {"title": "Östliche und Islamische Tradition", "scholar": "Ibn Sirin & Al-Nabulsi"},
        "es": {"title": "Tradición Oriental e Islámica", "scholar": "Ibn Sirin y Al-Nabulsi"},
        "ar": {"title": "التقليد الشرقي والإسلامي", "scholar": "ابن سيرين والنابلسي"},
        "fr": {"title": "Tradition Orientale et Islamique", "scholar": "Ibn Sirin et Al-Nabulsi"}
    },
    "antik_akdeniz": {
        "tr": {"title": "Antik Akdeniz Bilgeliği", "scholar": "Artemidorus (Oneirocritica)"},
        "en": {"title": "Ancient Mediterranean Wisdom", "scholar": "Artemidorus (Oneirocritica)"},
        "ru": {"title": "Античная Средиземноморская Мудрость", "scholar": "Артемидор (Онейрокритика)"},
        "de": {"title": "Antike Weisheit des Mittelmeers", "scholar": "Artemidorus (Oneirocritica)"},
        "es": {"title": "Sabiduría del Mediterráneo Antiguo", "scholar": "Artemidoro (Oneirocrítica)"},
        "ar": {"title": "حكمة البحر الأبيض المتوسط القديمة", "scholar": "أرتيميدوروس (أونيروكريتيكا)"},
        "fr": {"title": "Sagesse Méditerranéenne Antique", "scholar": "Artémidore (Oneirocritica)"}
    },
    "psikoloji": {
        "tr": {"title": "Derinlik Psikolojisi", "scholar": "Carl G. Jung & Sigmund Freud"},
        "en": {"title": "Depth Psychology", "scholar": "Carl G. Jung & Sigmund Freud"},
        "ru": {"title": "Глубинная Психология", "scholar": "Карл Г. Юнг и Зигмунд Фрейд"},
        "de": {"title": "Tiefenpsychologie", "scholar": "Carl G. Jung & Sigmund Freud"},
        "es": {"title": "Psicología Profunda", "scholar": "Carl G. Jung y Sigmund Freud"},
        "ar": {"title": "علم النفس العميق", "scholar": "كارل غ. يونغ وسيغموند فرويد"},
        "fr": {"title": "Psychologie des Profondeurs", "scholar": "Carl G. Jung et Sigmund Freud"}
    }
}


def get_tradition_metadata(tradition_id: str, lang: str = "tr") -> Dict[str, str]:
    """İstenen dilde gelenek başlığı ve bilgin adını döner (tr, en, ru, de, es, ar, fr)."""
    base = TRADITIONS.get(tradition_id, TRADITIONS["islam_dogu"])
    i18n_lang = TRADITIONS_I18N.get(tradition_id, {}).get(lang)
    if not i18n_lang:
        i18n_lang = TRADITIONS_I18N.get(tradition_id, {}).get("en", {
            "title": base["title"],
            "scholar": base["scholar"]
        })
    return {
        "id": tradition_id,
        "title": i18n_lang["title"],
        "scholar": i18n_lang["scholar"],
        "icon": base.get("icon", "scroll"),
        "accent_color": base.get("accent_color", "#D4AF37")
    }


def detect_language(text: str) -> str:
    """Metnin dilini sıfır harici bağımlılıkla ve 0 ms gecikmeyle tespit eder (ru, ar, tr, de, es, fr, en)."""
    if re.search(r"[\u0400-\u04FF]", text):
        return "ru"
    if re.search(r"[\u0600-\u06FF]", text):
        return "ar"
    if re.search(r"[çğıöşüÇĞİÖŞÜ]", text):
        return "tr"

    lower = text.lower()
    words = set(re.findall(r"\b[^\W\d_]{2,}\b", lower, flags=re.UNICODE))

    # Almanca belirteçleri
    if len(words.intersection({"ich", "und", "nicht", "der", "die", "das", "ein", "eine", "mit", "war", "im"})) >= 2:
        return "de"

    # İspanyolca belirteçleri
    if len(words.intersection({"que", "los", "las", "por", "para", "con", "una", "este", "habia", "sueno", "del"})) >= 2:
        return "es"

    # Fransızca belirteçleri
    if len(words.intersection({"les", "des", "dans", "pour", "avec", "une", "est", "reve", "sur"})) >= 2:
        return "fr"

    # İngilizce belirteçleri
    if len(words.intersection({"the", "and", "was", "were", "with", "that", "this", "from", "saw", "dream", "fell"})) >= 2:
        return "en"

    # Türkçe stopwords
    if len(words.intersection({"ve", "bir", "bu", "da", "de", "icin", "ben", "gordum", "ruyada", "kuyu", "yilan"})) >= 1:
        return "tr"

    return "en"


CHUNKS_DB: List[Dict[str, Any]] = []

# Kadim arketipleri Türkçe kitap dizinine bağlayan çok dilli köprü sözlüğü (RU, EN, DE, ES, FR, AR)
CROSS_LINGUAL_SYMBOLS: Dict[str, str] = {
    # YILAN / SNAKE
    "snake": "yilan", "snakes": "yilan", "serpent": "yilan", "serpents": "yilan", "viper": "yilan",
    "змея": "yilan", "змеи": "yilan", "змею": "yilan", "змеей": "yilan", "змей": "yilan", "змее": "yilan", "гадюка": "yilan",
    "schlange": "yilan", "schlangen": "yilan", "natter": "yilan",
    "serpiente": "yilan", "serpientes": "yilan", "vibora": "yilan",
    "couleuvre": "yilan", "vipere": "yilan",
    "ثعبان": "yilan", "افعى": "yilan", "حية": "yilan",

    # KUYU / WELL / PIT
    "well": "kuyu", "wells": "kuyu", "pit": "kuyu", "shaft": "kuyu",
    "колодец": "kuyu", "колодца": "kuyu", "колодце": "kuyu", "колодцем": "kuyu", "яма": "kuyu", "яме": "kuyu",
    "brunnen": "kuyu", "schacht": "kuyu", "pozo": "kuyu", "puits": "kuyu",
    "بئر": "kuyu", "حفرة": "kuyu",

    # SU / NEHİR / GÖL / WATER / RIVER / LAKE
    "water": "su", "waters": "su", "river": "nehir", "lake": "gol", "stream": "su",
    "вода": "su", "воде": "su", "воду": "su", "водой": "su", "река": "nehir", "реке": "nehir", "озеро": "gol", "ручей": "su",
    "wasser": "su", "fluss": "nehir", "see": "gol", "bach": "su",
    "agua": "su", "rio": "nehir", "lago": "gol",
    "eau": "su", "riviere": "nehir", "lac": "gol",
    "ماء": "su", "نهر": "nehir", "بحيرة": "gol",

    # DENİZ / OKYANUS / DALGA / FIRTINA
    "sea": "deniz", "ocean": "deniz", "wave": "dalga", "waves": "dalga", "storm": "firtina", "tempest": "firtina",
    "море": "deniz", "моря": "deniz", "морю": "deniz", "морем": "deniz", "океан": "deniz",
    "волна": "dalga", "волны": "dalga", "буря": "firtina", "шторм": "firtina",
    "meer": "deniz", "ozean": "deniz", "welle": "dalga", "wellen": "dalga", "sturm": "firtina",
    "mar": "deniz", "oceano": "deniz", "ola": "dalga", "olas": "dalga", "tormenta": "firtina",
    "mer": "deniz", "ocean": "deniz", "vague": "dalga", "tempete": "firtina",
    "بحر": "deniz", "محيط": "deniz", "موج": "dalga", "عاصفة": "firtina",

    # UÇMAK / FLY
    "fly": "ucmak", "flying": "ucmak", "flight": "ucmak", "soar": "ucmak", "wings": "kanat", "wing": "kanat",
    "лететь": "ucmak", "летал": "ucmak", "летала": "ucmak", "полет": "ucmak", "лечу": "ucmak", "крылья": "kanat", "крыло": "kanat",
    "fliegen": "ucmak", "flug": "ucmak", "fluegel": "kanat", "flügel": "kanat",
    "volar": "ucmak", "vuelo": "ucmak", "alas": "kanat",
    "voler": "ucmak", "vol": "ucmak", "ailes": "kanat",
    "طيران": "ucmak", "يطير": "ucmak", "جناح": "kanat", "اجنحة": "kanat",

    # DÜŞMEK / UÇURUM / FALL / ABYSS
    "fall": "dusmek", "falling": "dusmek", "fell": "dusmek", "cliff": "ucurum", "abyss": "ucurum", "precipice": "ucurum",
    "падать": "dusmek", "падал": "dusmek", "падала": "dusmek", "падение": "dusmek", "упал": "dusmek",
    "обрыв": "ucurum", "пропасть": "ucurum", "бездна": "ucurum",
    "fallen": "dusmek", "fiel": "dusmek", "abgrund": "ucurum",
    "caer": "dusmek", "caida": "dusmek", "abismo": "ucurum",
    "tomber": "dusmek", "chute": "dusmek", "gouffre": "ucurum",
    "سقوط": "dusmek", "يسقط": "dusmek", "هاوية": "ucurum", "جرف": "ucurum",

    # BOĞULMAK / DROWN
    "drown": "bogulmak", "drowning": "bogulmak", "sink": "bogulmak", "sinking": "bogulmak",
    "тонуть": "bogulmak", "утонул": "bogulmak", "захлебнуться": "bogulmak",
    "ertrinken": "bogulmak", "versinken": "bogulmak",
    "ahogarse": "bogulmak", "hundirse": "bogulmak",
    "se noyer": "bogulmak", "couler": "bogulmak",
    "غرق": "bogulmak", "يغرق": "bogulmak",

    # KAPI / ANAHTAR / DOOR / KEY
    "door": "kapi", "doors": "kapi", "gate": "kapi", "gates": "kapi", "portal": "kapi",
    "key": "anahtar", "keys": "anahtar",
    "дверь": "kapi", "двери": "kapi", "дверью": "kapi", "ворота": "kapi",
    "ключ": "anahtar", "ключи": "anahtar", "ключом": "anahtar",
    "tur": "kapi", "tuer": "kapi", "tor": "kapi", "schluessel": "anahtar", "schlüssel": "anahtar",
    "puerta": "kapi", "puertas": "kapi", "porton": "kapi", "llave": "anahtar", "llaves": "anahtar",
    "porte": "kapi", "portail": "kapi", "cle": "anahtar", "clef": "anahtar",
    "باب": "kapi", "بوابة": "kapi", "مفتاح": "anahtar",

    # KARTAL / KUŞ / EAGLE / BIRD
    "eagle": "kartal", "eagles": "kartal", "bird": "kus", "birds": "kus",
    "орел": "kartal", "орла": "kartal", "птица": "kus", "птицы": "kus", "птицу": "kus",
    "adler": "kartal", "vogel": "kus", "voegel": "kus",
    "aguila": "kartal", "pajaro": "kus", "ave": "kus",
    "aigle": "kartal", "oiseau": "kus",
    "نسر": "kartal", "طائر": "kus", "طيور": "kus",

    # AYNA / LABİRENT / MIRROR / LABYRINTH
    "mirror": "ayna", "mirrors": "ayna", "labyrinth": "labirent", "maze": "labirent",
    "зеркало": "ayna", "зеркале": "ayna", "лабиринт": "labirent",
    "spiegel": "ayna", "espejo": "ayna", "laberinto": "labirent",
    "miroir": "ayna", "labyrinthe": "labirent",
    "مرآة": "ayna", "متاهة": "labirent",

    # EV / ODA / MERDİVEN / HOUSE / ROOM / STAIRS
    "house": "ev", "home": "ev", "room": "oda", "rooms": "oda", "stairs": "merdiven", "staircase": "merdiven",
    "дом": "ev", "доме": "ev", "комната": "oda", "комнате": "oda", "лестница": "merdiven",
    "haus": "ev", "zimmer": "oda", "treppe": "merdiven",
    "casa": "ev", "habitacion": "oda", "escalera": "merdiven",
    "maison": "ev", "chambre": "oda", "escalier": "merdiven",
    "منزل": "ev", "بيت": "ev", "غرفة": "oda", "درج": "merdiven",

    # GÖLGE / KARANLIK / IŞIK / SHADOW / DARK / LIGHT
    "shadow": "golge", "shadows": "golge", "shade": "golge",
    "dark": "karanlik", "darkness": "karanlik", "gloom": "karanlik", "black": "kara",
    "light": "isik", "beam": "isik", "ray": "isik",
    "тень": "golge", "тени": "golge", "тьма": "karanlik", "темный": "karanlik", "темнота": "karanlik", "мрак": "karanlik", "свет": "isik",
    "schatten": "golge", "dunkel": "karanlik", "dunkelheit": "karanlik", "licht": "isik",
    "sombra": "golge", "sombras": "golge", "oscuridad": "karanlik", "oscuro": "karanlik", "luz": "isik",
    "ombre": "golge", "obscurite": "karanlik", "sombre": "karanlik", "lumiere": "isik",
    "ظل": "golge", "ظلال": "golge", "ظلام": "karanlik", "نور": "isik", "ضوء": "isik",

    # ATEŞ / GÜNEŞ / AY / YILDIZ
    "fire": "ates", "flame": "ates", "sun": "gunes", "moon": "ay", "star": "yildiz", "stars": "yildiz",
    "огонь": "ates", "пламя": "ates", "солнце": "gunes", "луна": "ay", "звезда": "yildiz", "звезды": "yildiz",
    "feuer": "ates", "flamme": "ates", "sonne": "gunes", "mond": "ay", "stern": "yildiz", "sterne": "yildiz",
    "fuego": "ates", "llama": "ates", "sol": "gunes", "luna": "ay", "estrella": "yildiz",
    "feu": "ates", "flamme": "ates", "soleil": "gunes", "lune": "ay", "etoile": "yildiz",
    "نار": "ates", "لهب": "ates", "شمس": "gunes", "قمر": "ay", "نجم": "yildiz", "نجوم": "yildiz",

    # DİŞ / KAN / TEETH / BLOOD
    "teeth": "dis", "tooth": "dis", "blood": "kan", "bleeding": "kan",
    "зуб": "dis", "зубы": "dis", "кровь": "kan",
    "zahn": "dis", "zaehne": "dis", "zähne": "dis", "blut": "kan",
    "diente": "dis", "dientes": "dis", "sangre": "kan",
    "dent": "dis", "dents": "dis", "sang": "kan",
    "سن": "dis", "أسنان": "dis", "دم": "kan",

    # ÖLÜM / MEZAR / DEATH / GRAVE
    "death": "olum", "dead": "olu", "grave": "mezar", "cemetery": "mezar", "tomb": "mezar",
    "смерть": "olum", "мертвый": "olu", "мертвая": "olu", "могила": "mezar", "кладбище": "mezar",
    "tod": "olum", "tot": "olu", "grab": "mezar", "friedhof": "mezar",
    "muerte": "olum", "muerto": "olu", "tumba": "mezar", "cementerio": "mezar",
    "mort": "olum", "tombe": "mezar", "cimetiere": "mezar",
    "موت": "olum", "ميت": "olu", "قبر": "mezar", "مقبرة": "mezar",

    # ASLAN / KURT / KÖPEK / KEDİ / AT
    "lion": "aslan", "wolf": "kurt", "dog": "kopek", "hound": "kopek", "cat": "kedi", "horse": "at",
    "лев": "aslan", "волк": "kurt", "собака": "kopek", "пес": "kopek", "кошка": "kedi", "кот": "kedi", "лошадь": "at", "конь": "at",
    "loewe": "aslan", "löwe": "aslan", "wolf": "kurt", "hund": "kopek", "katze": "kedi", "pferd": "at",
    "leon": "aslan", "lobo": "kurt", "perro": "kopek", "gato": "kedi", "caballo": "at",
    "lion": "aslan", "loup": "kurt", "chien": "kopek", "chat": "kedi", "cheval": "at",
    "اسد": "aslan", "ذئب": "kurt", "كلب": "kopek", "قطة": "kedi", "حصان": "at",

    # ALTIN / PARA / HAZİNE / YÜZÜK
    "gold": "altin", "golden": "altin", "money": "para", "treasure": "hazine", "ring": "yuzuk",
    "золото": "altin", "золотой": "altin", "деньги": "para", "сокровище": "hazine", "клад": "hazine", "кольцо": "yuzuk",
    "gold": "altin", "geld": "para", "schatz": "hazine", "ring": "yuzuk",
    "oro": "altin", "dinero": "para", "tesoro": "hazine", "anillo": "yuzuk",
    "or": "altin", "argent": "para", "tresor": "hazine", "bague": "yuzuk",
    "ذهب": "altin", "مال": "para", "كنز": "hazine", "خاتم": "yuzuk",

    # TAPINAK / SUNAK / RAHİP
    "temple": "tapinak", "altar": "sunak", "priest": "rahip", "church": "tapinak",
    "храм": "tapinak", "алтарь": "sunak", "жрец": "rahip", "священник": "rahip", "церковь": "tapinak",
    "tempel": "tapinak", "altar": "sunak", "priester": "rahip", "kirche": "tapinak",
    "templo": "tapinak", "altar": "sunak", "sacerdote": "rahip", "iglesia": "tapinak",
    "temple": "tapinak", "autel": "sunak", "pretre": "rahip", "eglise": "tapinak",
    "معبد": "tapinak", "مذبح": "sunak", "كاهن": "rahip", "كنيسة": "tapinak"
}

MULTILINGUAL_STOPWORDS = {
    # Türkçe
    "ve", "ile", "bu", "şu", "o", "bir", "de", "da", "ki", "için", "gibi", "kadar",
    "daha", "çok", "en", "ama", "fakat", "ancak", "çünkü", "mi", "mı", "mu", "mü",
    "ben", "sen", "biz", "siz", "onlar", "bana", "beni", "sana", "seni", "ona", "onu",
    "bize", "bizi", "size", "sizi", "onlara", "onları", "onlari", "bizim", "sizin", "onların", "onlarin",
    "kendimi", "kendini", "kendisi", "kendimize", "kendinizi", "kendilerini",
    "böyle", "boyle", "şöyle", "soyle", "öyle", "oyle", "her", "şey", "sey", "şeyler", "seyler",
    "tüm", "tum", "bütün", "butun", "bazı", "bazi", "biri", "birisi",
    "diye", "bunu", "buna", "bunun", "şunu", "sunu", "şuna", "suna", "şunun", "sunun",
    "olan", "olmak", "eden", "etmek", "vardı", "vardi", "yoktu", "oldu", "olmuş", "olmus", "olacak",
    "ayrıca", "ayrica", "birden", "aniden", "artık", "artik", "şimdi", "simdi",
    "rüyada", "ruyada", "rüyamda", "ruyamda", "rüya", "ruya", "rüyam", "ruyam",
    "gördüm", "gordum", "görüyorum", "goruyorum", "görmek", "gormek",
    "dün", "dun", "gece", "sabah", "sonra", "önce", "once",
    "baktım", "baktim", "gittim", "geldim", "vardım", "vardim", "çıktım", "ciktim",
    "yerde", "yere", "zaman", "bazen",

    # English
    "the", "and", "was", "were", "had", "have", "with", "for", "that", "this", "there",
    "from", "into", "over", "about", "dream", "dreamt", "saw", "seeing", "been", "myself",
    "they", "their", "them", "what", "which", "when", "where", "then", "just", "some",

    # Russian
    "что", "это", "как", "был", "была", "было", "были", "мне", "меня", "его", "для",
    "или", "если", "тоже", "только", "когда", "где", "куда", "здесь", "сон", "сне",
    "видел", "видела", "приснилось", "потом", "очень", "себя", "свой", "своем", "своей",

    # German
    "der", "die", "das", "ein", "eine", "einer", "einem", "einen", "und", "mit", "für",
    "auf", "aus", "von", "nach", "über", "war", "waren", "hatte", "hatten", "traum", "traumte",
    "ich", "mich", "mir", "wir", "uns", "sie", "ihr", "nicht", "auch", "dann",

    # Spanish
    "que", "los", "las", "una", "uno", "unas", "unos", "por", "para", "con", "sin",
    "sobre", "este", "esta", "estaba", "habia", "sueno", "sone", "vi", "veia", "pero",

    # French
    "les", "des", "dans", "pour", "avec", "une", "est", "etait", "reve", "reveur", "j'ai",

    # Arabic
    "في", "من", "على", "إلى", "الى", "عن", "مع", "هذا", "هذه", "كان", "كانت", "حلم", "حلمت", "رايت", "رأيت"
}


def normalize_turkish(text: str) -> str:
    """Türkçe karakterleri küçük harfe ve arama standardına dönüştürür."""
    t = text.lower()
    mapping = {
        "ı": "i", "İ": "i", "I": "i",
        "ğ": "g", "Ğ": "g",
        "ü": "u", "Ü": "u",
        "ş": "s", "Ş": "s",
        "ö": "o", "Ö": "o",
        "ç": "c", "Ç": "c"
    }
    for k, v in mapping.items():
        t = t.replace(k, v)
    return t


def extract_keywords(text: str) -> List[str]:
    """
    Çok dilli rüya metnindeki sembolleri ayıklar.
    Yabancı dildeki (Rusça, İngilizce, Almanca vb.) sembolleri
    CROSS_LINGUAL_SYMBOLS köprüsü ile Türkçeleştirip kitap aramasına hazır hale getirir.
    """
    clean_text = text.lower()
    norm = normalize_turkish(clean_text)
    words = re.findall(r"\b[^\W\d_]{3,}\b", norm, flags=re.UNICODE)

    meaningful: List[str] = []
    mapped_symbols: List[str] = []

    for w in words:
        if w in MULTILINGUAL_STOPWORDS:
            continue
        meaningful.append(w)
        if w in CROSS_LINGUAL_SYMBOLS:
            tr_sym = CROSS_LINGUAL_SYMBOLS[w]
            if tr_sym not in mapped_symbols:
                mapped_symbols.append(tr_sym)

    # Önce Türkçe RAG indeksine denk gelen kadim sembol kökleri, sonra kullanıcının özgün kelimeleri
    combined = mapped_symbols + [w for w in meaningful if w not in mapped_symbols]
    return combined if combined else words


def extract_user_symbols(text: str, lang: str = "tr") -> List[str]:
    """Kullanıcının kendi dilinde arayüzde gösterilecek 3-4 anahtar sembolü ayıklar."""
    words = re.findall(r"\b[^\W\d_]{3,}\b", text.lower(), flags=re.UNICODE)
    meaningful = [w.capitalize() for w in words if w not in MULTILINGUAL_STOPWORDS]

    # Varsa en belirgin kelimeleri seç
    if meaningful:
        # Tekrarları temizle sırayı koru
        seen = set()
        unique = []
        for w in meaningful:
            if w not in seen:
                seen.add(w)
                unique.append(w)
        if unique:
            return unique[:4]

    # Dil bazlı mistik varsayılanlar
    defaults: Dict[str, List[str]] = {
        "ru": ["Мистический Порог", "Темная Вода", "Золотой Свет"],
        "en": ["Mystic Threshold", "Dark Waters", "Golden Light"],
        "de": ["Mystische Schwelle", "Dunkles Wasser", "Goldenes Licht"],
        "es": ["Umbral Místico", "Aguas Oscuras", "Luz Dorada"],
        "ar": ["العتبة الصوفية", "الماء المظلم", "الضوء الذهبي"],
        "fr": ["Seuil Mystique", "Eau Sombre", "Lumière Dorée"],
        "tr": ["Mistik Eşik", "Karanlık Su", "Altın Işık"]
    }
    return defaults.get(lang, defaults["tr"])


def detect_tradition_id(filename: str) -> str:
    """Dosya adından geleneği (islam_dogu, antik_akdeniz, psikoloji) otomatik belirler."""
    fn = filename.lower()
    if any(k in fn for k in ("islam", "sirin", "nablusi", "dogu")):
        return "islam_dogu"
    if any(k in fn for k in ("antik", "yunan", "artemidorus", "oneirocritica", "roma", "akdeniz")):
        return "antik_akdeniz"
    if any(k in fn for k in ("psik", "jung", "freud", "arketip", "bilinc")):
        return "psikoloji"
    return "islam_dogu"


# -----------------------------------------------------------------------------
# 3. KİTAPLARI OKUMA VE METADATA İLE PARÇALAMA (CHUNKING)
# -----------------------------------------------------------------------------
def read_text_file(filepath: str) -> str:
    """Metin dosyasını Türkçe karakter güvenliğiyle okur."""
    for encoding in ("utf-8", "utf-8-sig", "windows-1254", "iso-8859-9", "latin-1"):
        try:
            with open(filepath, "r", encoding=encoding) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    with open(filepath, "r", errors="ignore") as f:
        return f.read()


def read_pdf_file(filepath: str) -> str:
    """PyMuPDF ile PDF dosyasını C hızında okur."""
    if fitz is None:
        logger.warning(f"PyMuPDF kütüphanesi yüklü değil, '{filepath}' okunamadı.")
        return ""
    text_content = []
    try:
        with fitz.open(filepath) as doc:
            for page in doc:
                text_content.append(page.get_text())
        return "\n\n".join(text_content)
    except Exception as e:
        logger.error(f"PDF okunurken hata oluştu ({filepath}): {e}")
        return ""


def chunk_text(text: str, source_name: str) -> List[Dict[str, Any]]:
    """Metni anlamlı paragraflara böler, kelime kümesini indeksler ve gelenek etiketi ekler."""
    tradition_id = detect_tradition_id(source_name)
    raw_paragraphs = text.split("\n\n")
    chunks = []

    for p in raw_paragraphs:
        cleaned = " ".join(p.split()).strip()
        if len(cleaned) >= 35:
            norm = normalize_turkish(cleaned)
            words_list = re.findall(r"\b[^\W\d_]{3,}\b", norm, flags=re.UNICODE)
            chunks.append({
                "text": cleaned,
                "source": source_name,
                "tradition": tradition_id,
                "tradition_title": TRADITIONS[tradition_id]["title"],
                "norm": norm,
                "words": set(words_list),
                "is_substantive": len(cleaned) >= 90
            })

    return chunks


def index_books():
    """`backend/books/` klasöründeki kitapları okur ve gelenek metadata'sı ile belleğe alır."""
    global CHUNKS_DB

    if not os.path.exists(BOOKS_DIR):
        os.makedirs(BOOKS_DIR, exist_ok=True)
        logger.warning(f"'{BOOKS_DIR}' klasörü mevcut değildi, yeni oluşturuldu.")

    book_files = glob.glob(os.path.join(BOOKS_DIR, "*.*"))
    supported_files = [f for f in book_files if f.lower().endswith((".txt", ".pdf"))]

    if not supported_files:
        logger.warning(f"'{BOOKS_DIR}' klasöründe .txt veya .pdf kitap bulunamadı.")
        return

    logger.info(f"İndekslenecek {len(supported_files)} adet kitap bulundu: {[os.path.basename(f) for f in supported_files]}")

    all_chunks: List[Dict[str, Any]] = []

    for filepath in supported_files:
        filename = os.path.basename(filepath)
        content = ""
        if filepath.lower().endswith(".txt"):
            content = read_text_file(filepath)
        elif filepath.lower().endswith(".pdf"):
            content = read_pdf_file(filepath)

        if content:
            file_chunks = chunk_text(content, filename)
            all_chunks.extend(file_chunks)
            logger.info(f"'{filename}' ({detect_tradition_id(filename)}) dosyasından {len(file_chunks)} paragraf çıkarıldı.")

    if not all_chunks:
        logger.warning("Kitaplardan ayrıştırılabilir anlamlı metin parçası çıkarılamadı.")
        return

    CHUNKS_DB = all_chunks
    logger.info(f"✅ Toplam {len(CHUNKS_DB)} paragraf metadata ile arama belleğine yüklendi.")


def _sync_http_ping(url: str, timeout: float = 10.0) -> bool:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Oneiro-KeepAlive/2.2"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status == 200
    except Exception:
        return False


async def render_keep_alive_task():
    """
    Render Free Tier 15 dakika hareketsiz kalırsa uyur (cold-start gecikmesi yaşanır).
    Bu arka plan görevi her 10 dakikada (600 sn) bir sunucuya ping atarak Render'ı 7/24 uyanık tutar.
    """
    await asyncio.sleep(45)  # Sunucu başladıktan 45 saniye sonra ilk ping döngüsünü başlat
    target_url = RENDER_EXTERNAL_URL.rstrip("/") + "/health"
    logger.info(f"🔄 Render Keep-Alive arka plan görevi aktif (Hedef: {target_url}, Aralık: 10 dk)")

    while True:
        try:
            await asyncio.sleep(600)  # 10 dakika bekle
            is_ok = await asyncio.to_thread(_sync_http_ping, target_url, 10.0)
            if is_ok:
                logger.info("💓 [Render Keep-Alive] Ping başarılı: Render sunucusu aktif tutuldu.")
            else:
                logger.warning("⚠️ [Render Keep-Alive] Ping yanıt vermedi veya zaman aşımına uğradı.")
        except asyncio.CancelledError:
            logger.info("Render Keep-Alive görevi sonlandırıldı.")
            break
        except Exception as e:
            logger.debug(f"[Render Keep-Alive] Ping uyarısı: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Oneiro RAG Backend başlatılıyor...")
    index_books()
    # Render Keep-Alive arka plan ping görevini başlat
    keep_alive_job = asyncio.create_task(render_keep_alive_task())
    yield
    keep_alive_job.cancel()
    logger.info("Oneiro RAG Backend kapatılıyor...")


# -----------------------------------------------------------------------------
# 4. FASTAPI UYGULAMASI VE CORS TANIMLARI
# -----------------------------------------------------------------------------
app = FastAPI(
    title="Oneiro RAG Backend (DeepSeek + Hybrid Freemium)",
    description="Teaser Tabanlı, Yüksek Hızlı ve Düşük Token Maliyetli Mistik Rüya Tabiri Servisi",
    version="2.1.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# -----------------------------------------------------------------------------
# 5. PYDANTIC VERİ MODELLERİ
# -----------------------------------------------------------------------------
class SourceUsedItem(BaseModel):
    source: str = Field(..., description="Pasajın ait olduğu kitap dosya adı")
    tradition: str = Field(..., description="Gelenek kimliği (islam_dogu, antik_akdeniz, psikoloji)")
    excerpt: str = Field(..., description="Rüyayla eşleşen kitap alıntısı")
    relevance_score: float = Field(..., description="Alaka skoru")


class FreeAnalysis(BaseModel):
    bilincalti_aynasi: str = Field(..., description="Rüyanın taşıdığı temel his ve arketipsel atmosfer")
    gunun_pusulasi: str = Field(..., description="Günün tek ve vurucu bilgelik notu")


class TraditionAnalysisItem(BaseModel):
    tradition_id: str = Field(..., description="Gelenek ID (islam_dogu, antik_akdeniz, psikoloji)")
    title: str = Field(..., description="Gelenek Başlığı")
    scholar: str = Field(..., description="Temsil edilen kadim bilge/ekol")
    teaser: Optional[str] = Field(None, description="Merak Fısıltısı (kilitli gelenekler için 1 cümlelik çarpıcı özet)")
    interpretation: Optional[str] = Field(None, description="Açılmış tam kadim yorum metni")
    is_unlocked: bool = Field(False, description="Kilidin açık olup olmadığı")


class DreamInterpretRequest(BaseModel):
    dream_text: str = Field(..., min_length=3, description="Kullanıcının rüya metni")
    preferred_tradition: Optional[str] = Field("islam_dogu", description="İlk analizde ücretsiz açılacak gelenek")
    user_id: Optional[str] = Field(None, description="Kullanıcı Firebase UID (opsiyonel)")


class DreamInterpretResponse(BaseModel):
    # Geriye dönük uyumluluk alanları:
    interpretation: str = Field(..., description="Özet/bütüncül kadim tabir metni")
    subconscious_analysis: str = Field(..., description="Bilinçaltı aynası metni")
    warning_of_day: str = Field(..., description="Günün pusulası metni")
    symbols: List[str] = Field(default_factory=list, description="Çıkarılan anahtar semboller")

    # Yeni Teaser & Freemium Yapısı:
    free_analysis: FreeAnalysis = Field(..., description="Bilinçaltı Aynası ve Günün Pusulası")
    primary_tradition: TraditionAnalysisItem = Field(..., description="Ücretsiz açılan ana kadim gelenek")
    locked_traditions: List[TraditionAnalysisItem] = Field(default_factory=list, description="Kilitli merak fısıltıları")
    sources_used: List[SourceUsedItem] = Field(default_factory=list, description="Kullanılan referans kitap pasajları")


class UnlockTraditionRequest(BaseModel):
    dream_text: str = Field(..., min_length=3, description="Rüya metni")
    tradition_id: str = Field(..., description="Açılmak istenen gelenek ID'si (antik_akdeniz, psikoloji vb.)")
    user_id: Optional[str] = Field(None, description="Kullanıcı Firebase UID (opsiyonel)")


class UnlockTraditionResponse(BaseModel):
    tradition_id: str
    title: str
    scholar: str
    interpretation: str
    sources_used: List[SourceUsedItem] = Field(default_factory=list)


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, description="Kullanıcının tabirciye ilettiği soru metni")
    system_context: Optional[str] = Field(None, description="Rüya ve önceki tabir bağlamı")
    history: Optional[List[Dict[str, Any]]] = Field(default_factory=list, description="Geçmiş sohbet mesajları")
    user_id: Optional[str] = Field(None, description="Kullanıcı Firebase UID (opsiyonel)")


class ChatResponse(BaseModel):
    reply: str = Field(..., description="Kadim rüyabilimcinin ürettiği bilgece cevap")


# -----------------------------------------------------------------------------
# 6. GELİŞMİŞ TÜRKÇE RAG RETRIEVAL & BOŞ EŞLEŞME GÜVENLİK KATMANI
# -----------------------------------------------------------------------------
def score_passage_relevance(dream_keywords: List[str], chunk: Dict[str, Any]) -> float:
    """
    Rüyadan gelen anahtar kelimeler ile kitap paragrafı arasındaki anlamsal alakayı hesaplar.
    
    1. Tam Kelime Eşleşmesi (Exact word match) -> 4.0 puan
    2. İki Yönlü Kök/Ek Toleransı (Substring / In-Word Match):
       - Kitap kökünün rüya kelimesi içinde geçmesi (örn: rüya: "kuyudaydim", kitap: "kuyu") -> 2.5 - 3.8 puan
       - Rüya kökünün kitap türevi içinde geçmesi (örn: rüya: "deniz", kitap: "denizlerde") -> 2.2 - 3.4 puan
    3. Ortak Ön Ek (Common Prefix >= 3 harf):
       - Ortak harf >= 4 (örn: "merdiven" / "merdivenlerden") -> 1.8 - 2.8 puan
       - Ortak harf == 3 (kısa kökler) -> 1.0 puan
    4. Cümle / Paragraf İçi Geçiş (norm substring) -> 2.0 puan
    """
    if not dream_keywords:
        return 0.0

    chunk_norm = chunk.get("norm", "")
    chunk_words = chunk.get("words", set())
    if not chunk_words and chunk_norm:
        chunk_words = set(re.findall(r"\b[^\W\d_]{3,}\b", chunk_norm, flags=re.UNICODE))

    total_score = 0.0
    matched_keywords_count = 0

    for kw in dream_keywords:
        kw_len = len(kw)
        if kw_len < 3:
            continue

        best_kw_score = 0.0

        # A) Tam Kelime Eşleşmesi
        if kw in chunk_words:
            best_kw_score = 4.0
        else:
            # B) İki yönlü substring ve kök/ek toleransı
            for bw in chunk_words:
                bw_len = len(bw)
                if bw_len < 3:
                    continue

                if bw == kw:
                    best_kw_score = 4.0
                    break

                # 1. Kitap kök kelimesi rüya kelimesinin içinde geçiyor mu?
                # Örn: kw = "yilanlardan", bw = "yilan" -> "yilan" in "yilanlardan"
                # Örn: kw = "kuyudaydim", bw = "kuyu" -> "kuyu" in "kuyudaydim"
                if bw in kw:
                    ratio = bw_len / kw_len
                    candidate = 2.4 + (ratio * 1.4)
                    if candidate > best_kw_score:
                        best_kw_score = candidate

                # 2. Rüya kelimesi kitap kelimesinin içinde geçiyor mu?
                # Örn: kw = "deniz", bw = "denizlerde" -> "deniz" in "denizlerde"
                elif kw in bw:
                    ratio = kw_len / bw_len
                    candidate = 2.2 + (ratio * 1.2)
                    if candidate > best_kw_score:
                        best_kw_score = candidate

                # 3. Ortak Ön Ek (Common Prefix toleransı)
                else:
                    common_len = 0
                    min_len = min(kw_len, bw_len)
                    while common_len < min_len and kw[common_len] == bw[common_len]:
                        common_len += 1

                    if common_len >= 4:
                        prefix_score = 1.6 + (common_len * 0.15)
                        if prefix_score > best_kw_score:
                            best_kw_score = prefix_score
                    elif common_len == 3 and min_len <= 5:
                        if 1.0 > best_kw_score:
                            best_kw_score = 1.0

            # C) Paragraf metni içinde doğrudan alt dize olarak geçme kontrolü
            if best_kw_score < 2.0 and kw in chunk_norm:
                best_kw_score = 2.0

        if best_kw_score > 0:
            total_score += best_kw_score
            matched_keywords_count += 1

    if matched_keywords_count == 0:
        return 0.0

    normalized_score = min(0.99, max(0.25, (total_score / (len(dream_keywords) * 3.0))))
    if matched_keywords_count >= 2:
        normalized_score = min(0.99, normalized_score + 0.10)

    return round(normalized_score, 4)


def retrieve_by_tradition(dream_text: str, tradition_id: str, top_k: int = 1) -> List[Dict[str, Any]]:
    """
    Belirli bir geleneğe ait en alakalı kitap pasajını / pasajlarını getirir.
    Gelişmiş Türkçe kök, ek ve alt dize toleransı ile çalışır.
    
    BOŞ EŞLEŞME GÜVENLİK KATMANI:
    Eğer rüyadaki kelimeler kitapta doğrudan geçmiyorsa veya nadir bir kelimeyse,
    o geleneğin en zengin ve temsili 2 genel pasajını DeepSeek'e bağlam olarak iletir.
    """
    tradition_chunks = [c for c in CHUNKS_DB if c.get("tradition") == tradition_id]
    if not tradition_chunks:
        logger.warning(f"'{tradition_id}' geleneğine ait indekslenmiş pasaj bulunamadı.")
        return []

    keywords = extract_keywords(dream_text)
    scored: List[Dict[str, Any]] = []

    if keywords:
        for c in tradition_chunks:
            rel_score = score_passage_relevance(keywords, c)
            if rel_score > 0:
                scored.append({"chunk": c, "score": rel_score, "is_fallback": False})

        scored.sort(key=lambda x: x["score"], reverse=True)

    # 1. Eşleşme bulunduysa en iyileri dön
    if scored:
        return scored[:top_k]

    # 2. BOŞ EŞLEŞME GÜVENLİK KATMANI:
    # Rüyada geçen kelimeler doğrudan eşleşmediğinde arama motoru boş kalmaz.
    # O geleneğin en zengin, içerikli ve temsili 2 pasajını seçer.
    logger.info(f"'{tradition_id}' geleneğinde doğrudan kelime eşleşmesi bulunamadı. Temsili 2 pasaj devreye alınıyor.")
    substantive_chunks = [c for c in tradition_chunks if c.get("is_substantive", len(c.get("text", "")) >= 90)]
    fallback_pool = substantive_chunks if len(substantive_chunks) >= 2 else tradition_chunks

    sorted_by_depth = sorted(fallback_pool, key=lambda x: len(x.get("text", "")), reverse=True)
    fallback_chunks = sorted_by_depth[:max(top_k, 2)]

    return [{"chunk": c, "score": 0.45, "is_fallback": True} for c in fallback_chunks[:top_k]]


def retrieve_top_k(dream_text: str, top_k: int = 3, tradition_id: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Tüm kitaplar (veya opsiyonel olarak tek bir gelenek) arasından
    en alakalı 'top_k' pasajı gelişmiş Türkçe hassasiyetiyle getirir.
    Boş eşleşme durumunda genel temsili pasajları güvenlik katmanı olarak sunar.
    """
    target_chunks = CHUNKS_DB
    if tradition_id:
        target_chunks = [c for c in CHUNKS_DB if c.get("tradition") == tradition_id]

    if not target_chunks:
        return []

    keywords = extract_keywords(dream_text)
    scored: List[Dict[str, Any]] = []

    if keywords:
        for c in target_chunks:
            rel_score = score_passage_relevance(keywords, c)
            if rel_score > 0:
                scored.append({"chunk": c, "score": rel_score, "is_fallback": False})

        scored.sort(key=lambda x: x["score"], reverse=True)

    if scored:
        return scored[:top_k]

    # Güvenlik Katmanı: En zengin 2 temsili pasajı dön
    substantive = [c for c in target_chunks if c.get("is_substantive", len(c.get("text", "")) >= 90)]
    fallback_pool = substantive if len(substantive) >= 2 else target_chunks
    sorted_by_depth = sorted(fallback_pool, key=lambda x: len(x.get("text", "")), reverse=True)
    fallback_chunks = sorted_by_depth[:max(top_k, 2)]

    return [{"chunk": c, "score": 0.45, "is_fallback": True} for c in fallback_chunks[:top_k]]


# -----------------------------------------------------------------------------
# 6.5. ÇİFT MOTORLU YAPAY ZEKA STRATEJİSİ (GOOGLE GEMINI FLASH + DEEPSEEK YEDEK)
# -----------------------------------------------------------------------------
def _sync_gemini_post(url: str, payload: dict, timeout: float = 5.0) -> Optional[dict]:
    try:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status == 200:
                body = resp.read().decode("utf-8")
                return json.loads(body)
    except Exception as e:
        logger.warning(f"Google Gemini isteği uyarısı: {e}")
    return None


async def call_gemini_json(system_prompt: str, user_prompt: str, timeout: float = 5.0) -> Optional[Dict[str, Any]]:
    """Google Gemini API'yi (gemini-flash-latest) 5 saniye zaman aşımı ile çağırır ve JSON çıktısını döner."""
    if not GEMINI_API_KEY:
        return None
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key={GEMINI_API_KEY}"
    payload = {
        "contents": [
            {
                "parts": [
                    {"text": f"SİSTEM TALİMATI:\n{system_prompt}\n\nKULLANICI TALEBİ:\n{user_prompt}"}
                ]
            }
        ],
        "generationConfig": {
            "responseMimeType": "application/json",
            "temperature": 0.7,
            "maxOutputTokens": 1500
        }
    }
    data = await asyncio.to_thread(_sync_gemini_post, url, payload, timeout)
    if data:
        candidates = data.get("candidates", [])
        if candidates:
            raw_text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
            if raw_text:
                return json.loads(raw_text)
    return None


async def call_gemini_text(system_prompt: str, user_prompt: str, timeout: float = 5.0) -> Optional[str]:
    """Google Gemini API'yi (gemini-flash-latest) 5 saniye zaman aşımı ile çağırır ve metin döner."""
    if not GEMINI_API_KEY:
        return None
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key={GEMINI_API_KEY}"
    payload = {
        "contents": [
            {
                "parts": [
                    {"text": f"SİSTEM TALİMATI:\n{system_prompt}\n\nKULLANICI TALEBİ:\n{user_prompt}"}
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 1200
        }
    }
    data = await asyncio.to_thread(_sync_gemini_post, url, payload, timeout)
    if data:
        candidates = data.get("candidates", [])
        if candidates:
            text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
            if text:
                return text.strip()
    return None


async def call_gemini_chat(contents: List[Dict[str, Any]], timeout: float = 5.0) -> Optional[str]:
    """Google Gemini API ile sohbet yanıtı üretir (5 saniye limitli)."""
    if not GEMINI_API_KEY:
        return None
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key={GEMINI_API_KEY}"
    payload = {
        "contents": contents,
        "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 1200
        }
    }
    data = await asyncio.to_thread(_sync_gemini_post, url, payload, timeout)
    if data:
        candidates = data.get("candidates", [])
        if candidates:
            parts = candidates[0].get("content", {}).get("parts", [])
            if parts:
                text = parts[0].get("text", "")
                if text:
                    return text.strip()
    return None


async def generate_dream_interpretation(system_prompt: str, user_prompt: str) -> Dict[str, Any]:
    """
    Hibrit Çift Motor Stratejisi:
    1. Öncelikli olarak Google Gemini (Ücretsiz) çağrılır (maksimum 5.0 saniye beklenir).
    2. 5 saniyeyi aşarsa veya hata verirse otomatik olarak DeepSeek API devreye girer.
    """
    # 1. Motor: Google Gemini (Ücretsiz, 5 saniye limitli)
    if GEMINI_API_KEY:
        try:
            logger.info("⚡ [1/2] Google Gemini Flash API çağrılıyor (Zaman aşımı: 5.0s)...")
            gemini_res = await asyncio.wait_for(
                call_gemini_json(system_prompt, user_prompt, timeout=5.0),
                timeout=5.2
            )
            if gemini_res and isinstance(gemini_res, dict):
                logger.info("✅ Google Gemini 5 saniye içinde başarıyla yanıt üretti.")
                return gemini_res
        except asyncio.TimeoutError:
            logger.warning("⏱️ Google Gemini 5 saniye sınırını aştı! DeepSeek yedek motoruna geçiliyor...")
        except Exception as e:
            logger.warning(f"⚠️ Google Gemini çağrısında hata ({e}), DeepSeek yedek motoruna geçiliyor...")

    # 2. Motor: DeepSeek (Yedek & Garantili Güçlü Motor)
    if deepseek_client:
        try:
            logger.info("🛡️ [2/2] DeepSeek API devreye giriyor...")
            completion = await deepseek_client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.7,
                max_tokens=1500,
                response_format={"type": "json_object"}
            )
            raw_text = completion.choices[0].message.content or "{}"
            parsed = json.loads(raw_text)
            logger.info("✅ DeepSeek API başarıyla yanıt üretti.")
            return parsed
        except Exception as e:
            logger.warning(f"DeepSeek JSON çıktısı ayrıştırılırken hata: {e}")

    return {}


async def generate_unlock_interpretation(system_prompt: str, dream_text: str) -> Optional[str]:
    """Tekil gelenek kilit açma için 5s Gemini + DeepSeek fallback motoru."""
    # 1. Motor: Google Gemini (5s)
    if GEMINI_API_KEY:
        try:
            logger.info("⚡ [1/2 Unlock] Google Gemini çağrılıyor (Zaman aşımı: 5.0s)...")
            gemini_text = await asyncio.wait_for(
                call_gemini_text(system_prompt, f'RÜYA: "{dream_text}"', timeout=5.0),
                timeout=5.2
            )
            if gemini_text and gemini_text.strip():
                logger.info("✅ Google Gemini unlock yanıtı başarıyla döndü.")
                return gemini_text.strip()
        except asyncio.TimeoutError:
            logger.warning("⏱️ Google Gemini unlock 5 saniyeyi aştı, DeepSeek'e geçiliyor...")
        except Exception as e:
            logger.warning(f"⚠️ Google Gemini unlock hatası ({e}), DeepSeek'e geçiliyor...")

    # 2. Motor: DeepSeek Fallback
    if deepseek_client:
        try:
            logger.info("🛡️ [2/2 Unlock] DeepSeek API devreye giriyor...")
            completion = await deepseek_client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f'RÜYA: "{dream_text}"'}
                ],
                temperature=0.7,
                max_tokens=1200
            )
            res = completion.choices[0].message.content
            if res and res.strip():
                logger.info("✅ DeepSeek unlock yanıtı başarıyla döndü.")
                return res.strip()
        except Exception as e:
            logger.error(f"DeepSeek unlock hatası: {e}")

    return None


async def generate_chat_reply(message: str, system_context: Optional[str] = None, history: Optional[List[Dict[str, Any]]] = None) -> str:
    """Tabirci sohbeti için çift motor (Gemini 5s -> DeepSeek fallback)."""
    # 1. Gemini İçin Formatlama
    gemini_contents = []
    if system_context:
        gemini_contents.append({
            "role": "user",
            "parts": [{"text": f"SİSTEM TALİMATI VE RÜYA BAĞLAMI:\n{system_context}\n\nLütfen bu rüyanın derinlikli bilge rehberi ol."}]
        })
        gemini_contents.append({
            "role": "model",
            "parts": [{"text": "Anladım. Rüyanızı ve kadim sembollerinizi hafızama aldım. Sorularınızı bu rüyanın ışığında, kadim bilgelikle yanıtlamaya hazırım."}]
        })
    if history:
        for item in history:
            is_user = item.get("isUser", True) if isinstance(item, dict) else True
            text = item.get("text", "") if isinstance(item, dict) else str(item)
            if text:
                role = "user" if is_user else "model"
                gemini_contents.append({"role": role, "parts": [{"text": text}]})
    gemini_contents.append({"role": "user", "parts": [{"text": message}]})

    if GEMINI_API_KEY:
        try:
            logger.info("⚡ [1/2 Chat] Google Gemini Flash çağrılıyor (Zaman aşımı: 5.0s)...")
            gemini_res = await asyncio.wait_for(
                call_gemini_chat(gemini_contents, timeout=5.0),
                timeout=5.2
            )
            if gemini_res and gemini_res.strip():
                logger.info("✅ Google Gemini sohbet yanıtı başarıyla döndü.")
                return gemini_res.strip()
        except asyncio.TimeoutError:
            logger.warning("⏱️ Google Gemini chat 5 saniyeyi aştı, DeepSeek'e geçiliyor...")
        except Exception as e:
            logger.warning(f"⚠️ Google Gemini chat hatası ({e}), DeepSeek'e geçiliyor...")

    # 2. DeepSeek Fallback
    if deepseek_client:
        try:
            logger.info("🛡️ [2/2 Chat] DeepSeek API devreye giriyor...")
            deepseek_messages = []
            sys_prompt = (
                "Sen Kadim Oneiro Rüyabilimci ve Derin Bilinçaltı Rehberisin.\n"
                "Kullanıcının gördüğü rüya ve tabir detayları sana verildiğinde, kullanıcının sorularını "
                "bu rüya deneyiminin doğal bir devamı olarak, derinlikli, bilgece, şefkatli, edebi ve doğrudan rüyadaki sembollere atıfta bulunarak cevapla.\n"
                "Asla yüzeysel veya basmakalıp hazır cevaplar verme. Cevaplarını samimi, doyurucu ve edebi tut."
            )
            if system_context:
                sys_prompt += f"\n\nRÜYA VE TABİR BAĞLAMI:\n{system_context}"
            deepseek_messages.append({"role": "system", "content": sys_prompt})

            if history:
                for item in history:
                    is_user = item.get("isUser", True) if isinstance(item, dict) else True
                    text = item.get("text", "") if isinstance(item, dict) else str(item)
                    if text:
                        role = "user" if is_user else "assistant"
                        deepseek_messages.append({"role": role, "content": text})

            deepseek_messages.append({"role": "user", "content": message})

            completion = await deepseek_client.chat.completions.create(
                model="deepseek-chat",
                messages=deepseek_messages,
                temperature=0.7,
                max_tokens=1200
            )
            reply = completion.choices[0].message.content
            if reply and reply.strip():
                logger.info("✅ DeepSeek sohbet yanıtı başarıyla döndü.")
                return reply.strip()
        except Exception as e:
            logger.error(f"DeepSeek chat hatası: {e}")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Kadim yapay zeka servisine ulaşılamadı: {str(e)}"
            )

    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Kadim rehber servisi şu anda yanıt veremiyor. Lütfen tekrar deneyin."
    )



# -----------------------------------------------------------------------------
# 7. ENDPOINT'LER
# -----------------------------------------------------------------------------
@app.get("/health", summary="Sunucu Durum ve Sağlık Kontrolü")
async def health_check():
    """Render.com uyanıklık ve anlık sistem durumu (0 ms)."""
    global CHUNKS_DB
    sources = list(set(c["source"] for c in CHUNKS_DB)) if CHUNKS_DB else []
    return {
        "status": "healthy",
        "service": "Oneiro RAG Backend",
        "version": "2.2.0",
        "total_chunks": len(CHUNKS_DB),
        "books_loaded": sources,
        "dual_ai_strategy": {
            "primary": "Google Gemini (gemini-flash-latest) [5s zaman aşımı]",
            "fallback": "DeepSeek (deepseek-chat)",
            "gemini_configured": bool(GEMINI_API_KEY),
            "deepseek_configured": bool(DEEPSEEK_API_KEY)
        },
        "render_keep_alive": True
    }


@app.post("/interpret", response_model=DreamInterpretResponse, summary="Hızlı ve Teaser Tabanlı Rüya Yorumu")
async def interpret_dream(request: DreamInterpretRequest):
    """
    1. Rüya metnini analiz eder ve 3 gelenekten en alakalı kitap pasajlarını toplar.
    2. DeepSeek ile tek çağrıda:
       - Bilinçaltı Aynası + Günün Pusulası (Ücretsiz)
       - Birincil Gelenek Tam Yorumu (Doğu & İslam)
       - Kilitli 2 Gelenek İçin 'Merak Fısıltıları' (Teaser cümleleri)
    3. ~350 token ile 2.5-3 saniyede yanıt döner.
    """
    global deepseek_client

    dream_text = request.dream_text.strip()
    if not dream_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Lütfen geçerli bir rüya metni giriniz."
        )

    logger.info(f"Rüya analizi talebi alındı. Kullanıcı ID: {request.user_id or 'Misafir/Anonim'}")

    lang = detect_language(dream_text)
    preferred_trad = request.preferred_tradition or "islam_dogu"
    if preferred_trad not in TRADITIONS:
        preferred_trad = "islam_dogu"

    other_trads = [t for t in TRADITIONS.keys() if t != preferred_trad]

    # Dil ve gelenek metadata'ları
    primary_meta = get_tradition_metadata(preferred_trad, lang)
    other_meta_0 = get_tradition_metadata(other_trads[0], lang)
    other_meta_1 = get_tradition_metadata(other_trads[1], lang)

    # Her gelenekten en alakalı pasajları çek (top_k=2; birincil ve kilitli gelenekler için zengin bağlam)
    matched_chunks: Dict[str, List[Dict[str, Any]]] = {}
    sources_payload: List[SourceUsedItem] = []

    for t_id in TRADITIONS.keys():
        matches = retrieve_by_tradition(dream_text, t_id, top_k=2)
        if matches:
            matched_chunks[t_id] = matches
            for m in matches:
                sources_payload.append(
                    SourceUsedItem(
                        source=m["chunk"]["source"],
                        tradition=t_id,
                        excerpt=m["chunk"]["text"],
                        relevance_score=round(m["score"], 4)
                    )
                )

    primary_matches = matched_chunks.get(preferred_trad, [])
    primary_chunk_text = "\n\n".join([m["chunk"]["text"] for m in primary_matches]) if primary_matches else ""

    other_context_lines = []
    for t_id in other_trads:
        t_matches = matched_chunks.get(t_id, [])
        if t_matches:
            t_meta = get_tradition_metadata(t_id, lang)
            t_text = "\n".join([f"- {m['chunk']['text']}" for m in t_matches])
            other_context_lines.append(f"[{t_meta['title']} Kaynak]:\n{t_text}")

    # Sembol çıkarımı (Kullanıcının dilindeki özgün semboller)
    symbols = extract_user_symbols(dream_text, lang)

    # DeepSeek Hızlı JSON Promptu (~350-400 token, Çok Dilli)
    system_prompt = (
        "Sen 'Oneiro', kadim rüya sembollerinin, arketiplerin ve insan bilinçdışının çok dilli bilge tercümanısın.\n\n"
        "🎯 KULLANICI DİLİ AYNASI (LANGUAGE MIRRORING - ÇOK ÖNEMLİ KURAL):\n"
        "- Kullanıcının rüyayı yazdığı dili otomatik tespit et (Rusça, İngilizce, Türkçe, Almanca, İspanyolca, Arapça, Fransızca vb.).\n"
        "- JSON çıktısındaki 'bilincalti_aynasi', 'gunun_pusulasi', 'primary_interpretation' ve 'teasers' alanlarını KESİNLİKLE VE İSTİSNASIZ kullanıcının yazdığı dilde üret!\n"
        "- Kaynak metinler Türkçe olsa dahi, kitaptaki kadim bilgeliği ve sembol mesajlarını kullanıcının diline akıcı, derinlikli, edebi ve mistik bir üslupla aktar.\n"
        "- Dil asla kullanıcının rüya metninden farklı olmamalıdır.\n\n"
        "İstenen JSON şeması:\n"
        "{\n"
        '  "bilincalti_aynasi": "Rüyanın taşıdığı temel hissi ve arketipsel atmosferi özetleyen 2-3 edebi cümle (kullanıcı dilinde).",\n'
        '  "gunun_pusulasi": "Rüya sahibinin gün boyu hatırlayacağı tek ve vurucu bilgelik aforizması (kullanıcı dilinde).",\n'
        f'  "primary_interpretation": "{primary_meta["title"]} ({primary_meta["scholar"]}) geleneğine göre rüyanın en az 2-3 doyurucu, akıcı, edebi ve derinlikli paragraflık kapsamlı ve yarım kalmayan tam tabiri (kullanıcı dilinde, yaklaşık 180-260 kelime).",\n'
        '  "teasers": {\n'
        f'    "{other_trads[0]}": "{other_meta_0["title"]} açısından rüyayı merak ettiren, 1 cümlelik şoke edici veya düşündürücü teaser (kullanıcı dilinde)",\n'
        f'    "{other_trads[1]}": "{other_meta_1["title"]} açısından rüyayı merak ettiren, 1 cümlelik çarpıcı teaser (kullanıcı dilinde)."\n'
        "  }\n"
        "}\n\n"
        f"KAYNAK METİNLER (KADİM BİLGELİK PASAJLARI):\n[Birincil Gelenek Kaynağı]: {primary_chunk_text}\n" +
        "\n".join(other_context_lines)
    )

    user_prompt = f'RÜYA: "{dream_text}"'

    # Çok dilli offline / test fallback sözlükleri
    offline_fallbacks = {
        "ru": {
            "bilincalti_aynasi": "Этот сон несет в себе атмосферу глубокого очищения и перехода через внутренний порог. Тени, которые вы стремитесь оставить позади, выходят на поверхность.",
            "gunun_pusulasi": "Доверяйте своему первому чувству и тихому голосу сердца; не позволяйте сомнениям заглушить интуицию.",
            "primary_interpretation": f"Согласно источникам традиции '{primary_meta['title']}' ({primary_meta['scholar']}), этот сон предвещает преодоление видимых трудностей, открытие тайных врат и скорое обретение духовного спокойствия и мудрости.",
            "teasers": {
                other_trads[0]: f"С точки зрения традиции '{other_meta_0['title']}', этот знак предвещает судьбоносный поворот в мирских делах...",
                other_trads[1]: f"В свете традиции '{other_meta_1['title']}', это падение символизирует зов Тени и встречу с глубинным Я..."
            }
        },
        "en": {
            "bilincalti_aynasi": "This dream carries an atmosphere of deep inner renewal and passage through a spiritual threshold. Hidden shadows are surfacing to be integrated.",
            "gunun_pusulasi": "Trust your first instinct; when the heart whispers ancient truth, let not doubt hesitate.",
            "primary_interpretation": f"According to the wisdom of {primary_meta['title']} ({primary_meta['scholar']}), this dream signifies that what initially seems challenging will soon lead to profound spiritual clarity, wisdom, and an opening of hidden doors.",
            "teasers": {
                other_trads[0]: f"Through the lens of {other_meta_0['title']}, this symbol reveals an unexpected twist of fate waiting in waking life...",
                other_trads[1]: f"Under {other_meta_1['title']}, this descent is not a collapse, but a summons to encounter your hidden Shadow..."
            }
        },
        "de": {
            "bilincalti_aynasi": "Dieser Traum trägt eine Atmosphäre tiefer innerer Wandlung und des Übergangs über eine seelische Schwelle in sich.",
            "gunun_pusulasi": "Vertraue deiner ersten Eingebung; dein Herz ist in dieser Reise der treueste Führer.",
            "primary_interpretation": f"Nach den Quellen der {primary_meta['title']} ({primary_meta['scholar']}) kündigt dieser Traum nach anfänglicher Prüfung geistige Klarheit und Erleichterung an.",
            "teasers": {
                other_trads[0]: f"Aus Sicht von {other_meta_0['title']} verbirgt dieser Traum ein entscheidendes Zeichen des Schicksals...",
                other_trads[1]: f"Im Lichte von {other_meta_1['title']} ist dieser Abstieg ein unbewusster Ruf zur Auseinandersetzung mit dem Schatten..."
            }
        },
        "es": {
            "bilincalti_aynasi": "Este sueño encierra una atmósfera de profunda purificación interior y el cruce de un umbral espiritual.",
            "gunun_pusulasi": "Confía en tu primera intuición; cuando el corazón susurra, la duda debe callar.",
            "primary_interpretation": f"Según la tradición de {primary_meta['title']} ({primary_meta['scholar']}), este sueño señala que una situación ardua se transformará en sabiduría y bendición.",
            "teasers": {
                other_trads[0]: f"Desde la óptica de {other_meta_0['title']}, este símbolo oculta una revelación crucial sobre tu destino...",
                other_trads[1]: f"Bajo {other_meta_1['title']}, este descenso es un encuentro arquetípico con tu Sombra interior..."
            }
        },
        "ar": {
            "bilincalti_aynasi": "يحمل هذا الحلم أجواء تطهير داخلي عميق وعبور نحو عتبة روحية جديدة.",
            "gunun_pusulasi": "ثق بإحساسك الأول وحدسك الداخلي؛ فالقلب حين يهمس لا يخطئ بوصلته.",
            "primary_interpretation": f"وفقاً لمصادر {primary_meta['title']} ({primary_meta['scholar']})، فإن هذا الحلم يبشر بانفراجة روحية ومقام حكمة بعد مرحلة من الصبر والترقب.",
            "teasers": {
                other_trads[0]: f"من منظور {other_meta_0['title']}، فإن هذا الرمز يحمل إشارة قدرية مفاجئة في حياتك الواقعية...",
                other_trads[1]: f"في ضوء {other_meta_1['title']}، يعبر هذا الهبوط عن مواجهة ملحة مع الظل الروحي لتحقيق التوازن الذاتي..."
            }
        },
        "tr": {
            "bilincalti_aynasi": "Bu rüya, derin bir içsel arınma ve ruhsal bir eşikten geçiş atmosferi taşımaktadır. Zihninizin geride bırakmak istediği gölgeler su yüzüne çıkıyor.",
            "gunun_pusulasi": "İlk hissinize ve iç sesinize güvenin; kalbiniz fısıldadığında mantığınızın duraksamasına izin vermeyin.",
            "primary_interpretation": (
                f"{primary_meta['title']} ({primary_meta['scholar']}) kaynaklarına göre bu rüya, başlangıçta çetin görünen bir durumun "
                "ardından gelecek manevi ferahlığı, gizli bir kapının açılışını ve sabırla beklenen bir müjdenin yaklaşmakta olduğunu simgeler."
            ),
            "teasers": {
                other_trads[0]: f"{other_meta_0['scholar']} geleneğine göre bu sembol bir son değil, kaderinizin mühürlendiği dünyevi bir basiret eşiğidir...",
                other_trads[1]: f"{other_meta_1['scholar']} arketipsel çözümlemesine göre bu düşüş, Gölge benliğinizle yüzleşme arzunuzun bilinçdışı feryadıdır..."
            }
        }
    }

    # Yanıt üretimi (1. Tercih: Google Gemini Flash 5s | 2. Tercih: DeepSeek | 3. Offline Şablon)
    default_payload = offline_fallbacks.get(lang, offline_fallbacks["tr"])
    parsed_json = await generate_dream_interpretation(system_prompt, user_prompt)
    if not parsed_json or not isinstance(parsed_json, dict):
        parsed_json = default_payload

    # Çıktı yapılandırması
    free_analysis = FreeAnalysis(
        bilincalti_aynasi=parsed_json.get("bilincalti_aynasi", default_payload["bilincalti_aynasi"]),
        gunun_pusulasi=parsed_json.get("gunun_pusulasi", default_payload["gunun_pusulasi"])
    )

    primary_trad_item = TraditionAnalysisItem(
        tradition_id=preferred_trad,
        title=primary_meta["title"],
        scholar=primary_meta["scholar"],
        interpretation=parsed_json.get("primary_interpretation", default_payload["primary_interpretation"]),
        is_unlocked=True
    )

    teasers_dict = parsed_json.get("teasers", {})
    locked_items: List[TraditionAnalysisItem] = []
    for t_id in other_trads:
        t_meta = get_tradition_metadata(t_id, lang)
        fallback_teaser = default_payload["teasers"].get(t_id, f"{t_meta['title']} bu rüyada beklenmedik bir sır saklamaktadır...")
        teaser_text = teasers_dict.get(t_id) or fallback_teaser
        locked_items.append(
            TraditionAnalysisItem(
                tradition_id=t_id,
                title=t_meta["title"],
                scholar=t_meta["scholar"],
                teaser=teaser_text,
                interpretation=None,
                is_unlocked=False
            )
        )

    # Eski ekranlarla %100 uyumluluk için birleştirilmiş genel tabir metni (Lokalize Başlıklar)
    headers = {
        "ru": ("🌌 ЗЕРКАЛО ПОДСОЗНАНИЯ", "📜", "🧭 КОМПАС ДНЯ"),
        "en": ("🌌 SUBCONSCIOUS MIRROR", "📜", "🧭 COMPASS OF THE DAY"),
        "de": ("🌌 SPIEGEL DES UNTERBEWUSSTSEINS", "📜", "🧭 KOMPASS DES TAGES"),
        "es": ("🌌 ESPEJO DEL SUBCONSCIENTE", "📜", "🧭 BRÚJULA DEL DÍA"),
        "ar": ("🌌 مرآة اللاوعي", "📜", "🧭 بوصلة اليوم"),
        "tr": ("🌌 BİLİNÇALTI AYNASI", "📜", "🧭 GÜNÜN PUSULASI")
    }
    h_sub, h_trad, h_comp = headers.get(lang, headers["tr"])
    full_interpretation_text = (
        f"{h_sub}:\n{free_analysis.bilincalti_aynasi}\n\n"
        f"{h_trad} {primary_trad_item.title} ({primary_trad_item.scholar}):\n{primary_trad_item.interpretation}\n\n"
        f"{h_comp}:\n{free_analysis.gunun_pusulasi}"
    )

    return DreamInterpretResponse(
        interpretation=full_interpretation_text,
        subconscious_analysis=free_analysis.bilincalti_aynasi,
        warning_of_day=free_analysis.gunun_pusulasi,
        symbols=symbols,
        free_analysis=free_analysis,
        primary_tradition=primary_trad_item,
        locked_traditions=locked_items,
        sources_used=sources_payload
    )


@app.post("/interpret/unlock-tradition", response_model=UnlockTraditionResponse, summary="Kilitli Geleneğin Tam Tabirini Aç")
async def unlock_tradition(request: UnlockTraditionRequest):
    """
    Kullanıcı reklam izlediğinde veya kredi harcadığında,
    yalnızca o spesifik geleneğin tam tabirini kullanıcının dilinde ~200 token ile hızlıca üretir.
    """
    global deepseek_client

    logger.info(f"Kilit açma talebi alındı: {request.tradition_id}. Kullanıcı ID: {request.user_id or 'Misafir/Anonim'}")

    tradition_id = request.tradition_id
    if tradition_id not in TRADITIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Geçersiz gelenek kimliği: {tradition_id}. Geçerli olanlar: {list(TRADITIONS.keys())}"
        )

    lang = detect_language(request.dream_text)
    trad_meta = get_tradition_metadata(tradition_id, lang)
    matches = retrieve_by_tradition(request.dream_text, tradition_id, top_k=2)
    chunk_text_content = "\n\n".join([m["chunk"]["text"] for m in matches]) if matches else ""

    sources_payload = [
        SourceUsedItem(
            source=m["chunk"]["source"],
            tradition=tradition_id,
            excerpt=m["chunk"]["text"],
            relevance_score=round(m["score"], 4)
        )
        for m in matches
    ]

    system_prompt = (
        f"Sen 'Oneiro', kadim sembollerin bilge ve çok dilli tercümanısın.\n\n"
        f"🎯 KULLANICI DİLİ AYNASI (LANGUAGE MIRRORING - ÇOK ÖNEMLİ KURAL):\n"
        f"- Kullanıcının rüyayı yazdığı dili otomatik tespit et ve yorumunu KESİNLİKLE kullanıcının dilinde üret.\n"
        f"- Kullanıcının rüyasını YALNIZCA '{trad_meta['title']}' ({trad_meta['scholar']}) geleneği ışığında yorumla.\n"
        f"- Aşağıdaki kaynak pasajından beslenerek, en az 2-3 derinlikli, edebi, akıcı ve sürükleyici paragraflık (yaklaşık 180-250 kelime) tatmin edici bir tabir sun. Asla sözünü yarım bırakma, son cümleyi tam bir bilgelik mesajıyla bitir.\n\n"
        f"KAYNAK PASAJI:\n{chunk_text_content}"
    )

    unlock_offline_fallbacks = {
        "ru": f"Согласно традиции '{trad_meta['title']}' ({trad_meta['scholar']}), этот символ указывает на пробуждение вашей скрытой силы и духовной проницательности. Обратите внимание на невидимые знаки вокруг вас.",
        "en": f"According to {trad_meta['title']} ({trad_meta['scholar']}), this dream symbol marks the awakening of a latent insight and personal wisdom. Pay close attention to subtle synchronicities surrounding you.",
        "de": f"Nach der Überlieferung der {trad_meta['title']} ({trad_meta['scholar']}) deutet dieses Symbol auf das Erwachen einer verborgenen Gabe und geistigen Schärfe hin.",
        "es": f"Según la tradición de {trad_meta['title']} ({trad_meta['scholar']}), este símbolo representa el despertar de una sabiduría latente y una visión profunda.",
        "ar": f"وفقاً لتقاليد {trad_meta['title']} ({trad_meta['scholar']})، يشير هذا الرمز إلى يقظة حكمة باطنية وبصيرة نافذة ترشدك في مسارك القادم.",
        "tr": f"{trad_meta['scholar']} kaynaklarına göre bu rüya sembolü, gizli kalmış bir yeteneğinizin ve dünyevi basiretinizin uyanışına işaret eder. Çevrenizdeki görünmez işaretlere dikkat kesilmeli ve ilk adımı atmaktan çekinmemelisiniz."
    }

    # 1. Tercih: Google Gemini (5s limit) | 2. Tercih: DeepSeek | 3. Offline Şablon
    full_text = await generate_unlock_interpretation(system_prompt, request.dream_text)
    if not full_text or not full_text.strip():
        full_text = unlock_offline_fallbacks.get(lang, unlock_offline_fallbacks["tr"])

    return UnlockTraditionResponse(
        tradition_id=tradition_id,
        title=trad_meta["title"],
        scholar=trad_meta["scholar"],
        interpretation=full_text,
        sources_used=sources_payload
    )


@app.post("/chat", response_model=ChatResponse, summary="Tabirciye Soru Sor (Rüyanın Devamı Olarak Sohbet)")
async def chat_with_interpreter(request: ChatRequest):
    """
    Rüya tabiri sonrasında kullanıcının rüyasıyla ilgili devam sorularını cevaplar.
    Google Gemini (5s) + DeepSeek yedek motoruyla gerçek zamanlı AI yanıtı üretir.
    """
    message = request.message.strip()
    if not message:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Lütfen tabirciye iletmek için bir soru yazınız."
        )

    logger.info(f"Tabirciye soru soruldu. Kullanıcı ID: {request.user_id or 'Anonim'}")
    reply = await generate_chat_reply(
        message=message,
        system_context=request.system_context,
        history=request.history
    )
    return ChatResponse(reply=reply)


# -----------------------------------------------------------------------------
# 8. LOCAL DEV
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
