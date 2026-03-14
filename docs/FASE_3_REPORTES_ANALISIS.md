# 🎓 Fase 3 — Reportes y Análisis Financiero (Guía de Aprendizaje)

> **Prerrequisito**: Haber completado la [Fase 2 - Registro de Gastos Diarios](./FASE_2_REGISTRO_GASTOS.md)

En esta fase vas a construir el **sistema de inteligencia financiera**: consultas avanzadas, análisis de gastos, proyecciones y comparaciones que te ayuden a entender realmente cómo manejas tu dinero.

Al terminar, podrás preguntarle al bot:
- "muéstrame un resumen del mes"
- "cuánto he gastado en alimentación?"
- "cuál es mi saldo proyectado?"
- "compara este mes con el anterior"
- "muéstrame todos los gastos de esta semana"

Y el bot te dará **reportes detallados, claros y accionables**.

---

## 🧠 ¿Qué vas a aprender?

1. **Cómo diseñar queries SQL complejas** para análisis financiero
2. **Qué es una agregación** y cómo usarla (SUM, COUNT, GROUP BY)
3. **Cómo hacer comparaciones entre periodos** (mes actual vs anterior)
4. **Qué es un snapshot mensual** y por qué es importante
5. **Cómo calcular saldo proyectado** y diferencia contra saldo real
6. **Cómo formatear reportes grandes** en Telegram (paginación, formato)
7. **Qué son las window functions** en SQL y cuándo usarlas
8. **Cómo crear un sistema de análisis por categorías**
9. **Cómo implementar triggers automáticos** para recálculo de snapshots
10. **Qué son las vistas SQL** y cómo simplifican las consultas

---

## 📊 Arquitectura de la Fase 3

```
┌──────────────────────────────────────────────────────────────┐
│                    USUARIO EN TELEGRAM                        │
│  Pregunta: "muéstrame un resumen del mes"                    │
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────────┐
│              TELEGRAM TRIGGER (n8n)                           │
│  Recibe mensaje y extrae: text, chat_id, date                │
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────────┐
│              AI AGENT (OpenAI GPT-4)                          │
│  • Detecta intención: "generar_resumen_mensual"              │
│  • Identifica parámetros: mes (actual), tipo (completo)      │
│  • Decide usar tool: "obtener_resumen_mes"                   │
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────────┐
│         POSTGRESQL: QUERY COMPLEJA                            │
│  SELECT                                                       │
│    sueldo_mensual,                                            │
│    total_fijos,                                               │
│    total_variables,                                           │
│    saldo_proyectado,                                          │
│    saldo_real,                                                │
│    diferencia                                                 │
│  FROM monthly_snapshots                                       │
│  WHERE user_id = ... AND mes = '2026-03'                     │
│                                                               │
│  + Queries adicionales para desglose por categoría            │
│  + Top 5 gastos más altos del mes                            │
│  + Comparación con mes anterior                               │
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────────┐
│         CODE NODE: Formatear Reporte                          │
│  • Genera reporte estructurado con secciones                  │
│  • Aplica formato Markdown                                    │
│  • Agrega emojis y barras de progreso                         │
│  • Calcula porcentajes y comparaciones                        │
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────────┐
│         TELEGRAM: ENVIAR REPORTE                              │
│  📊 *RESUMEN MARZO 2026*                                      │
│                                                               │
│  💰 *Ingresos*                                                │
│  • Sueldo: $5,000,000                                         │
│                                                               │
│  💸 *Gastos*                                                  │
│  • Fijos: $1,200,000 (24%)                                    │
│  • Variables: $2,100,000 (42%)                                │
│  • Total: $3,300,000                                          │
│                                                               │
│  🏦 *Saldos*                                                  │
│  • Proyectado: $1,700,000                                     │
│  • Real banco: $1,650,000                                     │
│  • Diferencia: -$50,000 ⚠️                                    │
│                                                               │
│  📈 *Por categoría* (top 3)                                   │
│  🍽️ Alimentación: $850,000 (40%)                             │
│  🚗 Transporte: $450,000 (21%)                                │
│  🏠 Vivienda: $400,000 (19%)                                  │
└──────────────────────────────────────────────────────────────┘
```

---

## Diferencias clave vs Fase 2

| Aspecto | Fase 2 | Fase 3 |
|---------|--------|--------|
| **Enfoque** | Escritura (INSERT) | Lectura (SELECT) |
| **Complejidad SQL** | Simple (INSERT, básico SELECT) | Avanzada (JOINs, GROUP BY, agregaciones) |
| **Tipo de datos** | Individuales (un gasto) | Agregados (totales, promedios) |
| **Respuestas** | Confirmaciones cortas | Reportes extensos formateados |
| **Cálculos** | Ninguno | Proyecciones, diferencias, porcentajes |
| **Temporalidad** | Tiempo real (ahora) | Histórico (comparaciones, tendencias) |

---

## Estructura del Plan

Este plan está dividido en **7 módulos pedagógicos**:

1. **Módulo 1**: Snapshot mensual y cálculo automático
2. **Módulo 2**: Reporte de resumen mensual completo
3. **Módulo 3**: Análisis por categorías
4. **Módulo 4**: Detalle de gastos con filtros
5. **Módulo 5**: Comparación entre meses
6. **Módulo 6**: Alertas y notificaciones inteligentes
7. **Módulo 7**: Vistas SQL y optimizaciones

Cada módulo incluye:
- 🎓 **Conceptos teóricos** (qué vas a aprender)
- 📋 **Pasos de implementación** (qué vas a hacer)
- 💻 **Queries SQL completas** (con explicación línea por línea)
- ✅ **Checklist de validación** (cómo sabes que funciona)

