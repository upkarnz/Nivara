from pydantic import BaseModel


class TokenData(BaseModel):
    uid: str
    email: str | None = None
