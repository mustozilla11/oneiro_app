import os
import glob
import logging
from typing import List, Dict, Any, Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import httpx
import numpy as np
import fitz  # PyMuPDF
from openai import AsyncOpenAI

# -----------------------------------------------------------------------------
# 1. LOGGING VE ORTAM DEĞİŞKENLERİ YAPILANDIRMASI
# -----------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s"
)
logger = logging.getLogger("oneiro_rag")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "").strip()
BOOKS_DIR = os.getenv("BOOKS_DIR", os.path.join(os.path.dirname(__file__), "books"))
GEMINI_EMBED_URL = "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004"

# -----------------------------------------------------------------------------
# 2. BELLEK İÇİ (IN-MEMORY) HAFİF VEKTÖR VERİTABANI
# -----------------------------------------------------------------------------
# Render'ın 512 MB RAM sınırını korumak için saf Python listesi ve NumPy matrisi
CHUNKS_DB: List[Dict[str, Any]] = []
VECTORS: Optional[np.ndarray] = None

# DeepSeek Async Client (OpenAI uyumlu arayüz)
deepseek_client: Optional[AsyncOpenAI] = None
if DEEPSEEK_API_KEY:
    deepseek_client = AsyncOpenAI(
        api_key=DEEPSEEK_API_KEY,
        base_url="https://api.deepseek.com"
    )
else:
    logger.warning("DEEPSEEK_API_KEY ortam değişkeni bulunamadı! LLM çağrıları yapılamayabilir.")


# -----------------------------------------------------------------------------
# 3. HAFİF GEMINI EMBEDDING İŞLEVLERİ (0 MB RAM TÜKETİMİ)
# -----------------------------------------------------------------------------
async def get_single_embedding(text: str, client: httpx.AsyncClient) -> Optional[List[float]]:
    """Gemini text-embedding-004 API'sini kullanarak tek bir metin parçasını vektöre çevirir."""
    if not GEMINI_API_KEY:
        logger.error("GEMINI_API_KEY tanımlı değil, embedding alınamıyor.")
        return None

    url = f"{GEMINI_EMBED_URL}:embedContent?key={GEMINI_API_KEY}"
    payload = {
        "model": "models/text-embedding-004",
        "content": {"parts": [{"text": text[:2000]}]}  # Güvenli karakter limiti
    }

    try:
        response = await client.post(url, json=payload, timeout=20.0)
        if response.status_code == 200:
            data = response.json()
            return data.get("embedding", {}).get("values")
        else:
            logger.error(f"Gemini API Hatası ({response.status_code}): {response.text}")
            return None
    except Exception as e:
        logger.error(f"Gemini embedding isteğinde istisna oluştu: {e}")
        return None


async def get_batch_embeddings(texts: List[str], client: httpx.AsyncClient) -> List[Optional[List[float]]]:
    """Gemini batchEmbedContents API'sini kullanarak birden fazla metni topluca vektörleştirir."""
    if not GEMINI_API_KEY:
        return [None] * len(texts)

    url = f"{GEMINI_EMBED_URL}:batchEmbedContents?key={GEMINI_API_KEY}"
    requests_payload = [
        {
            "model": "models/text-embedding-004",
            "content": {"parts": [{"text": t[:2000]}]}
        }
        for t in texts
    ]

    try:
        response = await client.post(url, json={"requests": requests_payload}, timeout=45.0)
        if response.status_code == 200:
            data = response.json()
            embeddings_list = data.get("embeddings", [])
            return [emb.get("values") for emb in embeddings_list]
        else:
            logger.warning(f"Batch embedding başarısız ({response.status_code}), tekil moda dönülüyor: {response.text}")
    except Exception as e:
        logger.warning(f"Batch embedding hatası: {e}. Tekil çağrılara geçiliyor.")

    # Fallback: Batch başarısız olursa tekil olarak dene
    results = []
    for text in texts:
        emb = await get_single_embedding(text, client)
        results.append(emb)
    return results


# -----------------------------------------------------------------------------
# 4. KİTAP METİNLERİNİ OKUMA VE ANLAMLI PARÇALAMA (CHUNKING)
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
    """PyMuPDF (fitz) ile PDF dosyasını C hızında ve minimum RAM ile okur."""
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
    """
    Metni çift satır sonlarına (\n\n) ve anlamlı paragraflara böler.
    Çok kısa veya anlamsız parçaları filtreler.
    """
    raw_paragraphs = text.split("\n\n")
    chunks = []

    for p in raw_paragraphs:
        cleaned = " ".join(p.split()).strip()
        # En az 35 karakter içeren anlamlı paragrafları al
        if len(cleaned) >= 35:
            chunks.append({
                "text": cleaned,
                "source": source_name
            })

    return chunks


