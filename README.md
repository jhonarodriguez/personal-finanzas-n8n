# 💰 Agente Personal de Finanzas — n8n

Sistema de control financiero personal automatizado con **n8n**, **PostgreSQL**, **Telegram Bot** y **Google Sheets**.

## 🏗️ Arquitectura

```
Telegram Bot  ──►  n8n (workflows)  ──►  PostgreSQL (source of truth)
                        │
                        └──►  Google Sheets (reporte mensual)
```

## ✨ Funcionalidades

- **Configurar** sueldo mensual, gastos fijos (arriendo, Netflix, etc.)
- **Registrar** gastos diarios desde el bot de Telegram
- **Calcular** saldo proyectado vs saldo real del banco
- **Sincronizar** todo a Google Sheets (1 hoja por mes)
- **Automatizar** creación de hoja mensual con rollover

## 🚀 Inicio rápido

### Prerrequisitos

- [Docker Desktop](https://docs.docker.com/get-docker/) instalado
- Un bot de Telegram (creado con [@BotFather](https://t.me/BotFather))
- Credenciales de Google Sheets API (opcional para fase inicial)

### Instalación

```bash
# 1. Clonar el repositorio
git clone <tu-repo-url>
cd personal-finanzas-n8n

# 2. Crear archivo de variables de entorno
cp .env.example .env
# Edita .env con tus valores reales

# 3. Levantar servicios
docker compose up -d

# 4. Abrir n8n en el navegador
# http://localhost:5678
```

### Verificar que todo funciona

```bash
# Ver estado de los contenedores
docker compose ps

# Ver logs de n8n
docker compose logs -f n8n

# Conectar a PostgreSQL (para verificar BD)
docker compose exec postgres psql -U finanzas_user -d finanzas_db
```

## 📁 Estructura del proyecto

```
personal-finanzas-n8n/
├── docker-compose.yml      # Orquestación de servicios
├── .env.example            # Plantilla de variables de entorno
├── .gitignore              # Archivos excluidos de Git
├── db/
│   ├── migrations/         # Scripts SQL de creación de tablas
│   └── seeds/              # Datos de ejemplo para desarrollo
├── workflows/              # Exports JSON de workflows n8n
├── docs/                   # Documentación adicional
└── scripts/                # Scripts de utilidad
```

## 📊 Modelo de datos

| Tabla | Propósito |
|-------|-----------|
| `users` | Usuarios del bot (chat_id, canal, timezone) |
| `finance_profiles` | Sueldo mensual, saldo real, mes de referencia |
| `fixed_expenses` | Gastos fijos configurados (Netflix, arriendo, etc.) |
| `expense_entries` | Gastos variables diarios registrados por el bot |
| `income_entries` | Ingresos extra del mes |
| `monthly_snapshots` | Resumen calculado: proyectado vs real vs diferencia |
| `sync_logs` | Registro de sincronizaciones con Google Sheets |

## 🤖 Comandos del bot

| Comando | Descripción | Ejemplo |
|---------|-------------|---------|
| `/start` | Registrar usuario | `/start` |
| `/sueldo <monto>` | Configurar sueldo | `/sueldo 5000000` |
| `/fijo <nombre> <monto>` | Agregar gasto fijo | `/fijo netflix 30000` |
| `/gasto <concepto> <monto>` | Registrar gasto variable | `/gasto almuerzo 18000` |
| `/banco <monto>` | Actualizar saldo real | `/banco 3200000` |
| `/resumen` | Ver resumen del mes | `/resumen` |
| `/sync` | Forzar sincronización a Sheets | `/sync` |

## 🛡️ Seguridad

- Variables sensibles en `.env` (nunca en código)
- Autenticación básica en panel n8n
- Credenciales Google cifradas por n8n
- Validación de input en cada comando del bot

## 📝 Licencia

Proyecto personal de portafolio.
