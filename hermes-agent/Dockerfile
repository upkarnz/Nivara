FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

# Pre-install CPU-only PyTorch before sentence-transformers.
# CPU wheel is ~200 MB vs ~700 MB for the default CUDA build.
RUN pip install --prefer-binary torch \
    --index-url https://download.pytorch.org/whl/cpu

RUN pip install --prefer-binary -r requirements.txt

COPY . .

CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}
