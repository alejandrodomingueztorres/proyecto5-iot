"""Simulador de sensores del Proyecto 5 (Rol 1).

Publica temperatura y humedad por MQTT segun docs/contrato.md:
  - topics de datos:  iot/{DEVICE_ID}/temperatura  e  iot/{DEVICE_ID}/humedad
  - topic de estado:  iot/{DEVICE_ID}/status  ("online"/"offline", retenido, QoS 1)
  - Last Will:        "offline" en el topic de estado si la conexion se cae de golpe
  - payload JSON:     {"device_id","sensor","value","unit","ts"}  (ts en UTC, termina en Z)

Toda la configuracion llega por variables de entorno (contrato, seccion 7).
"""
import json
import os
import random
import signal
import sys
import threading
import time
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

print("simulador v3", datetime.now(timezone.utc).isoformat(timespec="seconds"), flush=True)

DEVICE_ID = os.environ["DEVICE_ID"]
MQTT_USER = os.environ.get("MQTT_USER", DEVICE_ID)
MQTT_PASSWORD = os.environ["MQTT_PASSWORD"]
BROKER_HOST = os.environ["BROKER_HOST"]
BROKER_PORT = int(os.environ.get("BROKER_PORT", "8883"))
CA_CERT_PATH = os.environ.get("CA_CERT_PATH", "/app/ca.crt")
PUBLISH_INTERVAL = float(os.environ.get("PUBLISH_INTERVAL", "5"))

# Rango normal del simulador (contrato, seccion 1): por debajo del umbral de alerta (30 C).
TEMP_MIN, TEMP_MAX = 20.0, 29.0
HUM_MIN, HUM_MAX = 40.0, 80.0

# Opcional, solo para demos y pruebas de alertas (R5.6): si se define TEMP_FORZADA en Balena
# (por ejemplo 32), la temperatura publicada es ese valor +-0.5 en vez del rango normal.
# Sin la variable, el simulador se comporta igual que siempre. Se limita al rango fisico
# valido del contrato (-20 a 80 C) para no generar mensajes que Node-RED descartaria.
TEMP_FORZADA = None
_forzada = os.environ.get("TEMP_FORZADA", "").strip()
if _forzada:
    try:
        _valor = float(_forzada)
        if not -1000.0 < _valor < 1000.0:  # tambien descarta nan e inf
            raise ValueError(_forzada)
        TEMP_FORZADA = min(80.0, max(-20.0, _valor))
    except ValueError:
        print(f"TEMP_FORZADA='{_forzada}' no es un numero: se ignora", flush=True)

STATUS_TOPIC = f"iot/{DEVICE_ID}/status"

connected = threading.Event()
stop = threading.Event()


def log(msg):
    print(f"{datetime.now(timezone.utc).isoformat(timespec='seconds')} [{DEVICE_ID}] {msg}", flush=True)


def now_utc():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def on_connect(client, userdata, flags, reason_code, properties):
    if reason_code.is_failure:
        log(f"conexion rechazada: {reason_code}")
        return
    log(f"conectado a {BROKER_HOST}:{BROKER_PORT}")
    if TEMP_FORZADA is not None:
        log(f"AVISO: TEMP_FORZADA activa ({TEMP_FORZADA} C), la temperatura no es la normal")
    # Se publica aqui (y no una sola vez al arrancar) para que tras cada reconexion
    # el estado retenido vuelva a ser "online".
    client.publish(STATUS_TOPIC, "online", qos=1, retain=True)
    connected.set()


def on_disconnect(client, userdata, disconnect_flags, reason_code, properties):
    connected.clear()
    log(f"desconectado: {reason_code}")


def main():
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=DEVICE_ID)
    client.username_pw_set(MQTT_USER, MQTT_PASSWORD)
    if BROKER_PORT != 1883:  # 1883 solo para pruebas locales sin TLS; el sistema real usa 8883
        client.tls_set(ca_certs=CA_CERT_PATH)
    client.will_set(STATUS_TOPIC, "offline", qos=1, retain=True)
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.reconnect_delay_set(min_delay=1, max_delay=30)

    def shutdown(signum, frame):
        stop.set()

    signal.signal(signal.SIGTERM, shutdown)  # balena envia SIGTERM al actualizar el contenedor
    signal.signal(signal.SIGINT, shutdown)

    # connect_async + loop_start: si el broker no esta disponible al arrancar, reintenta solo.
    client.connect_async(BROKER_HOST, BROKER_PORT, keepalive=30)
    client.loop_start()

    while not stop.is_set():
        if connected.is_set():
            ts = now_utc()
            if TEMP_FORZADA is None:
                temperatura = random.uniform(TEMP_MIN, TEMP_MAX)
            else:
                temperatura = min(80.0, max(-20.0, TEMP_FORZADA + random.uniform(-0.5, 0.5)))
            lecturas = [
                ("temperatura", "C", temperatura),
                ("humedad", "%", random.uniform(HUM_MIN, HUM_MAX)),
            ]
            for sensor, unit, value in lecturas:
                msg = {
                    "device_id": DEVICE_ID,
                    "sensor": sensor,
                    "value": round(value, 1),
                    "unit": unit,
                    "ts": ts,
                }
                client.publish(f"iot/{DEVICE_ID}/{sensor}", json.dumps(msg), qos=1)
                log(f"{sensor}={msg['value']}")
        else:
            log("esperando conexion con el broker...")
        stop.wait(PUBLISH_INTERVAL)

    # Cierre limpio: un disconnect() normal NO activa el Last Will, asi que se avisa a mano.
    if connected.is_set():
        info = client.publish(STATUS_TOPIC, "offline", qos=1, retain=True)
        info.wait_for_publish(timeout=3)
    client.disconnect()
    client.loop_stop()
    log("detenido")


if __name__ == "__main__":
    try:
        main()
    except KeyError as e:
        sys.exit(f"Falta la variable de entorno {e}")