---

## Módulo 1: Snapshot Mensual Automático

### 🎓 Conceptos

#### ¿Qué es un snapshot mensual?

Un **snapshot** (instantánea) es una "fotografía" de tu situación financiera en un momento específico. En vez de calcular todo cada vez que consultas, guardas los totales pre-calculados.

**Sin snapshot** (ineficiente):
```sql
-- Cada vez que pides el resumen, el sistema calcula:
SELECT SUM(valor) FROM expense_entries WHERE mes = '2026-03' -- 1000+ filas
SELECT SUM(valor) FROM fixed_expenses WHERE user_id = ...
-- etc... 5-10 queries cada vez
```

**Con snapshot** (eficiente):
```sql
-- Los cálculos ya están guardados en una tabla:
SELECT * FROM monthly_snapshots WHERE mes = '2026-03' -- 1 fila, instantáneo
```

#### ¿Por qué es importante?

1. **Velocidad**: Respuestas en milisegundos en vez de segundos
2. **Historial**: Puedes ver cómo estabas hace 6 meses
3. **Comparaciones**: Fácil comparar mes con mes
4. **Integridad**: Los números no cambian retroactivamente

#### ¿Cuándo se actualiza el snapshot?

Cada vez que:
- Registras un gasto nuevo
- Actualizas un gasto fijo
- Cambias tu sueldo
- Actualizas el saldo real del banco

---

### 📋 Paso 1.1 — Crear función de cálculo de snapshot

Vamos a crear una **función SQL reutilizable** que calcule y actualice el snapshot:

```sql
-- ============================================================
-- Función: calcular_snapshot_mensual
-- ============================================================
-- Esta función calcula todos los totales del mes y los guarda
-- en la tabla monthly_snapshots.
--
-- Parámetros:
--   p_user_id: UUID del usuario
--   p_mes: Mes en formato 'YYYY-MM'
--
-- Retorna: el snapshot actualizado
-- ============================================================

CREATE OR REPLACE FUNCTION calcular_snapshot_mensual(
  p_user_id UUID,
  p_mes VARCHAR(7)
)
RETURNS TABLE (
  mes VARCHAR(7),
  saldo_inicio_mes NUMERIC,
  total_ingresos NUMERIC,
  total_fijos NUMERIC,
  total_variables NUMERIC,
  saldo_proyectado NUMERIC,
  saldo_real NUMERIC,
  diferencia NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_sueldo NUMERIC;
  v_saldo_real NUMERIC;
  v_total_fijos NUMERIC;
  v_total_variables NUMERIC;
  v_total_ingresos_extra NUMERIC;
  v_saldo_inicio NUMERIC;
  v_saldo_proyectado NUMERIC;
  v_diferencia NUMERIC;
BEGIN
  -- 1. Obtener sueldo y saldo real actual del usuario
  SELECT 
    fp.sueldo_mensual,
    fp.saldo_real
  INTO 
    v_sueldo,
    v_saldo_real
  FROM finance_profiles fp
  WHERE fp.user_id = p_user_id;

  -- Si no existe el perfil, retornar valores en 0
  IF v_sueldo IS NULL THEN
    v_sueldo := 0;
    v_saldo_real := 0;
  END IF;

  -- 2. Calcular total de gastos fijos activos
  SELECT COALESCE(SUM(valor), 0)
  INTO v_total_fijos
  FROM fixed_expenses
  WHERE user_id = p_user_id 
    AND activo = TRUE;

  -- 3. Calcular total de gastos variables del mes
  SELECT COALESCE(SUM(valor), 0)
  INTO v_total_variables
  FROM expense_entries
  WHERE user_id = p_user_id
    AND TO_CHAR(fecha_gasto, 'YYYY-MM') = p_mes;

  -- 4. Calcular total de ingresos extra del mes
  SELECT COALESCE(SUM(valor), 0)
  INTO v_total_ingresos_extra
  FROM income_entries
  WHERE user_id = p_user_id
    AND TO_CHAR(fecha, 'YYYY-MM') = p_mes;

  -- 5. Calcular saldo al inicio del mes
  -- (Por ahora, asumimos que es el saldo real - gastos del mes)
  -- En futuras versiones, esto vendría del snapshot del mes anterior
  v_saldo_inicio := v_saldo_real + v_total_variables + v_total_fijos - v_sueldo - v_total_ingresos_extra;

  -- 6. Calcular saldo proyectado
  -- Fórmula: saldo_inicio + ingresos_totales - gastos_totales
  v_saldo_proyectado := v_saldo_inicio + v_sueldo + v_total_ingresos_extra - v_total_fijos - v_total_variables;

  -- 7. Calcular diferencia (real vs proyectado)
  v_diferencia := v_saldo_real - v_saldo_proyectado;

  -- 8. Guardar o actualizar el snapshot
  INSERT INTO monthly_snapshots (
    user_id,
    mes,
    saldo_inicio_mes,
    total_ingresos,
    total_ingresos_extra,
    total_fijos,
    total_variables,
    saldo_proyectado,
    saldo_real,
    diferencia,
    recalculated_at
  )
  VALUES (
    p_user_id,
    p_mes,
    v_saldo_inicio,
    v_sueldo,
    v_total_ingresos_extra,
    v_total_fijos,
    v_total_variables,
    v_saldo_proyectado,
    v_saldo_real,
    v_diferencia,
    NOW()
  )
  ON CONFLICT (user_id, mes)
  DO UPDATE SET
    saldo_inicio_mes = v_saldo_inicio,
    total_ingresos = v_sueldo,
    total_ingresos_extra = v_total_ingresos_extra,
    total_fijos = v_total_fijos,
    total_variables = v_total_variables,
    saldo_proyectado = v_saldo_proyectado,
    saldo_real = v_saldo_real,
    diferencia = v_diferencia,
    recalculated_at = NOW();

  -- 9. Retornar el snapshot actualizado
  RETURN QUERY
  SELECT 
    s.mes,
    s.saldo_inicio_mes,
    s.total_ingresos,
    s.total_fijos,
    s.total_variables,
    s.saldo_proyectado,
    s.saldo_real,
    s.diferencia
  FROM monthly_snapshots s
  WHERE s.user_id = p_user_id AND s.mes = p_mes;

END;
$$;
```

