#!/usr/bin/env python3
"""Configura un Grafana nuevo con todo lo del proyecto, en un solo paso.

Crea, en este orden y solo si no existen:
  1. El data source de InfluxDB (Flux) con el token de solo lectura del .env.
  2. La carpeta "Proyecto 5".
  3. El dashboard de grafana/dashboard.json.
  4. El contact point "Telegram" con TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID del .env.
  5. Las reglas de alerta (grafana/alerting/reglas-sensores.json) y la política de
     notificaciones (grafana/alerting/politica-notificaciones.json).

El dashboard y las alertas apuntan al data source y a la carpeta por UID, así que se
crean con los mismos UID de los JSON del repo. Si se crearan a mano en la interfaz,
Grafana les daría otro UID y los paneles y las alertas quedarían sin datos.

Uso, en la VM, desde backend/ y con el stack arriba:
    python3 grafana/configurar-grafana.py
No guarda ni imprime claves: las lee del .env.
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.request

AQUI = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.dirname(AQUI)
GRAFANA = os.environ.get("GRAFANA_URL", "http://localhost:3000")
NOMBRE_CARPETA = "Proyecto 5"


def leer_env(ruta):
    valores = {}
    with open(ruta, encoding="utf-8") as f:
        for linea in f:
            linea = linea.strip()
            if linea and not linea.startswith("#") and "=" in linea:
                clave, valor = linea.split("=", 1)
                valores[clave.strip()] = valor.strip().strip('"').strip("'")
    return valores


def leer_json(ruta):
    with open(ruta, encoding="utf-8") as f:
        return json.load(f)


ENV = leer_env(os.path.join(BACKEND, ".env"))
AUTH = base64.b64encode(
    f"{ENV['GF_SECURITY_ADMIN_USER']}:{ENV['GF_SECURITY_ADMIN_PASSWORD']}".encode()
).decode()


def api(metodo, ruta, cuerpo=None, extra=None):
    """Llama a la API de Grafana. Devuelve (código HTTP, respuesta)."""
    datos = json.dumps(cuerpo).encode() if cuerpo is not None else None
    req = urllib.request.Request(GRAFANA + ruta, data=datos, method=metodo)
    req.add_header("Authorization", "Basic " + AUTH)
    req.add_header("Content-Type", "application/json")
    for k, v in (extra or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            texto = r.read().decode() or "{}"
            return r.status, json.loads(texto)
    except urllib.error.HTTPError as e:
        texto = e.read().decode() or "{}"
        try:
            return e.code, json.loads(texto)
        except ValueError:
            return e.code, {"message": texto}


def paso(texto):
    print(f"- {texto}")


def fallar(texto, respuesta):
    print(f"ERROR: {texto}: {respuesta}", file=sys.stderr)
    sys.exit(1)


def es_falso(valor):
    return not valor or valor in ("0", "token-falso-de-ejemplo")


def main():
    dashboard = leer_json(os.path.join(AQUI, "dashboard.json"))
    reglas = leer_json(os.path.join(AQUI, "alerting", "reglas-sensores.json"))
    politica = leer_json(os.path.join(AQUI, "alerting", "politica-notificaciones.json"))

    ds_uids = {r["datasourceUid"] for regla in reglas["rules"] for r in regla["data"]} - {"__expr__"}
    if len(ds_uids) != 1:
        fallar("las reglas deben usar un solo data source", ds_uids)
    ds_uid = ds_uids.pop()
    carpeta_uid = reglas["folderUid"]

    codigo, _ = api("GET", "/api/health")
    if codigo != 200:
        fallar(f"Grafana no responde en {GRAFANA}", codigo)

    # 1. Data source
    codigo, _ = api("GET", f"/api/datasources/uid/{ds_uid}")
    if codigo == 200:
        paso(f"Data source {ds_uid}: ya existía")
    else:
        token = ENV.get("INFLUXDB_GRAFANA_TOKEN", "")
        if es_falso(token):
            fallar("falta INFLUXDB_GRAFANA_TOKEN en el .env (paso de los tokens de InfluxDB)", token[:4])
        codigo, r = api("POST", "/api/datasources", {
            "uid": ds_uid, "name": "influxdb", "type": "influxdb", "access": "proxy",
            "url": "http://influxdb:8086", "isDefault": True,
            "jsonData": {"version": "Flux", "organization": ENV["INFLUXDB_ORG"],
                         "defaultBucket": ENV["INFLUXDB_BUCKET"]},
            "secureJsonData": {"token": token},
        })
        if codigo != 200:
            fallar("no se pudo crear el data source", r)
        paso(f"Data source {ds_uid} creado (InfluxDB, Flux, token de solo lectura)")
    codigo, r = api("GET", f"/api/datasources/uid/{ds_uid}/health")
    paso(f"Prueba del data source: {r.get('status', codigo)} {r.get('message', '')}".rstrip())

    # 2. Carpeta
    codigo, _ = api("GET", f"/api/folders/{carpeta_uid}")
    if codigo == 200:
        paso(f"Carpeta '{NOMBRE_CARPETA}': ya existía")
    else:
        codigo, r = api("POST", "/api/folders", {"uid": carpeta_uid, "title": NOMBRE_CARPETA})
        if codigo != 200:
            fallar("no se pudo crear la carpeta", r)
        paso(f"Carpeta '{NOMBRE_CARPETA}' creada")

    # 3. Dashboard
    codigo, _ = api("GET", f"/api/dashboards/uid/{dashboard['uid']}")
    if codigo == 200:
        paso(f"Dashboard '{dashboard['title']}': ya existía")
    else:
        dashboard["id"] = None
        dashboard.pop("version", None)
        codigo, r = api("POST", "/api/dashboards/db", {
            "dashboard": dashboard, "folderUid": carpeta_uid, "overwrite": False,
            "message": "configurar-grafana.py",
        })
        if codigo != 200:
            fallar("no se pudo importar el dashboard", r)
        paso(f"Dashboard importado: {GRAFANA}{r.get('url', '')}")

    # 4. Contact point de Telegram (las alertas lo usan por nombre)
    receptor = politica["receiver"]
    _, puntos = api("GET", "/api/v1/provisioning/contact-points")
    if any(p.get("name") == receptor for p in puntos):
        paso(f"Contact point '{receptor}': ya existía")
    else:
        bot, chat = ENV.get("TELEGRAM_BOT_TOKEN", ""), ENV.get("TELEGRAM_CHAT_ID", "")
        codigo, r = api("POST", "/api/v1/provisioning/contact-points", {
            "name": receptor, "type": "telegram",
            "settings": {"bottoken": bot or "falta", "chatid": chat or "0"},
        }, {"X-Disable-Provenance": "true"})
        if codigo not in (200, 202):
            fallar("no se pudo crear el contact point", r)
        if es_falso(bot) or es_falso(chat):
            paso(f"Contact point '{receptor}' creado SIN datos reales: completa TELEGRAM_* en el "
                 ".env y edítalo en Alerting → Contact points")
        else:
            paso(f"Contact point '{receptor}' creado con el bot del .env")

    # 5. Reglas y política. El PUT del grupo solo actualiza reglas que ya existen, así
    # que primero se crea cada regla que falte, con el mismo UID del JSON.
    sin_provenance = {"X-Disable-Provenance": "true"}
    for regla in reglas["rules"]:
        codigo, _ = api("GET", f"/api/v1/provisioning/alert-rules/{regla['uid']}")
        if codigo != 200:
            nueva = {k: v for k, v in regla.items() if k not in ("id", "updated", "provenance")}
            codigo, r = api("POST", "/api/v1/provisioning/alert-rules", nueva, sin_provenance)
            if codigo != 201:
                fallar(f"no se pudo crear la regla '{regla['title']}'", r)
    codigo, r = api("PUT", f"/api/v1/provisioning/folder/{carpeta_uid}/rule-groups/{reglas['title']}",
                    reglas, {"X-Disable-Provenance": "true"})
    if codigo != 200:
        fallar("no se pudieron cargar las reglas de alerta", r)
    paso(f"Reglas cargadas: {', '.join(x['title'] for x in reglas['rules'])}")
    codigo, r = api("PUT", "/api/v1/provisioning/policies", politica, {"X-Disable-Provenance": "true"})
    if codigo != 202 and codigo != 200:
        fallar("no se pudo cargar la política de notificaciones", r)
    paso(f"Política de notificaciones cargada (todo va a '{receptor}')")
    print("Listo.")


if __name__ == "__main__":
    main()
