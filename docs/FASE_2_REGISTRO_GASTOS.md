# 🎓 Fase 2 — Registro de Gastos Diarios (Guía Simplificada - Solo PostgreSQL)

> **Prerrequisito**: Haber completado la [Fase 1 - Configuración Financiera](./FASE_1_CONFIGURACION_FINANCIERA.md)

En esta fase vas a construir la funcionalidad **más importante** del sistema: **registrar gastos desde conversación natural y almacenarlos en PostgreSQL con capacidad de consulta**.

Al terminar, podrás escribir en Telegram cosas como:
- "almuerzo 18k"
- "uber 12 mil, café 9500 y pan 3000"
- "gasté 45 mil en mercado ayer"

Y el bot:
1. Entenderá que quieres registrar gastos
2. Extraerá todos los gastos del mensaje
3. Los guardará en PostgreSQL
4. Te confirmará con un resumen
5. Podrás consultar tus gastos con comandos como `/resumen` o `/gastos`

---

## 🧠 ¿Qué vas a aprender?

1. **Cómo estructurar prompts complejos** para que el LLM extraiga datos estructurados
2. **Qué es entity extraction** y cómo el AI Agent lo hace automáticamente
3. **Cómo manejar múltiples objetos** en un solo mensaje (array de gastos)
4. **Cómo normalizar formatos de montos** (18k → 18000)
5. **Cómo categorizar automáticamente** usando palabras clave
6. **Cómo hacer INSERT batch** en PostgreSQL (múltiples filas a la vez)
7. **Cómo generar reportes dinámicos** desde queries SQL
8. **Qué es idempotencia** y cómo evitar duplicados
9. **Cómo formatear respuestas** con Markdown para mejor legibilidad

---

## 📊 Arquitectura de la Fase 2

```
┌──────────────────────────────────────────────────────────────┐
│                    USUARIO EN TELEGRAM                        │
│  Escribe: "almuerzo 18k, uber 12k, café 9k"                  │
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
│  • Lee system prompt actualizado                              │
│  • Detecta intención: "registrar_gastos"                      │
│  • Extrae entidades:                                          │
│    [                                                          │
│      {concepto: "almuerzo", monto: 18000, cat: "alimentacion"}│
│      {concepto: "uber", monto: 12000, cat: "transporte"},    │
│      {concepto: "café", monto: 9000, cat: "alimentacion"}    │
│    ]                                                          │
│  • Decide usar tool: "registrar_gastos_diarios"              │
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────────┐
│         CODE NODE: Parser y Normalizador                      │
│  • Normaliza montos (18k → 18000)                            │
│  • Valida datos (monto > 0, concepto no vacío)               │
│  • Genera UUIDs para cada gasto                               │
│  • Asigna fecha (hoy o parseada del mensaje)                 │
│  • Output: array listo para insertar                          │
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────────┐
│         POSTGRESQL: INSERT BATCH                              │
│  INSERT INTO expense_entries                                  │
│  (id, user_id, fecha_gasto, concepto, categoria, valor, ...) │
│  VALUES                                                       │
│    (uuid1, user_id, '2026-03-06', 'almuerzo', 'alimentacion', 18000),│
│    (uuid2, user_id, '2026-03-06', 'uber', 'transporte', 12000),│
│    (uuid3, user_id, '2026-03-06', 'café', 'alimentacion', 9000);│
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────────┐
│         TELEGRAM: CONFIRMACIÓN                                │
│  ✅ Registré 3 gastos:                                        │
│  • Almuerzo: $18,000                                          │
│  • Uber: $12,000                                              │
│  • Café: $9,000                                               │
│  Total: $39,000                                               │
│  💾 Guardado en base de datos                                 │
└──────────────────────────────────────────────────────────────┘
```

---

## Módulos de implementación

### **Módulo 1**: Actualización del AI Agent con nueva herramienta
### **Módulo 2**: Parser avanzado de gastos múltiples
### **Módulo 3**: Inserción batch en PostgreSQL
### **Módulo 4**: Respuesta de confirmación
### **Módulo 5**: Comandos de consulta (/resumen, /gastos)
### **Módulo 6**: Pruebas integrales y refinamiento