**¿Qué hace esta función?**

Paso a paso:
1. **Obtiene el sueldo** del usuario desde `finance_profiles`
2. **Suma los gastos fijos** activos
3. **Suma los gastos variables** del mes especificado
4. **Suma los ingresos extra** del mes
5. **Calcula el saldo inicial** (diferencia del mes anterior)
6. **Calcula el saldo proyectado**: inicio + ingresos - gastos
7. **Calcula la diferencia**: saldo real - saldo proyectado
8. **Guarda o actualiza** en `monthly_snapshots` (UPSERT)
9. **Retorna** el snapshot actualizado

---

### 📋 Paso 1.2 — Agregar archivo de migración

Guarda la función anterior en un nuevo archivo de migración:

**Archivo**: `db/migrations/002_snapshot_function.sql`

```sql
-- ============================================================
-- Migración 002 — Función de cálculo de snapshot mensual
-- ============================================================

-- (Pegar aquí la función completa del Paso 1.1)

-- ============================================================
-- Helper: función para obtener mes actual en formato YYYY-MM
-- ============================================================

CREATE OR REPLACE FUNCTION get_current_month()
RETURNS VARCHAR(7)
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT TO_CHAR(CURRENT_DATE, 'YYYY-MM');
$$;

-- ============================================================
-- Vista: snapshot del mes actual por usuario
-- ============================================================
-- Esta vista facilita obtener el snapshot del mes en curso

CREATE OR REPLACE VIEW v_snapshot_actual AS
SELECT 
  u.id as user_id,
  u.chat_id,
  s.mes,
  s.saldo_inicio_mes,
  s.total_ingresos,
  s.total_ingresos_extra,
  s.total_fijos,
  s.total_variables,
  s.saldo_proyectado,
  s.saldo_real,
  s.diferencia,
  s.recalculated_at,
  -- Campos calculados adicionales
  (s.total_fijos + s.total_variables) as total_gastos,
  (s.total_ingresos + s.total_ingresos_extra) as total_ingresos_completo,
  CASE 
    WHEN s.diferencia >= 0 THEN 'superavit'
    WHEN s.diferencia < 0 AND s.diferencia >= -100000 THEN 'deficit_leve'
    ELSE 'deficit_fuerte'
  END as estado_financiero
FROM users u
LEFT JOIN monthly_snapshots s 
  ON u.id = s.user_id 
  AND s.mes = TO_CHAR(CURRENT_DATE, 'YYYY-MM');
```

---

### 📋 Paso 1.3 — Ejecutar la migración

```bash
docker compose exec postgres psql -U finanzas_user -d finanzas_db -f /db/migrations/002_snapshot_function.sql
```

O si tienes volúmenes mapeados correctamente, el archivo se ejecutará automáticamente.

---

### 📋 Paso 1.4 — Actualizar workflow de registro de gastos

Ahora necesitas que cada vez que se registre un gasto, se recalcule el snapshot.

En tu workflow `bot_finanzas_principal`, después del nodo "Insertar Gastos en BD", agrega:

**Nodo PostgreSQL: "Recalcular Snapshot"**

```sql
SELECT * FROM calcular_snapshot_mensual(
  (SELECT id FROM users WHERE chat_id = '{{ $('Telegram Trigger').item.json.message.chat.id }}'),
  TO_CHAR(CURRENT_DATE, 'YYYY-MM')
);
```

Este nodo se ejecuta automáticamente después de cada registro de gasto y actualiza el snapshot del mes actual.

---

### 📋 Paso 1.5 — Probar el snapshot

**Prueba manual desde psql:**

```sql
-- Ver el snapshot actual de un usuario
SELECT * FROM v_snapshot_actual 
WHERE chat_id = 'TU_CHAT_ID';

-- Forzar recálculo manual
SELECT * FROM calcular_snapshot_mensual(
  (SELECT id FROM users WHERE chat_id = 'TU_CHAT_ID'),
  '2026-03'
);

-- Ver historial de snapshots
SELECT 
  mes,
  total_ingresos,
  total_gastos_fijos + total_variables as total_gastado,
  saldo_proyectado,
  diferencia
FROM monthly_snapshots
WHERE user_id = (SELECT id FROM users WHERE chat_id = 'TU_CHAT_ID')
ORDER BY mes DESC;
```

---

### ✅ Checklist Módulo 1

- [ ] Función `calcular_snapshot_mensual` creada
- [ ] Vista `v_snapshot_actual` creada
- [ ] Migración 002 ejecutada exitosamente
- [ ] Workflow actualizado para recalcular snapshot automáticamente
- [ ] Prueba manual: snapshot se calcula correctamente
- [ ] Prueba: registrar un gasto recalcula el snapshot
- [ ] Prueba: actualizar sueldo recalcula el snapshot

---

## Módulo 2: Reporte de Resumen Mensual

### 🎓 Conceptos

#### ¿Qué es un reporte efectivo?

