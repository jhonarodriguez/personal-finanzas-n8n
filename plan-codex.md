# Plan de implementación — Agente personal de finanzas con n8n

## 1) Estado actual analizado

- **Repositorio objetivo (`personal-finanzas-n8n`)**: actualmente está vacío (greenfield).
- **Referencia funcional existente (`control-gastos-mensuales`)**:
  - Ya resuelve parte del dominio: configuración de sueldo/gastos fijos, registro de gastos variables, hoja mensual por mes/año, comparación saldo real vs proyectado, sync con Google Drive.
  - Está implementado en Python con lógica acoplada (parser + Excel + Drive + API local), útil como **fuente de reglas de negocio** pero no como arquitectura final para portafolio n8n.
- Conclusión: conviene crear una versión nueva orientada a automatizaciones n8n, reutilizando reglas de negocio del proyecto Python como insumo.

---

## 2) Objetivo del proyecto

Construir un agente financiero personal con estas capacidades:

1. Configuración de parámetros financieros (sueldo, gastos fijos, categorías, saldo real, etc.).
2. Registro diario de gastos desde bot (WhatsApp o Telegram).
3. Cálculo permanente de:
   - saldo proyectado,
   - saldo real reportado,
   - diferencia entre ambos.
4. Generación de reportes y resúmenes desde PostgreSQL con queries optimizadas.
5. Persistencia de configuración estable en BD.
6. Diseño demostrable para portafolio (buenas prácticas, observabilidad, seguridad, documentación).

---

## 3) Alcance funcional propuesto (MVP -> Portafolio)

### MVP (primera versión usable)

- Canal de bot (iniciar con **1 canal**, idealmente Telegram por simplicidad técnica).
- Comandos base:
  - `/config sueldo 5000000`
  - `/config fijo netflix 30000 mensual`
  - `/gasto almuerzo 18000`
  - `/saldo`
  - `/resumen`
- BD con configuración fija + movimientos diarios.
- Cálculo de proyección mensual y diferencia contra saldo real.
- Sincronización con Google Sheets (hoja del mes si no existe).

### Iteración portafolio (segunda fase)

- Soporte multi-canal (Telegram + WhatsApp).
- Parser de lenguaje natural robusto (múltiples gastos por mensaje).
- Categorías inteligentes y validaciones.
- Reglas avanzadas (recordatorios, alertas de desviación, cierre de mes, rollover).
- Reportes y gráficos generados desde PostgreSQL.
- Dashboard opcional (n8n + frontend ligero o exportación a Excel/PDF bajo demanda).

---

## 4) Arquitectura objetivo (n8n-centric)

## Componentes

1. **n8n** (orquestación principal)
   - Webhooks/comandos del bot.
   - Flujos de negocio y validación.
   - Cálculo y escritura en BD.
   - Generación de reportes y resúmenes.

2. **Base de datos (PostgreSQL)**
   - Persistencia durable y trazable.
   - Versionado de configuración y auditoría de movimientos.
   - Fuente única de verdad para todos los datos.
   - Cálculos y agregaciones con queries SQL optimizadas.

3. **Proveedor de mensajería**
   - Fase 1: Telegram Bot API.
   - Fase 2: WhatsApp Cloud API o Twilio WhatsApp.

## Decisión técnica recomendada

- n8n self-hosted + PostgreSQL + Telegram para MVP.
- Motivo: menor fricción de integración, costo inicial bajo, excelente trazabilidad y control total sobre los datos.

---

## 5) Modelo de datos (BD)

## Tablas núcleo

1. `users`
- id
- chat_id
- canal (`telegram|whatsapp`)
- timezone
- moneda
- created_at

2. `finance_profiles`
- id
- user_id (FK)
- sueldo_mensual
- saldo_real_actual
- mes_referencia (`YYYY-MM`)
- updated_at

3. `fixed_expenses`
- id
- user_id (FK)
- nombre
- valor
- frecuencia (`mensual|quincenal|semanal`)
- dia_cargo (nullable)
- activo
- updated_at

