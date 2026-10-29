FROM python:3.12-slim
RUN useradd --uid 10001 --create-home taskhub && mkdir /data && chown taskhub /data
WORKDIR /app
COPY backend /app/backend
USER taskhub
ENV TASKHUB_HOST=0.0.0.0 TASKHUB_DB=/data/taskhub.sqlite3 PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"
CMD ["python", "-m", "backend.app"]
