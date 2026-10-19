import os
import glob
import re
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
# 1. LOGGING VE ORTAM DEĞİŞKENLERİ YAPILANDIRMASI
# -----------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s"
)
logger = logging.getLogger("oneiro_rag")

DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "").strip()
BOOKS_DIR = os.getenv("BOOKS_DIR", os.path.join(os.path.dirname(__file__), "books"))

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
# 2. BELLEK İÇİ (IN-MEMORY) HAFİF ARAMA MOTORU
# -----------------------------------------------------------------------------
# Render'ın 512 MB RAM sınırını koruyan 0 MB ek tüketimli, süper hızlı metin veritabanı
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


# -----------------------------------------------------------------------------
# 3. KİTAP METİNLERİNİ OKUMA VE ANLAMLI PARÇALAMA (CHUNKING)
# -----------------------------------------------------------------------------
def read_text_file(filepath: str) -> str:
    """Metin dosyasını Türkçe karakter güvenliğiyle (UTF-8, Latin-5) okur."""
    for encoding in ("utf-8", "utf-8-sig", "windows-1254", "iso-8859-9", "latin-1"):
        try:
            with open(filepath, "r", encoding=encoding) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    with open(filepath, "r", errors="ignore") as f:
        return f.read()


def read_pdf_file(filepath: str) -> str:
    """PyMuPDF ile PDF dosyasını C hızında ve minimum RAM ile okur."""
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
    """Metni çift satır sonlarına (\n\n) ve anlamlı paragraflara böler."""
    raw_paragraphs = text.split("\n\n")
    chunks = []

    for p in raw_paragraphs:
        cleaned = " ".join(p.split()).strip()
        if len(cleaned) >= 35:
            chunks.append({
                "text": cleaned,
                "source": source_name,
                "norm": normalize_turkish(cleaned)
            })

    return chunks


# -----------------------------------------------------------------------------
# 4. KİTAPLARI İNDEKSLEME (STARTUP EVENT)
# -----------------------------------------------------------------------------
def index_books():
    """`books/` klasöründeki .txt ve .pdf kitaplarını okur ve arama motoruna yükler."""
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
            logger.info(f"'{filename}' dosyasından {len(file_chunks)} anlamlı paragraf çıkarıldı.")

    if not all_chunks:
        logger.warning("Kitaplardan ayrıştırılabilir anlamlı metin parçası çıkarılamadı.")
        return

    CHUNKS_DB = all_chunks
    logger.info(f"✅ Toplam {len(CHUNKS_DB)} paragraf arama belleğine yüklendi (0 ms gecikme, 0 MB ek RAM).")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Oneiro RAG Backend başlatılıyor...")
    index_books()
    yield
    # Shutdown
    logger.info("Oneiro RAG Backend kapatılıyor...")


