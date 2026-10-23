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
        "fr": {"title": "Tradition Orientale et Islamique", "scholar": "Ibn Sirin et Al-Nabulsi"},
        "pt": {"title": "Tradição Oriental e Islâmica", "scholar": "Ibn Sirin e Al-Nabulsi"},
        "hi": {"title": "पूर्वी और इस्लामी परंपरा", "scholar": "इब्न सिरीन और अन-नाबुलसी"},
        "zh": {"title": "东方与伊斯兰解梦传统", "scholar": "伊本·西林与纳布勒斯"}
    },
    "antik_akdeniz": {
        "tr": {"title": "Antik Akdeniz Bilgeliği", "scholar": "Artemidorus (Oneirocritica)"},
        "en": {"title": "Ancient Mediterranean Wisdom", "scholar": "Artemidorus (Oneirocritica)"},
        "ru": {"title": "Античная Средиземноморская Мудрость", "scholar": "Артемидор (Онейрокритика)"},
        "de": {"title": "Antike Weisheit des Mittelmeers", "scholar": "Artemidorus (Oneirocritica)"},
        "es": {"title": "Sabiduría del Mediterráneo Antiguo", "scholar": "Artemidoro (Oneirocrítica)"},
        "ar": {"title": "حكمة البحر الأبيض المتوسط القديمة", "scholar": "أرتيميدوروس (أونيروكريتيكا)"},
        "fr": {"title": "Sagesse Méditerranéenne Antique", "scholar": "Artémidore (Oneirocritica)"},
        "pt": {"title": "Sabedoria do Mediterrâneo Antigo", "scholar": "Artemidoro (Oneirocrítica)"},
        "hi": {"title": "प्राचीन भूमध्यसागरीय ज्ञान", "scholar": "आर्टेमिडोरस (ओनेइरोक्रिटिका)"},
        "zh": {"title": "古地中海解梦智慧", "scholar": "阿特米多鲁斯 (梦的解析)"}
    },
    "psikoloji": {
        "tr": {"title": "Derinlik Psikolojisi", "scholar": "Carl G. Jung & Sigmund Freud"},
        "en": {"title": "Depth Psychology", "scholar": "Carl G. Jung & Sigmund Freud"},
        "ru": {"title": "Глубинная Психология", "scholar": "Карл Г. Юнг и Зигмунд Фрейд"},
        "de": {"title": "Tiefenpsychologie", "scholar": "Carl G. Jung & Sigmund Freud"},
        "es": {"title": "Psicología Profunda", "scholar": "Carl G. Jung y Sigmund Freud"},
        "ar": {"title": "علم النفس العميق", "scholar": "كارل غ. يونغ وسيغموند فرويد"},
        "fr": {"title": "Psychologie des Profondeurs", "scholar": "Carl G. Jung et Sigmund Freud"},
        "pt": {"title": "Psicologia Profunda", "scholar": "Carl G. Jung e Sigmund Freud"},
        "hi": {"title": "गहन मनोविज्ञान", "scholar": "कार्ल जी. जुंग और सिगमंड फ्रायड"},
        "zh": {"title": "深度心理学", "scholar": "卡尔·荣格与西格蒙德·弗洛伊德"}
    }
}


def get_tradition_metadata(tradition_id: str, lang: str = "tr") -> Dict[str, str]:
    """İstenen dilde gelenek başlığı ve bilgin adını döner (tr, en, ru, de, es, ar, fr, pt, hi, zh)."""
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
    """Metnin dilini sıfır harici bağımlılıkla ve 0 ms gecikmeyle tespit eder (ru, ar, hi, zh, tr, de, es, fr, pt, en)."""
    if re.search(r"[\u0400-\u04FF]", text):
        return "ru"
    if re.search(r"[\u0600-\u06FF]", text):
        return "ar"
    if re.search(r"[\u0900-\u097F]", text):
        return "hi"
    if re.search(r"[\u4E00-\u9FFF]", text):
        return "zh"
    if re.search(r"[çğıöşüÇĞİÖŞÜ]", text):
        return "tr"

    lower = text.lower()
    words = set(re.findall(r"\b[^\W\d_]{2,}\b", lower, flags=re.UNICODE))

    # Portekizce belirteçleri
    if len(words.intersection({"não", "para", "com", "uma", "este", "sonho", "dos", "das", "mais", "voce", "você", "estava"})) >= 2:
        return "pt"

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
CHUNKS_BY_TRADITION: Dict[str, List[Dict[str, Any]]] = {}

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


TWO_LETTER_SYMBOLS = {"su", "ev", "at", "ay", "el", "ip", "ok", "ot", "et", "un", "ak"}

