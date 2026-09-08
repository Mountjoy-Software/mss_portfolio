FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src ./src

ARG APP_VERSION=local-dev
ENV APP_VERSION=${APP_VERSION}
ENV ENV=production
ENV PYTHONUNBUFFERED=1

EXPOSE 8000

RUN adduser --disabled-password --gecos "" --uid 10001 app
USER app

CMD ["python", "-m", "src.main"]
