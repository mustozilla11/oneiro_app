import os
import glob
import re
import json
import logging
from typing import List, Dict, Any, Optional
from contextlib import asynccontextmanager

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

DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "").strip()
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
BOOKS_DIR = os.getenv("BOOKS_DIR", os.path.join(BACKEND_DIR, "books"))

# DeepSeek Async Client (OpenAI uyumlu SDK)
deepseek_client: Optional[AsyncOpenAI] = None
if DEEPSEEK_API_KEY:
    deepseek_client = AsyncOpenAI(
        api_key=DEEPSEEK_API_KEY,
        base_url="https://api.deepseek.com"
    )
    logger.info("✅ DeepSeek API Client başarıyla yapılandırıldı.")
else:
    logger.warning("⚠️ DEEPSEEK_API_KEY ortam değişkeni bulunamadı! LLM çağrıları yapılamayabilir.")


# -----------------------------------------------------------------------------
# 2. METADATA DESTEKLİ GELENEKLER VE ARAMA MOTORU
# -----------------------------------------------------------------------------
TRADITIONS: Dict[str, Dict[str, str]] = {
    "islam_dogu": {
        "id": "islam_dogu",
        "title": "Doğu ve İslam Geleneği",
        "scholar": "İbn-i Sîrîn & Nablusî",
        "icon": "scroll",
        "accent_color": "#D4AF37"  # Ancient Gold
    },
    "antik_akdeniz": {
        "id": "antik_akdeniz",
        "title": "Antik Akdeniz Bilgeliği",
        "scholar": "Artemidorus (Oneirocritica)",
        "icon": "temple",
        "accent_color": "#9D4EDD"  # Neon Purple
    },
    "psikoloji": {
        "id": "psikoloji",
        "title": "Derinlik Psikolojisi",
        "scholar": "Carl G. Jung & Sigmund Freud",
        "icon": "brain",
        "accent_color": "#7209B7"  # Electric Lavender
    }
}

CHUNKS_DB: List[Dict[str, Any]] = []

TURKISH_STOPWORDS = {
    "ve", "ile", "bu", "şu", "o", "bir", "de", "da", "ki", "için", "gibi", "kadar",
    "daha", "çok", "en", "ama", "fakat", "ancak", "çünkü", "mi", "mı", "mu", "mü",
    "rüyada", "rüyamda", "gördüm", "dün", "gece", "sonra", "ben", "sen", "biz", "siz",
    "olan", "olmak", "eden", "etmek", "vardı", "yoktu", "diye", "bunu", "buna", "bunun",
    "kendimi", "kendini", "böyle", "şöyle", "her", "şey", "şeyler"
}


