FROM python:3.12-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

COPY pyproject.toml uv.lock* ./
RUN uv sync --no-dev --no-install-project

COPY server.py ./

ENV PORT=8080
ENV HOST=0.0.0.0
EXPOSE 8080

CMD ["uv", "run", "server.py"]
