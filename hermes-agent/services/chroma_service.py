"""ChromaDB service for semantic vector search over memories."""
import asyncio
import logging
import chromadb
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction
from models.memory import Memory

logger = logging.getLogger(__name__)

COLLECTION_NAME = "nivara_memories"
EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2"


class ChromaService:
    """Vector store service backed by ChromaDB with sentence-transformer embeddings.

    Provides upsert, semantic query, and delete operations for Memory objects.
    All ChromaDB calls run in a thread pool via asyncio.to_thread.
    """

    def __init__(self) -> None:
        self._client = chromadb.EphemeralClient()
        embedding_fn = SentenceTransformerEmbeddingFunction(model_name=EMBEDDING_MODEL)
        self._collection = self._client.get_or_create_collection(
            name=COLLECTION_NAME,
            embedding_function=embedding_fn,
        )

    async def upsert(self, memory: Memory) -> None:
        """Insert or update a memory in the vector store."""
        await asyncio.to_thread(
            self._collection.upsert,
            ids=[memory.id],
            documents=[memory.content],
            metadatas=[{
                "uid": memory.uid,
                "memory_type": memory.memory_type.value,
                "confidence": memory.confidence,
            }],
        )

    async def query(self, text: str, uid: str | None = None, n_results: int = 5) -> list[str]:
        """Return memory IDs semantically similar to text. Returns [] on error."""
        where = {"uid": uid} if uid is not None else None
        try:
            results = await asyncio.to_thread(
                self._collection.query,
                query_texts=[text],
                n_results=n_results,
                where=where,
            )
            return results["ids"][0] if results["ids"] else []
        except Exception:
            logger.exception("ChromaDB query failed")
            return []

    async def delete(self, memory_id: str) -> None:
        """Remove a memory from the vector store by ID."""
        await asyncio.to_thread(self._collection.delete, ids=[memory_id])