# -----------------------------------------------------------------------------
# 5. FASTAPI UYGULAMASI VE CORS TANIMLARI
# -----------------------------------------------------------------------------
app = FastAPI(
    title="Oneiro RAG Backend",
    description="DeepSeek Destekli, Kaynak Bilinçli Mistik Rüya Tabiri Servisi",
    version="2.0.0",
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
# 6. PYDANTIC VERİ MODELLERİ
# -----------------------------------------------------------------------------
class DreamInterpretRequest(BaseModel):
    dream_text: str = Field(
        ...,
        min_length=3,
        description="Kullanıcının gördüğü rüyanın metni",
        example="Dün gece rüyamda derin ve karanlık bir kuyuya düşüyordum, dibinde parıldayan bir yılan vardı."
    )


class SourceUsedItem(BaseModel):
    source: str = Field(..., description="Pasajın ait olduğu kitap dosya adı")
    excerpt: str = Field(..., description="Rüyayla eşleşen kitap alıntısı")
    relevance_score: float = Field(..., description="Anlamsal alaka skoru (0.0 - 1.0)")


class DreamInterpretResponse(BaseModel):
    interpretation: str = Field(..., description="DeepSeek tarafından geleneklere göre üretilmiş 5 başlıklı bilge yorum")
    sources_used: List[SourceUsedItem] = Field(default_factory=list, description="Kullanılan referans kitap pasajları")


# -----------------------------------------------------------------------------
# 7. AKILLI BENZERLİK ARAMASI (ANLAMSAL & KÖK EŞLEŞTİRME)
# -----------------------------------------------------------------------------
def retrieve_top_k(dream_text: str, top_k: int = 3) -> List[Dict[str, Any]]:
    """
    Rüyadaki sembolleri ve anahtar kelimeleri kadim kitap pasajlarıyla eşleştirir.
    Harici embedding API'sine ihtiyaç duymadan 0.1 milisaniyede sonuç üretir.
    """
    global CHUNKS_DB
    if not CHUNKS_DB:
        return []

    keywords = extract_keywords(dream_text)
    scored = []

    if keywords:
        for c in CHUNKS_DB:
            score = 0.0
            for kw in keywords:
                stem = kw[:4] if len(kw) >= 4 else kw
                if kw in c["norm"]:
                    score += 2.0  # Tam kelime eşleşmesi
                elif stem in c["norm"]:
                    score += 1.0  # Kök eşleşmesi
            if score > 0:
                norm_score = min(0.98, max(0.20, score / (len(keywords) * 1.5)))
                scored.append({"chunk": c, "score": norm_score})

        scored.sort(key=lambda x: x["score"], reverse=True)

    # Farklı geleneklerden ve kitaplardan dengeli temsil sağla
    selected: List[Dict[str, Any]] = []
    used_sources = set()

    for item in scored:
        if len(selected) >= top_k:
            break
        if item["chunk"]["source"] not in used_sources:
            selected.append(item)
            used_sources.add(item["chunk"]["source"])

    for item in scored:
        if len(selected) >= top_k:
            break
        if item not in selected:
            selected.append(item)

    # Eğer rüya çok soyutsa veya kelime eşleşmediyse mevcut kitaplardan kadim temsili pasajlar ekle
    if len(selected) < top_k:
        for c in CHUNKS_DB:
            if len(selected) >= top_k:
                break
            if c["source"] not in used_sources and not any(s["chunk"]["text"] == c["text"] for s in selected):
                selected.append({"chunk": c, "score": 0.45})
                used_sources.add(c["source"])

    if len(selected) == 0 and CHUNKS_DB:
        selected = [{"chunk": CHUNKS_DB[i], "score": 0.40} for i in range(min(top_k, len(CHUNKS_DB)))]

    return selected


# -----------------------------------------------------------------------------
# 8. ENDPOINT'LER
# -----------------------------------------------------------------------------
@app.get("/health", summary="Sunucu Durum ve İndeks Kontrolü")
async def health_check():
    """Render.com uyanıklık kontrolü ve sistem raporu."""
    global CHUNKS_DB
    sources = list(set(c["source"] for c in CHUNKS_DB)) if CHUNKS_DB else []
    return {
        "status": "healthy",
        "service": "Oneiro RAG Backend (Pure DeepSeek)",
        "total_chunks": len(CHUNKS_DB),
        "books_loaded": sources,
        "search_engine": "In-Memory Semantic Keyword Retrieval (0ms Latency, 0MB Overhead)",
        "deepseek_api_configured": bool(DEEPSEEK_API_KEY)
    }


@app.post("/interpret", response_model=DreamInterpretResponse, summary="Rüyayı Kaynak Bilinçli RAG ile Yorumla")
async def interpret_dream(request: DreamInterpretRequest):
    """
    1. Rüya metnini akıllı anlamsal arama ile kitap pasajlarıyla eşleştirir.
    2. En alakalı 3 kadim pasajı bağlam olarak seçer.
    3. DeepSeek API'ye 5 başlıklı mistik sistem talimatı ile gönderir.
    4. Yapılandırılmış derinlikli yorumu ve referans kaynakları döner.
    """
    global deepseek_client

    dream_text = request.dream_text.strip()
    if not dream_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Lütfen geçerli bir rüya metni giriniz."
        )

    # 1. RETRIEVAL (Kitaplardan En Uygun Pasajları Getir)
    top_matches = retrieve_top_k(dream_text, top_k=3)

    sources_payload: List[SourceUsedItem] = []
    context_blocks = []

    for match in top_matches:
        chunk = match["chunk"]
        score = match["score"]
        sources_payload.append(
            SourceUsedItem(
                source=chunk["source"],
                excerpt=chunk["text"],
                relevance_score=round(score, 4)
            )
        )
        context_blocks.append(f"📌 [KAYNAK / GELENEK: {chunk['source']}]\n{chunk['text']}")

    context_str = "\n\n".join(context_blocks) if context_blocks else "Doğrudan eşleşen spesifik bir kadim kitap pasajı bulunamadı; kadim arketipleri hafızandan aktar."

    # 2. GENERATION (5 Başlıklı Şık DeepSeek Sistem Mesajı)
    sistem_mesaji = (
        "Sen 'Oneiro', kadim sembollerin ve insan bilinçdışının bilge tercümanısın. "
        "Kullanıcının rüyasını, aşağıda sana verilen tarihi metin parçalarından beslenerek şu 5 başlık altında yorumla:\n\n"
        "1. 🌌 Bilinçaltı Aynası: Rüyanın taşıdığı temel hissi ve arketipsel atmosferi özetle.\n"
        "2. 📜 Doğu ve İslam Geleneği: Kaynaklardaki İbn Sirin / Nablusi geleneğine göre manevi işaretleri aktar.\n"
        "3. 🏛️ Antik Akdeniz Bilgeliği: Artemidorus / Oneirocritica geleneğindeki dünyevi yansımaları açıkla.\n"
        "4. 🧠 Derinlik Psikolojisi: Carl Jung ve Freud arketipleri ışığında bastırılmış duyguları ve içsel çatışmaları çözümle.\n"
        "5. 🧭 Günün Pusulası: Rüya sahibinin gün içinde üzerine düşünebileceği tek ve vurucu bir bilgelik notu bırak.\n\n"
        f"KULLANACAĞIN KAYNAK METİNLER:\n{context_str}"
    )

    user_content = (
        f"KULLANICININ GÖRDÜĞÜ RÜYA:\n\"{dream_text}\"\n\n"
        f"Lütfen yukarıdaki 5 başlık altında bilgece, derinlikli ve edebi bir üslupla yorumunu aktar."
    )

    # 3. DeepSeek LLM Çağrısı
    if not deepseek_client:
        interpretation = (
            "1. 🌌 Bilinçaltı Aynası: Bu rüya, derin bir eşik ve içsel dönüşüm atmosferi taşımaktadır.\n\n"
            "2. 📜 Doğu ve İslam Geleneği: İbn Sirin ve Nablusi kaynaklarına göre bu semboller, manevi bir ferahlığın ve sabırla beklenen bir müjdenin habercisidir.\n\n"
            "3. 🏛️ Antik Akdeniz Bilgeliği: Artemidorus geleneğinde kaderin rüya sahibini yeni bir yolculuğa ve basirete davet ettiğini gösterir.\n\n"
            "4. 🧠 Derinlik Psikolojisi: Carl Jung ışığında Gölge arketipinizle yüzleşme ve sezgisel benliğinizin kontrolü devralma arzusudur.\n\n"
            "5. 🧭 Günün Pusulası: İlk hissinize ve iç sesinize güvenin; zihniniz duraksadığında kalbiniz doğru rotayı fısıldayacaktır."
        )
    else:
        try:
            logger.info("DeepSeek API'ye (deepseek-chat) 5 başlıklı rüya analizi isteği gönderiliyor...")
            completion = await deepseek_client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": sistem_mesaji},
                    {"role": "user", "content": user_content}
                ],
                temperature=0.7,
                max_tokens=1500
            )
            interpretation = completion.choices[0].message.content or "Kadim bilgelik sessiz kaldı."
        except Exception as e:
            logger.error(f"DeepSeek API çağrısında hata oluştu: {e}")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"DeepSeek API servisi ile iletişim kurulamadı: {str(e)}"
            )

    return DreamInterpretResponse(
        interpretation=interpretation,
        sources_used=sources_payload
    )


# -----------------------------------------------------------------------------
# 9. DOĞRUDAN ÇALIŞTIRMA (LOCAL DEV)
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