# 11 Kitabın (Türkçe, İngilizce ve Arapça) tamamından nokta atışı veri çekmek için
# Çift Yönlü Çok Dilli Sembol ve Kavram Kümeleri
CONCEPT_CLUSTERS: Dict[str, Set[str]] = {
    "kaya": {"kaya", "kayalik", "kayalar", "tas", "taslik", "ucurum", "yamac", "rock", "rocks", "rocky", "stone", "stones", "boulder", "cliff", "crag", "precipice", "صخرة", "صخر", "صخور", "حجر", "حجارة", "جرف", "скала", "камень", "felsen", "stein", "roca", "piedra", "rocher", "pierre"},
    "deniz": {"deniz", "okyanus", "derya", "sea", "seas", "ocean", "oceans", "seawater", "marine", "maritime", "بحر", "بحار", "محيط", "يم", "море", "океан", "meer", "ozean", "mar", "oceano", "mer"},
    "sahil": {"sahil", "kiyi", "kumsal", "plaj", "iskele", "liman", "kordon", "shore", "shores", "seashore", "beach", "coast", "coastal", "sand", "sandy", "bank", "harbor", "port", "ساحل", "شاطئ", "شط", "رمل", "رمال", "ميناء", "берег", "пляж", "песок", "strand", "ufer", "playa", "costa", "orilla", "plage", "rivage"},
    "dalga": {"dalga", "dalgalar", "dalgali", "firtina", "kasirga", "girdap", "kopuk", "wave", "waves", "foaming", "foam", "surf", "tide", "storm", "stormy", "tempest", "whirlpool", "موج", "امواج", "أمواج", "عاصفة", "волна", "волны", "шторм", "буря", "welle", "wellen", "sturm", "ola", "olas", "tormenta", "vague", "tempete"},
    "su": {"su", "suyu", "sular", "sudan", "suya", "pinar", "cesme", "kaynak", "water", "waters", "spring", "fountain", "stream", "brook", "drinking", "drink", "thirst", "ماء", "مياه", "عين", "ينبوع", "شرب", "عطش", "вода", "wasser", "agua", "eau"},
    "nehir": {"nehir", "irmak", "dere", "akarsu", "cay", "river", "rivers", "stream", "creek", "brook", "نهر", "أنهار", "انهار", "سيل", "река", "fluss", "rio", "riviere"},
    "gol": {"gol", "golu", "golet", "havuz", "bataklik", "lake", "lakes", "pond", "pool", "swamp", "marsh", "بحيرة", "بركة", "غدير", "озеро", "see", "teich", "lago", "lac"},
    "kuyu": {"kuyu", "cukur", "sarnic", "well", "wells", "pit", "cistern", "shaft", "بئر", "ابار", "آبار", "حفرة", "جب", "колодец", "яма", "brunnen", "pozo", "puits"},
    "yagmur": {"yagmur", "sel", "tufan", "dolu", "kar", "buz", "rain", "raining", "flood", "hail", "snow", "ice", "cloud", "clouds", "bulut", "مطر", "امطار", "سيل", "طوفان", "ثلج", "برد", "سحاب", "غيم", "дождь", "снег", "regen", "schnee", "lluvia", "nieve", "pluie", "neige"},
    "bogulmak": {"bogulmak", "boguldu", "batmak", "drown", "drowning", "sinking", "sink", "submerged", "غرق", "يغرق", "غريق", "тонуть", "ertrinken", "ahogarse", "noyer"},
    "yuzmek": {"yuzmek", "yuzdu", "yikanmak", "dalmak", "swim", "swimming", "swimmer", "bathing", "bath", "dive", "diving", "سباحة", "يسبح", "اغتسال", "غوص", "плавать", "schwimmen", "nadar", "nager"},
    "gokyuzu": {"gokyuzu", "gok", "sema", "cennet", "sky", "skies", "heaven", "heavens", "air", "firmament", "سماء", "سماوات", "جو", "فضاء", "небо", "himmel", "cielo", "ciel"},
    "gunes": {"gunes", "safak", "sun", "sunshine", "sunrise", "sunset", "solar", "daylight", "شمس", "شروق", "غروب", "ضحى", "солнце", "sonne", "sol", "soleil"},
    "ay": {"ay", "hilal", "dolunay", "mehtap", "moon", "moonlight", "crescent", "lunar", "قمر", "هلال", "بدر", "луна", "mond", "luna", "lune"},
    "yildiz": {"yildiz", "yildizlar", "gezegen", "star", "stars", "meteor", "planet", "constellation", "نجم", "نجوم", "كوكب", "كواكب", "شهاب", "звезда", "stern", "estrella", "etoile"},
    "ates": {"ates", "alev", "yangin", "duman", "kul", "kivilcim", "yanmak", "fire", "fires", "flame", "flames", "burning", "burn", "smoke", "ash", "ashes", "spark", "coal", "نار", "نيران", "لهب", "حريق", "دخان", "رماد", "جمر", "огонь", "пламя", "feuer", "fuego", "feu"},
    "dag": {"dag", "daglar", "tepe", "zirve", "doruk", "tirmanmak", "mountain", "mountains", "hill", "hills", "peak", "summit", "climbing", "climb", "جبل", "جبال", "تل", "قمة", "صعود", "гора", "berg", "montana", "montagne"},
    "orman": {"orman", "agac", "agaclar", "bahce", "bag", "yaprak", "dal", "cicek", "gul", "forest", "woods", "wood", "tree", "trees", "garden", "orchard", "leaf", "leaves", "branch", "flower", "flowers", "rose", "roses", "غابة", "شجرة", "أشجار", "اشجار", "بستان", "حديقة", "ورد", "زهر", "лес", "дерево", "wald", "baum", "bosque", "arbol", "foret", "arbre"},
    "toprak": {"toprak", "tarla", "camur", "balcik", "toz", "earth", "soil", "ground", "land", "field", "mud", "clay", "dust", "أرض", "ارض", "تراب", "طين", "حقل", "غبار", "земля", "erde", "tierra", "terre"},
    "magara": {"magara", "tunel", "yeralti", "mahzen", "cave", "cavern", "grotto", "tunnel", "underground", "cellar", "كهف", "مغارة", "غار", "نفق", "سرداب", "пещера", "hoehle", "cueva", "grotte"},
    "yilan": {"yilan", "yilanlar", "engerek", "kobra", "ejderha", "snake", "snakes", "serpent", "serpents", "viper", "cobra", "dragon", "ثعبان", "افعى", "أفعى", "حية", "حيات", "تنين", "змея", "schlange", "serpiente", "couleuvre"},
    "kartal": {"kartal", "sahin", "dogan", "atmaca", "akbaba", "baykus", "karga", "kuzgun", "eagle", "eagles", "falcon", "hawk", "vulture", "owl", "crow", "raven", "نسر", "عقاب", "صقر", "باز", "بوم", "غراب", "орел", "adler", "aguila", "aigle"},
    "kus": {"kus", "kuslar", "guvercin", "serce", "kirlangic", "kanat", "tuy", "bird", "birds", "pigeon", "dove", "swallow", "sparrow", "wing", "wings", "feather", "feathers", "طائر", "طيور", "طير", "حمام", "حمامة", "عصفور", "جناح", "ريش", "птица", "vogel", "pajaro", "ave", "oiseau"},
    "aslan": {"aslan", "kaplan", "pars", "leopar", "lion", "lions", "tiger", "leopard", "panther", "beast", "أسد", "اسد", "سبع", "نمر", "فهد", "лев", "loewe", "leon"},
    "kurt": {"kurt", "kurtlar", "tilki", "cakal", "wolf", "wolves", "fox", "jackal", "ذئب", "ثعلب", "волк", "fuchs", "lobo", "loup"},
    "kopek": {"kopek", "kopekler", "havlamak", "dog", "dogs", "hound", "puppy", "bark", "barking", "كلب", "كلاب", "نباح", "собака", "hund", "perro", "chien"},
    "kedi": {"kedi", "kediler", "cat", "cats", "kitten", "feline", "قط", "قطة", "هر", "هرة", "سنور", "кошка", "katze", "gato", "chat"},
    "at": {"at", "atlar", "kisrak", "aygir", "eyer", "binmek", "horse", "horses", "mare", "stallion", "steed", "saddle", "riding", "ride", "فرس", "خيل", "حصان", "مهر", "سرج", "ركوب", "лошадь", "конь", "pferd", "caballo", "cheval"},
    "balik": {"balik", "baliklar", "yunus", "balina", "kopekbaligi", "yengec", "olta", "fish", "fishes", "fishing", "whale", "shark", "dolphin", "crab", "net", "سمك", "أسماك", "اسماك", "حوت", "صياد", "شبكة", "рыба", "fisch", "pez", "pescado", "poisson"},
    "bocek": {"bocek", "orumcek", "akrep", "ari", "karinca", "sinek", "kelebek", "kurtcuk", "insect", "spider", "scorpion", "bee", "bees", "honey", "ant", "ants", "butterfly", "worm", "عنكبوت", "عقرب", "نحل", "عسل", "نمل", "ذباب", "فراشة", "دود", "паук", "spinne", "arana", "araignee"},
    "ev": {"ev", "evi", "evde", "bina", "konak", "saray", "kale", "cati", "duvar", "avlu", "house", "houses", "home", "building", "palace", "castle", "roof", "wall", "walls", "courtyard", "بيت", "بيوت", "منزل", "دار", "قصر", "قلعة", "سقف", "جدار", "حائط", "дом", "haus", "casa", "maison"},
    "oda": {"oda", "odasi", "salon", "mutfak", "banyo", "yatak", "koridor", "pencere", "room", "rooms", "bedroom", "kitchen", "bathroom", "bed", "hall", "corridor", "window", "غرفة", "حجرة", "مطبخ", "حمام", "سرير", "فراش", "نافذة", "شباك", "комната", "zimmer", "habitacion", "chambre"},
    "kapi": {"kapi", "kapisi", "esik", "anahtar", "kilit", "acmak", "door", "doors", "gate", "gates", "threshold", "portal", "key", "keys", "lock", "opening", "باب", "أبواب", "ابواب", "بوابة", "عتبة", "مفتاح", "قفل", "دخول", "дверь", "ключ", "tuer", "schluessel", "puerta", "llave", "porte", "cle"},
    "merdiven": {"merdiven", "basamak", "asansor", "cikmak", "inmek", "stairs", "staircase", "steps", "ladder", "ascending", "descending", "سلم", "درج", "معراج", "صعود", "نزول", "лестница", "treppe", "escalera", "escalier"},
    "yol": {"yol", "yolu", "sokak", "cadde", "patika", "kopru", "kavsak", "yurumek", "road", "roads", "street", "path", "bridge", "crossroads", "walking", "walk", "طريق", "سبيل", "شارع", "جسر", "قنطرة", "مشي", "дорога", "мост", "weg", "bruecke", "camino", "puente", "chemin", "pont"},
    "okul": {"okul", "sinif", "ogretmen", "ogrenci", "sinav", "ders", "kitap", "defter", "kalem", "yazmak", "okumak", "school", "university", "classroom", "teacher", "student", "exam", "test", "lesson", "book", "books", "pen", "writing", "reading", "مدرسة", "معلم", "أستاذ", "امتحان", "كتاب", "كتب", "قلم", "قراءة", "كتابة", "школа", "книга", "schule", "buch", "escuela", "libro", "ecole", "livre"},
    "ibadet": {"cami", "mescit", "kilise", "tapinak", "sunak", "namaz", "dua", "ezan", "kabe", "kuran", "imam", "rahip", "melek", "seytan", "cin", "mosque", "church", "temple", "altar", "prayer", "praying", "worship", "kaaba", "quran", "priest", "angel", "devil", "satan", "jinn", "مسجد", "جامع", "كنيسة", "معبد", "صلاة", "دعاء", "أذان", "كعبة", "قرآن", "إمام", "ملاك", "ملائكة", "شيطان", "جن", "храм", "tempel", "templo"},
    "dis": {"dis", "disler", "disi", "azi", "dokulmek", "cekilmek", "agiz", "dil", "dudak", "tooth", "teeth", "molar", "mouth", "tongue", "lips", "biting", "سن", "أسنان", "اسنان", "ضرس", "فم", "لسان", "شفة", "зуб", "зубы", "zahn", "zaehne", "diente", "dent"},
    "sac": {"sac", "saclar", "sakal", "biyik", "tarak", "taramak", "kesmek", "tras", "kel", "bas", "kafa", "hair", "hairs", "beard", "mustache", "comb", "combing", "shaving", "shave", "bald", "head", "شعر", "لحية", "شارب", "مشط", "حلاقة", "حلق", "رأس", "волосы", "haar", "cabello", "pelo", "cheveux"},
    "kan": {"kan", "kanamak", "yara", "kesik", "blood", "bleeding", "bleed", "wound", "wounded", "injury", "scar", "دم", "دماء", "نزيف", "جرح", "جروح", "кровь", "blut", "sangre", "sang"},
    "goz": {"goz", "gozler", "kor", "gozyasi", "eye", "eyes", "sight", "vision", "blind", "tears", "tear", "weeping", "عين", "عيون", "بصر", "عمى", "أعمى", "دموع", "دمع", "بكاء", "глаз", "auge", "ojo", "oeil"},
    "el": {"el", "eller", "parmak", "kol", "avuc", "tutmak", "hand", "hands", "finger", "fingers", "arm", "arms", "palm", "holding", "يد", "أيدي", "ايدي", "كف", "إصبع", "اصابع", "ذراع", "рука", "mano", "main"},
    "ayak": {"ayak", "ayaklar", "bacak", "topuk", "ayakkabi", "foot", "feet", "leg", "legs", "heel", "barefoot", "shoe", "shoes", "boot", "boots", "قدم", "أقدام", "اقدام", "رجل", "ساق", "حذاء", "نعل", "حافي", "нога", "обувь", "fuss", "schuh", "pie", "zapato", "pied", "chaussure"},
    "bebek": {"bebek", "cocuk", "ogul", "kiz", "hamile", "dogum", "dogurmak", "besik", "baby", "infant", "child", "children", "boy", "girl", "son", "daughter", "pregnant", "pregnancy", "birth", "cradle", "طفل", "أطفال", "رضيع", "ولد", "بنت", "غلام", "حمل", "حامل", "ولادة", "مهد", "ребенок", "kind", "nino", "bebe", "enfant"},
    "olum": {"olum", "olu", "olmek", "cenaze", "mezar", "mezarlik", "tabut", "kefen", "kabir", "death", "dead", "dying", "die", "corpse", "funeral", "grave", "graves", "cemetery", "tomb", "coffin", "shroud", "موت", "ميت", "أموات", "اموات", "جنازة", "قبر", "قبور", "مقبرة", "كفن", "نعش", "смерть", "могила", "tod", "grab", "muerte", "tumba", "mort", "tombe"},
    "aile": {"anne", "ana", "baba", "kardes", "abi", "abla", "dede", "nine", "akraba", "mother", "father", "parents", "brother", "sister", "grandfather", "grandmother", "family", "أم", "ام", "والدة", "أب", "اب", "والد", "أخ", "اخ", "أخت", "اخت", "أهل", "мать", "отец", "mutter", "vater", "madre", "padre", "mere", "pere"},
    "evlilik": {"evlilik", "evlenmek", "dugun", "nikah", "gelin", "damat", "es", "kari", "koca", "sevgili", "nisan", "yuzuk", "marriage", "marry", "wedding", "bride", "groom", "husband", "wife", "spouse", "lover", "sweetheart", "ring", "engagement", "زواج", "نكاح", "عرس", "عروس", "عريس", "زوج", "زوجة", "حبيب", "خاتم", "خطوبة", "свадьба", "hochzeit", "boda", "mariage"},
    "ucmak": {"ucmak", "ucuyordum", "uctu", "havalanmak", "suzulen", "suzulmek", "fly", "flying", "flight", "soar", "soaring", "floating", "طيران", "يطير", "طار", "تحليق", "лететь", "полет", "fliegen", "volar", "voler"},
    "dusmek": {"dusmek", "dustu", "dusuyordum", "yuvarlanmak", "kaymak", "fall", "falling", "fell", "drop", "slipping", "stumble", "سقوط", "يسقط", "سقط", "وقوع", "انزلاق", "падать", "упал", "fallen", "caer", "tomber"},
    "kosmak": {"kosmak", "kacmak", "takip", "kovalamak", "kovalanmak", "saklanmak", "kurtulmak", "kaybolmak", "kayip", "run", "running", "flee", "fleeing", "escape", "escaping", "chase", "chased", "pursuit", "hiding", "lost", "losing", "هروب", "يهرب", "فرار", "جري", "ركض", "مطاردة", "اختباء", "ضياع", "تائه", "бежать", "погоня", "rennen", "flucht", "correr", "huir", "courir", "fuir"},
    "aglamak": {"aglamak", "agliyordum", "gozyasi", "uzulmek", "huzun", "keder", "cry", "crying", "weep", "weeping", "sob", "sadness", "grief", "sorrow", "بكاء", "يبكي", "دموع", "حزن", "هم", "غم", "плакать", "weinen", "llorar", "pleurer"},
    "kavga": {"kavga", "savas", "dovusmek", "vurmak", "saldiri", "silah", "tabanca", "tufek", "kilic", "bicak", "ok", "dusman", "fight", "fighting", "war", "battle", "strike", "hit", "attack", "weapon", "gun", "rifle", "sword", "knife", "dagger", "arrow", "enemy", "enemies", "قتال", "حرب", "شجار", "ضرب", "سلاح", "سيف", "سكين", "رمح", "سهم", "عدو", "أعداء", "война", "оружие", "krieg", "waffe", "guerra", "arma", "guerre", "arme"},
    "yemek": {"yemek", "ekmek", "et", "sut", "bal", "meyve", "elma", "uzum", "incir", "zeytin", "sofra", "ziyafet", "aclik", "pisirmek", "food", "eat", "eating", "bread", "meat", "milk", "honey", "fruit", "apple", "grapes", "fig", "olive", "olives", "table", "banquet", "feast", "hunger", "cooking", "طعام", "أكل", "اكل", "خبز", "لحم", "لبن", "حليب", "عسل", "فاكهة", "تفاح", "عنب", "تين", "زيتون", "مائدة", "وليمة", "جوع", "طبخ", "еда", "хлеб", "essen", "brot", "comida", "pan", "nourriture", "pain"},
    "altin": {"altin", "gumus", "elmas", "mucevher", "inci", "hazine", "tac", "bilezik", "kolye", "gold", "golden", "silver", "diamond", "jewel", "jewels", "pearl", "pearls", "treasure", "crown", "bracelet", "necklace", "ذهب", "فضة", "جوهر", "جواهر", "لؤلؤ", "در", "كنز", "تاج", "سوار", "عقد", "золото", "серебро", "silber", "oro", "plata", "argent"},
    "para": {"para", "nakit", "cuzdan", "borc", "zengin", "fakir", "maas", "ticaret", "kazanc", "money", "coin", "coins", "cash", "wallet", "debt", "wealth", "rich", "poor", "poverty", "business", "profit", "trade", "مال", "أموال", "اموال", "نقود", "درهم", "دينار", "دين", "ديون", "غنى", "غني", "فقر", "فقير", "تجارة", "ربح", "деньги", "geld", "dinero"},
    "elbise": {"elbise", "kiyafet", "gomlek", "pantolon", "etek", "palto", "pelerin", "beyaz", "siyah", "kirmizi", "yesil", "mavi", "sari", "ciplak", "clothes", "clothing", "garment", "dress", "shirt", "coat", "cloak", "white", "black", "red", "green", "blue", "yellow", "naked", "nudity", "ثوب", "ثياب", "ملابس", "لباس", "قميص", "أبيض", "ابيض", "أسود", "اسود", "أحمر", "احمر", "أخضر", "اخضر", "أصفر", "اصفر", "عريان", "عاري", "одежда", "kleidung", "ropa", "vetement"},
    "ayna": {"ayna", "yansima", "cam", "kristal", "kirmak", "kirik", "mirror", "mirrors", "reflection", "glass", "crystal", "broken", "shattered", "مرآة", "مرايا", "زجاج", "بلور", "انكسار", "مكسور", "зеркало", "spiegel", "espejo", "miroir"},
    "arac": {"araba", "otomobil", "otobus", "tren", "gemi", "kayik", "tekne", "ucak", "bisiklet", "surmek", "yolculuk", "sefer", "car", "bus", "train", "ship", "boat", "vessel", "arc", "ark", "plane", "aircraft", "driving", "voyage", "journey", "travel", "travelling", "سفينة", "سفن", "مركب", "قارب", "فلك", "سيارة", "قطار", "طائرة", "سفر", "رحلة", "ركوب", "корабль", "машина", "schiff", "auto", "barco", "coche", "navire", "voiture"},
    "golge": {"golge", "karanlik", "gece", "isik", "aydinlik", "lamba", "mum", "fener", "sis", "shadow", "shadows", "shade", "dark", "darkness", "gloom", "night", "light", "bright", "lamp", "candle", "lantern", "fog", "mist", "ظل", "ظلال", "ظلام", "ظلمة", "ليل", "نور", "ضوء", "مصباح", "سراج", "شمعة", "ضباب", "тень", "тьма", "свет", "schatten", "dunkel", "licht", "sombra", "luz", "ombre", "lumiere"},
    "hastane": {"hastane", "hasta", "hastalik", "doktor", "hekim", "ilac", "ameliyat", "iyilesmek", "sifa", "agri", "hospital", "sick", "sickness", "illness", "disease", "doctor", "physician", "medicine", "cure", "healing", "pain", "مرض", "مريض", "طبيب", "دواء", "شفاء", "ألم", "وجع", "больница", "врач", "krankenhaus", "arzt", "medico"},
    "kral": {"kral", "padisah", "sultan", "devlet", "baskan", "hakim", "yargic", "mahkeme", "adalet", "hapis", "zindan", "polis", "asker", "ordu", "king", "ruler", "sultan", "emperor", "governor", "authority", "government", "judge", "court", "prison", "jail", "police", "soldier", "army", "ملك", "سلطان", "حاكم", "قاضي", "محكمة", "سجن", "حبس", "جيش", "عسكر", "جنود", "король", "тюрьма", "koenig", "gefaengnis", "rey", "prision", "roi"},
    "hirsiz": {"hirsiz", "calmak", "soygun", "kaybetmek", "bulmak", "yabanci", "misafir", "dilenci", "thief", "thieves", "robber", "stealing", "steal", "stolen", "stranger", "guest", "beggar", "لص", "سارق", "سرقة", "ضيف", "غريب", "سائل", "вор", "dieb", "ladron", "voleur"},
    "ruzgar": {"ruzgar", "esinti", "hortum", "hava", "deprem", "zelzele", "sarsinti", "wind", "winds", "breeze", "gale", "hurricane", "tornado", "earthquake", "tremor", "ريح", "رياح", "زلزال", "زلزلة", "رجفة", "ветер", "землетрясение", "erdbeben", "viento", "terremoto", "vent", "seisme"},
    "hayvan_ciftlik": {"koyun", "kuzu", "keci", "inek", "boga", "okuz", "dana", "deve", "esek", "katir", "domuz", "tavuk", "horoz", "sheep", "lamb", "goat", "cow", "cattle", "bull", "ox", "calf", "camel", "donkey", "ass", "mule", "pig", "swine", "chicken", "hen", "rooster", "cock", "غنم", "شاة", "كبش", "خروف", "ماعز", "بقرة", "بقر", "ثور", "عجل", "جمل", "إبل", "ابل", "ناقة", "حمار", "بغل", "خنزير", "دجاج", "ديك"},
    "vahsi_hayvan": {"ayi", "fil", "maymun", "timsah", "kurbaga", "kaplumbaga", "geyik", "ceylan", "tavsan", "bear", "elephant", "monkey", "ape", "crocodile", "frog", "turtle", "tortoise", "deer", "gazelle", "rabbit", "hare", "دب", "فيل", "قرد", "تمساح", "ضفدع", "سلحفاة", "غزال", "ظبي", "أرنب", "ارنب"},
    "duygu": {"korku", "korkmak", "dehset", "panik", "endise", "mutluluk", "sevinc", "gulmek", "ofke", "kizmak", "utanc", "yalnizlik", "huzur", "fear", "afraid", "terror", "fright", "anxiety", "worry", "joy", "happiness", "happy", "laugh", "laughing", "smile", "anger", "angry", "rage", "shame", "ashamed", "peace", "خوف", "فزع", "رعب", "قلق", "فرح", "سرور", "ضحك", "ابتسام", "غضب", "حياء", "خجل", "أمن", "سكينة"}
}

