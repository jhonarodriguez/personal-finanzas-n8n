# 🎓 Fase 2 — Registro de Gastos Diarios (Guía de Aprendizaje)

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
└──────────────────────────────────────────────────────────────┘
```

---

## Módulo 1: Configuración de Google Sheets API

### 🎓 Conceptos

#### ¿Qué es Google Sheets API?

Es la interface que permite a aplicaciones externas (como n8n) leer y escribir datos en Google Sheets de forma programática. Sin esta API, solo podrías modificar el Sheet manualmente.

#### ¿Qué es OAuth2?

Es un protocolo de autorización que permite a n8n acceder a tu Google Sheets **sin conocer tu contraseña**. En vez de eso, Google te muestra una pantalla donde autorizas explícitamente a n8n.

El flujo es:
1. n8n te redirige a Google
2. Tú autorizas el acceso
3. Google le da a n8n un **token de acceso** temporal
4. n8n usa ese token para acceder a tus Sheets

#### ¿Por qué necesitas un proyecto en Google Cloud?

Porque Google agrupa todas las APIs bajo "proyectos". Necesitas:
- Un proyecto (contenedor lógico)
- Habilitar la API de Sheets
- Configurar la pantalla de consentimiento (lo que ve el usuario al autorizar)
- Crear credenciales OAuth2

---

### 📋 Paso 1.1 — Crear proyecto en Google Cloud Console

1. Ve a https://console.cloud.google.com/
2. Si es tu primera vez, acepta los términos de servicio
3. Click en el selector de proyectos (arriba, al lado de "Google Cloud")
4. Click en **"NEW PROJECT"**
5. Nombre del proyecto: `n8n-finanzas-bot`
6. Location: puedes dejar "No organization"
7. Click en **"CREATE"**
8. Espera 10-20 segundos y refresca

**¿Por qué esto?** Google necesita agrupar todas las configuraciones de API bajo un proyecto. Esto también te permite ver métricas de uso y configurar límites.

---

### 📋 Paso 1.2 — Habilitar Google Sheets API

1. En la consola, asegúrate de tener seleccionado el proyecto `n8n-finanzas-bot`
2. En el menú lateral izquierdo, ve a **"APIs & Services"** → **"Library"**
3. En el buscador, escribe: `Google Sheets API`
4. Click en **"Google Sheets API"**
5. Click en **"ENABLE"**

**¿Por qué esto?** Por defecto, ninguna API está habilitada. Necesitas habilitarla explícitamente para poder usarla.

---

### 📋 Paso 1.3 — Configurar pantalla de consentimiento OAuth

1. En el menú lateral, ve a **"APIs & Services"** → **"OAuth consent screen"**
2. Selecciona **"External"** (porque no tienes Google Workspace)
3. Click en **"CREATE"**

**Configuración básica:**
- App name: `n8n Finanzas Bot`
- User support email: tu email
- Developer contact: tu email
- Click **"SAVE AND CONTINUE"**

**Scopes (paso 2):**
- Click en **"ADD OR REMOVE SCOPES"**
- Busca y selecciona:
  - `https://www.googleapis.com/auth/spreadsheets` (leer y escribir sheets)
- Click **"UPDATE"**
- Click **"SAVE AND CONTINUE"**

**Test users (paso 3):**
- Click en **"ADD USERS"**
- Agrega tu email (el mismo de tu cuenta Google)
- Click **"ADD"**
- Click **"SAVE AND CONTINUE"**

**Summary (paso 4):**
- Revisa que todo esté correcto
- Click **"BACK TO DASHBOARD"**

**¿Por qué esto?** La pantalla de consentimiento es lo que ves cuando una app te pide permisos. Google requiere que la configures incluso para uso personal.

---

### 📋 Paso 1.4 — Crear credenciales OAuth 2.0

1. En el menú lateral, ve a **"APIs & Services"** → **"Credentials"**
2. Click en **"CREATE CREDENTIALS"** → **"OAuth client ID"**
3. Application type: **"Web application"**
4. Name: `n8n OAuth Client`

**Authorized JavaScript origins:**
- Add URI: `http://localhost:5678` (si n8n corre local)
- Si n8n corre en otro puerto o dominio, usa ese

**Authorized redirect URIs:**
- Add URI: `http://localhost:5678/rest/oauth2-credential/callback`
- **MUY IMPORTANTE**: Este endpoint debe coincidir exactamente con el de n8n

5. Click en **"CREATE"**

**Resultado:**
- Verás una ventana con:
  - **Client ID**: algo como `123456789-abc...apps.googleusercontent.com`
  - **Client Secret**: algo como `GOCSPX-abc123...`
- **Copia ambos** y guárdalos en un lugar seguro (los necesitarás en n8n)

**¿Por qué esto?** Estas credenciales identifican a n8n ante Google. El Client ID es público, pero el Client Secret es privado (nunca lo compartas).

---

### 📋 Paso 1.5 — Publicar la app (modo prueba)

Por defecto, la app está en modo "Testing" y solo funciona con los usuarios que agregaste. Para uso personal esto es suficiente.

Si ves advertencias de "App no verificada", ignóralas y click en "Avanzado" → "Ir a n8n Finanzas Bot (no seguro)".

**¿Por qué esto?** Google quiere que las apps públicas pasen por revisión de seguridad. Como esto es para uso personal, no necesitas ese paso.

---

### ✅ Checklist Módulo 1

- [ ] Proyecto `n8n-finanzas-bot` creado en Google Cloud
- [ ] Google Sheets API habilitada
- [ ] Pantalla de consentimiento OAuth configurada
- [ ] Tu email agregado como test user
- [ ] Credenciales OAuth 2.0 creadas
- [ ] Client ID copiado
- [ ] Client Secret copiado
- [ ] Redirect URI configurada correctamente

---

## Módulo 2: Conexión de n8n con Google Sheets

### 🎓 Conceptos

#### ¿Qué es una credencial en n8n?

Es una configuración guardada de forma cifrada que permite a n8n conectarse a servicios externos. En vez de poner las credenciales en cada nodo, las configuras una vez y las reutilizas.

#### Flujo de autorización OAuth en n8n

1. Configuras Client ID y Secret
2. Click en "Connect my account"
3. n8n te redirige a Google
4. Autorizas el acceso
5. Google redirige de vuelta a n8n con un token
6. n8n guarda el token cifrado

---

### 📋 Paso 2.1 — Crear credencial Google Sheets en n8n

1. En n8n, ve al menú lateral izquierdo → **"Credentials"** (ícono de llave 🔑)
2. Click en **"Add Credential"**
3. Busca **"Google Sheets OAuth2 API"** y selecciónalo

**Configuración:**

- **Credential Name**: `Google Sheets Finanzas`
- **Client ID**: pega el que copiaste de Google Cloud
- **Client Secret**: pega el que copiaste de Google Cloud

4. Click en **"Connect my account"**