---

## Módulo 1: Actualización del AI Agent

### 🎓 Conceptos

#### ¿Qué es un system prompt?

Es el conjunto de instrucciones que definen el comportamiento del LLM. Es como el "manual de operación" del AI Agent.

Un buen system prompt incluye:
1. **Rol**: quién es el agente ("eres un asistente financiero")
2. **Contexto**: qué información tiene disponible
3. **Capacidades**: qué puede hacer
4. **Formato de entrada**: qué tipo de mensajes espera
5. **Formato de salida**: cómo debe responder
6. **Reglas de negocio**: validaciones, restricciones

#### ¿Qué es entity extraction?

Es el proceso de identificar y extraer datos estructurados de texto natural.

Ejemplo:
```
Input: "almuerzo 18k, uber 12000"
Entities extraídas:
- Gasto 1: {concepto: "almuerzo", monto: 18000}
- Gasto 2: {concepto: "uber", monto: 12000}
```

El LLM hace esto automáticamente si le das las instrucciones correctas.

---

### 📋 Paso 1.1 — Abrir el workflow existente

1. En n8n, abre el workflow `bot_finanzas_principal` (el de la Fase 1)
2. Busca el nodo **"AI Agent"**
3. Click en él para editarlo

---

### 📋 Paso 1.2 — Actualizar el system prompt

Reemplaza o extiende el system prompt existente con esto:

```
Eres un asistente financiero personal que ayuda al usuario a gestionar sus finanzas.

## TUS CAPACIDADES

1. **Configuración financiera** (ya implementado):
   - Configurar sueldo mensual
   - Agregar o actualizar gastos fijos recurrentes
   - Actualizar saldo real del banco
   - Mostrar resumen financiero

2. **Registro de gastos diarios** (nueva capacidad):
   - Registrar uno o múltiples gastos del día
   - Entender diferentes formatos de montos: 18k, 18000, $18,000, dieciocho mil
   - Detectar categorías automáticamente
   - Procesar fechas relativas: hoy, ayer, anteayer

## CÓMO DETECTAR INTENCIÓN DE REGISTRAR GASTOS

El usuario quiere registrar gastos cuando dice cosas como:
- "almuerzo 18k"
- "uber 12000"
- "gasté 45 mil en mercado"
- "compré zapatos 150000"
- "pagué netflix 30k, spotify 15k y gym 80k"
- "ayer gasté 50k en cine"

Indicadores clave:
- Menciona un concepto + un monto
- Usa palabras como "gasté", "pagué", "compré"
- Lista varios items con montos

## FORMATO DE EXTRACCIÓN DE GASTOS

Cuando detectes intención de registrar gastos, extrae un array de objetos:

[
  {
    "concepto": "descripción corta del gasto",
    "monto": número_sin_formato,
    "categoria": "categoría_detectada",
    "fecha": "YYYY-MM-DD"
  }
]

### Reglas de extracción:

**Montos:**
- 18k → 18000
- 12mil → 12000
- $18,000 → 18000
- 18.000 → 18000
- dieciocho mil → 18000
- Siempre devolver número sin formato (solo dígitos)

**Categorías** (asignar automáticamente según palabras clave):
- "almuerzo", "desayuno", "cena", "comida", "café", "pan" → alimentacion
- "uber", "taxi", "gasolina", "transporte" → transporte
- "netflix", "spotify", "youtube", "gamepass" → suscripciones
- "arriendo", "alquiler" → vivienda
- "mercado", "supermercado" → mercado
- "farmacia", "medicina", "doctor" → salud
- "gimnasio", "gym" → salud
- "cine", "restaurante", "bar" → entretenimiento
- "zapatos", "ropa", "camisa" → vestuario
- Si no hay coincidencia → "general"

**Fechas:**
- Si no se menciona fecha → usar hoy (fecha actual)
- "ayer" → restar 1 día
- "anteayer" → restar 2 días
- Si dice fecha específica "el 3 de marzo" → parsear esa fecha

### Ejemplo de extracción:

Usuario: "almuerzo 18k, uber 12 mil y café 9500"

Tu respuesta interna (para la tool):
[
  {
    "concepto": "almuerzo",
    "monto": 18000,
    "categoria": "alimentacion",
    "fecha": "2026-03-06"
  },
  {
    "concepto": "uber",
    "monto": 12000,
    "categoria": "transporte",
    "fecha": "2026-03-06"
  },
  {
    "concepto": "café",
    "monto": 9500,
    "categoria": "alimentacion",
    "fecha": "2026-03-06"
  }
]

## CUANDO USAR CADA HERRAMIENTA

- **actualizar_sueldo**: cuando dice "mi sueldo es X" o "actualiza mi sueldo a X"
- **agregar_gasto_fijo**: cuando dice "agrega X como gasto fijo de Y al mes"
- **actualizar_saldo_banco**: cuando dice "tengo X en el banco" o "saldo banco X"
- **obtener_resumen**: cuando pregunta "cómo voy?", "cuánto llevo?", "resumen"
- **registrar_gastos_diarios**: cuando menciona gastos con montos (ver indicadores arriba)

## TU PERSONALIDAD

- Eres conciso y directo
- Confirmas cada acción con emoji ✅
- Formateas montos con separador de miles: $18,000 (no 18000)
- Respondes en español colombiano (usas "mil" no "k" en las confirmaciones)

## ERRORES COMUNES A EVITAR

❌ NO asumas categoría incorrecta. Si no estás seguro, usa "general"
❌ NO aceptes montos negativos (excepto devoluciones)
❌ NO registres el mismo gasto dos veces
❌ NO confundas configuración (gasto fijo) con registro diario (gasto variable)
```

