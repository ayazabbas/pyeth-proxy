FROM python:3.10-alpine AS builder
WORKDIR /app
ADD pyeth-proxy/pyproject.toml pyeth-proxy/poetry.lock /app/

RUN apk add build-base libffi-dev
RUN pip install poetry
RUN poetry config virtualenvs.in-project true
RUN poetry install --no-ansi

# ---

FROM python:3.10-alpine
WORKDIR /app

COPY --from=builder /app /app
ADD ./pyeth-proxy /app

RUN addgroup -g 1000 app && \
    adduser app -h /app -u 1000 -G app -DH && \
    chown -R app:app /app

USER 1000

CMD /app/.venv/bin/uvicorn pyeth_proxy.main:app --host 0.0.0.0 --proxy-headers