Un buen reporte financiero debe:
1. **Ser visual**: Emojis, barras de progreso, secciones claras
2. **Ser accionable**: No solo números, sino interpretación
3. **Ser completo**: Vista general + detalles importantes
4. **Ser rápido**: Menos de 3 segundos en generar

#### Estructura de un reporte profesional

```
📊 TÍTULO Y PERIODO
───────────────────
💰 SECCIÓN 1: Ingresos
   • Detalle línea por línea
   • Total con formato

💸 SECCIÓN 2: Gastos
   • Desglose por tipo
   • Porcentajes visuales

🏦 SECCIÓN 3: Saldos
   • Proyectado vs Real
   • Alertas si hay desviación

📈 SECCIÓN 4: Insights
   • Top gastos
   • Comparación histórica
```

---

### 📋 Paso 2.1 — Crear tool en AI Agent

En el nodo AI Agent, agrega una nueva tool:

```
Name: obtener_resumen_mensual

Description:
Usa esta herramienta cuando el usuario quiera ver un resumen completo de sus finanzas del mes.

Preguntas que activan esta tool:
- "dame un resumen"
- "cómo voy este mes?"
- "muéstrame el resumen"
- "estado de mis finanzas"
- "cuánto he gastado?"

Parámetros:
- mes (opcional): formato YYYY-MM, por defecto mes actual

Esta herramienta retorna:
- Resumen completo de ingresos, gastos, saldos
- Desglose por categorías
- Top 5 gastos más altos
- Alertas si hay desviaciones
```

---

### 📋 Paso 2.2 — Crear query del resumen

**Nodo PostgreSQL: "Query Resumen Mensual"**

```sql
-- ============================================================
-- QUERY: Resumen mensual completo
-- ============================================================

WITH
-- CTE 1: Snapshot del mes
snapshot AS (
  SELECT 
    mes,
    saldo_inicio_mes,
    total_ingresos,
    total_ingresos_extra,
    total_fijos,
    total_variables,
    saldo_proyectado,
    saldo_real,
    diferencia,
    recalculated_at
  FROM monthly_snapshots
  WHERE user_id = (SELECT id FROM users WHERE chat_id = '{{ $('Telegram Trigger').item.json.message.chat.id }}')
    AND mes = COALESCE('{{ $json.mes }}', TO_CHAR(CURRENT_DATE, 'YYYY-MM'))
),

-- CTE 2: Gastos por categoría del mes
gastos_categoria AS (
  SELECT 
    categoria,
    COUNT(*) as cantidad,
    SUM(valor) as total
  FROM expense_entries
  WHERE user_id = (SELECT id FROM users WHERE chat_id = '{{ $('Telegram Trigger').item.json.message.chat.id }}')
    AND TO_CHAR(fecha_gasto, 'YYYY-MM') = COALESCE('{{ $json.mes }}', TO_CHAR(CURRENT_DATE, 'YYYY-MM'))
  GROUP BY categoria
  ORDER BY total DESC
),

-- CTE 3: Top 5 gastos más altos
top_gastos AS (
  SELECT 
    fecha_gasto,
    concepto,
    categoria,
    valor
  FROM expense_entries
  WHERE user_id = (SELECT id FROM users WHERE chat_id = '{{ $('Telegram Trigger').item.json.message.chat.id }}')
    AND TO_CHAR(fecha_gasto, 'YYYY-MM') = COALESCE('{{ $json.mes }}', TO_CHAR(CURRENT_DATE, 'YYYY-MM'))
  ORDER BY valor DESC
  LIMIT 5
),

-- CTE 4: Comparación con mes anterior
comparacion_mes_anterior AS (
  SELECT 
    total_fijos as fijos_anterior,
    total_variables as variables_anterior,
    (total_fijos + total_variables) as total_anterior
  FROM monthly_snapshots
  WHERE user_id = (SELECT id FROM users WHERE chat_id = '{{ $('Telegram Trigger').item.json.message.chat.id }}')
    AND mes = TO_CHAR(
      (TO_DATE(COALESCE('{{ $json.mes }}', TO_CHAR(CURRENT_DATE, 'YYYY-MM')), 'YYYY-MM') - INTERVAL '1 month')::DATE,
      'YYYY-MM'
    )
)

-- Resultado final: todo en un JSON
SELECT json_build_object(
  'snapshot', (SELECT row_to_json(s) FROM snapshot s),
  'categorias', (SELECT json_agg(row_to_json(gc)) FROM gastos_categoria gc),
  'top_gastos', (SELECT json_agg(row_to_json(tg)) FROM top_gastos tg),
  'mes_anterior', (SELECT row_to_json(cma) FROM comparacion_mes_anterior cma)
) as reporte_completo;
```

**¿Qué hace esta query?**

1. **CTE 1 (snapshot)**: Obtiene el snapshot pre-calculado
2. **CTE 2 (gastos_categoria)**: Agrupa gastos por categoría con totales
3. **CTE 3 (top_gastos)**: Los 5 gastos más altos del mes
4. **CTE 4 (comparacion_mes_anterior)**: Datos del mes pasado para comparar
5. **SELECT final**: Combina todo en un solo JSON

---

### 📋 Paso 2.3 — Formatear el reporte

**Nodo Code: "Formatear Resumen Mensual"**