4. `expense_entries`
- id
- user_id (FK)
- fecha_gasto
- concepto
- categoria
- valor
- origen (`bot|manual|ajuste`)
- mensaje_fuente (nullable)
- created_at

5. `income_entries` (opcional MVP, recomendado)
- id
- user_id (FK)
- fecha
- concepto
- valor
- created_at

6. `monthly_snapshots`
- id
- user_id (FK)
- mes (`YYYY-MM`)
- total_fijos
- total_variables
- total_ingresos_extra
- saldo_proyectado
- saldo_real
- diferencia
- recalculated_at

7. `sync_logs`
- id
- user_id
- mes
- destino (`google_sheets`)
- estado (`ok|error`)
- detalle_error
- created_at

---

## 6) Reportes y consultas desde PostgreSQL

Los reportes se generan dinámicamente desde la base de datos usando queries SQL optimizadas.

## Tipos de reportes disponibles

1. **Resumen mensual**
   - Sueldo del mes
   - Total gastos fijos
   - Total gastos variables
   - Saldo proyectado
   - Saldo real
   - Diferencia

2. **Detalle de gastos variables**
   - Lista de gastos del mes con fecha, concepto, categoría y valor
   - Agrupado por categoría
   - Ordenado por fecha descendente

3. **Detalle de gastos fijos**
   - Lista de gastos fijos configurados
   - Con valor y frecuencia

4. **Análisis por categoría**
   - Total gastado por categoría en el mes
   - Comparación con meses anteriores (opcional)

## Comandos del bot para reportes

- `/resumen` → Resumen completo del mes actual
- `/gastos` → Lista detallada de gastos variables del mes
- `/fijos` → Lista de gastos fijos configurados
- `/categorias` → Gastos agrupados por categoría
- `/historial [mes]` → Resumen de un mes anterior

---

## 7) Workflows n8n propuestos

## WF-01 `bot_ingest_command`
- Trigger: webhook Telegram/WhatsApp.
- Función: identificar intención (`config`, `gasto`, `saldo`, `resumen`, `sync`).
- Salida: enruta a sub-workflow correspondiente.

## WF-02 `config_upsert`
- Actualiza sueldo, saldo real, gastos fijos.
- Guarda en BD con validaciones.
- Responde confirmación al chat.

## WF-03 `expense_register`
- Parsea gasto(s) del mensaje.
- Inserta en `expense_entries`.
- Recalcula snapshot mensual.
- Retorna confirmación al chat.

## WF-04 `monthly_projection_recalc`
- Calcula: `saldo_proyectado = saldo_inicio + ingresos - fijos - variables`.
- Lee saldo real actual.
- Persiste diferencia en `monthly_snapshots`.

## WF-05 `generate_report`
- Recibe tipo de reporte solicitado (resumen, gastos, categorías).
- Ejecuta queries SQL correspondientes.
- Formatea respuesta en texto legible.
- Envía al chat con formato Markdown.

## WF-06 `month_rollover_scheduler`
- Cron mensual (fin/inicio de mes).
- Crea snapshot inicial del nuevo mes.
- Envía resumen automático del mes cerrado al chat.

## WF-07 `healthcheck_alerting`
- Monitorea fallos de ejecución n8n.
- Notifica errores críticos (Telegram/email).

---

## 8) Reglas de negocio clave

1. PostgreSQL es la **fuente única de verdad** para todos los datos.
2. Cada gasto diario registra fecha exacta y origen.
3. Debe existir comando para actualizar saldo real del banco.
4. Diferencia = `saldo_real - saldo_proyectado`.
5. Si la diferencia supera umbral configurable, generar alerta.
6. Cambios de sueldo/fijos deben versionarse (auditoría).
7. Los reportes se generan dinámicamente desde queries SQL.
8. Las respuestas del bot deben ser claras y legibles (formato Markdown).

---

## 9) Seguridad y buenas prácticas (portafolio)

- Variables sensibles en `.env` (tokens/API keys/credenciales).
- Principio de mínimo privilegio en Google API.
- Validación estricta de input de bot.
- Idempotencia en sincronización (evitar duplicados).
- Logging estructurado por workflow + correlation id.
- Backups de BD + export de workflows n8n.
- README técnico + diagrama + ADRs de decisiones.

