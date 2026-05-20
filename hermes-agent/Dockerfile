FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

# Pre-install CPU-only PyTorch before sentence-transformers.
# Default PyPI torch includes CUDA (~700 MB); CPU wheel is ~200 MB.
# BuildKit cache mount reuses downloaded wheels across Railway builds.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefer-binary torch \
    --index-url https://download.pytorch.org/whl/cpu

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefer-binary -r requirements.txt

COPY . .

CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}
