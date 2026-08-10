FROM python:3.11-slim

# Install system dependencies including Tesseract OCR, PyMuPDF dependencies
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    libtesseract-dev \
    libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Set container default port environment
ENV PORT=8080
ENV DATABASE_URL=sqlite:///./academic_research.db
ENV TESSERACT_CMD=tesseract
ENV MODEL_PROVIDER=gemini

CMD uvicorn app.main:app --host 0.0.0.0 --port $PORT
