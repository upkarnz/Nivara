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

    async def query(self, text: str, uid: str = "", n_results: int = 5) -> list[str]:
        """Return memory IDs semantically similar to text. Returns [] on error."""
        where = {"uid": uid} if uid else None
        try:
            results = await asyncio.to_thread(
                self._collection.query,
                query_texts=[text],
                n_results=n_results,
                where=where,
            )
            return results["ids"][0] if results["ids"] else []
        except Exception as e:
            logger.warning("ChromaDB query failed: %s", e)
            return []

    async def delete(self, memory_id: str) -> None:
        """Remove a memory from the vector store by ID."""
        await asyncio.to_thread(self._collection.delete, ids=[memory_id])