---

### 📋 Paso 1.3 — Crear la nueva herramienta (tool)

1. En el nodo **AI Agent**, busca la sección **"Tools"**
2. Click en **"Add Tool"**
3. Selecciona el tipo apropiado que permita ejecutar nodos

**Configuración de la tool:**

```
Name: registrar_gastos_diarios

Description:
Usa esta herramienta cuando el usuario quiera registrar uno o más gastos del día.
El usuario mencionará conceptos y montos, por ejemplo:
- "almuerzo 18k"
- "uber 12000, café 9k"

Parámetros esperados:
- gastos (array): lista de gastos a registrar
  Cada gasto tiene:
  - concepto (string): descripción del gasto
  - monto (number): valor numérico sin formato
  - categoria (string): categoría detectada automáticamente
  - fecha (string): fecha en formato YYYY-MM-DD

Esta herramienta:
1. Valida los datos
2. Guarda en la base de datos PostgreSQL
3. Retorna confirmación

Output:
{
  "success": true,
  "gastos_registrados": número,
  "total": monto_total,
  "mensaje": "confirmación formateada"
}
```

---

### ✅ Checklist Módulo 1

- [ ] Workflow `bot_finanzas_principal` abierto
- [ ] Nodo AI Agent localizado
- [ ] System prompt actualizado con reglas de gastos
- [ ] Ejemplos de extracción incluidos en el prompt
- [ ] Reglas de categorización documentadas
- [ ] Tool `registrar_gastos_diarios` creada
- [ ] Descripción de la tool clara y específica
- [ ] Parámetros de entrada definidos

---

## Módulo 2: Parser Avanzado de Gastos

### 🎓 Conceptos

#### ¿Qué es un parser?

Es un componente que toma datos en un formato (texto natural) y los convierte a otro formato (estructura de datos).

```
Input (texto):    "almuerzo 18k, uber 12000"
Output (JSON):    [
                    {concepto: "almuerzo", monto: 18000},
                    {concepto: "uber", monto: 12000}
                  ]
```

#### ¿Por qué necesitas un parser si el LLM ya extrae?

Porque:
1. **Validación**: asegurar que los datos cumplen las reglas
2. **Normalización**: convertir formatos inconsistentes a formato estándar
3. **Enriquecimiento**: agregar datos calculados (UUIDs, timestamps)
4. **Garantía**: el LLM puede fallar; el parser es la última línea de defensa

---

### 📋 Paso 2.1 — Crear el nodo Code