WORD_TO_CLUSTER: Dict[str, Any] = {}
for _cname, _cset in list(CONCEPT_CLUSTERS.items()):
    _expanded = set(_cset)
    for _w in list(_cset):
        if re.search(r"[\u0600-\u06FF]", _w):
            _expanded.add("ال" + _w)
            _expanded.add("وال" + _w)
            _expanded.add("بال" + _w)
            if _w.startswith("أ") or _w.startswith("إ"):
                _bare = "ا" + _w[1:]
                _expanded.add(_bare)
                _expanded.add("ال" + _bare)
    CONCEPT_CLUSTERS[_cname] = _expanded
    for _w in _expanded:
        WORD_TO_CLUSTER[_w] = (_cname, _expanded)


def clean_turkish_stem(w: str) -> str:
    """Türkçe çekim eklerini soyarak kelimenin gerçek sembol kökünü bulur."""
    w = normalize_turkish(w.strip())
    if w in WORD_TO_CLUSTER:
        return w
    suffixes = [
        "larindan", "lerinden", "larinda", "lerinde", "larinin", "lerinin",
        "daydim", "deydim", "taydim", "teydim", "daydik", "deydik",
        "ymisim", "larina", "lerine", "lardan", "lerden", "larim", "lerim",
        "larin", "lerin", "larla", "lerle", "imdan", "imden", "umdan", "umden",
        "indan", "inden", "undan", "unden", "ndan", "nden",
        "imda", "imde", "umda", "umde", "inda", "inde", "unda", "unde",
        "imin", "umun", "unun", "inin", "nin", "nun",
        "dan", "den", "tan", "ten", "lar", "ler",
        "da", "de", "ta", "te", "ya", "ye", "yi", "yu", "na", "ne",
        "im", "in", "um", "un", "ik", "uk", "li", "lu", "si", "su",
        "a", "e", "i", "u"
    ]
    for sfx in suffixes:
        if w.endswith(sfx):
            stem = w[:-len(sfx)]
            if len(stem) >= 3 or stem in TWO_LETTER_SYMBOLS:
                if stem in WORD_TO_CLUSTER:
                    return stem
                if stem.endswith("b") and (stem[:-1] + "p") in WORD_TO_CLUSTER:
                    return stem[:-1] + "p"
                if stem.endswith("g") and (stem[:-1] + "k") in WORD_TO_CLUSTER:
                    return stem[:-1] + "k"
                if stem.endswith("d") and (stem[:-1] + "t") in WORD_TO_CLUSTER:
                    return stem[:-1] + "t"
    for sfx in ["lardan", "lerden", "daydim", "deydim", "indan", "inden", "larin", "lerin", "inda", "inde", "dan", "den", "tan", "ten", "lar", "ler", "da", "de", "ta", "te", "in", "un", "im", "um"]:
        if w.endswith(sfx) and len(w) - len(sfx) >= 3:
            return w[:-len(sfx)]
    return w


def extract_dream_concepts(text: str) -> List[Any]:
    """
    Rüya metnindeki her bir sembolü (ör. kaya, deniz, sahil) tespit eder ve
    11 kitabın tamamında (TR, EN, AR) eşleşecek kavram kümelerini döner.
    """
    norm = normalize_turkish(text.lower())
    raw_tokens = re.findall(r"\b[^\W\d_]{2,}\b", norm, flags=re.UNICODE)
    concepts = []
    seen_names = set()

    for w in raw_tokens:
        if w in MULTILINGUAL_STOPWORDS:
            continue
        if len(w) == 2 and w not in TWO_LETTER_SYMBOLS:
            continue

        stem = clean_turkish_stem(w)
        if stem in MULTILINGUAL_STOPWORDS:
            continue

        if stem in WORD_TO_CLUSTER:
            cname, cset = WORD_TO_CLUSTER[stem]
            if cname not in seen_names:
                seen_names.add(cname)
                concepts.append((cname, cset))
        elif w in WORD_TO_CLUSTER:
            cname, cset = WORD_TO_CLUSTER[w]
            if cname not in seen_names:
                seen_names.add(cname)
                concepts.append((cname, cset))
        elif len(stem) >= 3:
            if stem not in seen_names:
                seen_names.add(stem)
                concepts.append((stem, {w, stem}))

    return concepts


def extract_keywords(text: str) -> List[str]:
    """Rüya metnindeki anahtar sembol köklerini listeler."""
    concepts = extract_dream_concepts(text)
    return [cname for cname, _ in concepts]


