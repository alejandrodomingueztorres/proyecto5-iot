FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ca.crt es la CA publica del broker (la entrega el Rol 2). Si falta, el build falla a proposito.
COPY simulador.py ca.crt ./

ENV PYTHONUNBUFFERED=1

CMD ["python", "-u", "simulador.py"]