**Resultado:**
- Se abrirá una ventana/pestaña de Google
- Selecciona tu cuenta
- Verás la pantalla de consentimiento con "n8n Finanzas Bot"
- Puede aparecer advertencia "App no verificada" → Click "Avanzado" → "Ir a n8n Finanzas Bot"
- Selecciona los permisos (ver y editar sheets)
- Click **"Permitir"**

5. La ventana se cierra y vuelves a n8n
6. Deberías ver ✅ "Connected"
7. Click en **"Save"**

**¿Por qué esto?** n8n ahora tiene un token de acceso válido para leer/escribir tus Sheets. Este token se renueva automáticamente.

---

### 📋 Paso 2.2 — Probar la conexión

1. Crea un workflow temporal
2. Agrega un nodo **"Google Sheets"**
3. Selecciona la credencial `Google Sheets Finanzas`
4. Operation: **"Get All Sheets"**
5. Document: pon el ID de cualquier Sheet que tengas (puedes crear uno temporal)
6. Click en **"Execute Node"**

**Resultado esperado:**
- Lista de hojas del documento
- Si ves error de permisos, revisa los scopes en OAuth consent screen

---

### ✅ Checklist Módulo 2

- [ ] Credencial `Google Sheets Finanzas` creada en n8n
- [ ] Autorización OAuth completada exitosamente
- [ ] Estado "Connected" visible
- [ ] Prueba de conexión exitosa

---

## Módulo 3: Diseño de la Plantilla Mensual

### 🎓 Conceptos

#### ¿Por qué una plantilla?

Necesitas una estructura consistente donde n8n pueda escribir datos. Si cada mes tiene diferente formato, el bot no sabría dónde escribir.

#### Secciones de la plantilla (basado en control-gastos-mensuales)

1. **Resumen financiero** (parte superior)
   - Ingresos totales
   - Gastos fijos totales
   - Gastos variables totales
   - Saldo real banco
   - Saldo proyectado
   - Diferencia

2. **Tabla de gastos fijos** (lado izquierdo)
   - Columnas: Concepto, Valor, Categoría
   - Filas pre-configuradas: Arriendo, Netflix, Internet, etc.
   - Fila TOTAL con fórmula SUM

3. **Tabla de gastos variables** (lado derecho)
   - Columnas: Fecha, Concepto, Categoría, Valor
   - Filas vacías que se llenan desde el bot
   - Fila TOTAL con fórmula SUM

---

### 📋 Paso 3.1 — Crear el Google Spreadsheet

1. Ve a https://sheets.google.com/
2. Click en **"+"** para crear nuevo
3. Renombra el archivo: `Finanzas Personales 2026`
4. Renombra la primera hoja: `Marzo 2026` (usa el mes actual)

**Guardar el ID del documento:**
- En la URL verás algo como: `https://docs.google.com/spreadsheets/d/ABCD1234xyz/edit`
- El ID es la parte entre `/d/` y `/edit`: `ABCD1234xyz`
- **Guarda este ID**, lo necesitarás en n8n

---

### 📋 Paso 3.2 — Diseñar el layout (estructura de celdas)

#### **Fila 1-2: Título y mes**

```
A1: "CONTROL DE GASTOS MENSUALES"  [Combinar A1:F1, negrita, tamaño 16]
A2: "Marzo 2026"                   [Combinar A2:F2, negrita, tamaño 14]
```

#### **Fila 4-10: Resumen financiero**

```
A4: "RESUMEN MENSUAL"              [Negrita, fondo azul oscuro, texto blanco]
A5: "Sueldo mensual:"              B5: =SUM(C25:C40)  [fórmula]
A6: "Ingresos extra:"              B6: 0
A7: "Total gastos fijos:"          B7: =SUM(E23)      [fórmula → suma de fijos]
A8: "Total gastos variables:"      B8: =SUM(F50)      [fórmula → suma de variables]
A9: "Saldo proyectado:"            B9: =B5+B6-B7-B8   [fórmula]
A10: "Saldo real banco:"           B10: 0             [se actualiza desde bot]
A11: "Diferencia:"                 B11: =B10-B9       [fórmula]
```

**Formato:**
- B5:B11 → formato moneda: `$ #,##0`
- B11 → formato condicional: verde si positivo, rojo si negativo

---

#### **Columna D-E: Gastos fijos**

```
D4: "GASTOS FIJOS"                 [Negrita, fondo azul, texto blanco]
D5: "Concepto"  E5: "Valor"  F5: "Categoría"  [Negrita, fondo azul claro]

D6: "Arriendo"           E6: 0    F6: "Vivienda"
D7: "Internet"           E7: 0    F7: "Servicios"
D8: "Gas"                E8: 0    F8: "Servicios"
D9: "Netflix"            E9: 0    F9: "Suscripciones"
D10: "YouTube Premium"   E10: 0   F10: "Suscripciones"
D11: "Google Drive"      E11: 0   F11: "Suscripciones"
D12: "Gimnasio"          E12: 0   F12: "Salud"
D13: "Movistar"          E13: 0   F13: "Telefonía"
D14: "Mercado quincena 1" E14: 0  F14: "Alimentación"
D15: "Mercado quincena 2" E15: 0  F15: "Alimentación"
...
D22: [vacío por si agregan más]
D23: "TOTAL"             E23: =SUM(E6:E22)  [Negrita, fondo amarillo]
```

**Formato:**
- E6:E22 → formato moneda: `$ #,##0`
- Bordes en toda la tabla

---

#### **Columna H-K: Gastos variables**

```
H4: "GASTOS VARIABLES DEL MES"     [Negrita, fondo verde oscuro, texto blanco]
H5: "Fecha"  I5: "Concepto"  J5: "Categoría"  K5: "Valor"  [Negrita, fondo verde claro]

H6: [vacío - aquí escribe el bot]
H7: [vacío]
...
H49: [vacío]
H50: "TOTAL"  K50: =SUM(K6:K49)    [Negrita, fondo amarillo]
```

**Formato:**
- H6:H49 → formato fecha: `dd/mm/yyyy`
- K6:K49 → formato moneda: `$ #,##0`
- Bordes en toda la tabla

---

### 📋 Paso 3.3 — Aplicar colores y formato profesional

#### Paleta de colores (usar los mismos del proyecto Python):

```
Título: #1F4E78 (azul marino oscuro)
Headers: #4472C4 (azul medio)
Subheaders: #D9E2F3 (azul muy claro)
Totales: #FFF2CC (amarillo claro)
Fondo blanco: #FFFFFF
Texto: #000000
```

#### Formato general:

1. Toda la hoja: fuente **"Arial"** tamaño 10
2. Títulos (fila 1-2): tamaño 14-16, negrita
3. Headers de tablas: negrita, fondo color, texto blanco
4. Totales: negrita, fondo amarillo
5. Bordes: aplicar a todas las tablas

#### Anchos de columnas:

```
A: 200px
B: 120px
C: 100px
D: 180px
E: 100px
F: 150px
G: 20px (separador)
H: 100px
I: 200px
J: 150px
K: 100px
```

---

### 📋 Paso 3.4 — Configurar fórmulas y validaciones

#### Fórmulas importantes:

```
B7: =SUM(E6:E22)           # Total gastos fijos
B8: =SUM(K6:K49)           # Total gastos variables
B9: =B5+B6-B7-B8           # Saldo proyectado
B11: =B10-B9               # Diferencia (real vs proyectado)
E23: =SUM(E6:E22)          # Suma gastos fijos
K50: =SUM(K6:K49)          # Suma gastos variables
```

#### Formato condicional en B11 (diferencia):

```
Si B11 >= 0:  fondo verde claro (#D4EDDA), texto verde oscuro (#155724)
Si B11 < 0:   fondo rojo claro (#F8D7DA), texto rojo oscuro (#721C24)
```

Cómo hacerlo:
1. Selecciona B11
2. Formato → Formato condicional
3. Regla 1: "Es mayor o igual a" 0 → verde
4. Regla 2: "Es menor que" 0 → rojo

---

### 📋 Paso 3.5 — Documentar rangos clave

Para que n8n sepa dónde escribir, documenta estos rangos:

```
CONFIGURACIÓN DE RANGOS (guardar en .env o notas)

SHEET_ID=ABCD1234xyz  (el ID del spreadsheet)
HOJA_ACTUAL=Marzo 2026

RANGOS:
- Saldo real banco: B10
- Total gastos fijos: B7
- Total gastos variables: B8
- Saldo proyectado: B9
- Diferencia: B11

TABLAS:
- Gastos fijos: D6:F22 (17 filas de datos)
- Gastos variables: H6:K49 (44 filas de datos)
  → Primera fila de datos: H6
  → Última fila de datos: H49
  → Fila TOTAL: H50
```

**¿Por qué esto?** n8n necesita saber exactamente dónde escribir. Los rangos pueden cambiar si rediseñas la hoja.

---

### ✅ Checklist Módulo 3

- [ ] Spreadsheet `Finanzas Personales 2026` creado
- [ ] ID del spreadsheet guardado
- [ ] Hoja del mes actual creada (ej: `Marzo 2026`)
- [ ] Sección Resumen diseñada (filas 4-11)
- [ ] Tabla Gastos Fijos diseñada (D4:F23)
- [ ] Tabla Gastos Variables diseñada (H4:K50)
- [ ] Fórmulas configuradas y probadas
- [ ] Colores y formato aplicados
- [ ] Formato condicional en diferencia funcionando
- [ ] Anchos de columna ajustados
- [ ] Rangos clave documentados

---

## Módulo 4: Actualización del AI Agent

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

### 📋 Paso 4.1 — Abrir el workflow existente

1. En n8n, abre el workflow `bot_finanzas_principal` (el de la Fase 1)
2. Busca el nodo **"AI Agent"**
3. Click en él para editarlo

---

### 📋 Paso 4.2 — Actualizar el system prompt

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
    "fecha": "2026-03-05"
  },
  {
    "concepto": "uber",
    "monto": 12000,
    "categoria": "transporte",
    "fecha": "2026-03-05"
  },
  {
    "concepto": "café",
    "monto": 9500,
    "categoria": "alimentacion",
    "fecha": "2026-03-05"
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

**¿Por qué este system prompt?**
- Define claramente las reglas de negocio
- Da ejemplos concretos (few-shot learning)
- Especifica formato de salida (facilita el parsing)
- Maneja edge cases (fechas, formatos raros)

---

### 📋 Paso 4.3 — Crear la nueva herramienta (tool)

1. En el nodo **AI Agent**, busca la sección **"Tools"**
2. Click en **"Add Tool"**
3. Selecciona **"Call n8n Workflow Tool"** (o el equivalente que permita ejecutar nodos)

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
2. Guarda en la base de datos
3. Sincroniza con Google Sheets
4. Retorna confirmación

Output:
{
  "success": true,
  "gastos_registrados": número,
  "total": monto_total,
  "mensaje": "confirmación formateada"
}
```

**¿Por qué esto?** La descripción le dice al LLM exactamente cuándo y cómo usar esta tool. Mientras más específico seas, mejor funciona.

---

### 📋 Paso 4.4 — Conectar la tool con los nodos de procesamiento

La tool va a llamar a una secuencia de nodos:

```
[Tool: registrar_gastos_diarios]
         │
         ▼
[Code Node: Parser y normalizador]
         │
         ▼
[PostgreSQL: INSERT batch]
         │
         ▼
[Google Sheets: Append rows]
         │
         ▼
[Code Node: Generar respuesta]
         │
         ▼
[Telegram: Enviar confirmación]
```

Por ahora, solo configura la estructura. Los nodos los implementaremos en los siguientes módulos.

---

### ✅ Checklist Módulo 4

- [ ] Workflow `bot_finanzas_principal` abierto
- [ ] Nodo AI Agent localizado
- [ ] System prompt actualizado con reglas de gastos
- [ ] Ejemplos de extracción incluidos en el prompt
- [ ] Reglas de categorización documentadas
- [ ] Tool `registrar_gastos_diarios` creada
- [ ] Descripción de la tool clara y específica
- [ ] Parámetros de entrada definidos
- [ ] Estructura de output definida

---

## Módulo 5: Parser Avanzado de Gastos

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

#### ¿Qué es normalización de montos?

Convertir diferentes formatos a un estándar:
```
18k → 18000
18.000 → 18000
$18,000 → 18000
18000.50 → 18000.5
```

---

### 📋 Paso 5.1 — Crear el nodo Code

1. En el workflow, después de la tool `registrar_gastos_diarios`, agrega un nodo **"Code"**
2. Renómbralo a: `Parser de Gastos`
3. Lenguaje: **JavaScript**

---

### 📋 Paso 5.2 — Implementar la lógica de parsing

```javascript
// ============================================================
// PARSER DE GASTOS - Fase 2
// ============================================================
// Este nodo recibe el output del AI Agent (array de gastos)
// y los normaliza/valida antes de insertar en BD.
//
// Input esperado:
// {
//   gastos: [
//     {concepto: "almuerzo", monto: "18k", categoria: "alimentacion", fecha: "2026-03-05"},
//     {concepto: "uber", monto: 12000, categoria: "transporte"}
//   ]
// }
//
// Output:
// [
//   {
//     id: "uuid-v4",
//     concepto: "almuerzo",
//     monto: 18000,
//     categoria: "alimentacion",
//     fecha: "2026-03-05",
//     timestamp: "2026-03-05T10:30:00Z"
//   },
//   ...
// ]
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

  // Normalizar separadores:
  // - Si tiene punto Y coma, asumir formato europeo (18.000,50 → 18000.50)
  // - Si solo tiene coma, asumir separador de miles (18,000 → 18000)
  // - Si solo tiene punto, puede ser miles o decimal

  if (montoStr.includes(',') && montoStr.includes('.')) {
    // Formato con ambos: determinar cuál es el separador decimal
    const lastCommaPos = montoStr.lastIndexOf(',');
    const lastDotPos = montoStr.lastIndexOf('.');

    if (lastCommaPos > lastDotPos) {
      // Coma es decimal: 18.000,50
      montoStr = montoStr.replace(/\./g, '').replace(',', '.');
    } else {
      // Punto es decimal: 18,000.50
      montoStr = montoStr.replace(/,/g, '');
    }
  } else if (montoStr.includes(',')) {
    // Solo coma: puede ser miles o decimal
    const parts = montoStr.split(',');
    if (parts[1] && parts[1].length <= 2) {
      // Probablemente decimal: 18,50
      montoStr = montoStr.replace(',', '.');
    } else {
      // Probablemente miles: 18,000
      montoStr = montoStr.replace(/,/g, '');
    }
  } else if (montoStr.includes('.')) {
    // Solo punto: determinar si es miles o decimal
    const parts = montoStr.split('.');
    if (parts[1] && parts[1].length === 3) {
      // Probablemente miles: 18.000
      montoStr = montoStr.replace(/\./g, '');
    }
    // Si son 2 dígitos, asumir decimal: 18.50
  }

  const parsed = parseFloat(montoStr);

  // Validar que sea un número válido
  if (isNaN(parsed) || parsed <= 0) {
    throw new Error(`Monto inválido: ${monto}`);
  }

  return parsed;
}