def clean_turkish_symbol_root(word: str) -> str:
    """Türkçe rüya metinlerindeki belirgin çekim eklerini ('okuldaydım' -> 'Okul') ayıklayarak yalın kökü bulur."""
    w = word.lower().strip()
    patterns = [
        r"(?:ler|lar)?(?:da|de|ta|te)yd(?:ım|im|ik|ük|un|ün|ı|i)$",
        r"(?:ler|lar)?(?:da|de|ta|te)ym(?:ışım|işim|ışız|işiz|ış|iş)$",
        r"(?:ler|lar)?(?:da|de|ta|te)y(?:ım|im|ız|iz)$",
        r"(?:ler|lar)?(?:da|de|ta|te)k(?:i)$",
        r"(?:ler|lar)?(?:dan|den|tan|ten)$",
        r"(?:ler|lar)?(?:da|de|ta|te)$",
        r"(?:ım|im|um|üm|m)(?:da|de|ta|te)yd(?:ım|im)$",
        r"(?:ım|im|um|üm|m)(?:da|de|ta|te)$",
        r"(?:umuz|ümüz|unuz|ünüz|ları|leri)$",
        r"(?:ler|lar)$",
    ]
    for p in patterns:
        subbed = re.sub(p, "", w)
        if len(subbed) >= 3 and subbed != w:
            w = subbed
            break
    return w.capitalize()


def extract_user_symbols(text: str, lang: str = "tr") -> List[str]:
    """Kullanıcının kendi dilinde arayüzde gösterilecek 3-4 anahtar sembolü ayıklar."""
    words = re.findall(r"\b[^\W\d_]{2,}\b", text.lower(), flags=re.UNICODE)
    meaningful = []
    for w in words:
        if w in MULTILINGUAL_STOPWORDS:
            continue
        if len(w) == 2 and normalize_turkish(w) not in TWO_LETTER_SYMBOLS:
            continue
        cleaned = clean_turkish_symbol_root(w) if lang == "tr" else w.capitalize()
        if cleaned.lower() not in MULTILINGUAL_STOPWORDS and len(cleaned) >= 2:
            meaningful.append(cleaned)

    if meaningful:
        seen = set()
        unique = []
        for w in meaningful:
            if w not in seen:
                seen.add(w)
                unique.append(w)
        if unique:
            return unique[:4]

    defaults: Dict[str, List[str]] = {
        "ru": ["Вода", "Дорога", "Свет"],
        "en": ["Water", "Path", "Light"],
        "de": ["Wasser", "Weg", "Licht"],
        "es": ["Agua", "Camino", "Luz"],
        "ar": ["الماء", "الطريق", "النور"],
        "fr": ["Eau", "Chemin", "Lumière"],
        "tr": ["Su", "Yol", "Işık"]
    }
    return defaults.get(lang, defaults["tr"])


def detect_tradition_id(filename: str, sample_text: str = "") -> str:
    """Dosya adından veya içerik örneğinden geleneği (islam_dogu, antik_akdeniz, psikoloji) otomatik belirler."""
    fn = normalize_turkish(filename.lower())
    if any(k in fn for k in (
        "islam", "sirin", "nablusi", "nabulusi", "dogu", "cafer", "sadik",
        "suleyman", "gazali", "arabi", "tasavvuf", "kuran", "hadis", "tabirname", "diyanet",
        "ansiklopedi", "sunnah", "jibali"
    )):
        return "islam_dogu"
    if any(k in fn for k in (
        "antik", "yunan", "artemidorus", "oneirocritica", "roma", "akdeniz",
        "mitoloji", "misir", "mezopotamya", "babil", "asur", "homeros", "hipokrat", "galen", "kehanet",
        "aristo", "aristotle", "platon", "plato", "parva"
    )):
        return "antik_akdeniz"
    if any(k in fn for k in (
        "psik", "jung", "freud", "arketip", "bilinc", "analiz", "adler",
        "fromm", "lacan", "modern", "terapi", "golge", "anima", "ego", "miller"
    )):
        return "psikoloji"

    if sample_text:
        sample_norm = normalize_turkish(sample_text[:4000].lower())
        scores = {
            "islam_dogu": sum(1 for k in ("ibn sirin", "nablusi", "delalet", "tabir", "cafer", "hayra", "rizik", "hikmet", "cenab") if k in sample_norm),
            "antik_akdeniz": sum(1 for k in ("artemidorus", "antik", "kehanet", "mitoloji", "tanri", "oneirocritica", "kader", "tapinak") if k in sample_norm),
            "psikoloji": sum(1 for k in ("jung", "freud", "bilincalti", "bilincdisi", "arketip", "psikanaliz", "bastirilmis", "golge", "ego") if k in sample_norm),
        }
        best_trad = max(scores, key=scores.get)
        if scores[best_trad] > 0:
            return best_trad

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
                page_txt = page.get_text()
                if page_txt and page_txt.strip():
                    text_content.append(page_txt.strip())
        return "\n\n".join(text_content)
    except Exception as e:
        logger.error(f"PDF okunurken hata oluştu ({filepath}): {e}")
        return ""


def _split_into_optimal_passages(text: str, target_max_chars: int = 680) -> List[str]:
    """
    Ansiklopedi ve sözlüklerdeki madde başlıklarını (örn. 'KAYA', 'DENİZ', 'Shore.')
    altındaki açıklama paragrafıyla birleştirerek böler; böylece hiçbir sembol başlığı kaybolmaz.
    """
    lines = text.split("\n")
    normalized_lines: List[str] = []
    pending_header = ""

    for ln in lines:
        s = ln.strip()
        if not s:
            if not pending_header:
                normalized_lines.append("")
            continue
        # Kısa sözlük/ansiklopedi başlığı tespiti (örn. 'DENİZ', 'KAYA', 'Abbey.*')
        if (2 <= len(s) <= 42 and len(s.split()) <= 4 and
                (s.isupper() or s.endswith("*") or s.endswith(":")) and
                not s.endswith((".", "!", "?"))):
            pending_header = s.rstrip("*: ")
            normalized_lines.append("")
        else:
            if pending_header:
                normalized_lines.append(f"{pending_header}: {s}")
                pending_header = ""
            else:
                normalized_lines.append(s)

    joined_text = "\n".join(normalized_lines)
    raw_blocks = re.split(r"\n\s*\n", joined_text)
    passages: List[str] = []

    for block in raw_blocks:
        block_str = block.strip()
        if not block_str:
            continue

        if len(block_str) > target_max_chars:
            sub_lines = [ln.strip() for ln in block_str.split("\n") if ln.strip()]
        else:
            sub_lines = [block_str]

        current_buf = ""
        for line in sub_lines:
            cleaned_line = " ".join(line.split()).strip()
            if not cleaned_line:
                continue

            if len(cleaned_line) > target_max_chars:
                if current_buf:
                    passages.append(current_buf.strip())
                    current_buf = ""
                sentences = re.split(r"(?<=[.!?])\s+", cleaned_line)
                sent_buf = ""
                for s in sentences:
                    if len(sent_buf) + len(s) + 1 <= target_max_chars:
                        sent_buf = f"{sent_buf} {s}".strip() if sent_buf else s
                    else:
                        if sent_buf:
                            passages.append(sent_buf.strip())
                        if len(s) > target_max_chars:
                            for i in range(0, len(s), target_max_chars):
                                passages.append(s[i:i + target_max_chars].strip())
                            sent_buf = ""
                        else:
                            sent_buf = s
                if sent_buf:
                    passages.append(sent_buf.strip())
            else:
                if len(current_buf) + len(cleaned_line) + 1 <= target_max_chars:
                    current_buf = f"{current_buf} {cleaned_line}".strip() if current_buf else cleaned_line
                else:
                    if current_buf:
                        passages.append(current_buf.strip())
                    current_buf = cleaned_line

        if current_buf:
            passages.append(current_buf.strip())

    return passages


def chunk_text(text: str, source_name: str) -> List[Dict[str, Any]]:
    """Metni anlamlı paragraflara böler, Türkçe/İngilizce/Arapça kökleri indeksler ve gelenek etiketi ekler."""
    tradition_id = detect_tradition_id(source_name, sample_text=text[:4000])
    passages = _split_into_optimal_passages(text, target_max_chars=680)
    chunks = []

    for p in passages:
        cleaned = " ".join(p.split()).strip()
        if len(cleaned) >= 35:
            norm = normalize_turkish(cleaned)
            raw_words = re.findall(r"\b[^\W\d_]{2,}\b", norm, flags=re.UNICODE)
            if not raw_words:
                continue

            words_set: Set[str] = set()
            for rw in raw_words:
                if len(rw) == 2 and rw not in TWO_LETTER_SYMBOLS:
                    continue
                words_set.add(rw)
                # Türkçe çekim eki soyulmuş kökü de indekse ekle (örn. 'denizde' -> 'deniz')
                if len(rw) >= 4 and rw.isascii():
                    st = clean_turkish_stem(rw)
                    if st != rw and (len(st) >= 3 or st in TWO_LETTER_SYMBOLS):
                        words_set.add(st)
                # Arapça belirlilik takısı ('ال') soyulmuş kökü de indekse ekle
                elif len(rw) >= 4 and re.search(r"[\u0600-\u06FF]", rw):
                    for ar_pfx in ("وال", "بال", "كال", "فال", "لل", "ال"):
                        if rw.startswith(ar_pfx) and len(rw) - len(ar_pfx) >= 2:
                            words_set.add(rw[len(ar_pfx):])
                            break

            head_words = set(re.findall(r"\b[^\W\d_]{2,}\b", norm[:75], flags=re.UNICODE))

            chunks.append({
                "text": cleaned,
                "source": source_name,
                "tradition": tradition_id,
                "tradition_title": TRADITIONS[tradition_id]["title"],
                "norm": norm,
                "words": words_set,
                "head_words": head_words,
                "is_substantive": len(cleaned) >= 90
            })

    return chunks


