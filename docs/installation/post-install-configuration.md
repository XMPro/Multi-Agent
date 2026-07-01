# Post-Installation Configuration — Stream Designer & App Designer Variables

Once the MAGS infrastructure stack (Neo4j, MQTT, TimescaleDB, the vector database, Ollama, OpenTelemetry) is deployed and healthy, the deployed MAGS **Stream Designer** stream and **App Designer** pages still have no way to reach it. Connection details are supplied through **Variables** you create in XMPro. This run sheet is the "what to do next" step: create each variable, in the right app, with the right value.

> This guide is deployment-agnostic. Wherever it says "from your credentials store", the Docker installer has already written the value to `CREDENTIALS.txt` in the install directory — that is the worked example used throughout.

## Before you start

- [ ] The infrastructure stack is running and reachable from the XMPro host.
- [ ] You have the generated secrets to hand. For the Docker deployment, open `CREDENTIALS.txt` from the install directory.
- [ ] XMPro is licensed, and you can open both **Stream Designer** and **App Designer**.
- [ ] You know the **hostname/address** each XMPro app should use to reach the stack. Below this is written as `<host>`; replace it with your actual host (or the Docker service name / IP). Secure ports assume the SSL-enabled stack.

## How to read this run sheet

- Variables are split into two lists — **create each list in its own app.** Stream Designer and App Designer share the same variables, but each app encrypts values with its **own encryption key**, so a value entered in one app cannot be decrypted by the other. Every variable — including the ones needed by *both* apps — must be entered **separately in each app**; you cannot set it once and have it carry across.
- **Secure?** = `Yes` means create the variable as a **Secure** variable so its value is masked and not exported in plain text. These map 1:1 to the secrets in your credentials store.
- Values shown as `<...>` are placeholders — substitute your environment's value.

---

## 1. Stream Designer variables

Create these in **Stream Designer**.

| Key | Value | Secure? |
|-----|-------|---------|
| `otel_endpoint` | `http://<host>:4318` (OpenTelemetry collector; omit if not using OTel) | No |
| `neo4j_database` | `neo4j` | No |
| `neo4j_uri` | `neo4j+s://<host>:7687` | No |
| `neo4j_neo4j_username` | `neo4j` | No |
| `neo4j_neo4j_password` | Neo4j password — from your credentials store | **Yes** |
| `mags_memory_collection` | `mags_agent_memories` | No |
| `rag_general` | `rag_general` | No |
| `mqtt_broker` | `<host>` | No |
| `mqtt_port` | `1883` | No |
| `mqtt_usetls` | `FALSE` | No |
| `mqtt_xmpro_username` | `xmpro` | No |
| `mqtt_xmpro_password` | MQTT `xmpro` user password — from your credentials store | **Yes** |
| `ollama_host_url` | `https://<host>:11443` | No |
| `ollama_embedding_model` | your embedding model name (e.g. `nomic-embed-text`) | No |
| `ollama_inference_model` | your inference model name | No |
| `timescaledb_host` | `<host>` | No |
| `timescaledb_port` | `5432` | No |
| `timescaledb_database` | `timescaledb` | No |
| `timescaledb_postgres_username` | `postgres` | No |
| `timescaledb_postgres_password` | Postgres/TimescaleDB password — from your credentials store | **Yes** |
| `vector_url` | `https://<host>:19531` | No |
| `vector_db_name` | `default` | No |
| `vector_api_key` | vector DB API key — from your credentials store | **Yes** |

---

## 2. App Designer variables

Create these in **App Designer**. Note the values that intentionally differ from Stream Designer (**⚠️** below).

| Key | Value | Secure? |
|-----|-------|---------|
| `neo4j_db_type` | `neo4j-https` | No |
| `neo4j_uri` | `neo4j+s://<host>:7687` | No |
| `neo4j_uri_https` | `https://<host>:7473/db/neo4j/query/v2` | No |
| `neo4j_database` *(if required by your app)* | `neo4j` | No |
| `neo4j_neo4j_username` | `neo4j` | No |
| `neo4j_neo4j_password` | Neo4j password — from your credentials store | **Yes** |
| `neo4j_neo4j_https` ⚠️ | **base64 of `username:password`** — see [section 3](#3-the-neo4j_neo4j_https-token) | **Yes** |
| `mqtt_broker` | `<host>` | No |
| `mqtt_port` ⚠️ | `9003` (**not** 1883 — App Designer uses the websocket port) | No |
| `mqtt_protocol` | `wss://` | No |
| `mqtt_xmpro_username` | `xmpro` | No |
| `mqtt_xmpro_password` | MQTT `xmpro` user password — from your credentials store | **Yes** |
| `ollama_host_url` | `https://<host>:11443` | No |
| `ollama_embedding_model` | your embedding model name | No |
| `ollama_inference_model` | your inference model name | No |
| `timescaledb_host` | `<host>` | No |
| `timescaledb_port` | `5432` | No |
| `timescaledb_database` | `timescaledb` | No |
| `timescaledb_postgres_username` | `postgres` | No |
| `timescaledb_postgres_password` | Postgres/TimescaleDB password — from your credentials store | **Yes** |
| `vector_db_type` | `milvus-https` | No |
| `vector_url` | `https://<host>:19531` | No |
| `vector_db_name` | `default` | No |
| `vector_api_key` | vector DB API key — from your credentials store | **Yes** |

---

## 3. The `neo4j_neo4j_https` token

App Designer talks to Neo4j over the **HTTPS Query API** (`neo4j_uri_https` → `https://<host>:7473/db/neo4j/query/v2`), which authenticates with an **HTTP Basic** header. The `neo4j_neo4j_https` variable holds that token: the base64 encoding of `username:password`.

**Docker deployment — no manual encoding needed.** The installer pre-computes this and writes it into `CREDENTIALS.txt` under the Neo4j section:

```
App Designer variable 'neo4j_neo4j_https' (base64 of username:password):
  bmVvNGo6eW91cnBhc3N3b3Jk
```

Copy that value straight into the `neo4j_neo4j_https` variable (mark it **Secure**).

**Any other deployment — compute it yourself** from your Neo4j username and password:

```bash
# Linux / macOS
printf '%s:%s' "neo4j" "YOUR_NEO4J_PASSWORD" | base64
```

```powershell
# Windows PowerShell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("neo4j:YOUR_NEO4J_PASSWORD"))
```

Re-run this whenever the Neo4j password changes.

---

## 4. Watch-outs

- **`mqtt_port` is not the same in both apps** — Stream Designer uses `1883` (native MQTT), App Designer uses `9003` (MQTT over websockets, paired with `mqtt_protocol=wss://`). Copying 1883 into App Designer is the most common mistake.
- **Secure variables** — always create the five password/key/token variables as Secure so they are masked and excluded from plain-text exports.
- **Host and ports must match your deployment** — the URLs above assume the SSL-enabled stack (7473/7687 for Neo4j, 11443 for Ollama, 19531 for the vector DB). Adjust if you deployed on different ports or without SSL.
- **Ollama model names** are environment-specific — set them to the exact models you pulled for embedding and inference.

## 5. Verify

- [ ] Every Secure variable resolves against the value in your credentials store.
- [ ] `neo4j_neo4j_https` matches the token in `CREDENTIALS.txt` (Docker) or your recomputed value.
- [ ] Stream Designer: the MAGS stream starts and connects to Neo4j, MQTT (1883), TimescaleDB, and the vector DB without connection errors.
- [ ] App Designer: pages load MAGS data over the HTTPS Query API and MQTT over websockets (9003).