// Helper: validar fecha (formato YYYY-MM-DD)
function validarFecha(fechaStr) {
  if (!fechaStr) {
    // Si no hay fecha, usar hoy
    return new Date().toISOString().split('T')[0];
  }

  // Validar formato YYYY-MM-DD
  const match = fechaStr.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) {
    throw new Error(`Formato de fecha inválido: ${fechaStr}`);
  }

  // Validar que sea una fecha válida
  const [, year, month, day] = match;
  const date = new Date(year, month - 1, day);

  if (date.getFullYear() != year || date.getMonth() + 1 != month || date.getDate() != day) {
    throw new Error(`Fecha inválida: ${fechaStr}`);
  }

  return fechaStr;
}

// 2. Procesar cada gasto
const gastosNormalizados = gastos.map(gasto => {
  try {
    // Validar campos requeridos
    if (!gasto.concepto || gasto.concepto.trim() === '') {
      throw new Error('El concepto no puede estar vacío');
    }

    if (!gasto.monto) {
      throw new Error('El monto es requerido');
    }

    // Normalizar monto
    const montoNormalizado = normalizarMonto(gasto.monto);

    // Validar fecha
    const fechaValida = validarFecha(gasto.fecha);

    // Categoría por defecto si no viene
    const categoria = (gasto.categoria || 'general').toLowerCase();

    // Generar ID único
    const id = uuidv4();

    // Timestamp de creación
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
    // Si hay error en un gasto, lo registramos pero continuamos con los demás
    console.error(`Error procesando gasto:`, gasto, error.message);
    return null;
  }
}).filter(g => g !== null); // Remover gastos que fallaron

// 3. Validación final
if (gastosNormalizados.length === 0) {
  throw new Error('No se pudo procesar ningún gasto válido');
}

// 4. Retornar gastos listos para insertar
return gastosNormalizados.map(gasto => ({json: gasto}));
```

**¿Qué hace este código?**

1. **Extrae datos**: del output del AI Agent
2. **Normaliza montos**: convierte todos los formatos a número
3. **Valida fechas**: asegura formato correcto o usa hoy
4. **Genera UUIDs**: cada gasto tiene ID único
5. **Asigna categoría**: usa la detectada o "general"
6. **Maneja errores**: si un gasto falla, continúa con los demás
7. **Retorna array limpio**: listo para INSERT

---

### 📋 Paso 5.3 — Agregar el categorizador mejorado (opcional)

Si el AI Agent no categoriza bien, puedes agregar lógica adicional:

```javascript
// Diccionario de palabras clave → categorías
const CATEGORIAS = {
  // Alimentación
  'almuerzo': 'alimentacion',
  'desayuno': 'alimentacion',
  'cena': 'alimentacion',
  'comida': 'alimentacion',
  'cafe': 'alimentacion',
  'café': 'alimentacion',
  'pan': 'alimentacion',
  'fruta': 'alimentacion',
  'mercado': 'mercado',
  'supermercado': 'mercado',

  // Transporte
  'uber': 'transporte',
  'taxi': 'transporte',
  'gasolina': 'transporte',
  'transporte': 'transporte',
  'bus': 'transporte',
  'metro': 'transporte',

  // Suscripciones
  'netflix': 'suscripciones',
  'spotify': 'suscripciones',
  'youtube': 'suscripciones',
  'prime': 'suscripciones',
  'hbo': 'suscripciones',
  'disney': 'suscripciones',

  // Salud
  'farmacia': 'salud',
  'medicina': 'salud',
  'doctor': 'salud',
  'medico': 'salud',
  'gimnasio': 'salud',
  'gym': 'salud',

  // Entretenimiento
  'cine': 'entretenimiento',
  'restaurante': 'entretenimiento',
  'bar': 'entretenimiento',
  'fiesta': 'entretenimiento',

  // Servicios
  'arriendo': 'vivienda',
  'alquiler': 'vivienda',
  'internet': 'servicios',
  'luz': 'servicios',
  'agua': 'servicios',
  'gas': 'servicios',
};

function detectarCategoria(concepto, categoriaActual) {
  // Si ya viene categoría del LLM, usarla (excepto "general")
  if (categoriaActual && categoriaActual !== 'general') {
    return categoriaActual;
  }

  // Buscar en el diccionario
  const conceptoNormalizado = concepto.toLowerCase().trim();

  for (const [palabra, categoria] of Object.entries(CATEGORIAS)) {
    if (conceptoNormalizado.includes(palabra)) {
      return categoria;
    }
  }

  // Si no hay coincidencia, retornar general
  return 'general';
}

// Usar en el .map():
categoria: detectarCategoria(gasto.concepto, gasto.categoria),
```

---

### ✅ Checklist Módulo 5

- [ ] Nodo "Parser de Gastos" creado
- [ ] Función `normalizarMonto` implementada
- [ ] Pruebas de normalización: 18k → 18000 ✓
- [ ] Pruebas de normalización: $18,000 → 18000 ✓
- [ ] Pruebas de normalización: 18.000 → 18000 ✓
- [ ] Función `validarFecha` implementada
- [ ] Generación de UUIDs funcional
- [ ] Categorizador implementado (opcional pero recomendado)
- [ ] Manejo de errores por gasto individual
- [ ] Output listo para PostgreSQL

---

## Módulo 6: Inserción en PostgreSQL

### 🎓 Conceptos

#### ¿Qué es un INSERT batch?

Es insertar múltiples filas en una sola query en vez de hacer N queries separadas.

**Ineficiente** (N queries):
```sql
INSERT INTO expense_entries (...) VALUES (...);
INSERT INTO expense_entries (...) VALUES (...);
INSERT INTO expense_entries (...) VALUES (...);
```

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

#### ¿Qué es idempotencia?

Es la propiedad de que una operación produce el mismo resultado sin importar cuántas veces se ejecute.

Ejemplo:
- Si envías "almuerzo 18k" dos veces por error
- El sistema debería detectarlo y no duplicar

Estrategias:
1. **Constraint única** en BD (user_id + fecha + concepto + monto)
2. **Validación antes de insertar** (buscar duplicados)
3. **ON CONFLICT DO NOTHING** (PostgreSQL)

---

### 📋 Paso 6.1 — Crear el nodo PostgreSQL

1. Después del nodo "Parser de Gastos", agrega un nodo **"PostgreSQL"**
2. Renómbralo a: `Insertar Gastos en BD`
3. Credencial: selecciona tu credencial de PostgreSQL
4. Operation: **Execute Query**

---

### 📋 Paso 6.2 — Implementar la query de inserción

```sql
-- ============================================================
-- INSERT BATCH de gastos variables
-- ============================================================
-- Esta query inserta múltiples gastos de una sola vez.
-- Usa ON CONFLICT para evitar duplicados.
-- ============================================================