def index_books():
    """`backend/books/` klasöründeki tüm kitapları (.txt, .pdf, .md) okur ve gelenek metadata'sı ile belleğe alır."""
    global CHUNKS_DB, CHUNKS_BY_TRADITION

    if not os.path.exists(BOOKS_DIR):
        os.makedirs(BOOKS_DIR, exist_ok=True)
        logger.warning(f"'{BOOKS_DIR}' klasörü mevcut değildi, yeni oluşturuldu.")

    book_files = sorted(glob.glob(os.path.join(BOOKS_DIR, "*.*")))
    supported_files = [f for f in book_files if f.lower().endswith((".txt", ".pdf", ".md"))]

    if not supported_files:
        logger.warning(f"'{BOOKS_DIR}' klasöründe .txt, .pdf veya .md kitap bulunamadı.")
        return

    logger.info(f"İndekslenecek {len(supported_files)} adet kitap bulundu: {[os.path.basename(f) for f in supported_files]}")

    all_chunks: List[Dict[str, Any]] = []

    for filepath in supported_files:
        filename = os.path.basename(filepath)
        content = ""
        if filepath.lower().endswith((".txt", ".md")):
            content = read_text_file(filepath)
        elif filepath.lower().endswith(".pdf"):
            content = read_pdf_file(filepath)

        if content:
            file_chunks = chunk_text(content, filename)
            all_chunks.extend(file_chunks)
            detected_trad = file_chunks[0]["tradition"] if file_chunks else detect_tradition_id(filename, content[:4000])
            logger.info(f"'{filename}' ({detected_trad}) dosyasından {len(file_chunks)} paragraf çıkarıldı.")

    if not all_chunks:
        logger.warning("Kitaplardan ayrıştırılabilir anlamlı metin parçası çıkarılamadı.")
        return

    CHUNKS_DB = all_chunks
    CHUNKS_BY_TRADITION = {
        t_id: [c for c in all_chunks if c.get("tradition") == t_id]
        for t_id in TRADITIONS.keys()
    }
    logger.info(f"✅ Toplam {len(supported_files)} kitaptan {len(CHUNKS_DB)} paragraf metadata ile arama belleğine yüklendi. (Gelenek Dağılımı: { {t: len(cl) for t, cl in CHUNKS_BY_TRADITION.items()} })")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Oneiro RAG Backend başlatılıyor...")
    index_books()
    logger.info("✅ Oneiro RAG Motoru hazır (Dış ping / UptimeRobot ile 7/24 uyanık tutulur).")
    yield
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
    language: Optional[str] = Field(None, description="Hedef çıktı dili (tr, en, es, ar, de, fr, pt, ru, hi, zh)")


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
# 6. KAVRAM KÜMESİ & SEMBOL BAZLI HASSAS RAG RETRIEVAL MOTORU
# -----------------------------------------------------------------------------
def score_passage_relevance(
    concepts: List[Dict[str, Any]],
    dream_keywords: List[str],
    chunk: Dict[str, Any]
) -> Tuple[float, List[str]]:
    """
    Rüyadaki her bir somut sembol/kavram kümesi (örn: 'kaya', 'deniz', 'sahil') ile
    kitap pasajı arasındaki doğrudan veri eşleşmesini hesaplar.
    Yanlış pozitif üreten 3 harfli ön-ek (kartal -> karşı) eşleşmeleri kaldırılmıştır;
    yalnızca gerçek sembol/kelime kökü ve sözlük madde başlığı (headword) eşleşmeleri puanlanır.
    """
    chunk_words = chunk.get("words", set())
    head_words = chunk.get("head_words", set())
    chunk_norm = chunk.get("norm", "")
    if not chunk_words:
        return 0.0, []

    total_score = 0.0
    matched_clusters: List[str] = []

    # 1. Kavram Kümesi Eşleşmesi (Çok Dilli Sembol Karşılıkları: TR + EN + AR + Kök)
    for concept in concepts:
        cid = concept["cluster_id"]
        c_terms = concept["search_terms"]
        common = chunk_words.intersection(c_terms)
        if common:
            # Sözlük madde başlığında (ilk 75 karakterde) geçiyorsa yüksek öncelik ver
            head_common = head_words.intersection(c_terms)
            if head_common:
                total_score += 8.0
            else:
                total_score += 4.5
            matched_clusters.append(cid)
        else:
            # 5+ harfli Türkçe/İngilizce sembol köklerinin çekimli halleri (örn: "merdivenlerden")
            for term in c_terms:
                if len(term) >= 5 and term in chunk_norm:
                    total_score += 3.0
                    matched_clusters.append(cid)
                    break

    # 2. Ek Anahtar Kelime Eşleşmesi (Küme dışı özel kelimeler)
    extra_matches = 0
    for kw in dream_keywords:
        if len(kw) < 3:
            continue
        if kw in chunk_words:
            extra_matches += 1
            if kw in head_words:
                total_score += 3.5
            else:
                total_score += 1.8

    if not matched_clusters and extra_matches == 0:
        return 0.0, []

    # Birden fazla rüya sembolünü aynı anda barındıran pasajlara kombo bonusu
    unique_clusters = list(dict.fromkeys(matched_clusters))
    if len(unique_clusters) >= 2:
        total_score += len(unique_clusters) * 3.0

    # Ansiklopedik / kurallı içerik bonusu (çok kısa başlıklar yerine açıklamalı maddeler)
    text_len = len(chunk.get("text", ""))
    if 90 <= text_len <= 950:
        total_score += 0.8

    denom = max(1.0, (len(concepts) * 6.0) + 2.0)
    normalized_score = min(0.99, max(0.30, total_score / denom))
    return round(normalized_score, 4), unique_clusters


def retrieve_by_tradition(dream_text: str, tradition_id: str, top_k: int = 4) -> List[Dict[str, Any]]:
    """
    Belirli bir geleneğe ait kitaplar içinden rüyadaki HER BİR SEMBOLÜ kapsayacak şekilde
    en alakalı pasajları getirir.
    Örneğin kullanıcı rüyasında 'kaya, deniz ve sahil' gördüyse, tek bir sembolün 4 pasajını
    getirmek yerine hem 'kaya', hem 'deniz', hem de 'sahil' için kitaptaki en iyi maddeleri seçer.
    """
    tradition_chunks = CHUNKS_BY_TRADITION.get(tradition_id)
    if tradition_chunks is None:
        tradition_chunks = [c for c in CHUNKS_DB if c.get("tradition") == tradition_id]
    if not tradition_chunks:
        logger.warning(f"'{tradition_id}' geleneğine ait indekslenmiş pasaj bulunamadı.")
        return []

    concepts = extract_dream_concepts(dream_text)
    keywords = extract_keywords(dream_text)
    scored: List[Dict[str, Any]] = []

    if concepts or keywords:
        for c in tradition_chunks:
            rel_score, matched_cids = score_passage_relevance(concepts, keywords, c)
            if rel_score > 0:
                scored.append({
                    "chunk": c,
                    "score": rel_score,
                    "matched_concepts": matched_cids,
                    "is_fallback": False
                })

        scored.sort(key=lambda x: (x["score"], len(x["matched_concepts"])), reverse=True)

    if scored:
        selected: List[Dict[str, Any]] = []
        seen_chunk_ids = set()

        # Adım 1: Rüyadaki her bir sembol/kavram için en yüksek puanlı pasajı garanti altına al
        for concept in concepts:
            cid = concept["cluster_id"]
            for item in scored:
                c_id = item["chunk"]["id"]
                if c_id not in seen_chunk_ids and cid in item["matched_concepts"]:
                    selected.append(item)
                    seen_chunk_ids.add(c_id)
                    break
            if len(selected) >= top_k:
                break

        # Adım 2: Kalan kontenjanı genel en yüksek puanlı pasajlarla tamamla
        for item in scored:
            if len(selected) >= top_k:
                break
            c_id = item["chunk"]["id"]
            if c_id not in seen_chunk_ids:
                selected.append(item)
                seen_chunk_ids.add(c_id)

        return selected[:top_k]

    # BOŞ EŞLEŞME GÜVENLİK KATMANI
    logger.info(f"'{tradition_id}' geleneğinde doğrudan sembol eşleşmesi bulunamadı. Temsili pasajlar seçiliyor.")
    substantive_chunks = [c for c in tradition_chunks if c.get("is_substantive", len(c.get("text", "")) >= 90)]
    fallback_pool = substantive_chunks if len(substantive_chunks) >= 2 else tradition_chunks
    sorted_by_depth = sorted(fallback_pool, key=lambda x: len(x.get("text", "")), reverse=True)
    fallback_chunks = sorted_by_depth[:max(top_k, 2)]

    return [{"chunk": c, "score": 0.45, "matched_concepts": [], "is_fallback": True} for c in fallback_chunks[:top_k]]


def retrieve_top_k(dream_text: str, top_k: int = 4, tradition_id: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Tüm kitaplar (veya tek bir gelenek) arasından her sembolü kapsayan en iyi 'top_k' pasajı getirir.
    """
    if tradition_id:
        return retrieve_by_tradition(dream_text, tradition_id, top_k=top_k)

    if not CHUNKS_DB:
        return []

    concepts = extract_dream_concepts(dream_text)
    keywords = extract_keywords(dream_text)
    scored: List[Dict[str, Any]] = []

    if concepts or keywords:
        for c in CHUNKS_DB:
            rel_score, matched_cids = score_passage_relevance(concepts, keywords, c)
            if rel_score > 0:
                scored.append({
                    "chunk": c,
                    "score": rel_score,
                    "matched_concepts": matched_cids,
                    "is_fallback": False
                })
        scored.sort(key=lambda x: (x["score"], len(x["matched_concepts"])), reverse=True)

    if scored:
        selected: List[Dict[str, Any]] = []
        seen_ids = set()
        for concept in concepts:
            cid = concept["cluster_id"]
            for item in scored:
                c_id = item["chunk"]["id"]
                if c_id not in seen_ids and cid in item["matched_concepts"]:
                    selected.append(item)
                    seen_ids.add(c_id)
                    break
            if len(selected) >= top_k:
                break
        for item in scored:
            if len(selected) >= top_k:
                break
            c_id = item["chunk"]["id"]
            if c_id not in seen_ids:
                selected.append(item)
                seen_ids.add(c_id)
        return selected[:top_k]

    substantive = [c for c in CHUNKS_DB if c.get("is_substantive", len(c.get("text", "")) >= 90)]
    fallback_pool = substantive if len(substantive) >= 2 else CHUNKS_DB
    sorted_by_depth = sorted(fallback_pool, key=lambda x: len(x.get("text", "")), reverse=True)
    return [{"chunk": c, "score": 0.45, "matched_concepts": [], "is_fallback": True} for c in sorted_by_depth[:top_k]]


# -----------------------------------------------------------------------------
# 6.5. ÇİFT MOTORLU YAPAY ZEKA STRATEJİSİ (GOOGLE GEMINI FLASH + DEEPSEEK YEDEK)
# -----------------------------------------------------------------------------
GEMINI_MODELS = ["gemini-2.5-flash", "gemini-2.0-flash"]
GEMINI_DEFAULT_TIMEOUT = 6.5  # Hızlı ve takılmayan yanıt için 6.5 saniye zaman aşımı (gecikirse derhal DeepSeek'e geçer)

def _sync_gemini_post(url: str, payload: dict, timeout: float = 6.5) -> Optional[dict]:
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
    except urllib.error.HTTPError as he:
        logger.warning(f"Google Gemini HTTP {he.code} hatası ({url.split('models/')[1].split(':')[0]}): {he.reason}")
    except Exception as e:
        logger.warning(f"Google Gemini isteği uyarısı ({url.split('models/')[1].split(':')[0]}): {e}")
    return None


async def call_gemini_json(system_prompt: str, user_prompt: str, timeout: float = 6.5) -> Optional[Dict[str, Any]]:
    """Google Gemini API'yi 4096 token ve düşük sıcaklık (0.35 - kaynağa sadık) ile çağırıp JSON döner."""
    if not GEMINI_API_KEY:
        return None

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
            "temperature": 0.35,
            "maxOutputTokens": 4096,
            "thinkingConfig": {
                "thinkingBudget": 0
            }
        }
    }

    for model_name in GEMINI_MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={GEMINI_API_KEY}"
        data = await asyncio.to_thread(_sync_gemini_post, url, payload, timeout)
        if data:
            candidates = data.get("candidates", [])
            if candidates:
                parts = candidates[0].get("content", {}).get("parts", [])
                if parts:
                    raw_text = parts[0].get("text", "")
                    if raw_text:
                        try:
                            return json.loads(raw_text)
                        except Exception as e:
                            logger.warning(f"Gemini ({model_name}) JSON parse hatası: {e}")
    return None


