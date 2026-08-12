from datetime import datetime

from pydantic import BaseModel, ConfigDict


class DocumentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    file_name: str
    url: str
    resource_type: str
    file_size_bytes: int | None
    uploaded_at: datetime