def normalize_turkish(text: str) -> str:
    """Türkçe karakterleri eşleştirme için küçük harfe ve arama standardına dönüştürür."""
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
    """Metindeki anlamlı anahtar kelimeleri ve kökleri ayıklar."""
    norm = normalize_turkish(text)
    words = re.findall(r"\b[a-z0-9]{3,}\b", norm)
    return [w for w in words if w not in TURKISH_STOPWORDS]


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
    """Metni anlamlı paragraflara böler ve gelenek etiketi ekler."""
    tradition_id = detect_tradition_id(source_name)
    raw_paragraphs = text.split("\n\n")
    chunks = []

    for p in raw_paragraphs:
        cleaned = " ".join(p.split()).strip()
        if len(cleaned) >= 35:
            chunks.append({
                "text": cleaned,
                "source": source_name,
                "tradition": tradition_id,
                "tradition_title": TRADITIONS[tradition_id]["title"],
                "norm": normalize_turkish(cleaned)
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


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Oneiro RAG Backend başlatılıyor...")
    index_books()
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


# -----------------------------------------------------------------------------
# 6. GELENEK BAZLI RETRIEVAL
# -----------------------------------------------------------------------------
def retrieve_by_tradition(dream_text: str, tradition_id: str, top_k: int = 1) -> List[Dict[str, Any]]:
    """Belirli bir geleneğe ait en alakalı kitap pasajını getirir."""
    tradition_chunks = [c for c in CHUNKS_DB if c.get("tradition") == tradition_id]
    if not tradition_chunks:
        return []

    keywords = extract_keywords(dream_text)
    scored = []

    if keywords:
        for c in tradition_chunks:
            score = 0.0
            for kw in keywords:
                stem = kw[:4] if len(kw) >= 4 else kw
                if kw in c["norm"]:
                    score += 2.0
                elif stem in c["norm"]:
                    score += 1.0
            if score > 0:
                norm_score = min(0.98, max(0.20, score / (len(keywords) * 1.5)))
                scored.append({"chunk": c, "score": norm_score})

        scored.sort(key=lambda x: x["score"], reverse=True)

    if scored:
        return scored[:top_k]

    # Eşleşme yoksa o gelenekten temsili ilk parçayı döner
    return [{"chunk": tradition_chunks[0], "score": 0.40}]


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
        "version": "2.1.0",
        "total_chunks": len(CHUNKS_DB),
        "books_loaded": sources,
        "deepseek_api_configured": bool(DEEPSEEK_API_KEY)
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

    preferred_trad = request.preferred_tradition or "islam_dogu"
    if preferred_trad not in TRADITIONS:
        preferred_trad = "islam_dogu"

    other_trads = [t for t in TRADITIONS.keys() if t != preferred_trad]

    # Her gelenekten en alakalı 1 pasajı çek
    matched_chunks: Dict[str, Dict[str, Any]] = {}
    sources_payload: List[SourceUsedItem] = []

    for t_id in TRADITIONS.keys():
        matches = retrieve_by_tradition(dream_text, t_id, top_k=1)
        if matches:
            match = matches[0]
            matched_chunks[t_id] = match
            sources_payload.append(
                SourceUsedItem(
                    source=match["chunk"]["source"],
                    tradition=t_id,
                    excerpt=match["chunk"]["text"],
                    relevance_score=round(match["score"], 4)
                )
            )

    primary_chunk_text = matched_chunks.get(preferred_trad, {}).get("chunk", {}).get("text", "")
    other_context_lines = []
    for t_id in other_trads:
        txt = matched_chunks.get(t_id, {}).get("chunk", {}).get("text", "")
        other_context_lines.append(f"[{TRADITIONS[t_id]['title']} Kaynak]: {txt}")

    # Sembol çıkarımı (Türkçe anahtar kelimeler)
    keywords = extract_keywords(dream_text)
    symbols = [k.capitalize() for k in keywords[:4]]
    if not symbols:
        symbols = ["Mistik Eşik", "Karanlık Su", "Altın Işık"]

    # DeepSeek Hızlı JSON Promptu (~350 token)
    system_prompt = (
        "Sen 'Oneiro', kadim sembollerin ve insan bilinçdışının bilge tercümanısın. "
        "Kullanıcının rüyasını analiz et ve SADECE geçerli bir JSON nesnesi döndür.\n\n"
        "İstenen JSON şeması:\n"
        "{\n"
        '  "bilincalti_aynasi": "Rüyanın taşıdığı temel hissi ve arketipsel atmosferi özetleyen 2-3 edebi cümle.",\n'
        '  "gunun_pusulasi": "Rüya sahibinin gün boyu hatırlayacağı tek ve vurucu bilgelik aforizması.",\n'
        f'  "primary_interpretation": "{TRADITIONS[preferred_trad]["title"]} ({TRADITIONS[preferred_trad]["scholar"]}) geleneğine göre rüyanın 1-2 paragraflık tam, bilgece ve derinlikli tabiri.",\n'
        '  "teasers": {\n'
        f'    "{other_trads[0]}": "{TRADITIONS[other_trads[0]]["title"]} açısından rüyayı merak ettiren, 1 cümlelik şoke edici veya düşündürücü teaser (ör: Jungian açıdan bu kuyu bir düşüş değil, Anima ile karşılaşma eşiğidir...)",\n'
        f'    "{other_trads[1]}": "{TRADITIONS[other_trads[1]]["title"]} açısından rüyayı merak ettiren, 1 cümlelik çarpıcı teaser."\n'
        "  }\n"
        "}\n\n"
        f"KAYNAK METİNLER:\n[Birincil Gelenek Kaynağı]: {primary_chunk_text}\n" +
        "\n".join(other_context_lines)
    )

    user_prompt = f'RÜYA: "{dream_text}"'

    # Yanıt üretimi
    parsed_json: Dict[str, Any] = {}
    if not deepseek_client:
        # Offline / Test fallback
        parsed_json = {
            "bilincalti_aynasi": "Bu rüya, derin bir içsel arınma ve ruhsal bir eşikten geçiş atmosferi taşımaktadır. Zihninizin geride bırakmak istediği gölgeler su yüzüne çıkıyor.",
            "gunun_pusulasi": "İlk hissinize ve iç sesinize güvenin; kalbiniz fısıldadığında mantığınızın duraksamasına izin vermeyin.",
            "primary_interpretation": (
                f"{TRADITIONS[preferred_trad]['scholar']} kaynaklarına göre bu rüya, başlangıçta çetin görünen bir durumun "
                "ardından gelecek manevi ferahlığı, gizli bir kapının açılışını ve sabırla beklenen bir müjdenin yaklaşmakta olduğunu simgeler."
            ),
            "teasers": {
                other_trads[0]: f"{TRADITIONS[other_trads[0]]['scholar']} geleneğine göre bu sembol bir son değil, kaderinizin mühürlendiği dünyevi bir basiret eşiğidir...",
                other_trads[1]: f"{TRADITIONS[other_trads[1]]['scholar']} arketipsel çözümlemesine göre bu düşüş, Gölge benliğinizle yüzleşme arzunuzun bilinçdışı feryadıdır..."
            }
        }
    else:
        try:
            logger.info("DeepSeek API'ye hızlı teaser tabanlı rüya isteği gönderiliyor...")
            completion = await deepseek_client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.7,
                max_tokens=650,
                response_format={"type": "json_object"}
            )
            raw_text = completion.choices[0].message.content or "{}"
            parsed_json = json.loads(raw_text)
        except Exception as e:
            logger.warning(f"DeepSeek JSON çıktısı ayrıştırılırken hata oluştu ({e}), yedek şablon kullanılıyor.")
            parsed_json = {
                "bilincalti_aynasi": "Bu rüya, derin bir eşik ve içsel dönüşüm atmosferi taşımaktadır.",
                "gunun_pusulasi": "İlk sezginize güvenin; kadim yolculuğunuzda en doğru rehber kalbinizdir.",
                "primary_interpretation": "Kadim yazmalar bu sembollerin ruhsal bir yükselişe ve arınmaya işaret ettiğini bildirir.",
                "teasers": {
                    other_trads[0]: f"{TRADITIONS[other_trads[0]]['title']} bu rüyada gizlenmiş dünyevi bir kader işareti görmektedir...",
                    other_trads[1]: f"{TRADITIONS[other_trads[1]]['title']} ışığında bastırılmış bir duygunun dışa vurumudur..."
                }
            }

    # Çıktı yapılandırması
    free_analysis = FreeAnalysis(
        bilincalti_aynasi=parsed_json.get("bilincalti_aynasi", "Rüyanız kadim bir eşik atmosferi taşımaktadır."),
        gunun_pusulasi=parsed_json.get("gunun_pusulasi", "İç sesinize güvenin.")
    )

    primary_trad_item = TraditionAnalysisItem(
        tradition_id=preferred_trad,
        title=TRADITIONS[preferred_trad]["title"],
        scholar=TRADITIONS[preferred_trad]["scholar"],
        interpretation=parsed_json.get("primary_interpretation", "Kadim tabir hazırlanıyor."),
        is_unlocked=True
    )

    teasers_dict = parsed_json.get("teasers", {})
    locked_items: List[TraditionAnalysisItem] = []
    for t_id in other_trads:
        teaser_text = teasers_dict.get(t_id) or f"{TRADITIONS[t_id]['title']} bu rüyada beklenmedik bir sır saklamaktadır..."
        locked_items.append(
            TraditionAnalysisItem(
                tradition_id=t_id,
                title=TRADITIONS[t_id]["title"],
                scholar=TRADITIONS[t_id]["scholar"],
                teaser=teaser_text,
                interpretation=None,
                is_unlocked=False
            )
        )

    # Eski ekranlarla %100 uyumluluk için birleştirilmiş genel tabir metni
    full_interpretation_text = (
        f"🌌 BİLİNÇALTI AYNASI:\n{free_analysis.bilincalti_aynasi}\n\n"
        f"📜 {primary_trad_item.title} ({primary_trad_item.scholar}):\n{primary_trad_item.interpretation}\n\n"
        f"🧭 GÜNÜN PUSULASI:\n{free_analysis.gunun_pusulasi}"
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
    yalnızca o spesifik geleneğin tam tabirini ~200 token ile hızlıca üretir.
    """
    global deepseek_client

    logger.info(f"Kilit açma talebi alındı: {request.tradition_id}. Kullanıcı ID: {request.user_id or 'Misafir/Anonim'}")

    tradition_id = request.tradition_id
    if tradition_id not in TRADITIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Geçersiz gelenek kimliği: {tradition_id}. Geçerli olanlar: {list(TRADITIONS.keys())}"
        )

    trad_info = TRADITIONS[tradition_id]
    matches = retrieve_by_tradition(request.dream_text, tradition_id, top_k=1)
    chunk_text_content = matches[0]["chunk"]["text"] if matches else ""

    sources_payload = [
        SourceUsedItem(
            source=matches[0]["chunk"]["source"],
            tradition=tradition_id,
            excerpt=chunk_text_content,
            relevance_score=round(matches[0]["score"], 4)
        )
    ] if matches else []

    system_prompt = (
        f"Sen 'Oneiro', kadim sembollerin bilge tercümanısın. "
        f"Kullanıcının rüyasını YALNIZCA '{trad_info['title']}' ({trad_info['scholar']}) geleneği ışığında yorumla. "
        f"Aşağıdaki kaynak pasajından beslenerek, 1-2 paragraflık derinlikli, edebi ve vurucu bir tabir sun.\n\n"
        f"KAYNAK PASAJI:\n{chunk_text_content}"
    )

    if not deepseek_client:
        full_text = (
            f"{trad_info['scholar']} kaynaklarına göre bu rüya sembolü, gizli kalmış bir yeteneğinizin ve dünyevi basiretinizin "
            f"uyanışına işaret eder. Çevrenizdeki görünmez işaretlere dikkat kesilmeli ve ilk adımı atmaktan çekinmemelisiniz."
        )
    else:
        try:
            logger.info(f"DeepSeek'ten '{tradition_id}' geleneğinin kilidi için tam analiz isteniyor...")
            completion = await deepseek_client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f'RÜYA: "{request.dream_text}"'}
                ],
                temperature=0.7,
                max_tokens=400
            )
            full_text = completion.choices[0].message.content or "Kadim bilgelik bu sembol hakkında sessiz kaldı."
        except Exception as e:
            logger.error(f"DeepSeek unlock çağrısında hata: {e}")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"DeepSeek ile iletişim kurulamadı: {str(e)}"
            )

    return UnlockTraditionResponse(
        tradition_id=tradition_id,
        title=trad_info["title"],
        scholar=trad_info["scholar"],
        interpretation=full_text,
        sources_used=sources_payload
    )


# -----------------------------------------------------------------------------
# 8. LOCAL DEV
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