INSERT INTO expense_entries (
  id,
  user_id,
  fecha_gasto,
  concepto,
  categoria,
  valor,
  origen,
  mensaje_fuente,
  created_at
)
SELECT
  data.id::UUID,
  u.id,
  data.fecha_gasto::DATE,
  data.concepto,
  data.categoria,
  data.valor,
  data.origen,
  data.mensaje_fuente,
  data.created_at::TIMESTAMPTZ
FROM (
  VALUES
    {{
      $items().map((item, index) => 
        `('${item.json.id}', '${item.json.chat_id}', '${item.json.fecha}', '${item.json.concepto}', '${item.json.categoria}', ${item.json.monto}, 'bot', NULL, '${item.json.timestamp}')`
      ).join(',\n    ')
    }}
) AS data(id, chat_id, fecha_gasto, concepto, categoria, valor, origen, mensaje_fuente, created_at)
JOIN users u ON u.chat_id = data.chat_id
ON CONFLICT (id) DO NOTHING;

-- Retornar los gastos insertados para confirmación
SELECT
  id,
  concepto,
  categoria,
  valor,
  fecha_gasto
FROM expense_entries
WHERE id IN (
  {{
    $items().map(item => `'${item.json.id}'`).join(', ')
  }}
)
ORDER BY fecha_gasto DESC, created_at DESC;
```

**¿Qué hace esta query?**

1. **Usa VALUES** para crear una tabla temporal con todos los gastos
2. **JOIN con users** para obtener el user_id desde el chat_id
3. **ON CONFLICT** para evitar duplicados (si se reintenta la operación)
4. **SELECT final** para retornar los gastos insertados (necesario para confirmación)

---

### 📋 Paso 6.3 — Alternativa más simple (si la anterior falla)

Si n8n tiene problemas con expresiones complejas, usa este enfoque:

```javascript
// En un Code Node antes de PostgreSQL:
const items = $input.all();

// Generar query dinámicamente
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

return [{json: {query}}];
```

Luego en el nodo PostgreSQL:
```sql
{{ $json.query }}
```

---

### 📋 Paso 6.4 — Verificar la inserción

Después de ejecutar, el nodo PostgreSQL debe retornar las filas insertadas.

Output esperado:
```json
[
  {
    "id": "uuid-1",
    "concepto": "almuerzo",
    "categoria": "alimentacion",
    "valor": 18000,
    "fecha_gasto": "2026-03-05"
  },
  {
    "id": "uuid-2",
    "concepto": "uber",
    "categoria": "transporte",
    "valor": 12000,
    "fecha_gasto": "2026-03-05"
  }
]
```

---

### ✅ Checklist Módulo 6

- [ ] Nodo "Insertar Gastos en BD" creado
- [ ] Query de INSERT batch implementada
- [ ] JOIN con tabla users funcional
- [ ] ON CONFLICT configurado (evita duplicados)
- [ ] RETURNING clause incluida
- [ ] Prueba manual: insertar 1 gasto ✓
- [ ] Prueba manual: insertar 3 gastos ✓
- [ ] Verificación en psql: datos correctos ✓

**Verificar en psql:**
```sql
SELECT * FROM expense_entries 
WHERE fecha_gasto = CURRENT_DATE 
ORDER BY created_at DESC 
LIMIT 10;
```

---

## Módulo 7: Sincronización con Google Sheets

### 🎓 Conceptos

#### ¿Cómo escribe n8n en Google Sheets?

n8n usa la API de Google Sheets, que tiene varias operaciones:

1. **Append** (agregar al final): agrega filas al final de los datos existentes
2. **Update**: actualiza celdas específicas por rango
3. **Clear**: limpia un rango
4. **Get**: lee datos

Para nuestro caso, usaremos **Append** porque queremos agregar gastos nuevos sin sobrescribir.

#### ¿Qué es un rango en Sheets?

Es una referencia a celdas específicas:
```
A1         → celda única
A1:B10     → rectángulo desde A1 hasta B10
H6:K6      → fila 6, columnas H a K
H:H        → toda la columna H
```

#### ¿Cómo mantener el formato?

Google Sheets mantiene automáticamente el formato de las celdas existentes cuando usas Append. Pero debes asegurarte de escribir en las columnas correctas.

---

### 📋 Paso 7.1 — Crear el nodo Google Sheets

1. Después del nodo "Insertar Gastos en BD", agrega un nodo **"Google Sheets"**
2. Renómbralo a: `Sincronizar con Sheets`
3. Credencial: selecciona `Google Sheets Finanzas`

---

### 📋 Paso 7.2 — Configurar la operación Append

**Configuración:**

- **Resource**: Spreadsheet
- **Operation**: Append or Update Row
- **Document**: 
  - Method: **By ID**
  - Document ID: `{{ $env.GOOGLE_SHEET_ID }}` (o pégalo directamente)
- **Sheet Name**: `{{ $env.SHEET_MES_ACTUAL }}` (ej: "Marzo 2026")
  - **Importante**: Esto debe coincidir exactamente con el nombre de la hoja
- **Data Mode**: **Define Below**

---

### 📋 Paso 7.3 — Mapear las columnas

Según el diseño de la plantilla, la tabla de variables está en H:K:

| Columna | Campo | Valor n8n |
|---------|-------|-----------|
| H | Fecha | `{{ $json.fecha_gasto }}` |
| I | Concepto | `{{ $json.concepto }}` |
| J | Categoría | `{{ $json.categoria }}` |
| K | Valor | `{{ $json.valor }}` |

**En la configuración de n8n:**

Click en "Add Column" por cada campo:

1. **Column**: `Fecha`  
   **Value**: `{{ $json.fecha_gasto }}`

2. **Column**: `Concepto`  
   **Value**: `{{ $json.concepto }}`

3. **Column**: `Categoría`  
   **Value**: `{{ $json.categoria }}`

4. **Column**: `Valor`  
   **Value**: `{{ $json.valor }}`

---

### 📋 Paso 7.4 — Configurar opciones avanzadas

En **Options** (dentro del nodo):

- **Range**: `H:K` (escribir solo en las columnas de variables)
- **Value Input Mode**: **USER_ENTERED**
  - Esto hace que Google Sheets interprete las fórmulas y formatee los números automáticamente

**¿Por qué USER_ENTERED?**
- Permite que Sheets aplique formato de moneda automáticamente
- Si hubiera fórmulas, las evaluaría
- Mantiene el formato existente de la columna

---

### 📋 Paso 7.5 — Configurar variables de entorno

Para no hardcodear los IDs, agrégalos al `.env`:

```env
# Google Sheets
GOOGLE_SHEET_ID=ABCD1234xyz
SHEET_MES_ACTUAL=Marzo 2026
```

Luego en n8n, usa:
```
{{ $env.GOOGLE_SHEET_ID }}
{{ $env.SHEET_MES_ACTUAL }}
```

**Beneficio:** Cuando cambie el mes, solo actualizas la variable.

---

### 📋 Paso 7.6 — Manejo de errores

Agrega un nodo **"IF"** antes de Google Sheets:

```javascript
// Condición: verificar que haya gastos para sincronizar
{{ $items().length > 0 }}
```

Si es FALSE, salta la sincronización.

También puedes agregar un nodo **"Error Trigger"** para capturar fallos de la API de Google:

1. Agrega nodo **"Error Trigger"**
2. Conéctalo al flujo principal
3. Si falla Google Sheets, este nodo se activa
4. Puedes enviar notificación de error al usuario o registrar en logs

---

### 📋 Paso 7.7 — Registrar la sincronización (opcional pero recomendado)

Después de escribir en Sheets, registra el evento en `sync_logs`:

```sql
INSERT INTO sync_logs (
  user_id,
  mes,
  destino,
  estado,
  filas_escritas,
  created_at
)
VALUES (
  (SELECT id FROM users WHERE chat_id = '{{ $('Telegram Trigger').item.json.message.chat.id }}'),
  '{{ $env.SHEET_MES_ACTUAL }}',
  'google_sheets',
  'ok',
  {{ $items().length }},
  NOW()
);
```

Esto te permite:
- Auditoría completa de sincronizaciones
- Detectar fallos históricos
- Métricas de uso

---

### ✅ Checklist Módulo 7

- [ ] Nodo "Sincronizar con Sheets" creado
- [ ] Credencial Google Sheets configurada
- [ ] Document ID configurado (variable de entorno)
- [ ] Sheet Name configurado (variable de entorno)
- [ ] Columnas mapeadas correctamente (H:K)
- [ ] Range configurado: `H:K`
- [ ] Value Input Mode: USER_ENTERED
- [ ] Variables de entorno agregadas al .env
- [ ] Nodo IF para validar datos antes de escribir
- [ ] Error Trigger configurado
- [ ] Sync log registrado en BD
- [ ] Prueba manual: escribir 1 gasto ✓
- [ ] Prueba manual: escribir 3 gastos ✓
- [ ] Verificación en Sheets: formato correcto ✓

**Verificar en Google Sheets:**
- Abre la hoja del mes actual
- Ve a la sección "Gastos Variables"
- Deberías ver las filas nuevas con:
  - Fecha formateada
  - Concepto claro
  - Categoría correcta
  - Monto con formato de moneda

---

## Módulo 8: Respuesta de Confirmación

### 🎓 Conceptos

#### ¿Por qué es importante una buena confirmación?

1. **Feedback inmediato**: el usuario sabe que la acción funcionó
2. **Transparencia**: muestra exactamente qué se registró
3. **Detección de errores**: si algo está mal, el usuario lo ve enseguida
4. **UX profesional**: hace que el bot se sienta "inteligente"

#### Elementos de una buena confirmación

✅ **Emoji de éxito**  
📊 **Resumen cuantitativo** (cuántos gastos, total)  
📝 **Detalle por gasto** (concepto + monto)  
💰 **Total sumado** (para verificación rápida)  
📅 **Fecha** (si no es hoy, mencionar)

---

### 📋 Paso 8.1 — Crear el nodo Code para generar mensaje

1. Después del nodo "Sincronizar con Sheets", agrega un nodo **"Code"**
2. Renómbralo a: `Generar Confirmación`

```javascript
// ============================================================
// GENERADOR DE CONFIRMACIÓN - Fase 2
// ============================================================
// Este nodo recibe los gastos insertados y genera un mensaje
// formateado para enviar por Telegram.
// ============================================================