1. En el workflow, después de la tool `registrar_gastos_diarios`, agrega un nodo **"Code"**
2. Renómbralo a: `Parser de Gastos`
3. Lenguaje: **JavaScript**

---

### 📋 Paso 2.2 — Implementar la lógica de parsing

```javascript
// ============================================================
// PARSER DE GASTOS - Fase 2
// ============================================================
// Este nodo recibe el output del AI Agent (array de gastos)
// y los normaliza/valida antes de insertar en BD.
// ============================================================

// 1. Obtener datos del input
const inputData = $input.all()[0].json;
const gastos = inputData.gastos || [];
const chatId = $('Telegram Trigger').item.json.message.chat.id;

// Helper: generar UUID v4
function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// Helper: normalizar monto (convertir strings a números)
function normalizarMonto(monto) {
  // Si ya es número, retornar
  if (typeof monto === 'number') {
    return Math.abs(monto); // Asegurar que sea positivo
  }

  // Si es string, procesar
  let montoStr = String(monto).trim();

  // Remover símbolos de moneda
  montoStr = montoStr.replace(/[$€£¥COP]/gi, '').trim();

  // Detectar sufijo "k" o "mil" (18k = 18000)
  const matchK = montoStr.match(/^([\d.,]+)\s*k$/i);
  const matchMil = montoStr.match(/^([\d.,]+)\s*mil$/i);

  if (matchK) {
    const base = parseFloat(matchK[1].replace(/,/g, '.'));
    return base * 1000;
  }

  if (matchMil) {
    const base = parseFloat(matchMil[1].replace(/,/g, '.'));
    return base * 1000;
  }

  // Normalizar separadores
  if (montoStr.includes(',') && montoStr.includes('.')) {
    const lastCommaPos = montoStr.lastIndexOf(',');
    const lastDotPos = montoStr.lastIndexOf('.');

    if (lastCommaPos > lastDotPos) {
      montoStr = montoStr.replace(/\./g, '').replace(',', '.');
    } else {
      montoStr = montoStr.replace(/,/g, '');
    }
  } else if (montoStr.includes(',')) {
    const parts = montoStr.split(',');
    if (parts[1] && parts[1].length <= 2) {
      montoStr = montoStr.replace(',', '.');
    } else {
      montoStr = montoStr.replace(/,/g, '');
    }
  } else if (montoStr.includes('.')) {
    const parts = montoStr.split('.');
    if (parts[1] && parts[1].length === 3) {
      montoStr = montoStr.replace(/\./g, '');
    }
  }

  const parsed = parseFloat(montoStr);

  if (isNaN(parsed) || parsed <= 0) {
    throw new Error(`Monto inválido: ${monto}`);
  }

  return parsed;
}

// Helper: validar fecha (formato YYYY-MM-DD)
function validarFecha(fechaStr) {
  if (!fechaStr) {
    return new Date().toISOString().split('T')[0];
  }

  const match = fechaStr.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) {
    throw new Error(`Formato de fecha inválido: ${fechaStr}`);
  }

  const [, year, month, day] = match;
  const date = new Date(year, month - 1, day);

  if (date.getFullYear() != year || date.getMonth() + 1 != month || date.getDate() != day) {
    throw new Error(`Fecha inválida: ${fechaStr}`);
  }

  return fechaStr;
}

// Diccionario de categorías mejorado
const CATEGORIAS = {
  'almuerzo': 'alimentacion',
  'desayuno': 'alimentacion',
  'cena': 'alimentacion',
  'comida': 'alimentacion',
  'cafe': 'alimentacion',
  'café': 'alimentacion',
  'pan': 'alimentacion',
  'uber': 'transporte',
  'taxi': 'transporte',
  'transporte': 'transporte',
  'netflix': 'suscripciones',
  'spotify': 'suscripciones',
  'mercado': 'mercado',
  'supermercado': 'mercado',
  'farmacia': 'salud',
  'gimnasio': 'salud',
  'gym': 'salud',
  'cine': 'entretenimiento',
  'arriendo': 'vivienda',
};

function detectarCategoria(concepto, categoriaActual) {
  if (categoriaActual && categoriaActual !== 'general') {
    return categoriaActual;
  }

  const conceptoNormalizado = concepto.toLowerCase().trim();

  for (const [palabra, categoria] of Object.entries(CATEGORIAS)) {
    if (conceptoNormalizado.includes(palabra)) {
      return categoria;
    }
  }

  return 'general';
}

// 2. Procesar cada gasto
const gastosNormalizados = gastos.map(gasto => {
  try {
    if (!gasto.concepto || gasto.concepto.trim() === '') {
      throw new Error('El concepto no puede estar vacío');
    }

    if (!gasto.monto) {
      throw new Error('El monto es requerido');
    }

    const montoNormalizado = normalizarMonto(gasto.monto);
    const fechaValida = validarFecha(gasto.fecha);
    const categoria = detectarCategoria(gasto.concepto, gasto.categoria);
    const id = uuidv4();
    const timestamp = new Date().toISOString();

    return {
      id,
      chat_id: chatId,
      concepto: gasto.concepto.trim(),
      monto: montoNormalizado,
      categoria,
      fecha: fechaValida,
      timestamp,
      origen: 'bot'
    };

  } catch (error) {
    console.error(`Error procesando gasto:`, gasto, error.message);
    return null;
  }
}).filter(g => g !== null);

// 3. Validación final
if (gastosNormalizados.length === 0) {
  throw new Error('No se pudo procesar ningún gasto válido');
}

// 4. Retornar gastos listos para insertar
return gastosNormalizados.map(gasto => ({json: gasto}));
```