async def call_gemini_text(system_prompt: str, user_prompt: str, timeout: float = 6.5) -> Optional[str]:
    """Google Gemini API'yi 4096 token ve 0.35 sıcaklık ile çağırıp metin döner."""
    if not GEMINI_API_KEY:
        return None

    payload = {
        "contents": [
            {
                "parts": [
                    {"text": f"SİSTEM TALİMATI:\n{system_prompt}\n\nKULLANICI TALEBİ:\n{user_prompt}"}
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.35,
            "maxOutputTokens": 4096,
            "thinkingConfig": {
                "thinkingBudget": 0
            }
        }
    }

    for model_name in GEMINI_MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={GEMINI_API_KEY}"
        data = await asyncio.to_thread(_sync_gemini_post, url, payload, timeout)
        if data:
            candidates = data.get("candidates", [])
            if candidates:
                parts = candidates[0].get("content", {}).get("parts", [])
                if parts:
                    text = parts[0].get("text", "")
                    if text and text.strip():
                        return text.strip()
    return None


async def call_gemini_chat(contents: List[Dict[str, Any]], timeout: float = 6.5) -> Optional[str]:
    """Google Gemini API ile sohbet yanıtı üretir (4096 token, 0.35 sıcaklık)."""
    if not GEMINI_API_KEY:
        return None

    payload = {
        "contents": contents,
        "generationConfig": {
            "temperature": 0.35,
            "maxOutputTokens": 4096,
            "thinkingConfig": {
                "thinkingBudget": 0
            }
        }
    }

    for model_name in GEMINI_MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={GEMINI_API_KEY}"
        data = await asyncio.to_thread(_sync_gemini_post, url, payload, timeout)
        if data:
            candidates = data.get("candidates", [])
            if candidates:
                parts = candidates[0].get("content", {}).get("parts", [])
                if parts:
                    text = parts[0].get("text", "")
                    if text and text.strip():
                        return text.strip()
    return None


async def generate_dream_interpretation(system_prompt: str, user_prompt: str) -> Dict[str, Any]:
    """
    Hibrit Çift Motor Stratejisi:
    1. Öncelikli olarak Google Gemini (Ücretsiz, 4096 token) çağrılır.
    2. Zaman aşımına uğrarsa veya hata verirse otomatik olarak DeepSeek API devreye girer.
    """
    if GEMINI_API_KEY:
        try:
            logger.info(f"⚡ [1/2] Google Gemini API çağrılıyor (Zaman aşımı: {GEMINI_DEFAULT_TIMEOUT}s)...")
            gemini_res = await asyncio.wait_for(
                call_gemini_json(system_prompt, user_prompt, timeout=GEMINI_DEFAULT_TIMEOUT),
                timeout=GEMINI_DEFAULT_TIMEOUT + 0.5
            )
            if gemini_res and isinstance(gemini_res, dict):
                logger.info("✅ Google Gemini başarıyla yanıt üretti.")
                if "primary_interpretation" in gemini_res and gemini_res["primary_interpretation"]:
                    gemini_res["primary_interpretation"] = gemini_res["primary_interpretation"].strip()
                return gemini_res
        except asyncio.TimeoutError:
            logger.warning("⏱️ Google Gemini zaman sınırını aştı! DeepSeek yedek motoruna anında geçiliyor...")
        except Exception as e:
            logger.warning(f"⚠️ Google Gemini çağrısında hata ({e}), DeepSeek yedek motoruna geçiliyor...")

    if deepseek_client:
        try:
            logger.info("🛡️ [2/2] DeepSeek API devreye giriyor (3500 token)...")
            completion = await deepseek_client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.35,
                max_tokens=3500,
                response_format={"type": "json_object"}
            )
            raw_text = completion.choices[0].message.content or "{}"
            parsed = json.loads(raw_text)
            if "primary_interpretation" in parsed and parsed["primary_interpretation"]:
                parsed["primary_interpretation"] = parsed["primary_interpretation"].strip()
            logger.info("✅ DeepSeek API başarıyla yanıt üretti.")
            return parsed
        except Exception as e:
            logger.warning(f"DeepSeek JSON çıktısı ayrıştırılırken hata: {e}")

    return {}


async def generate_unlock_interpretation(system_prompt: str, dream_text: str) -> Optional[str]:
    """Tekil gelenek kilit açma için Gemini + DeepSeek fallback motoru."""
    if GEMINI_API_KEY:
        try:
            logger.info(f"⚡ [1/2 Unlock] Google Gemini çağrılıyor (Zaman aşımı: {GEMINI_DEFAULT_TIMEOUT}s)...")
            gemini_text = await asyncio.wait_for(
                call_gemini_text(system_prompt, f'RÜYA: "{dream_text}"', timeout=GEMINI_DEFAULT_TIMEOUT),
                timeout=GEMINI_DEFAULT_TIMEOUT + 0.5
            )
            if gemini_text and gemini_text.strip():
                logger.info("✅ Google Gemini unlock yanıtı başarıyla döndü.")
                return gemini_text.strip()
        except asyncio.TimeoutError:
            logger.warning("⏱️ Google Gemini unlock zaman sınırını aştı, DeepSeek'e geçiliyor...")
        except Exception as e:
            logger.warning(f"⚠️ Google Gemini unlock hatası ({e}), DeepSeek'e geçiliyor...")

    if deepseek_client:
        try:
            logger.info("🛡️ [2/2 Unlock] DeepSeek API devreye giriyor (3000 token)...")
            completion = await deepseek_client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f'RÜYA: "{dream_text}"'}
                ],
                temperature=0.35,
                max_tokens=3000
            )
            res = completion.choices[0].message.content
            if res and res.strip():
                logger.info("✅ DeepSeek unlock yanıtı başarıyla döndü.")
                return res.strip()
        except Exception as e:
            logger.error(f"DeepSeek unlock hatası: {e}")

    return None


async def generate_chat_reply(message: str, system_context: Optional[str] = None, history: Optional[List[Dict[str, Any]]] = None) -> str:
    """Rüya yorumcusu soru-cevap sohbeti için RAG destekli çift motor (Gemini -> DeepSeek fallback)."""
    # Kullanıcının yeni sorusunda geçen semboller için de kütüphaneden somut pasajlar çek
    combined_query = f"{system_context or ''} {message}"
    rag_matches = retrieve_top_k(combined_query, top_k=3)
    rag_context_str = "\n".join(
        [f"- [{m['chunk']['source']}]: {m['chunk']['text']}" for m in rag_matches]
    ) if rag_matches else ""

    chat_rules = (
        "Sen DreamApp'in kaynak kitaplara dayalı Rüya Yorumcususun.\n"
        "KURALLAR:\n"
        "1. Asla standart bir yapay zeka (Claude/ChatGPT) gibi yuvarlak, süslü, soyut veya ağdalı konuşma. 'Teemmül', 'kadim eşik', 'mühürlenmek', 'içsel yolculuk' gibi anlaşılması güç veya klişe kelimeler kullanma.\n"
        "2. Kullanıcının rüyasında gördüğü somut nesneleri, mekanları ve olayları doğrudan cümle içinde anarak (örneğin: 'Rüyanızda bahsettiğiniz kaya ve sahil detayı...'), kütüphanemizdeki kaynak kitaplarda (İbn-i Sîrîn, Nablusî, Artemidorus, Miller, Jung, Freud) bu semboller için verilen somut hükümleri açık ve sade bir dille anlat.\n"
        "3. Her cümleni net, anlaşılır ve eksiksiz tamamla."
    )

    full_context = chat_rules
    if system_context:
        full_context += f"\n\nKULLANICININ RÜYA BİLGİSİ:\n{system_context}"
    if rag_context_str:
        full_context += f"\n\nKÜTÜPHANEDEN EŞLEŞEN KAYNAK KİTAP VERİLERİ:\n{rag_context_str}"

    gemini_contents = [
        {
            "role": "user",
            "parts": [{"text": full_context}]
        },
        {
            "role": "model",
            "parts": [{"text": "Anlaşıldı. Kullanıcının rüyasındaki somut unsurları ve kütüphanedeki kaynak kitap verilerini esas alarak açık, sade ve veriye dayalı cevaplar vereceğim."}]
        }
    ]
    if history:
        for item in history:
            is_user = item.get("is_user", item.get("isUser", True)) if isinstance(item, dict) else True
            text = item.get("text", "") if isinstance(item, dict) else str(item)
            if text:
                role = "user" if is_user else "model"
                gemini_contents.append({"role": role, "parts": [{"text": text}]})
    gemini_contents.append({"role": "user", "parts": [{"text": message}]})

    if GEMINI_API_KEY:
        try:
            logger.info(f"⚡ [1/2 Chat] Google Gemini çağrılıyor (Zaman aşımı: {GEMINI_DEFAULT_TIMEOUT}s)...")
            gemini_res = await asyncio.wait_for(
                call_gemini_chat(gemini_contents, timeout=GEMINI_DEFAULT_TIMEOUT),
                timeout=GEMINI_DEFAULT_TIMEOUT + 0.5
            )
            if gemini_res and gemini_res.strip():
                logger.info("✅ Google Gemini sohbet yanıtı başarıyla döndü.")
                return gemini_res.strip()
        except asyncio.TimeoutError:
            logger.warning("⏱️ Google Gemini chat zaman sınırını aştı, DeepSeek'e geçiliyor...")
        except Exception as e:
            logger.warning(f"⚠️ Google Gemini chat hatası ({e}), DeepSeek'e geçiliyor...")

    if deepseek_client:
        try:
            logger.info("🛡️ [2/2 Chat] DeepSeek API devreye giriyor (3000 token)...")
            deepseek_messages = [{"role": "system", "content": full_context}]

            if history:
                for item in history:
                    is_user = item.get("is_user", item.get("isUser", True)) if isinstance(item, dict) else True
                    text = item.get("text", "") if isinstance(item, dict) else str(item)
                    if text:
                        role = "user" if is_user else "assistant"
                        deepseek_messages.append({"role": role, "content": text})

            deepseek_messages.append({"role": "user", "content": message})

            completion = await deepseek_client.chat.completions.create(
                model="deepseek-chat",
                messages=deepseek_messages,
                temperature=0.35,
                max_tokens=3000
            )
            reply = completion.choices[0].message.content
            if reply and reply.strip():
                logger.info("✅ DeepSeek sohbet yanıtı başarıyla döndü.")
                return reply.strip()
        except Exception as e:
            logger.error(f"DeepSeek chat hatası: {e}")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Yorum servisine ulaşılamadı: {str(e)}"
            )

    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Yorum servisi şu anda yanıt veremiyor. Lütfen tekrar deneyin."
    )


# -----------------------------------------------------------------------------
# 7. ENDPOINT'LER
# -----------------------------------------------------------------------------
@app.get("/", summary="Kök Uç Noktası (UptimeRobot / Health)")
@app.head("/", summary="HEAD Sağlık Kontrolü")
@app.get("/health", summary="Sunucu Durum ve Sağlık Kontrolü")
@app.head("/health", summary="HEAD Sağlık Kontrolü")
async def health_check():
    """Render.com uyanıklık ve anlık sistem durumu (0 ms)."""
    global CHUNKS_DB
    sources = sorted(list(set(c["source"] for c in CHUNKS_DB))) if CHUNKS_DB else []
    by_tradition = {
        t_id: len([c for c in CHUNKS_DB if c.get("tradition") == t_id])
        for t_id in TRADITIONS.keys()
    }
    return {
        "status": "healthy",
        "service": "Oneiro RAG Backend",
        "version": "2.6.0",
        "total_books": len(sources),
        "total_chunks": len(CHUNKS_DB),
        "chunks_by_tradition": by_tradition,
        "books_loaded": sources,
        "dual_ai_strategy": {
            "primary": "Google Gemini (gemini-2.5-flash / gemini-2.0-flash) [6.5s zaman aşımı, 4096 token, temp=0.35]",
            "fallback": "DeepSeek (deepseek-chat) [3500 token, temp=0.35]",
            "gemini_configured": bool(GEMINI_API_KEY),
            "deepseek_configured": bool(DEEPSEEK_API_KEY)
        },
        "render_keep_alive": True
    }


