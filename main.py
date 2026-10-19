"""
Oneiro Backend - Root Proxy Entrypoint
Bu dosya, backend uygulamasını kök dizinden çalıştırabilmek (örneğin Render veya lokal uvicorn 'main:app')
için backend/main.py dosyasını dışa aktarır.

Tek gerçek backend kodu ve kitaplar: 'backend/' klasöründedir.
"""
import os
import sys

# Backend dizinini Python modül arama yoluna ekle
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.join(BASE_DIR, "backend")
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

# Tek gerçek olan backend/main.py uygulamasını ve bileşenlerini dışa aktar
from backend.main import (
    app,
    lifespan,
    CHUNKS_DB,
    index_books,
    retrieve_top_k,
    DreamInterpretRequest,
    DreamInterpretResponse,
    SourceUsedItem,
    BOOKS_DIR
)

__all__ = [
    "app",
    "lifespan",
    "CHUNKS_DB",
    "index_books",
    "retrieve_top_k",
    "DreamInterpretRequest",
    "DreamInterpretResponse",
    "SourceUsedItem",
    "BOOKS_DIR"
]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)
