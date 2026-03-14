# 🛠️ Guía de Configuración Inicial

Esta guía te lleva paso a paso por toda la configuración necesaria **antes** de empezar a crear workflows en n8n.

---

## Paso 1 — Crear tu Bot de Telegram con @BotFather

1. Abre **Telegram** en tu celular o PC.
2. Busca **@BotFather** (tiene un check azul ✅ de verificado).
3. Envíale el comando `/newbot`.
4. Te pedirá un **nombre visible** para el bot → escribe algo como:
   ```
   Mi Finanzas Bot
   ```
5. Te pedirá un **username** (debe terminar en `bot`) → escribe algo como:
   ```
   mi_finanzas_personal_bot
   ```
6. **BotFather te responderá con un token** tipo:
   ```
   7123456789:AAH1b2c3d4e5f6g7h8i9j0k...
   ```
7. **Copia ese token completo** — lo necesitas para el `.env`.

> 💡 **Tip:** también puedes enviarle `/setdescription` a BotFather y poner una descripción como *"Bot personal para control de gastos mensuales"*, para que se vea más profesional.

---

## Paso 2 — Crear tu archivo `.env`

1. Ve a la carpeta del proyecto:
   ```
   C:\Users\Admin\Documents\personal-repos\personal-finanzas-n8n
   ```

2. **Copia** el archivo `.env.example` y renómbralo a `.env`:
   - Click derecho en `.env.example` → Copiar → Pegar → Renombrar a `.env`
   - O desde terminal:
     ```bash
     copy .env.example .env
     ```

3. **Abre `.env`** con VS Code y edita estos 3 valores:

   | Variable | Qué poner |
   |----------|-----------|
   | `POSTGRES_PASSWORD` | Una contraseña inventada, ej: `MiFinanzas2026!` |
   | `N8N_BASIC_AUTH_PASSWORD` | Otra contraseña para el panel n8n, ej: `N8nAdmin2026!` |
   | `TELEGRAM_BOT_TOKEN` | El token que te dio BotFather en el paso 1 |

   Los demás valores (`POSTGRES_USER`, `POSTGRES_DB`, `N8N_HOST`, etc.) **déjalos como están**, funcionan bien con los defaults.

> ⚠️ **Importante:** el archivo `.env` está en `.gitignore`, así que **NUNCA** se subirá a GitHub. Eso es correcto y por diseño.

---

## Paso 3 — Levantar Docker y verificar

### Pre-requisito: Docker Desktop

- Si no lo tienes: descárgalo de [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/)
- Ábrelo y espera a que el ícono de la ballena (🐳) diga **"Docker Desktop is running"**

### Levantar los servicios

Abre terminal en la carpeta del proyecto y ejecuta:

```bash
docker compose up -d
```

**¿Qué pasa aquí?**
- Docker descarga las imágenes de PostgreSQL y n8n (solo la primera vez, puede tardar 2-5 minutos).
- Crea los contenedores.
- PostgreSQL arranca y ejecuta automáticamente `001_initial_schema.sql` (crea las 7 tablas).
- n8n arranca y se conecta a PostgreSQL.

---

## Paso 4 — Verificar que todo funciona

### 4a. Verificar contenedores

```bash
docker compose ps
```

Debes ver **2 servicios** con estado `Up` o `running (healthy)`:
- `finanzas-postgres`
- `finanzas-n8n`

### 4b. Abrir n8n en el navegador

- Ve a: **[http://localhost:5678](http://localhost:5678)**
- Te pedirá usuario/contraseña → usa los valores de `N8N_BASIC_AUTH_USER` y `N8N_BASIC_AUTH_PASSWORD` de tu `.env`.
- Si ves el dashboard de n8n, **¡está funcionando!** 🎉

### 4c. Verificar la base de datos (opcional pero recomendado)

```bash
docker compose exec postgres psql -U finanzas_user -d finanzas_db -c "\dt"
```

Debes ver las 7 tablas:

| Tabla | Propósito |
|-------|-----------|
| `users` | Usuarios del bot |
| `finance_profiles` | Sueldo y saldo real |
| `fixed_expenses` | Gastos fijos (Netflix, arriendo, etc.) |
| `expense_entries` | Gastos variables diarios |
| `income_entries` | Ingresos extra |
| `monthly_snapshots` | Resumen calculado mensual |
| `sync_logs` | Registro de sincronizaciones |

### 4d. Cargar datos de prueba (opcional)

```bash
docker compose exec postgres psql -U finanzas_user -d finanzas_db -f /docker-entrypoint-initdb.d/../seeds/001_sample_data.sql
```

---

## 🔍 Solución de problemas comunes

| Problema | Solución |
|----------|----------|
| `docker compose` no reconocido | Asegúrate de tener Docker Desktop 4.x+. Intenta `docker-compose` (con guión) |
| Puerto 5678 ocupado | Cambia `N8N_PORT` en `.env` a otro puerto, ej: `5679` |
| Puerto 5432 ocupado | Cambia `POSTGRES_PORT` en `.env` a otro, ej: `5433` |
| PostgreSQL no arranca | Revisa logs: `docker compose logs postgres` |
| n8n dice "database not ready" | Espera 10 segundos y recarga, el healthcheck necesita tiempo |

---

## ✅ Checklist antes de pasar a la siguiente fase

- [ ] Bot creado en Telegram con BotFather → tengo el token
- [ ] Archivo `.env` creado con mis valores reales
- [ ] Docker Desktop corriendo
- [ ] `docker compose up -d` ejecutado sin errores
- [ ] http://localhost:5678 abre el panel de n8n
- [ ] Las 7 tablas existen en PostgreSQL

---

> **Cuando todo el checklist esté listo, pasamos a la Fase 1:** crear los primeros workflows en n8n para configurar sueldo, gastos fijos y saldo real desde el bot de Telegram. 🚀