@app.get("/books", summary="Yüklü Kitapları ve Gelenek Dağılımını Listele")
async def list_loaded_books():
    """`backend/books/` klasöründen indekslenmiş tüm kitapları ve paragraf sayılarını döner."""
    global CHUNKS_DB
    book_stats: Dict[str, Dict[str, Any]] = {}
    for c in CHUNKS_DB:
        src = c["source"]
        if src not in book_stats:
            book_stats[src] = {
                "filename": src,
                "tradition": c["tradition"],
                "tradition_title": c["tradition_title"],
                "chunks_count": 0
            }
        book_stats[src]["chunks_count"] += 1
    return {
        "total_books": len(book_stats),
        "total_chunks": len(CHUNKS_DB),
        "books": list(book_stats.values())
    }


@app.post("/books/reindex", summary="Yeni Eklenen Kitapları Yeniden İndeksle")
async def reindex_books_endpoint():
    """Sunucuyu yeniden başlatmaya gerek kalmadan `backend/books/` klasöründeki yeni PDF/TXT kitapları tarar."""
    index_books()
    return await list_loaded_books()


@app.post("/interpret", response_model=DreamInterpretResponse, summary="Kitap Verilerine Dayalı Somut Rüya Yorumu")
async def interpret_dream(request: DreamInterpretRequest):
    """
    1. Rüyadaki tüm somut sembolleri (örn: kaya, deniz, sahil) tespit eder ve 11 kaynak kitaptan
       her bir sembolün tam karşılığını getirir (top_k=4).
    2. Sıradan AI / Claude klişelerinden tamamen uzak, doğrudan kitaptaki hükümleri ve
       kullanıcının rüyasındaki cümleleri/nesneleri eşleştiren anlaşılır bir analiz üretir.
    """
    global deepseek_client

    dream_text = request.dream_text.strip()
    if not dream_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Lütfen geçerli bir rüya metni giriniz."
        )

    logger.info(f"Rüya analizi talebi alındı. Kullanıcı ID: {request.user_id or 'Misafir/Anonim'}")

    lang = request.language.lower() if request.language else detect_language(dream_text)
    if lang not in ("tr", "en", "es", "ar", "de", "fr", "pt", "ru", "hi", "zh"):
        lang = detect_language(dream_text)
    preferred_trad = request.preferred_tradition or "islam_dogu"
    if preferred_trad not in TRADITIONS:
        preferred_trad = "islam_dogu"

    other_trads = [t for t in TRADITIONS.keys() if t != preferred_trad]

    # Dil ve gelenek metadata'ları
    primary_meta = get_tradition_metadata(preferred_trad, lang)
    other_meta_0 = get_tradition_metadata(other_trads[0], lang)
    other_meta_1 = get_tradition_metadata(other_trads[1], lang)

    # Her gelenekten rüyadaki tüm sembolleri kapsayacak şekilde en alakalı 4 pasajı çek
    matched_chunks: Dict[str, List[Dict[str, Any]]] = {}
    sources_payload: List[SourceUsedItem] = []

    for t_id in TRADITIONS.keys():
        matches = retrieve_by_tradition(dream_text, t_id, top_k=4)
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
    primary_chunk_text = "\n\n".join(
        [f"[Kaynak Kitap: {m['chunk']['source']}]\n{m['chunk']['text']}" for m in primary_matches]
    ) if primary_matches else ""

    other_context_lines = []
    for t_id in other_trads:
        t_matches = matched_chunks.get(t_id, [])
        if t_matches:
            t_meta = get_tradition_metadata(t_id, lang)
            t_text = "\n".join([f"- ({m['chunk']['source']}): {m['chunk']['text']}" for m in t_matches])
            other_context_lines.append(f"[{t_meta['title']} Kaynak Verileri]:\n{t_text}")

    # Sembol çıkarımı (Kullanıcının dilindeki özgün semboller)
    symbols = extract_user_symbols(dream_text, lang)

    # Veriye Dayalı, Anlaşılır ve Klişe Karşıtı Sistem Promptu
    system_prompt = (
        "Sen 11 temel rüya tabiri ve psikoloji kitabından oluşan RAG kütüphanesini kullanan bir Rüya Veri Analistisin.\n"
        "Amacın, sıradan bir yapay zekanın (Claude veya ChatGPT gibi) verdiği genel geçer, yuvarlak ve süslü cevaplardan TAMAMEN FARKLI olarak; "
        "doğrudan aşağıdaki KAYNAK METİNLERDE yer alan somut kitap verilerine ve rüyadaki olay örgüsüne dayalı, herkesin kolayca anlayabileceği net bir yorum sunmaktır.\n\n"
        "🚫 KESİN YASAKLAR (BUNLARI ASLA YAPMA):\n"
        "1. 'İçsel yolculuğunuzun bir yansıması', 'bilinçaltınızın fısıltısı', 'duygusal dalgalanmalar yaşıyorsunuz', 'belirsizliklerle yüzleşmek', 'yeni bir başlangıç' gibi her rüyaya uyan boş yapay zeka klişeleri KULLANMA!\n"
        "2. 'Teemmül', 'kadim eşik', 'mühürlenmek', 'nefs-i emmare', 'basiret eşiği', 'uhrevi yankı' gibi anlaşılması zor, ağdalı veya eski kelimeler KULLANMA! Günlük, duru, akıcı ve net bir dil kullan.\n\n"
        "✅ ZORUNLU YORUMLAMA YÖNTEMİ (CÜMLE VE SEMBOL EŞLEŞTİRMESİ):\n"
        "1. Kullanıcının rüyasında gördüğü her bir somut unsuru ve eylemi (örneğin kullanıcı 'kaya, deniz ve sahil' gördüyse; kayanın duruşunu, denizin dalgalı veya sakin oluşunu, sahilde yürümesini) kendi cümlenin içinde tek tek ele al.\n"
        "2. Aşağıda sana verilen [Birincil Gelenek Kaynağı] pasajlarında bu semboller için hangi somut karşılıklar, şartlar ve ayrımlar yazıyorsa (örneğin: İbn-i Sîrîn / Nablusî'de kayanın sabır ve sağlam mevki olması, denizin devlet/ilim/rızık olması, sahilin kurtuluş ve emniyet olması; Artemidorus'ta kıyının liman ve umut olması; Miller veya Jung'da bu imgelerin somut karşılıkları) doğrudan bu kitap verilerini rüyadaki sahneyle birleştirerek açıkla.\n"
        "3. Kaynak pasajlar İngilizce veya Arapça olsa bile, içindeki somut kuralları ve örnekleri kullanıcının diline sadık kalarak anlaşılır biçimde aktar.\n\n"
        "🎯 KULLANICI DİLİ KURALI:\n"
        "- JSON çıktısındaki tüm metinleri KESİNLİKLE kullanıcının rüyayı yazdığı dilde üret.\n"
        "- Hiçbir cümleyi yarıda bırakma; tüm cümleleri tam ve noktalı bitir.\n\n"
        "İstenen JSON şeması:\n"
        "{\n"
        '  "symbols": ["Rüyadaki en belirgin 3-4 somut sembol/nesne YALIN haliyle (örneğin: \\"Kaya\\", \\"Deniz\\", \\"Sahil\\")"],\n'
        '  "bilincalti_aynasi": "Rüyadaki sahnenin (mekan, nesneler ve rüya sahibinin eylemi arasındaki ilişkinin) psikolojik kaynaklarımıza (Jung, Freud, Miller) göre ne anlama geldiğini somut olarak açıklayan 2-3 net ve anlaşılır cümle.",\n'
        '  "gunun_pusulasi": "Bu rüyadaki sembollerin verdiği mesaja göre rüya sahibinin günlük hayatında uygulayabileceği 1 cümlelik net, pratik ve anlaşılır tavsiye.",\n'
        f'  "primary_interpretation": "{primary_meta["title"]} ({primary_meta["scholar"]}) kaynak kitaplarımızdaki verilere göre rüyanın detaylı analizi. Rüyadaki her bir sembolü ve cümleyi (örn: kaya, deniz, sahil vb.) tek tek ele alıp, kaynak metinlerde bu semboller için verilen somut hükümleri, şartları ve anlamları açık, sade ve doyurucu 2-3 paragraf halinde anlat.",\n'
        '  "teasers": {\n'
        f'    "{other_trads[0]}": "{other_meta_0["title"]} kaynaklarında bu rüyadaki semboller için verilen farklı ve somut hükmü özetleyen 1 cümlelik net ipucu",\n'
        f'    "{other_trads[1]}": "{other_meta_1["title"]} kaynaklarında bu rüyadaki semboller için verilen farklı ve somut hükmü özetleyen 1 cümlelik net ipucu"\n'
        "  }\n"
        "}\n\n"
        f"KÜTÜPHANEDEN ÇEKİLEN KAYNAK KİTAP VERİLERİ:\n[Birincil Gelenek Kaynağı - {primary_meta['title']}]:\n{primary_chunk_text}\n\n" +
        "\n\n".join(other_context_lines)
    )

    user_prompt = f'KULLANICININ RÜYASI: "{dream_text}"'

    # Çok dilli sade ve anlaşılır yedek (fallback) şablonlar
    offline_fallbacks = {
        "ru": {
            "bilincalti_aynasi": "Образы и действия в вашем сне указывают на потребность опереться на надежную основу и обрести эмоциональное равновесие после периода неопределенности.",
            "gunun_pusulasi": "Опирайтесь на проверенные факты и не торопитесь с решениями, пока ситуация полностью не прояснится.",
            "primary_interpretation": f"Согласно книжным источникам традиции '{primary_meta['title']}' ({primary_meta['scholar']}), символы вашего сна указывают на преодоление препятствий благодаря терпению и выход к безопасному, стабильному положению в делах.",
            "teasers": {
                other_trads[0]: f"В источниках '{other_meta_0['title']}' эти же символы связываются с конкретными переменами в работе и планах...",
                other_trads[1]: f"Согласно книгам '{other_meta_1['title']}', эта сцена отражает поиск точки опоры между сознательным контролем и эмоциями..."
            }
        },
        "en": {
            "bilincalti_aynasi": "The specific objects and setting in your dream point to how you are currently balancing emotional movement with the need for a solid, dependable foundation in waking life.",
            "gunun_pusulasi": "Focus on concrete steps and rely on what is proven and steady rather than reacting to temporary fluctuations.",
            "primary_interpretation": f"According to the source texts of {primary_meta['title']} ({primary_meta['scholar']}), the symbols seen in your dream indicate reaching safety, stability, and tangible progress after navigating through a demanding situation.",
            "teasers": {
                other_trads[0]: f"In {other_meta_0['title']} source books, these specific symbols carry a distinct rule regarding your practical plans...",
                other_trads[1]: f"According to {other_meta_1['title']} texts, the contrast between the elements in your dream highlights a concrete shift in your mindset..."
            }
        },
        "de": {
            "bilincalti_aynasi": "Die konkreten Bilder in Ihrem Traum zeigen das Zusammenspiel zwischen emotionaler Bewegung und dem Wunsch nach Sicherheit und festem Halt.",
            "gunun_pusulasi": "Stützen Sie Ihre heutigen Entscheidungen auf verlässliche Fakten und bewahren Sie Ruhe.",
            "primary_interpretation": f"Nach den Quellbüchern der {primary_meta['title']} ({primary_meta['scholar']}) weisen die Symbole Ihres Traums auf Beständigkeit, Schutz und das Erreichen eines sicheren Ziels nach einer Phase der Anstrengung hin.",
            "teasers": {
                other_trads[0]: f"In den Quellen von {other_meta_0['title']} werden diese Symbole mit konkreten beruflichen und persönlichen Ergebnissen verknüpft...",
                other_trads[1]: f"Laut {other_meta_1['title']} zeigt diese Szene, wie Ihr Geist aktuelle Eindrücke ordnet und stabilisiert..."
            }
        },
        "es": {
            "bilincalti_aynasi": "Los elementos concretos de tu sueño reflejan la búsqueda de un punto firme y seguro frente a situaciones cambiantes en tu vida diaria.",
            "gunun_pusulasi": "Apóyate en hechos concretos y mantén la calma antes de tomar decisiones importantes hoy.",
            "primary_interpretation": f"Según los libros de referencia de {primary_meta['title']} ({primary_meta['scholar']}), los símbolos de tu sueño indican estabilidad, protección y la resolución favorable de un asunto que requería paciencia.",
            "teasers": {
                other_trads[0]: f"En los textos de {other_meta_0['title']}, estos mismos símbolos tienen una interpretación práctica sobre tus proyectos...",
                other_trads[1]: f"Según los libros de {other_meta_1['title']}, la relación entre los objetos de tu sueño muestra cómo estás procesando una decisión..."
            }
        },
        "ar": {
            "bilincalti_aynasi": "تشير العناصر الملموسة في حلمك إلى سعي ذهنك لتحقيق التوازن والاستقرار والوصول إلى بر الأمان في واقعك اليومي.",
            "gunun_pusulasi": "اعتمد على الخطوات الثابتة والواضحة اليوم ولا تتعجل في حسم الأمور قبل اكتمالها.",
            "primary_interpretation": f"وفقاً لكتب ومصادر {primary_meta['title']} ({primary_meta['scholar']})، فإن الرموز الواردة في رؤياك تدل على الثبات والنجاة من الهموم وتحقيق مطلب بعد صبر.",
            "teasers": {
                other_trads[0]: f"في مصادر {other_meta_0['title']}، تحمل هذه الرموز دلالة خاصة تتعلق بمسار أعمالك وعلاقاتك...",
                other_trads[1]: f"وفقاً لكتب {other_meta_1['title']}، تعكس هذه المشاهد تفاعلاً مباشراً بين رغباتك الواعية وحاجتك للأمان..."
            }
        },
        "tr": {
            "bilincalti_aynasi": "Rüyanızdaki mekan ve nesnelerin birbiriyle ilişkisi, günlük hayatınızda hareketli veya belirsiz bir süreçten geçerken sağlam, güvenilir bir dayanak noktası arayışınızı göstermektedir.",
            "gunun_pusulasi": "Bugün kararlarınızı geçici duygulara göre değil, elinizdeki somut verilere ve güvendiğiniz sağlam temellere dayandırarak alın.",
            "primary_interpretation": (
                f"{primary_meta['title']} ({primary_meta['scholar']}) kaynak kitaplarımızdaki verilere göre rüyanızdaki semboller, "
                "sabır ve kararlılık gerektiren bir sürecin ardından güvenli bir konuma ulaşmaya, işlerinizde sağlam bir dayanak elde etmeye ve rızık/ferahlık kapılarının açılmasına işaret etmektedir."
            ),
            "teasers": {
                other_trads[0]: f"{other_meta_0['scholar']} kaynak kitaplarında rüyanızdaki bu semboller, iş ve sosyal hayatınızla ilgili çok daha somut bir kurala bağlanır...",
                other_trads[1]: f"{other_meta_1['scholar']} eserlerinde rüyanızdaki nesnelerin yan yana gelişi, zihninizdeki somut bir karar süreciyle açıklanır..."
            }
        }
    }

    default_payload = offline_fallbacks.get(lang, offline_fallbacks["tr"])
    parsed_json = await generate_dream_interpretation(system_prompt, user_prompt)
    if not parsed_json or not isinstance(parsed_json, dict):
        parsed_json = default_payload

    free_analysis = FreeAnalysis(
        bilincalti_aynasi=parsed_json.get("bilincalti_aynasi", default_payload["bilincalti_aynasi"]),
        gunun_pusulasi=parsed_json.get("gunun_pusulasi", default_payload["gunun_pusulasi"])
    )

    ai_symbols = parsed_json.get("symbols")
    if isinstance(ai_symbols, list) and len(ai_symbols) > 0:
        clean_ai_symbols = []
        for s in ai_symbols:
            s_str = str(s).strip()
            s_str = re.sub(r'^[^\w]+|[^\w]+$', '', s_str, flags=re.UNICODE)
            if len(s_str) >= 2 and s_str.lower() not in MULTILINGUAL_STOPWORDS:
                clean_ai_symbols.append(s_str.capitalize())
        if clean_ai_symbols:
            symbols = clean_ai_symbols[:4]

    raw_prim = parsed_json.get("primary_interpretation", default_payload["primary_interpretation"])
    clean_prim = re.sub(r"^\s*#+\s*.*(?:\n+|$)", "", raw_prim).strip()
    clean_prim = re.sub(r"^\s*(?:rüyanın tabiri|rüya tabiri|tabir)\s*[:\-]?\s*", "", clean_prim, flags=re.IGNORECASE).strip()

    primary_trad_item = TraditionAnalysisItem(
        tradition_id=preferred_trad,
        title=primary_meta["title"],
        scholar=primary_meta["scholar"],
        interpretation=clean_prim,
        is_unlocked=True
    )

    teasers_dict = parsed_json.get("teasers", {})
    locked_items: List[TraditionAnalysisItem] = []
    for t_id in other_trads:
        t_meta = get_tradition_metadata(t_id, lang)
        fallback_teaser = default_payload["teasers"].get(t_id, f"{t_meta['title']} kaynaklarında bu semboller için farklı bir açıklama yer alıyor...")
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

    headers = {
        "ru": ("🌌 ПСИХОЛОГИЧЕСКИЙ АНАЛИЗ", "📜", "🧭 ПРАКТИЧЕСКИЙ СОВЕТ"),
        "en": ("🌌 PSYCHOLOGICAL SUMMARY", "📜", "🧭 PRACTICAL ADVICE"),
        "de": ("🌌 PSYCHOLOGISCHE ANALYSE", "📜", "🧭 PRAKTISCHER RAT"),
        "es": ("🌌 ANÁLISIS PSICOLÓGICO", "📜", "🧭 CONSEJO PRÁCTICO"),
        "ar": ("🌌 التحليل النفسي", "📜", "🧭 نصيحة عملية"),
        "tr": ("🌌 PSİKOLOJİK ÖZET", "📜", "🧭 SOMUT TAVSİYE")
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
    ilgili geleneğin kaynak kitaplarındaki somut verilerle rüyadaki her sembolü tek tek açıklar.
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
    matches = retrieve_by_tradition(request.dream_text, tradition_id, top_k=4)
    chunk_text_content = "\n\n".join(
        [f"[Kaynak Kitap: {m['chunk']['source']}]\n{m['chunk']['text']}" for m in matches]
    ) if matches else ""

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
        f"Sen 11 temel rüya tabiri ve psikoloji kitabından oluşan RAG kütüphanesini kullanan bir Rüya Veri Analistisin.\n\n"
        f"🎯 GÖREVİN:\n"
        f"- Kullanıcının rüyasını YALNIZCA '{trad_meta['title']}' ({trad_meta['scholar']}) kaynak kitaplarımızdaki somut verilere dayanarak, kullanıcının rüyayı yazdığı dilde yorumla.\n"
        f"- Sıradan yapay zeka (Claude/ChatGPT) klişelerinden ('içsel yolculuk', 'bilinçaltı fısıltısı', 'duygusal dalgalanmalar') ve anlaşılması güç eski kelimelerden ('teemmül', 'mühürlenmek', 'kadim eşik') KESİNLİKLE uzak dur.\n"
        f"- Rüyadaki her bir somut sembolü, nesneyi ve cümleyi (örn: kaya, deniz, sahil, yürümek vb.) tek tek ele al ve aşağıdaki KAYNAK KİTAP PASAJLARINDA bu semboller için verilen somut kuralları, şartları ve anlamları açık, sade ve net bir dille 2-3 paragrafta anlat.\n"
        f"- Cümlelerini ASLA yarıda bırakma; eksiksiz ve tam noktalanmış olarak bitir.\n\n"
        f"KÜTÜPHANEDEN ÇEKİLEN KAYNAK KİTAP PASAJLARI ({trad_meta['title']}):\n{chunk_text_content}"
    )

    unlock_offline_fallbacks = {
        "ru": f"Согласно книжным источникам традиции '{trad_meta['title']}' ({trad_meta['scholar']}), конкретные образы вашего сна указывают на укрепление ваших позиций и прояснение важного вопроса.",
        "en": f"According to the source books of {trad_meta['title']} ({trad_meta['scholar']}), the specific symbols in your dream point to tangible stability, clear judgment, and a favorable outcome in a matter you have been working on.",
        "de": f"Nach den Quellbüchern der {trad_meta['title']} ({trad_meta['scholar']}) weisen die konkreten Symbole Ihres Traums auf Stabilität und eine klare Lösung in einer wichtigen Angelegenheit hin.",
        "es": f"Según los libros de {trad_meta['title']} ({trad_meta['scholar']}), los símbolos concretos de tu sueño señalan estabilidad y un resultado claro en un asunto importante.",
        "ar": f"وفقاً لمصادر وكتب {trad_meta['title']} ({trad_meta['scholar']})، فإن الرموز المحددة في رؤياك تدل على الثبات ووضوح الرؤية في أمر يشغل بالك.",
        "tr": f"{trad_meta['title']} ({trad_meta['scholar']}) kaynak kitaplarımızdaki verilere göre rüyanızda yer alan somut semboller, üzerinde düşündüğünüz bir konuda sağlam bir zemine kavuşacağınıza ve belirsizliklerin netleşeceğine işaret eder."
    }

    full_text = await generate_unlock_interpretation(system_prompt, request.dream_text)
    if not full_text or not full_text.strip():
        full_text = unlock_offline_fallbacks.get(lang, unlock_offline_fallbacks["tr"])

    full_text = re.sub(r"^\s*#+\s*.*(?:\n+|$)", "", full_text).strip()
    full_text = re.sub(r"^\s*(?:rüyanın tabiri|rüya tabiri|tabir)\s*[:\-]?\s*", "", full_text, flags=re.IGNORECASE).strip()

    return UnlockTraditionResponse(
        tradition_id=tradition_id,
        title=trad_meta["title"],
        scholar=trad_meta["scholar"],
        interpretation=full_text,
        sources_used=sources_payload
    )


@app.post("/chat", response_model=ChatResponse, summary="Rüya Yorumcusuna Soru Sor (Kaynak Kitap Destekli Sohbet)")
async def chat_with_interpreter(request: ChatRequest):
    """
    Rüya tabiri sonrasında kullanıcının rüyasıyla ilgili devam sorularını
    kütüphanedeki 11 kaynak kitaptan eşleşen verilerle net ve anlaşılır biçimde cevaplar.
    """
    message = request.message.strip()
    if not message:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Lütfen sorunuzu yazınız."
        )

    logger.info(f"Rüya yorumcusuna soru soruldu. Kullanıcı ID: {request.user_id or 'Anonim'}")
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
