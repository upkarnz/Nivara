"""Memory Service: orchestrates Firestore (hot), ChromaDB (vector), and Obsidian (graph)."""
import asyncio
import logging
import uuid
from datetime import datetime, timezone

from firebase_admin import firestore
from services.chroma_service import ChromaService
from services.obsidian_service import ObsidianService
from models.memory import Memory, MemoryCreate

logger = logging.getLogger(__name__)

DUPLICATE_THRESHOLD = 0.8
MEMORIES_COLLECTION = "memories"


class MemoryService:
    """Orchestrates memory persistence across Firestore, ChromaDB, and Obsidian.

    Firestore is authoritative. ChromaDB provides semantic search.
    Obsidian is fire-and-forget graph layer.
    """

    def __init__(
        self,
        chroma: ChromaService | None = None,
        obsidian: ObsidianService | None = None,
        db=None,
    ) -> None:
        self._chroma = chroma or ChromaService()
        self._obsidian = obsidian or ObsidianService()
        self._db = db or firestore.client()

    def _memories_ref(self, uid: str):
        return self._db.collection("users").document(uid).collection(MEMORIES_COLLECTION)

    def _is_duplicate(self, content_a: str, content_b: str) -> bool:
        """Jaccard-like word overlap to detect near-duplicate memories."""
        tokens_a = set(content_a.lower().split())
        tokens_b = set(content_b.lower().split())
        if not tokens_a or not tokens_b:
            return False
        overlap = len(tokens_a & tokens_b) / max(len(tokens_a), len(tokens_b))
        return overlap >= DUPLICATE_THRESHOLD

    async def _get_doc(self, ref):
        return await asyncio.to_thread(ref.get)

    async def retrieve_memories(self, uid: str, query_text: str, n: int = 5) -> list[Memory]:
        """Semantic search via ChromaDB, hydrated from Firestore."""
        ids = await self._chroma.query(query_text, uid=uid, n_results=n)
        memories: list[Memory] = []
        ref = self._memories_ref(uid)
        for memory_id in ids:
            try:
                doc = await self._get_doc(ref.document(memory_id))
                if doc.exists:
                    memories.append(Memory(id=doc.id, **doc.to_dict()))
            except Exception:
                logger.warning("Failed to fetch memory %s", memory_id, exc_info=True)
        return memories

    async def save_memory(self, uid: str, create: MemoryCreate) -> Memory:
        """Persist a new memory, reinforcing duplicates if found."""
        now = datetime.now(timezone.utc).isoformat()
        memory_id = str(uuid.uuid4())
        ref = self._memories_ref(uid)

        existing_docs = await asyncio.to_thread(
            lambda: list(ref.where("memory_type", "==", create.memory_type.value).stream())
        )
        for doc in existing_docs:
            data = doc.to_dict()
            if self._is_duplicate(create.content, data.get("content", "")):
                update_data = {
                    "last_reinforced": now,
                    "reinforcement_count": data.get("reinforcement_count", 1) + 1,
                    "confidence": max(data.get("confidence", 0), create.confidence),
                }
                await asyncio.to_thread(ref.document(doc.id).update, update_data)
                return Memory(id=doc.id, uid=uid, **{**data, **update_data})

        memory_data = {
            "uid": uid,
            "content": create.content,
            "memory_type": create.memory_type.value,
            "confidence": create.confidence,
            "created_at": now,
            "last_reinforced": now,
            "reinforcement_count": 1,
            "source_turn": create.source_turn,
        }
        await asyncio.to_thread(ref.document(memory_id).set, memory_data)
        memory = Memory(id=memory_id, **memory_data)

        await self._chroma.upsert(memory)
        asyncio.create_task(self._obsidian.write_memory(memory))

        return memory

    async def list_memories(self, uid: str) -> list[Memory]:
        """List all memories for a user, ordered by last_reinforced descending."""
        ref = self._memories_ref(uid)
        docs = await asyncio.to_thread(
            lambda: list(ref.order_by("last_reinforced", direction="DESCENDING").stream())
        )
        return [Memory(id=d.id, **d.to_dict()) for d in docs]

    async def delete_memory(self, uid: str, memory_id: str) -> None:
        """Delete from Firestore and ChromaDB."""
        ref = self._memories_ref(uid)
        await asyncio.to_thread(ref.document(memory_id).delete)
        await self._chroma.delete(memory_id)