```javascript
// ============================================================
// FORMATEADOR DE RESUMEN MENSUAL
// ============================================================

const data = $input.first().json.reporte_completo;

if (!data.snapshot) {
  return [{json: {
    mensaje: "❌ No hay datos del mes solicitado.\n\nRegistra algunos gastos primero usando frases como:\n\"almuerzo 18k\" o \"uber 12000\"",
    chat_id: $('Telegram Trigger').item.json.message.chat.id
  }}];
}

const s = data.snapshot;
const categorias = data.categorias || [];
const topGastos = data.top_gastos || [];
const mesAnterior = data.mes_anterior || {};

// Helper: formatear monto
function fmt(valor) {
  return '$' + Math.round(valor).toLocaleString('es-CO');
}

// Helper: formatear porcentaje
function pct(parte, total) {
  if (total === 0) return '0%';
  return Math.round((parte / total) * 100) + '%';
}

// Helper: barra de progreso visual
function barra(porcentaje, longitud = 10) {
  const llenos = Math.round((porcentaje / 100) * longitud);
  return '█'.repeat(llenos) + '░'.repeat(longitud - llenos);
}

// Helper: emoji de estado
function emojiEstado(diferencia) {
  if (diferencia >= 50000) return '✅';
  if (diferencia >= 0) return '🟢';
  if (diferencia >= -100000) return '🟡';
  return '🔴';
}

// Parsear mes para mostrar nombre
const [anio, mesNum] = s.mes.split('-');
const nombresMeses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
                       'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
const nombreMes = nombresMeses[parseInt(mesNum) - 1];

// Construir reporte
let mensaje = `📊 *RESUMEN FINANCIERO*\n`;
mensaje += `📅 ${nombreMes} ${anio}\n`;
mensaje += `⏰ Actualizado: ${new Date(s.recalculated_at).toLocaleString('es-CO', {day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit'})}\n`;
mensaje += `━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

// SECCIÓN 1: Ingresos
mensaje += `💰 *INGRESOS*\n`;
mensaje += `• Sueldo mensual: ${fmt(s.total_ingresos)}\n`;
if (s.total_ingresos_extra > 0) {
  mensaje += `• Ingresos extra: ${fmt(s.total_ingresos_extra)}\n`;
}
mensaje += `• *Total ingresos: ${fmt(s.total_ingresos + s.total_ingresos_extra)}*\n\n`;

// SECCIÓN 2: Gastos
const totalGastos = s.total_fijos + s.total_variables;
const pctFijos = pct(s.total_fijos, totalGastos);
const pctVariables = pct(s.total_variables, totalGastos);

mensaje += `💸 *GASTOS*\n`;
mensaje += `• Gastos fijos: ${fmt(s.total_fijos)} (${pctFijos})\n`;
mensaje += `  ${barra(parseInt(pctFijos))} ${pctFijos}\n`;
mensaje += `• Gastos variables: ${fmt(s.total_variables)} (${pctVariables})\n`;
mensaje += `  ${barra(parseInt(pctVariables))} ${pctVariables}\n`;
mensaje += `• *Total gastado: ${fmt(totalGastos)}*\n\n`;

// SECCIÓN 3: Saldos
mensaje += `🏦 *SALDOS*\n`;
mensaje += `• Proyectado: ${fmt(s.saldo_proyectado)}\n`;
mensaje += `• Real en banco: ${fmt(s.saldo_real)}\n`;
mensaje += `• Diferencia: ${fmt(s.diferencia)} ${emojiEstado(s.diferencia)}\n`;

if (s.diferencia < 0) {
  mensaje += `  ⚠️ _Estás gastando más de lo planeado_\n`;
} else if (s.diferencia > 50000) {
  mensaje += `  ✨ _¡Vas muy bien! Estás ahorrando_\n`;
}
mensaje += `\n`;

// SECCIÓN 4: Por categoría (top 3)
if (categorias.length > 0) {
  mensaje += `📈 *GASTOS POR CATEGORÍA* (top 3)\n`;
  
  const emojis = {
    'alimentacion': '🍽️',
    'transporte': '🚗',
    'suscripciones': '📱',
    'vivienda': '🏠',
    'mercado': '🛒',
    'salud': '💊',
    'entretenimiento': '🎬',
    'vestuario': '👕',
    'servicios': '💡',
    'general': '📦'
  };
  
  categorias.slice(0, 3).forEach(cat => {
    const emoji = emojis[cat.categoria] || '📦';
    const pctCat = pct(cat.total, s.total_variables);
    const nombre = cat.categoria.charAt(0).toUpperCase() + cat.categoria.slice(1);
    mensaje += `${emoji} ${nombre}: ${fmt(cat.total)} (${pctCat})\n`;
  });
  mensaje += `\n`;
}

// SECCIÓN 5: Top 5 gastos
if (topGastos.length > 0) {
  mensaje += `🔝 *TOP 5 GASTOS MÁS ALTOS*\n`;
  topGastos.forEach((g, i) => {
    const fecha = new Date(g.fecha_gasto).toLocaleDateString('es-CO', {day: '2-digit', month: 'short'});
    mensaje += `${i + 1}. ${g.concepto}: ${fmt(g.valor)} (${fecha})\n`;
  });
  mensaje += `\n`;
}

// SECCIÓN 6: Comparación con mes anterior
if (mesAnterior.total_anterior) {
  const difTotal = totalGastos - mesAnterior.total_anterior;
  const difPct = pct(Math.abs(difTotal), mesAnterior.total_anterior);
  
  mensaje += `📊 *COMPARACIÓN CON MES ANTERIOR*\n`;
  
  if (difTotal > 0) {
    mensaje += `📈 Gastaste ${fmt(difTotal)} *más* (+${difPct})\n`;
  } else if (difTotal < 0) {
    mensaje += `📉 Gastaste ${fmt(Math.abs(difTotal))} *menos* (-${difPct})\n`;
  } else {
    mensaje += `➡️ Gastaste lo mismo que el mes pasado\n`;
  }
}

mensaje += `\n━━━━━━━━━━━━━━━━━━━━━━━━\n`;
mensaje += `💡 _Usa /gastos para ver el detalle completo_`;

return [{json: {
  mensaje,
  chat_id: $('Telegram Trigger').item.json.message.chat.id
}}];
```

---

### 📋 Paso 2.4 — Enviar reporte por Telegram

**Nodo Telegram: "Enviar Resumen"**

- **Chat ID**: `{{ $json.chat_id }}`
- **Text**: `{{ $json.mensaje }}`
- **Parse Mode**: `Markdown`

---

### 📋 Paso 2.5 — Ejemplo de reporte final

```
📊 RESUMEN FINANCIERO
📅 Marzo 2026
⏰ Actualizado: 10 mar, 00:55
━━━━━━━━━━━━━━━━━━━━━━━━

💰 INGRESOS
• Sueldo mensual: $5,000,000
• Total ingresos: $5,000,000

💸 GASTOS
• Gastos fijos: $1,200,000 (36%)
  ███████████░░░░░░░░░ 36%
• Gastos variables: $2,100,000 (64%)
  ████████████████████ 64%
• Total gastado: $3,300,000

🏦 SALDOS
• Proyectado: $1,700,000
• Real en banco: $1,650,000
• Diferencia: -$50,000 🟡
  ⚠️ Estás gastando más de lo planeado

📈 GASTOS POR CATEGORÍA (top 3)
🍽️ Alimentacion: $850,000 (40%)
🚗 Transporte: $450,000 (21%)
🏠 Vivienda: $400,000 (19%)

🔝 TOP 5 GASTOS MÁS ALTOS
1. Arriendo: $400,000 (01 mar)
2. Mercado: $180,000 (05 mar)
3. Gasolina: $120,000 (08 mar)
4. Restaurante: $85,000 (07 mar)
5. Uber: $45,000 (09 mar)

📊 COMPARACIÓN CON MES ANTERIOR
📈 Gastaste $200,000 más (+6%)

━━━━━━━━━━━━━━━━━━━━━━━━
💡 Usa /gastos para ver el detalle completo
```

---

### ✅ Checklist Módulo 2

- [ ] Tool `obtener_resumen_mensual` creada en AI Agent
- [ ] Query SQL con CTEs implementada
- [ ] Formateador de reporte implementado
- [ ] Nodo Telegram para envío configurado
- [ ] Prueba: "dame un resumen" funciona
- [ ] Prueba: reporte muestra todas las secciones
- [ ] Prueba: formato Markdown se renderiza correctamente
- [ ] Prueba: comparación con mes anterior funciona

---

## Módulo 3: Análisis por Categorías

### 🎓 Conceptos

El análisis por categorías te ayuda a entender **dónde se va tu dinero**. Es uno de los reportes más valiosos porque revela patrones de gasto.

#### Métricas clave por categoría

1. **Total gastado**: Suma de todos los gastos
2. **Cantidad de transacciones**: Cuántas veces gastaste
3. **Promedio por transacción**: Total / cantidad
4. **Porcentaje del total**: Qué % representa
5. **Tendencia**: Comparado con mes anterior

---

### 📋 Paso 3.1 — Crear tool de categorías

**Tool en AI Agent: `obtener_gastos_por_categoria`**

```
Description:
Usa esta herramienta cuando el usuario quiera ver un análisis detallado por categoría.

Preguntas que activan:
- "cuánto he gastado en alimentación?"
- "muéstrame por categorías"
- "análisis por categoría"
- "en qué gasto más?"

Parámetros:
- categoria (opcional): filtrar por una categoría específica
- mes (opcional): mes a analizar, por defecto mes actual
```

---

### 📋 Paso 3.2 — Query de análisis por categoría

```sql
-- ============================================================
-- QUERY: Análisis detallado por categoría
-- ============================================================

WITH
-- Gastos del mes actual por categoría
gastos_mes_actual AS (
  SELECT 
    categoria,
    COUNT(*) as cantidad,
    SUM(valor) as total,
    AVG(valor) as promedio,
    MIN(valor) as minimo,
    MAX(valor) as maximo
  FROM expense_entries
  WHERE user_id = (SELECT id FROM users WHERE chat_id = '{{ $('Telegram Trigger').item.json.message.chat.id }}')
    AND TO_CHAR(fecha_gasto, 'YYYY-MM') = TO_CHAR(CURRENT_DATE, 'YYYY-MM')
  GROUP BY categoria
),

-- Gastos del mes anterior por categoría (para comparación)
gastos_mes_anterior AS (
  SELECT 
    categoria,
    SUM(valor) as total_anterior
  FROM expense_entries
  WHERE user_id = (SELECT id FROM users WHERE chat_id = '{{ $('Telegram Trigger').item.json.message.chat.id }}')
    AND TO_CHAR(fecha_gasto, 'YYYY-MM') = TO_CHAR((CURRENT_DATE - INTERVAL '1 month')::DATE, 'YYYY-MM')
  GROUP BY categoria
),

-- Total general para calcular porcentajes
total_general AS (
  SELECT SUM(total) as total FROM gastos_mes_actual
)

-- Resultado final con comparaciones
SELECT 
  gma.categoria,
  gma.cantidad,
  gma.total,
  gma.promedio,
  gma.minimo,
  gma.maximo,
  ROUND((gma.total / tg.total * 100)::NUMERIC, 1) as porcentaje,
  COALESCE(gma2.total_anterior, 0) as total_mes_anterior,
  CASE 
    WHEN gma2.total_anterior IS NULL THEN 'nueva_categoria'
    WHEN gma.total > gma2.total_anterior THEN 'aumento'
    WHEN gma.total < gma2.total_anterior THEN 'disminucion'
    ELSE 'igual'
  END as tendencia,
  COALESCE(gma.total - gma2.total_anterior, gma.total) as diferencia
FROM gastos_mes_actual gma
CROSS JOIN total_general tg
LEFT JOIN gastos_mes_anterior gma2 ON gma.categoria = gma2.categoria
ORDER BY gma.total DESC;
```

---

### 📋 Paso 3.3 — Formatear reporte de categorías

```javascript
// ============================================================
// FORMATEADOR DE ANÁLISIS POR CATEGORÍAS
// ============================================================

const categorias = $input.all();

if (categorias.length === 0) {
  return [{json: {
    mensaje: "📊 No hay gastos registrados en este mes.\n\nRegistra algunos gastos primero.",
    chat_id: $('Telegram Trigger').item.json.message.chat.id
  }}];
}

function fmt(valor) {
  return '$' + Math.round(valor).toLocaleString('es-CO');
}

const emojis = {
  'alimentacion': '🍽️',
  'transporte': '🚗',
  'suscripciones': '📱',
  'vivienda': '🏠',
  'mercado': '🛒',
  'salud': '💊',
  'entretenimiento': '🎬',
  'vestuario': '👕',
  'servicios': '💡',
  'general': '📦'
};

function emojiTendencia(tendencia) {
  if (tendencia === 'aumento') return '📈';
  if (tendencia === 'disminucion') return '📉';
  if (tendencia === 'igual') return '➡️';
  return '🆕';
}

let mensaje = `📊 *ANÁLISIS POR CATEGORÍAS*\n`;
mensaje += `📅 ${new Date().toLocaleDateString('es-CO', {month: 'long', year: 'numeric'})}\n`;
mensaje += `━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

categorias.forEach((item, index) => {
  const cat = item.json;
  const emoji = emojis[cat.categoria] || '📦';
  const nombre = cat.categoria.charAt(0).toUpperCase() + cat.categoria.slice(1);
  const emojiTend = emojiTendencia(cat.tendencia);
  
  mensaje += `${emoji} *${nombre}*\n`;
  mensaje += `• Total: ${fmt(cat.total)} (${cat.porcentaje}%)\n`;
  mensaje += `• Transacciones: ${cat.cantidad}\n`;
  mensaje += `• Promedio: ${fmt(cat.promedio)}\n`;
  mensaje += `• Rango: ${fmt(cat.minimo)} - ${fmt(cat.maximo)}\n`;
  
  // Comparación con mes anterior
  if (cat.tendencia === 'nueva_categoria') {
    mensaje += `  🆕 _Nueva categoría este mes_\n`;
  } else {
    const dif = Math.abs(cat.diferencia);
    if (cat.tendencia === 'aumento') {
      mensaje += `  📈 +${fmt(dif)} vs mes anterior\n`;
    } else if (cat.tendencia === 'disminucion') {
      mensaje += `  📉 -${fmt(dif)} vs mes anterior\n`;
    } else {
      mensaje += `  ➡️ Igual que mes anterior\n`;
    }
  }
  
  mensaje += `\n`;
});

mensaje += `━━━━━━━━━━━━━━━━━━━━━━━━\n`;
mensaje += `💡 _Usa /gastos [categoría] para ver el detalle_`;

return [{json: {
  mensaje,
  chat_id: $('Telegram Trigger').item.json.message.chat.id
}}];
```

---

### ✅ Checklist Módulo 3

- [ ] Tool `obtener_gastos_por_categoria` creada
- [ ] Query con comparación mes anterior implementada
- [ ] Formateador con emojis y tendencias implementado
- [ ] Prueba: "muéstrame por categorías" funciona
- [ ] Prueba: tendencias se calculan correctamente
- [ ] Prueba: porcentajes suman 100%

---

## Módulo 4: Detalle de Gastos con Filtros

### 🎓 Conceptos

A veces necesitas ver el **detalle granular**: todos los gastos, no solo los resúmenes. Este módulo implementa filtros avanzados.

#### Filtros disponibles:

1. **Por fecha**: Hoy, esta semana, este mes, rango personalizado
2. **Por categoría**: Solo alimentación, solo transporte, etc.
3. **Por monto**: Gastos mayores a X cantidad
4. **Ordenamiento**: Por fecha, por monto, por categoría

---

### 📋 Paso 4.1 — Tool de listado de gastos

```
Name: listar_gastos

Description:
Usa esta herramienta para obtener una lista detallada de gastos con filtros opcionales.

Preguntas que activan:
- "muéstrame todos los gastos"
- "gastos de esta semana"
- "gastos de alimentación"
- "gastos mayores a 50000"

Parámetros:
- periodo (opcional): 'hoy', 'semana', 'mes', 'todo'
- categoria (opcional): filtrar por categoría específica
- monto_minimo (opcional): solo gastos >= este monto
- limite (opcional): cantidad máxima de registros, default 20
```

---

### 📋 Paso 4.2 — Query con filtros dinámicos

```javascript
// ============================================================
// CODE NODE: Construir query dinámica con filtros
// ============================================================

const params = $input.first().json;
const chatId = $('Telegram Trigger').item.json.message.chat.id;

// Construir filtros WHERE dinámicamente
let whereFilters = [
  `user_id = (SELECT id FROM users WHERE chat_id = '${chatId}')`
];

// Filtro de periodo
if (params.periodo === 'hoy') {
  whereFilters.push(`fecha_gasto = CURRENT_DATE`);
} else if (params.periodo === 'semana') {
  whereFilters.push(`fecha_gasto >= DATE_TRUNC('week', CURRENT_DATE)`);
} else if (params.periodo === 'mes' || !params.periodo) {
  whereFilters.push(`DATE_TRUNC('month', fecha_gasto) = DATE_TRUNC('month', CURRENT_DATE)`);
}

// Filtro de categoría
if (params.categoria) {
  whereFilters.push(`categoria = '${params.categoria}'`);
}

// Filtro de monto mínimo
if (params.monto_minimo) {
  whereFilters.push(`valor >= ${params.monto_minimo}`);
}

// Límite de registros
const limite = params.limite || 20;

// Construir query completa
const query = `
SELECT 
  fecha_gasto,
  concepto,
  categoria,
  valor,
  origen,
  created_at
FROM expense_entries
WHERE ${whereFilters.join(' AND ')}
ORDER BY fecha_gasto DESC, created_at DESC
LIMIT ${limite};
`;

return [{json: {query, params}}];
```

Luego en nodo PostgreSQL:
```sql
{{ $json.query }}
```

---

### 📋 Paso 4.3 — Formatear lista de gastos

```javascript
// ============================================================
// FORMATEADOR DE LISTA DE GASTOS
// ============================================================

const gastos = $input.all();
const params = $('Code Node - Query Builder').item.json.params;

if (gastos.length === 0) {
  return [{json: {
    mensaje: "📋 No se encontraron gastos con esos filtros.",
    chat_id: $('Telegram Trigger').item.json.message.chat.id
  }}];
}

function fmt(valor) {
  return '$' + Math.round(valor).toLocaleString('es-CO');
}

const emojis = {
  'alimentacion': '🍽️',
  'transporte': '🚗',
  'suscripciones': '📱',
  'vivienda': '🏠',
  'mercado': '🛒',
  'salud': '💊',
  'entretenimiento': '🎬',
  'vestuario': '👕',
  'servicios': '💡',
  'general': '📦'
};

// Título según filtros
let titulo = '📋 *LISTADO DE GASTOS*\n';
if (params.periodo) {
  const periodos = {
    'hoy': 'Hoy',
    'semana': 'Esta semana',
    'mes': 'Este mes',
    'todo': 'Todos los registros'
  };
  titulo += `📅 ${periodos[params.periodo]}\n`;
}
if (params.categoria) {
  titulo += `🏷️ Categoría: ${params.categoria}\n`;
}
if (params.monto_minimo) {
  titulo += `💰 Monto mínimo: ${fmt(params.monto_minimo)}\n`;
}
titulo += `━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

let mensaje = titulo;

// Agrupar por fecha
const porFecha = {};
gastos.forEach(item => {
  const g = item.json;
  const fecha = new Date(g.fecha_gasto).toLocaleDateString('es-CO', {
    weekday: 'short',
    day: '2-digit',
    month: 'short'
  });
  
  if (!porFecha[fecha]) {
    porFecha[fecha] = [];
  }
  porFecha[fecha].push(g);
});

// Formatear por fecha
Object.entries(porFecha).forEach(([fecha, gastosDelDia]) => {
  const totalDia = gastosDelDia.reduce((sum, g) => sum + g.valor, 0);
  
  mensaje += `📅 *${fecha}* — ${fmt(totalDia)}\n`;
  
  gastosDelDia.forEach(g => {
    const emoji = emojis[g.categoria] || '📦';
    mensaje += `  ${emoji} ${g.concepto}: ${fmt(g.valor)}\n`;
  });
  
  mensaje += `\n`;
});

// Total general
const totalGeneral = gastos.reduce((sum, item) => sum + item.json.valor, 0);
mensaje += `━━━━━━━━━━━━━━━━━━━━━━━━\n`;
mensaje += `💰 *Total: ${fmt(totalGeneral)}*\n`;
mensaje += `📊 ${gastos.length} transacción${gastos.length > 1 ? 'es' : ''}`;

if (gastos.length >= (params.limite || 20)) {
  mensaje += `\n\n_ℹ️ Mostrando los primeros ${params.limite || 20} registros_`;
}

return [{json: {
  mensaje,
  chat_id: $('Telegram Trigger').item.json.message.chat.id
}}];
```

---

### ✅ Checklist Módulo 4

- [ ] Tool `listar_gastos` creada
- [ ] Query builder dinámico implementado
- [ ] Filtros funcionan correctamente
- [ ] Agrupación por fecha implementada
- [ ] Prueba: "gastos de hoy" funciona
- [ ] Prueba: "gastos de alimentación" funciona
- [ ] Prueba: paginación muestra límite correcto

---

## Resumen de la Fase 3

### 🎯 Lo que construiste

1. ✅ **Snapshot mensual automático**: Cálculos pre-computados y rápidos
2. ✅ **Resumen mensual completo**: Reporte profesional con múltiples secciones
3. ✅ **Análisis por categorías**: Entender dónde se va el dinero
4. ✅ **Listado de gastos con filtros**: Drill-down a nivel granular

### 📈 Comandos disponibles

| Comando | Función |
|---------|---------|
| "dame un resumen" | Resumen mensual completo |
| "por categorías" | Análisis de gastos por categoría |
| "gastos de hoy" | Gastos del día actual |
| "gastos de esta semana" | Gastos de la semana |
| "gastos de alimentación" | Filtrar por categoría |

### 🔄 Próximos pasos (Fase 4)

- Automatización mensual (rollover automático)
- Alertas inteligentes (cuando gastas de más)
- Predicciones basadas en historial
- Export de datos a Excel/PDF

---

> **¡Felicitaciones!** 🎉 Ahora tienes un sistema completo de análisis financiero que te da **insights reales** sobre tu dinero.