---

### ✅ Checklist Módulo 2

- [ ] Nodo "Parser de Gastos" creado
- [ ] Función `normalizarMonto` implementada
- [ ] Función `validarFecha` implementada
- [ ] Categorizador implementado
- [ ] Manejo de errores por gasto individual
- [ ] Output listo para PostgreSQL

---

## Módulo 3: Inserción en PostgreSQL

### 🎓 Conceptos

#### ¿Qué es un INSERT batch?

Es insertar múltiples filas en una sola query en vez de hacer N queries separadas.

**Eficiente** (1 query):
```sql
INSERT INTO expense_entries (...)
VALUES
  (...),
  (...),
  (...);
```

Ventajas:
- Más rápido (menos roundtrips a la BD)
- Transaccional (todo o nada)
- Menos carga en la BD

---

### 📋 Paso 3.1 — Crear el nodo PostgreSQL

1. Después del nodo "Parser de Gastos", agrega un nodo **"PostgreSQL"**
2. Renómbralo a: `Insertar Gastos en BD`
3. Credencial: selecciona tu credencial de PostgreSQL
4. Operation: **Execute Query**

---

### 📋 Paso 3.2 — Implementar la query de inserción

En el nodo PostgreSQL, en el campo de query, usa este enfoque:

**Opción 1: Query directa (simple)**

Crear un Code Node antes de PostgreSQL que genere la query:

```javascript
const items = $input.all();

const values = items.map(item => {
  const g = item.json;
  return `(
    '${g.id}'::UUID,
    (SELECT id FROM users WHERE chat_id = '${g.chat_id}'),
    '${g.fecha}'::DATE,
    '${g.concepto.replace(/'/g, "''")}',
    '${g.categoria}',
    ${g.monto},
    'bot',
    NOW()
  )`;
}).join(',\n');

const query = `
INSERT INTO expense_entries (
  id, user_id, fecha_gasto, concepto, categoria, valor, origen, created_at
)
VALUES
${values}
ON CONFLICT (id) DO NOTHING
RETURNING id, concepto, categoria, valor, fecha_gasto;
`;

return [{json: {query, gastos: items.map(i => i.json)}}];
```

Luego en el nodo PostgreSQL:
```sql
{{ $json.query }}
```

---

### ✅ Checklist Módulo 3

- [ ] Nodo "Insertar Gastos en BD" creado
- [ ] Query de INSERT batch implementada
- [ ] ON CONFLICT configurado (evita duplicados)
- [ ] RETURNING clause incluida
- [ ] Prueba manual: insertar 1 gasto ✓
- [ ] Prueba manual: insertar 3 gastos ✓