---

## 10) Plan de implementación por fases

## Fase 0 — Bootstrap técnico
- Levantar n8n y PostgreSQL (docker-compose).
- Estructura de proyecto y `.env.example`.
- Configurar credenciales en n8n (Telegram + Google + DB).

## Fase 1 — Dominio financiero base ✅ COMPLETADA
- Crear esquema BD (migraciones).
- Implementar WF-02 (`config_upsert`).
- Implementar AI Agent con conversación natural.

## Fase 2 — Registro de gastos ✅ COMPLETADA
- Implementar WF-01 y WF-03.
- Parser avanzado de gastos con normalización de montos.
- Categorización automática.
- Respuestas de bot con confirmación y resumen corto.
- Pruebas de casos: 1 gasto, múltiples gastos, errores de formato.

## Fase 3 — Reportes y análisis financiero 🚧 EN PROGRESO
- Implementar sistema de snapshots mensuales automáticos.
- Implementar WF-05 para generar reportes desde PostgreSQL.
- Comandos: "dame un resumen", "por categorías", "gastos de hoy".
- Análisis comparativo con mes anterior.
- Formateo de respuestas con Markdown para mejor legibilidad.

## Fase 4 — Automatización mensual
- Implementar WF-06 (rollover del mes).
- Snapshot inicial de mes nuevo.
- Envío automático de resumen mensual.

## Fase 5 — Hardening portafolio
- WF-07 observabilidad/alertas.
- Manejo de errores y reintentos.
- Documentación final + evidencia (capturas/diagramas).

---

## 11) Estrategia de pruebas

- **Unitarias (funciones parser/cálculo)**: montos, categorías, saldo proyectado, diferencia.
- **Integración**: bot -> n8n -> DB -> Sheets.
- **E2E**: comando real desde chat y ver reflejo en hoja mensual.
- **No regresión**: evitar duplicados al reintentar sync.
- **UAT personal**: escenario completo de 1 mes simulado.

---

## 12) Riesgos y mitigación

1. **Complejidad WhatsApp** (webhooks/plantillas/políticas)
   - Mitigación: iniciar Telegram primero.

2. **Reportes lentos con muchos datos**
   - Mitigación: Índices en BD + queries optimizadas + paginación.

3. **Errores de parseo en lenguaje natural**
   - Mitigación: comandos semi-estructurados para MVP + mejora incremental.

4. **Credenciales/seguridad mal gestionadas**
   - Mitigación: secrets manager/.env y checklist de seguridad.

5. **Exportación de datos si el usuario la necesita**
   - Mitigación: comando `/exportar` que genera CSV o Excel bajo demanda.

---

## 13) Entregables de portafolio

- Workflows n8n exportados (`/workflows/*.json`).
- SQL schema + seeds de ejemplo.
- Queries SQL para reportes documentadas.
- README principal + guía de despliegue + arquitectura.
- Casos de prueba y evidencia de ejecución.
- Documentación de API queries para reportes.

---

## 14) Backlog de implementación (todos)

1. Definir stack final y proveedor bot inicial.
2. Crear infraestructura local (n8n + PostgreSQL + variables).
3. Diseñar e implementar esquema de BD y migraciones.
4. Implementar workflows de configuración financiera.
5. Implementar workflows de registro de gastos desde bot.
6. Implementar cálculos de proyección, saldo real y diferencia.
7. Implementar generación de reportes desde PostgreSQL.
8. Implementar comandos de consulta (/resumen, /gastos, etc.).
9. Añadir observabilidad, manejo de errores e idempotencia.
10. Documentar arquitectura, decisiones y guía paso a paso.

## Nota para implementación guiada

Cuando iniciemos, avanzaremos por fases pequeñas con enfoque docente:
- objetivo de la fase,
- conceptos que aprendes,
- implementación paso a paso,
- validación práctica,
- checklist de cierre antes de pasar a la siguiente fase.