const gastos = $input.all();

// Función para formatear monto con separador de miles
function formatearMonto(valor) {
  return '$' + Math.round(valor).toLocaleString('es-CO');
}

// Función para emoji de categoría
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

// Calcular total
const total = gastos.reduce((sum, item) => sum + item.json.valor, 0);

// Generar lista de gastos
const listaGastos = gastos.map((item, index) => {
  const g = item.json;
  const emoji = emojiCategoria(g.categoria);
  const monto = formatearMonto(g.valor);
  
  // Capitalizar primera letra del concepto
  const concepto = g.concepto.charAt(0).toUpperCase() + g.concepto.slice(1);
  
  return `${emoji} ${concepto}: ${monto}`;
}).join('\n');

// Detectar si todos los gastos son del mismo día
const fechas = [...new Set(gastos.map(item => item.json.fecha_gasto))];
const esHoy = fechas.length === 1 && fechas[0] === new Date().toISOString().split('T')[0];

// Construir mensaje
let mensaje = `✅ *Registré ${gastos.length} gasto${gastos.length > 1 ? 's' : ''}*\n\n`;
mensaje += listaGastos;
mensaje += `\n\n💰 *Total: ${formatearMonto(total)}*`;

if (!esHoy) {
  mensaje += `\n📅 Fecha: ${fechas[0]}`;
}

mensaje += '\n\n_Sincronizado con Google Sheets_ ✨';

return [{json: {
  mensaje,
  chat_id: gastos[0].json.chat_id || $('Telegram Trigger').item.json.message.chat.id,
  total,
  cantidad: gastos.length
}}];
```

**¿Qué hace este código?**

1. **Formatea montos**: $18,000 en vez de 18000
2. **Agrega emojis**: cada categoría tiene su emoji
3. **Capitaliza conceptos**: "almuerzo" → "Almuerzo"
4. **Calcula total**: suma todos los gastos
5. **Detecta fecha**: si no es hoy, lo menciona
6. **Usa Markdown**: para negritas en Telegram

---

### 📋 Paso 8.2 — Crear el nodo Telegram

1. Después de "Generar Confirmación", agrega un nodo **"Telegram"**
2. Renómbralo a: `Enviar Confirmación`
3. Credencial: tu credencial de Telegram
4. Operation: **Send Message**

**Configuración:**

- **Chat ID**: `{{ $json.chat_id }}`
- **Text**: `{{ $json.mensaje }}`
- **Additional Fields** → **Reply Markup**:
  - Parse Mode: **Markdown**
  - Disable Web Page Preview: **True**

**¿Por qué Markdown?**
- Permite usar `*negritas*` y `_cursivas_`
- Hace el mensaje más legible
- Mantiene consistencia con mensajes profesionales

---

### 📋 Paso 8.3 — Ejemplo de mensaje final

```
✅ Registré 3 gastos