# -----------------------------------------------------------------------------
# 5. UYGULAMA BAŞLATMA VE BAŞLANGIÇ İNDEKSLEMESİ (STARTUP EVENT)
# -----------------------------------------------------------------------------
async def index_books():
    """`books/` klasöründeki .txt ve .pdf kitaplarını okur ve Gemini ile indeksler."""
    global CHUNKS_DB, VECTORS

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
    logger.info(f"Toplam {len(CHUNKS_DB)} paragraf vektörleştirilmek üzere hazırlanıyor...")

    if not GEMINI_API_KEY:
        logger.warning("GEMINI_API_KEY eksik! Vektörleştirme atlandı, sunucu mock/arama olmadan başlayacak.")
        return

    # Paragrafları Gemini API ile toplu (batch) olarak vektörleştir
    vector_list: List[List[float]] = []
    valid_chunks: List[Dict[str, Any]] = []
    batch_size = 30

    async with httpx.AsyncClient() as client:
        for i in range(0, len(CHUNKS_DB), batch_size):
            batch = CHUNKS_DB[i:i + batch_size]
            texts = [c["text"] for c in batch]
            logger.info(f"Embedding alınıyor: {i + 1} - {min(i + batch_size, len(CHUNKS_DB))} / {len(CHUNKS_DB)}")

            embeddings = await get_batch_embeddings(texts, client)
            for chunk, emb in zip(batch, embeddings):
                if emb is not None:
                    vector_list.append(emb)
                    valid_chunks.append(chunk)

    if vector_list:
        CHUNKS_DB = valid_chunks
        # NumPy matrisine dönüştür ve L2 normalizasyonu uygula (Kosinüs benzerliği tek dot-product olur)
        raw_matrix = np.array(vector_list, dtype=np.float32)
        norms = np.linalg.norm(raw_matrix, axis=1, keepdims=True)
        norms[norms == 0] = 1.0
        VECTORS = raw_matrix / norms
        logger.info(f"✅ RAG İndeksleme Tamamlandı! Toplam Vektör Sayısı: {len(VECTORS)}, Boyut: {VECTORS.shape[1]}")
    else:
        logger.error("Vektörler alınamadı. Vektör matrisi oluşturulamadı.")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Kitapları oku ve embedding al
    logger.info("Oneiro RAG Backend başlatılıyor...")
    await index_books()
    yield
    # Shutdown
    logger.info("Oneiro RAG Backend kapatılıyor...")


# -----------------------------------------------------------------------------
# 6. FASTAPI UYGULAMASI VE CORS TANIMLARI
# -----------------------------------------------------------------------------
app = FastAPI(
    title="Oneiro RAG Backend",
    description="Kaynak Bilinçli (Metadata-Aware), Ultra Hafif Mistik Rüya Tabiri Servisi",
    version="1.0.0",
    lifespan=lifespan
)

# Flutter mobil uygulamasından ve web'den gelebilecek istekler için CORS izni
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# -----------------------------------------------------------------------------
# 7. PYDANTIC VERİ MODELLERİ
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
    relevance_score: float = Field(..., description="Kosinüs benzerlik skoru")


class DreamInterpretResponse(BaseModel):
    interpretation: str = Field(..., description="DeepSeek tarafından geleneklere göre üretilmiş bilge yorum")
    sources_used: List[SourceUsedItem] = Field(default_factory=list, description="Kullanılan referans kitap pasajları")


# -----------------------------------------------------------------------------
# 8. BENZERLİK ARAMASI (COSINE SIMILARITY RETRIEVAL)
# -----------------------------------------------------------------------------
def retrieve_top_k(query_vector: List[float], top_k: int = 3) -> List[Dict[str, Any]]:
    """NumPy matris çarpımı ile 0.5 milisaniyede en alakalı k adet paragrafı çeker."""
    global VECTORS, CHUNKS_DB

    if VECTORS is None or len(CHUNKS_DB) == 0:
        return []

    q_vec = np.array(query_vector, dtype=np.float32)
    q_norm = np.linalg.norm(q_vec)
    if q_norm == 0:
        return []
    q_unit = q_vec / q_norm

    # Matris çarpımı = Kosinüs Benzerliği
    scores = np.dot(VECTORS, q_unit)
    top_indices = np.argsort(scores)[::-1][:top_k]

    results = []
    for idx in top_indices:
        results.append({
            "chunk": CHUNKS_DB[idx],
            "score": float(scores[idx])
        })
    return results