---

## Módulo 4: Respuesta de Confirmación

### 📋 Paso 4.1 — Crear el nodo Code para generar mensaje

```javascript
const gastos = $input.all();

function formatearMonto(valor) {
  return '$' + Math.round(valor).toLocaleString('es-CO');
}

function emojiCategoria(categoria) {
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
  return emojis[categoria] || '📦';
}

const total = gastos.reduce((sum, item) => sum + item.json.valor, 0);

const listaGastos = gastos.map(item => {
  const g = item.json;
  const emoji = emojiCategoria(g.categoria);
  const monto = formatearMonto(g.valor);
  const concepto = g.concepto.charAt(0).toUpperCase() + g.concepto.slice(1);
  
  return `${emoji} ${concepto}: ${monto}`;
}).join('\n');

let mensaje = `✅ *Registré ${gastos.length} gasto${gastos.length > 1 ? 's' : ''}*\n\n`;
mensaje += listaGastos;
mensaje += `\n\n💰 *Total: ${formatearMonto(total)}*`;
mensaje += '\n\n_💾 Guardado en base de datos_';

return [{json: {
  mensaje,
  chat_id: gastos[0].json.chat_id || $('Telegram Trigger').item.json.message.chat.id,
  total,
  cantidad: gastos.length
}}];
```

---

### 📋 Paso 4.2 — Crear el nodo Telegram

1. Después de "Generar Confirmación", agrega un nodo **"Telegram"**
2. Renómbralo a: `Enviar Confirmación`
3. Operation: **Send Message**

**Configuración:**

- **Chat ID**: `{{ $json.chat_id }}`
- **Text**: `{{ $json.mensaje }}`
- **Parse Mode**: **Markdown**

---

### ✅ Checklist Módulo 4

- [ ] Nodo "Generar Confirmación" creado
- [ ] Formateo de montos implementado
- [ ] Emojis por categoría configurados
- [ ] Nodo "Enviar Confirmación" creado
- [ ] Parse mode Markdown configurado

---

## Módulo 5: Comandos de Consulta

### 📋 Paso 5.1 — Agregar tool de resumen

En el AI Agent, agrega una nueva tool llamada `obtener_gastos_mes` que ejecute esta query:

```sql
SELECT 
  fecha_gasto,
  concepto,
  categoria,
  valor
FROM expense_entries
WHERE user_id = (SELECT id FROM users WHERE chat_id = '{{ $('Telegram Trigger').item.json.message.chat.id }}')
  AND DATE_TRUNC('month', fecha_gasto) = DATE_TRUNC('month', CURRENT_DATE)
ORDER BY fecha_gasto DESC, created_at DESC
LIMIT 50;
```

Luego formatea la respuesta en un Code Node.

---

## Módulo 6: Pruebas

### Casos de prueba:

1. ✅ "almuerzo 18k" → 1 gasto registrado
2. ✅ "uber 12k, café 9k, pan 3k" → 3 gastos registrados
3. ✅ Diferentes formatos: 18k, $18,000, 18.000
4. ✅ Categorías automáticas funcionando
5. ✅ Mensajes de confirmación claros

---

## 🎯 Resumen Final

### Lo que has construido

✅ Un sistema completo de registro de gastos que:
1. Entiende lenguaje natural
2. Extrae múltiples gastos de un mensaje
3. Normaliza formatos de montos
4. Categoriza automáticamente
5. Guarda en PostgreSQL con idempotencia
6. Confirma con mensajes profesionales
7. Permite consultas desde comandos

### Próximos pasos (Fase 3)

La Fase 3 incluirá:
- Cálculos automáticos de proyección y diferencia
- Reportes más avanzados con análisis por categoría
- Comando `/resumen` completo con estadísticas
- Rollover de mes automático
- Alertas cuando gastas más de lo proyectado
- Exportación opcional a Excel/PDF bajo demanda

---

> **¡Felicitaciones!** 🎉 Tu sistema ahora registra gastos de forma inteligente y los mantiene en PostgreSQL para consultas posteriores.