🍽️ Almuerzo: $18,000
🚗 Uber: $12,000
🍽️ Café: $9,000

💰 Total: $39,000

Sincronizado con Google Sheets ✨
```

---

### ✅ Checklist Módulo 8

- [ ] Nodo "Generar Confirmación" creado
- [ ] Función de formateo de montos implementada
- [ ] Emojis por categoría configurados
- [ ] Cálculo de total correcto
- [ ] Detección de fecha implementada
- [ ] Nodo "Enviar Confirmación" creado
- [ ] Parse mode Markdown configurado
- [ ] Prueba: mensaje con 1 gasto ✓
- [ ] Prueba: mensaje con 3 gastos ✓
- [ ] Prueba: mensaje con fecha pasada ✓

---

## Módulo 9: Pruebas Integrales

### 🎓 Conceptos

#### ¿Por qué necesitas pruebas exhaustivas?

Porque el sistema tiene muchos puntos de fallo:
1. LLM puede malinterpretar
2. Parser puede fallar con formatos raros
3. BD puede rechazar datos inválidos
4. Google API puede dar timeout
5. Usuario puede escribir cosas inesperadas

#### Tipos de pruebas

1. **Funcionales**: ¿funciona el caso normal?
2. **Edge cases**: ¿funciona con casos límite?
3. **Negativos**: ¿rechaza datos inválidos?
4. **Integración**: ¿funcionan todos los componentes juntos?

---

### 📋 Paso 9.1 — Casos de prueba funcionales

| # | Input | Output esperado |
|---|-------|----------------|
| 1 | `almuerzo 18000` | 1 gasto registrado: Almuerzo $18,000 |
| 2 | `uber 12k` | 1 gasto registrado: Uber $12,000 |
| 3 | `café 9500` | 1 gasto registrado: Café $9,500 |
| 4 | `almuerzo 18k, uber 12k, café 9k` | 3 gastos registrados, total $39,000 |
| 5 | `gasté 45mil en mercado` | 1 gasto: Mercado $45,000 |

**Validación:**
- ✓ Mensaje de confirmación correcto
- ✓ Datos en PostgreSQL
- ✓ Datos en Google Sheets
- ✓ Formato de montos correcto
- ✓ Categorías asignadas correctamente

---

### 📋 Paso 9.2 — Casos de prueba de formatos

| # | Input | Monto esperado |
|---|-------|----------------|
| 1 | `almuerzo 18k` | 18000 |
| 2 | `almuerzo 18mil` | 18000 |
| 3 | `almuerzo 18.000` | 18000 |
| 4 | `almuerzo $18,000` | 18000 |
| 5 | `almuerzo 18000` | 18000 |
| 6 | `almuerzo 18,500` | 18500 |
| 7 | `almuerzo 18.5k` | 18500 |

---

### 📋 Paso 9.3 — Casos de prueba de categorías

| Concepto | Categoría esperada |
|----------|-------------------|
| almuerzo | alimentacion |
| desayuno | alimentacion |
| uber | transporte |
| taxi | transporte |
| netflix | suscripciones |
| mercado | mercado |
| farmacia | salud |
| gimnasio | salud |
| cine | entretenimiento |
| arriendo | vivienda |
| zapatos | vestuario |
| (cualquier otro) | general |

---

### 📋 Paso 9.4 — Casos de prueba de fechas

| # | Input | Fecha esperada |
|---|-------|----------------|
| 1 | `almuerzo 18k` | hoy |
| 2 | `ayer gasté 50k en mercado` | ayer |
| 3 | `gasté 30k en cine anteayer` | hace 2 días |

**Validación:**
- ✓ Fecha correcta en BD
- ✓ Fecha correcta en Sheets

---

### 📋 Paso 9.5 — Casos de prueba negativos (deben fallar o corregirse)

| # | Input | Comportamiento esperado |
|---|-------|------------------------|
| 1 | `almuerzo` (sin monto) | Error: "falta el monto" |
| 2 | `18000` (sin concepto) | Error: "falta el concepto" |
| 3 | `almuerzo -18000` | Convertir a positivo: 18000 |
| 4 | `almuerzo abc` | Error: "monto inválido" |

---

### 📋 Paso 9.6 — Checklist de pruebas

**Fase 1: Pruebas unitarias (nodo por nodo)**

- [ ] AI Agent detecta intención correctamente
- [ ] AI Agent extrae entidades correctamente
- [ ] Parser normaliza montos correctamente
- [ ] Parser valida fechas correctamente
- [ ] INSERT en PostgreSQL funciona
- [ ] Append en Google Sheets funciona
- [ ] Confirmación se genera correctamente

**Fase 2: Pruebas de integración (flujo completo)**

- [ ] 1 gasto simple funciona end-to-end
- [ ] 3 gastos múltiples funcionan end-to-end
- [ ] Diferentes formatos de monto funcionan
- [ ] Categorización automática funciona
- [ ] Fechas pasadas funcionan

**Fase 3: Pruebas de estrés**

- [ ] 10 gastos en un mensaje
- [ ] Gasto con concepto muy largo (200 caracteres)
- [ ] Gasto con caracteres especiales (émojis, tildes)
- [ ] Reintentar el mismo mensaje (idempotencia)

**Fase 4: Pruebas de errores**

- [ ] Qué pasa si Google Sheets no responde
- [ ] Qué pasa si PostgreSQL falla
- [ ] Qué pasa si el usuario escribe basura
- [ ] Qué pasa si el token de OpenAI expira

---

### ✅ Checklist Módulo 9

- [ ] Casos funcionales: 5/5 pasan
- [ ] Casos de formatos: 7/7 pasan
- [ ] Casos de categorías: 10/10 correctas
- [ ] Casos de fechas: 3/3 correctos
- [ ] Casos negativos manejados correctamente
- [ ] Pruebas de integración: todas pasan
- [ ] Idempotencia verificada
- [ ] Manejo de errores validado

---

## Módulo 10: Refinamiento y Documentación

### 🎓 Conceptos

#### ¿Por qué refinar?

Después de las pruebas, siempre encuentras:
- Prompts que necesitan ajustes
- Categorías que faltan
- Formatos de monto no contemplados
- Errores de UX

El refinamiento es la diferencia entre "funciona" y "funciona bien".

---

### 📋 Paso 10.1 — Ajustar el system prompt

Basándote en las pruebas, actualiza:

1. **Agregar ejemplos** de casos que fallaron
2. **Clarificar ambigüedades** que detectaste
3. **Agregar palabras clave** de categorías que faltaron

Ejemplo de mejora:
```
Antes:
"Detecta gastos en el mensaje"

Después:
"Detecta gastos en el mensaje. Un gasto SIEMPRE tiene:
1. Un concepto (qué se gastó)
2. Un monto (cuánto se gastó)

Ejemplos válidos:
✓ almuerzo 18k
✓ gasté 50mil en mercado
✓ pagué netflix 30000