# -----------------------------------------------------------------------------
# 9. ENDPOINT'LER
# -----------------------------------------------------------------------------
@app.get("/health", summary="Sunucu Durum ve İndeks Kontrolü")
async def health_check():
    """Render.com uyanıklık kontrolü ve indekslenen kitapların raporu."""
    global CHUNKS_DB, VECTORS
    sources = list(set(c["source"] for c in CHUNKS_DB)) if CHUNKS_DB else []
    return {
        "status": "healthy",
        "service": "Oneiro RAG Backend",
        "total_chunks": len(CHUNKS_DB),
        "total_vectors": len(VECTORS) if VECTORS is not None else 0,
        "books_loaded": sources,
        "gemini_api_configured": bool(GEMINI_API_KEY),
        "deepseek_api_configured": bool(DEEPSEEK_API_KEY)
    }


@app.post("/interpret", response_model=DreamInterpretResponse, summary="Rüyayı Kaynak Bilinçli RAG ile Yorumla")
async def interpret_dream(request: DreamInterpretRequest):
    """
    1. Rüya metnini Gemini text-embedding-004 ile vektöre dönüştürür.
    2. NumPy kosinüs benzerliği ile kitaplardan en alakalı 3 pasajı çeker.
    3. DeepSeek LLM'e kaynak ayrımı odaklı sistem talimatıyla gönderir.
    4. Bütüncül ve mistik yanıtı döner.
    """
    global deepseek_client

    dream_text = request.dream_text.strip()
    if not dream_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Lütfen geçerli bir rüya metni giriniz."
        )

    # 1. RETRIEVAL (Vektörleştir ve Benzer Pasajları Bul)
    top_matches = []
    async with httpx.AsyncClient() as client:
        query_vector = await get_single_embedding(dream_text, client)

    if query_vector is not None:
        top_matches = retrieve_top_k(query_vector, top_k=3)

    # Referans metinlerini kaynak adlarına göre grupla
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

    # 2. GENERATION (Kaynak Ayrımı Odaklı DeepSeek Promptu)
    system_prompt = (
        "Sen 'Oneiro' kadim rüya mabedinin baş bilgesi ve derin bilinçaltı rehberisin.\n"
        "Görevin: Kullanıcının paylaştığı rüyayı, sana sunulan kadim referans kaynakları temel alarak bilgece yorumlamaktır.\n\n"
        "ÖNEMLİ KURALLAR:\n"
        "1. Kullanıcının rüyasını yorumlarken gelen kaynakları (İslam/Doğu geleneği, Antik Yunan kaynakları, Psikanaliz vb. kaynak dosya adlarına göre) AÇIKÇA BİRBİRİNDEN AYIR.\n"
        "2. Hangi geleneğin bu sembole ne anlam yüklediğini sırasıyla belirt (Örn: 'İslam ve Doğu kaynakları bu sembolü... olarak bildirirken, Antik Akdeniz bilgeliğinde bu... olarak yankılanır. Carl Jung ve analitik psikoloji ise bunu... olarak çözümler').\n"
        "3. Yüzeysel falcı veya ucuz kehanet tonundan kesinlikle uzak dur. Bütüncül, derin, şefkatli ve edebi bir üslup kullan.\n"
        "4. En sonda rüya sahibinin bugünkü uyanık hayatına ışık tutacak tek cümlelik bilge bir 'Günün Uyarısı ve Hikmeti' bırak."
    )

    user_content = (
        f"KULLANICININ GÖRDÜĞÜ RÜYA:\n\"{dream_text}\"\n\n"
        f"KİTAPLARDAN BULUNAN İLGİLİ KAYNAK PASAJLAR:\n{context_str}\n\n"
        f"Lütfen yukarıdaki kaynak ayrımına sadık kalarak, her geleneğin bakışını belirten bütüncül tabirini aktar."
    )

    # DeepSeek API Çağrısı
    if not deepseek_client:
        # API Key girilmediyse bilgilendirici ve zengin bir simülasyon yanıtı dön
        interpretation = (
            "Kadim kaynaklar rüyanızdaki sembolleri çözümlüyor:\n\n"
            "📜 Doğu ve İslam Geleneğinde: Bu sembol içsel bir arınmaya ve yakında sabırla aşılacak manevi bir eşiğe işaret eder.\n\n"
            "🏛️ Antik Akdeniz Bilgeliğinde: Kaderin (Moira) rüya sahibine sezgilerini dinlemesi yönünde fısıldadığı bir çağrıdır.\n\n"
            "🧠 Carl Jung ve Psikanalizde: Bastırılmış Gölge (Shadow) arketipinizin bilinç düzeyine çıkma gayretidir.\n\n"
            "⚡ Günün Uyarısı: İlk sezginize güvenin; mantığınızın duraksadığı yerde ruhunuz doğru yolu bilir."
        )
    else:
        try:
            logger.info("DeepSeek API'ye kaynak bilinçli prompt gönderiliyor...")
            completion = await deepseek_client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_content}
                ],
                temperature=0.7,
                max_tokens=1400
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
# 10. DOĞRUDAN ÇALIŞTIRMA (LOCAL DEV)
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