Ejemplos NO válidos:
✗ almuerzo (falta monto)
✗ 18000 (falta concepto)
✗ compré cosas (falta monto)"
```

---

### 📋 Paso 10.2 — Actualizar categorizador

Si detectaste conceptos que se categorizan mal:

```javascript
// Agregar al diccionario CATEGORIAS
const CATEGORIAS = {
  // ... existentes ...
  
  // Nuevas detectadas en pruebas:
  'domicilios': 'alimentacion',
  'rappi': 'alimentacion',
  'pizza': 'alimentacion',
  'sushi': 'alimentacion',
  
  'parqueadero': 'transporte',
  'peaje': 'transporte',
  
  'steam': 'entretenimiento',
  'videojuego': 'entretenimiento',
  
  'corte pelo': 'cuidado_personal',
  'peluqueria': 'cuidado_personal',
};
```

---

### 📋 Paso 10.3 — Exportar el workflow

1. En n8n, abre el workflow
2. Click en los **3 puntos** (menú superior)
3. **Download**
4. Guarda como: `workflows/bot_finanzas_fase2_completo.json`
5. Commit al repositorio

**¿Por qué exportar?**
- Backup del trabajo
- Versionamiento
- Portabilidad (importar en otro n8n)
- Documentación del código

---

### 📋 Paso 10.4 — Crear diagrama del flujo

Crea un diagrama visual del workflow:

```
┌─────────────────┐
│ Telegram Trigger│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   AI Agent      │  ← LLM (OpenAI)
│   + Tools       │
└────────┬────────┘
         │
         ├─── Tool: actualizar_sueldo ──► [PostgreSQL]
         ├─── Tool: agregar_gasto_fijo ─► [PostgreSQL]
         ├─── Tool: obtener_resumen ────► [PostgreSQL]
         │
         └─── Tool: registrar_gastos ───┐
                                         │
                     ┌───────────────────┘
                     ▼
              ┌──────────────┐
              │ Parser Gastos│
              └──────┬───────┘
                     │
                     ▼
              ┌──────────────┐
              │ INSERT Batch │  ← PostgreSQL
              └──────┬───────┘
                     │
                     ▼
              ┌──────────────┐
              │ Sync Sheets  │  ← Google API
              └──────┬───────┘
                     │
                     ▼
              ┌──────────────┐
              │ Confirmación │  ← Telegram
              └──────────────┘
```

Guárdalo como: `docs/diagrams/flujo-fase2.txt`

---

### 📋 Paso 10.5 — Documentar variables de entorno

Actualiza `.env.example`:

```env
# ============================================================
# Configuración - Fase 2
# ============================================================

# OpenAI (para AI Agent)
OPENAI_API_KEY=sk-...

# Telegram Bot
TELEGRAM_BOT_TOKEN=123456:ABC...

# PostgreSQL
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=finanzas_db
POSTGRES_USER=finanzas_user
POSTGRES_PASSWORD=tu_password_seguro

# Google Sheets
GOOGLE_SHEET_ID=ABCD1234xyz
SHEET_MES_ACTUAL=Marzo 2026

# n8n
N8N_PORT=5678
N8N_ENCRYPTION_KEY=genera_uno_aleatorio_aqui
```

---

### 📋 Paso 10.6 — Crear CHANGELOG

Documenta qué cambiaste:

```markdown
# Changelog - personal-finanzas-n8n

## [Fase 2] - 2026-03-05

### Agregado
- Tool "registrar_gastos_diarios" en AI Agent
- Parser avanzado de gastos con normalización de montos
- Categorizador automático con 30+ palabras clave
- Sincronización automática a Google Sheets
- Plantilla mensual profesional con formato y fórmulas
- Mensajes de confirmación con emojis y formato

### Cambiado
- System prompt extendido con reglas de extracción de gastos
- Mejoras en manejo de errores y validaciones

### Soporte para
- Múltiples gastos en un mensaje
- Formatos de monto: 18k, 18mil, $18,000, 18.000
- Fechas relativas: hoy, ayer, anteayer
- 10+ categorías automáticas

## [Fase 1] - 2026-03-01

### Agregado
- Configuración inicial de n8n + PostgreSQL
- Bot de Telegram con comandos /start
- AI Agent con tools de configuración
- Esquema de base de datos completo
```

---

### ✅ Checklist Módulo 10

- [ ] System prompt refinado con aprendizajes
- [ ] Categorizador actualizado con nuevas palabras
- [ ] Workflow exportado a JSON
- [ ] Diagrama de flujo creado
- [ ] `.env.example` actualizado
- [ ] CHANGELOG documentado
- [ ] README actualizado con Fase 2

---

## 🎯 Resumen Final

### Lo que has construido

✅ Un sistema completo de registro de gastos que:
1. Entiende lenguaje natural
2. Extrae múltiples gastos de un mensaje
3. Normaliza formatos de montos
4. Categoriza automáticamente
5. Guarda en PostgreSQL
6. Sincroniza a Google Sheets con formato
7. Confirma al usuario con mensajes profesionales

### Tecnologías dominadas

- ✅ n8n workflows
- ✅ AI Agent con OpenAI
- ✅ System prompts complejos
- ✅ Entity extraction
- ✅ PostgreSQL batch operations
- ✅ Google Sheets API
- ✅ Parsing de texto natural
- ✅ Categorización con ML

### Próximos pasos (Fase 3)

La Fase 3 incluirá:
- Cálculos automáticos de proyección y diferencia
- Creación automática de hoja mensual nueva
- Comando `/resumen` mejorado con gráficos
- Rollover de mes automático
- Alertas cuando gastas más de lo proyectado
- Dashboard opcional

---

## 📚 Recursos adicionales

### Documentación oficial

- [n8n Docs](https://docs.n8n.io/)
- [Google Sheets API](https://developers.google.com/sheets/api)
- [PostgreSQL Docs](https://www.postgresql.org/docs/)
- [OpenAI API](https://platform.openai.com/docs)
- [Telegram Bot API](https://core.telegram.org/bots/api)

### Comunidad

- [n8n Community](https://community.n8n.io/)
- [Reddit r/n8n](https://reddit.com/r/n8n)

---

## 🐛 Troubleshooting común

### Error: "Tool not found"
**Causa:** El AI Agent no encuentra la tool configurada  
**Solución:** Verificar que el nombre de la tool coincida exactamente

### Error: "Invalid date format"
**Causa:** La fecha no está en formato YYYY-MM-DD  
**Solución:** Verificar parser de fechas

### Error: "Duplicate key violation"
**Causa:** Intentando insertar un gasto que ya existe  
**Solución:** ON CONFLICT DO NOTHING debería manejarlo automáticamente

### Error: "Google Sheets quota exceeded"
**Causa:** Demasiadas peticiones a Google API  
**Solución:** Usar batch operations y respetar límites

### Error: "OpenAI API rate limit"
**Causa:** Demasiadas peticiones a OpenAI  
**Solución:** Implementar retry con backoff exponencial

---

> **¡Felicitaciones!** 🎉 Has completado la Fase 2. Tu sistema ahora puede registrar gastos de forma inteligente y mantener tus finanzas sincronizadas automáticamente.
