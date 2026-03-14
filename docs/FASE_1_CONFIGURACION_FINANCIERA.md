# 🎓 Fase 1 — Configuración Financiera (Guía de Aprendizaje)

> ⚠️ **Decisión arquitectural actualizada:** El enfoque de comandos rígidos con `/split` fue reemplazado por **conversación natural con LLM**. Ver sección "Arquitectura LLM" más abajo. El único comando fijo que se mantiene es `/start`.

En esta fase vas a construir tu primer workflow real en n8n. Al terminar, podrás **hablarle naturalmente** al bot y él decidirá qué hacer — exactamente como ChatGPT pero para tus finanzas.

---

## 🧠 ¿Qué vas a aprender?

1. **Qué es un workflow en n8n** y cómo se estructura
2. **Qué es un Trigger** y por qué es el punto de entrada de todo flujo
3. **Cómo conectar n8n con Telegram, PostgreSQL y OpenAI** (credenciales)
4. **Cómo usar el nodo AI Agent de n8n** para análisis de intención
5. **Qué es un "system prompt"** y cómo instruir al LLM para tu caso de negocio
6. **Cómo conectar LLM + BD** para que el bot actúe sobre los datos
7. **Qué son las "tools" del AI Agent** y cómo definirlas

---

## 📐 Arquitectura con LLM (conversación natural)

### ¿Por qué no usar comandos `/split`?

El enfoque con `split(' ')` obliga al usuario a recordar sintaxis exacta:
- `/fijo netflix 30000` → ¿y si escribe `/fijo 30000 netflix`? Falla.
- `/sueldo cinco millones` → No entiende texto.
- No es conversacional ni amigable.

### La nueva arquitectura

```
Usuario escribe EN LENGUAJE NATURAL en Telegram
  "mi sueldo es 5 millones"
  "agrega netflix por 30 mil fijo mensual"
  "gasté 18 mil en almuerzo hoy"
        │
        ▼
  n8n recibe el mensaje (Telegram Trigger)
        │
        ├── ¿Es /start? ─► Registro en BD + mensaje bienvenida
        │
        └── ¿Cualquier otro texto? ─►  [AI Agent (LLM)]
                                              │
                                     Analiza la intención:
                                     ¿Configurar sueldo?
                                     ¿Agregar gasto fijo?
                                     ¿Registrar gasto diario?
                                     ¿Actualizar saldo banco?
                                     ¿Pedir resumen?
                                              │
                                     Extrae los datos relevantes
                                     (monto, nombre, categoría, fecha)
                                              │
                                     Llama a la "herramienta" correcta
                                     (nodo PostgreSQL correspondiente)
                                              │
                                     Genera respuesta natural
                                              │
                                        ▼
                               Telegram responde al usuario
```

### ¿Qué es el "AI Agent" de n8n?

n8n tiene un nodo nativo llamado **AI Agent** que conecta un LLM (OpenAI, Anthropic, Gemini, etc.) con **herramientas** (tools). Las herramientas son acciones que el LLM puede decidir ejecutar según la conversación.

Es el mismo concepto detrás de ChatGPT con plugins o Claude con tools.

```
LLM = el cerebro que entiende el lenguaje
Tools = las acciones que puede ejecutar (leer BD, escribir BD, calcular)
```

El flujo interno del AI Agent es:
1. Recibe el mensaje del usuario
2. Lee el system prompt (tus instrucciones de negocio)
3. Decide qué tool usar
4. Ejecuta la tool (query a PostgreSQL, por ejemplo)
5. Procesa el resultado
6. Genera una respuesta en lenguaje natural

---

## Paso 1 — Credenciales (actualizado)

Ahora necesitas **3 credenciales** en vez de 2:

### 1a. Telegram (igual que antes)
- Tipo: Telegram
- Token: el de BotFather

### 1b. PostgreSQL (igual que antes)
- Host: `postgres` (nombre del servicio docker)
- Database: `finanzas_db`
- User/Password: los de tu `.env`

### 1c. OpenAI (nueva)
1. Ve a https://platform.openai.com/api-keys
2. Crea una API key
3. En n8n → Credentials → Add → busca **"OpenAI"**
4. Pega tu API key
5. Nómbrala `OpenAI Finanzas`

> 💡 **¿Puedo usar otro LLM?**
> Sí. n8n soporta también Anthropic (Claude), Google Gemini, y modelos locales (Ollama). Para portafolio, OpenAI GPT-4o-mini es la opción más económica y confiable. Cuesta centavos por conversación.

---

## Paso 2 — Estructura del workflow

El workflow `bot_finanzas_principal` ahora tiene 2 ramas simples:

```
[Telegram Trigger]
        │
        ▼
  [IF: ¿es /start?]
        │
        ├── SÍ ─► [Postgres: buscar usuario] ─► [IF existe?]
        │                                            ├─ NO ─► [Crear user + perfil] ─► [Telegram: Bienvenida]
        │                                            └─ SÍ ─► [Telegram: Ya registrado]
        │
        └── NO ─► [AI Agent] ─► [Telegram: respuesta del agente]
```

Mucho más limpio. El AI Agent absorbe TODA la lógica de intención.

---

## Paso 3 — El nodo AI Agent: configuración

### 3a. Agrega el nodo

1. Arrastra un nodo **"AI Agent"** al canvas
2. Conéctalo a la salida "NO" del IF de /start

### 3b. Configura el modelo

- Dentro del AI Agent, agrega un nodo **"OpenAI Chat Model"** como sub-nodo
- Model: `gpt-4o-mini` (barato y muy bueno para tareas estructuradas)
- Credencial: `OpenAI Finanzas`

### 3c. El System Prompt — la parte más importante

El **system prompt** es el conjunto de instrucciones que le das al LLM para que sepa quién es, qué puede hacer y cómo comportarse. Es literalmente la "personalidad y reglas" del agente.

Para nuestro bot, el system prompt debe decirle:
- Que es un asistente financiero personal
- Qué tipos de intención existe (configurar sueldo, registrar gasto, etc.)
- Qué datos debe extraer de cada intención
- Cómo responder (tono, idioma, formato)
- Qué hacer si no entiende el mensaje

Ejemplo de system prompt (tú lo escribes en el campo "System Message" del AI Agent):

```
Eres un asistente financiero personal para {{ $('Telegram Trigger').item.json.message.chat.first_name }}.

El usuario tiene un chat_id de Telegram: {{ $('Telegram Trigger').item.json.message.chat.id }}

Tu rol es ayudarle a gestionar sus finanzas personales. Puedes:
1. Configurar su sueldo mensual
2. Registrar o actualizar gastos fijos (Netflix, arriendo, gym, etc.)
3. Registrar gastos variables del día (almuerzo, transporte, etc.)
4. Actualizar su saldo real del banco
5. Mostrar resumen del mes

Reglas:
- Siempre responde en español, de forma concisa y amigable
- Usa emojis para hacer la conversación más visual 💰
- Si el usuario menciona un monto con palabras ("cinco millones", "30 mil"), conviértelo a número
- Si el mensaje no es sobre finanzas, responde amablemente que solo puedes ayudar con finanzas
- Confirma siempre lo que hiciste con los datos exactos que guardaste
```

### 3d. Las Tools (herramientas del agente)

Las tools son las acciones que el LLM puede ejecutar. En n8n AI Agent, se agregan como nodos conectados al agente. Cada tool tiene:
- **Nombre**: lo que el LLM ve para decidir cuándo usarla
- **Descripción**: explicación de para qué sirve y qué datos necesita
- **Implementación**: el nodo real (PostgreSQL query, cálculo, etc.)

Para esta fase, necesitas estas tools:

| Tool | Cuándo el LLM la usa | Qué hace |
|------|----------------------|----------|
| `actualizar_sueldo` | "mi sueldo es X", "gano X mensual" | UPDATE finance_profiles SET sueldo_mensual |
| `agregar_gasto_fijo` | "agrega X fijo por Y", "netflix cuesta Z" | UPSERT fixed_expenses |
| `actualizar_saldo_banco` | "tengo X en el banco", "mi saldo es X" | UPDATE finance_profiles SET saldo_real |
| `obtener_resumen` | "resumen", "cómo voy", "cuánto tengo" | SELECT snapshot del mes |

Cada tool en n8n se configura como un **"Call n8n Workflow" tool** o directamente como un **"PostgreSQL" tool** (n8n tiene soporte nativo para tools de BD).

---

## Paso 4 — Configurar cada Tool

### Tool 1: `actualizar_sueldo`

- **Nombre en el agente**: `actualizar_sueldo`
- **Descripción** (esto lo lee el LLM para decidir cuándo usarla):
  ```
  Usa esta herramienta cuando el usuario quiera configurar o actualizar su sueldo mensual.
  Parámetros requeridos: monto (número, en COP)
  ```
- **Query SQL**:
  ```sql
  UPDATE finance_profiles
  SET sueldo_mensual = $1, updated_at = NOW()
  WHERE user_id = (SELECT id FROM users WHERE chat_id = '$2');
  ```
  El LLM extrae el monto del mensaje natural y lo pasa como parámetro.

### Tool 2: `agregar_gasto_fijo`

- **Descripción**:
  ```
  Usa cuando el usuario quiera agregar o actualizar un gasto fijo recurrente
  (servicios, suscripciones, arriendo, etc.).
  Parámetros: nombre (string), valor (número COP), categoria (string, opcional)
  ```
- **Query SQL** (UPSERT):
  ```sql
  INSERT INTO fixed_expenses (user_id, nombre, valor, categoria)
  VALUES (
    (SELECT id FROM users WHERE chat_id = '$chat_id'),
    '$nombre', $valor, '$categoria'
  )
  ON CONFLICT (user_id, nombre)
  DO UPDATE SET valor = $valor, updated_at = NOW();
  ```

### Tool 3: `actualizar_saldo_banco`

- Similar a actualizar_sueldo pero actualiza `saldo_real`

### Tool 4: `obtener_resumen`

- **Query SQL**:
  ```sql
  SELECT
    fp.sueldo_mensual,
    fp.saldo_real,
    COALESCE(SUM(fe.valor), 0) AS total_fijos,
    COALESCE((
      SELECT SUM(valor) FROM expense_entries
      WHERE user_id = fp.user_id
        AND DATE_TRUNC('month', fecha_gasto) = DATE_TRUNC('month', NOW())
    ), 0) AS total_variables
  FROM finance_profiles fp
  LEFT JOIN fixed_expenses fe ON fe.user_id = fp.user_id AND fe.activo = TRUE
  WHERE fp.user_id = (SELECT id FROM users WHERE chat_id = '$chat_id')
  GROUP BY fp.sueldo_mensual, fp.saldo_real, fp.user_id;
  ```
  El LLM recibe estos datos y genera un resumen legible en lenguaje natural.

---

## Paso 5 — Memoria de conversación (opcional pero recomendado)

El AI Agent puede tener **memoria** para mantener contexto entre mensajes.

Por ejemplo, si el usuario dice:
- "agrega netflix"
- El bot responde: "¿cuánto cuesta?"
- El usuario responde: "30 mil"

Sin memoria, el segundo mensaje llega sin contexto. Con memoria, el agente recuerda que estaba hablando de netflix.

En n8n, agrega un nodo **"Window Buffer Memory"** al AI Agent:
- Window Size: `10` (últimos 10 mensajes de contexto)
- Session ID: `{{ $('Telegram Trigger').item.json.message.chat.id }}`

Usar el `chat.id` como session ID garantiza que cada usuario tenga su propia memoria de conversación.

---

## Paso 6 — Probar el agente

Con el workflow activo, prueba estos mensajes en Telegram:

| Lo que escribes | Lo que debe hacer el agente |
|-----------------|----------------------------|
| `mi sueldo es 5 millones` | Actualiza sueldo a 5.000.000 y confirma |
| `agrega netflix, cuesta 30 mil al mes` | Crea gasto fijo Netflix 30.000 |
| `el arriendo me cuesta 1.2 millones` | Crea gasto fijo Arriendo 1.200.000 |
| `tengo 3 millones en el banco` | Actualiza saldo_real a 3.000.000 |
| `cómo voy este mes?` | Muestra resumen con cálculos |
| `cuánto gasto en fijos?` | Suma gastos fijos y responde |

---

## ✅ Checklist actualizado Fase 1

- [ ] Credencial OpenAI creada
- [ ] Credencial Telegram creada  
- [ ] Credencial PostgreSQL creada y test OK
- [ ] `/start` funciona: registra usuario y responde bienvenida ✅ (ya lo tienes)
- [ ] AI Agent configurado con system prompt
- [ ] Tool `actualizar_sueldo` funciona
- [ ] Tool `agregar_gasto_fijo` funciona (con UPSERT)
- [ ] Tool `actualizar_saldo_banco` funciona
- [ ] Tool `obtener_resumen` funciona
- [ ] Memoria de conversación configurada
- [ ] Workflow exportado en `workflows/bot_finanzas_principal.json`

---

## 🧠 Conceptos que aprendiste (versión LLM)

| Concepto | Qué es |
|----------|--------|
| **AI Agent** | Nodo de n8n que conecta un LLM con herramientas ejecutables |
| **System Prompt** | Instrucciones que definen el comportamiento y rol del LLM |
| **Tools / Herramientas** | Acciones que el LLM puede decidir ejecutar (BD, APIs, etc.) |
| **Intent detection** | El LLM infiere qué quiere hacer el usuario sin sintaxis rígida |
| **Entity extraction** | El LLM extrae datos estructurados (monto, nombre) del texto libre |
| **Window Buffer Memory** | Memoria de conversación con ventana deslizante de N mensajes |
| **Session ID** | Identificador para separar la memoria de cada usuario |

---

> **Cuando termines el checklist**, avísame y pasamos a la **Fase 2: Registro de gastos diarios** — donde el bot entiende mensajes como *"almuerzo 18k, uber 12k y café 9k"* y los guarda todos de una. 🚀

---

## Paso 1 — Configurar credenciales en n8n

### ¿Qué son las credenciales en n8n?

Las credenciales son las "llaves" que n8n necesita para conectarse a servicios externos. Se configuran UNA vez y luego las reutilizas en todos los workflows.

n8n las guarda **cifradas** en su base de datos interna. Nunca se exponen en los workflows exportados.

### 1a. Credencial de Telegram

1. En n8n, ve al menú izquierdo → **Credentials** (ícono de llave 🔑)
2. Click en **"Add Credential"**
3. Busca **"Telegram"** y selecciónalo
4. En el campo **"Access Token"**, pega el token que te dio BotFather
5. Click en **"Save"**
6. Dale un nombre descriptivo como `Telegram Finanzas Bot`

**¿Por qué?** Este token es lo que le permite a n8n enviar y recibir mensajes como si fuera tu bot. Sin esto, n8n no puede comunicarse con Telegram.

### 1b. Credencial de PostgreSQL

1. En **Credentials** → **"Add Credential"**
2. Busca **"Postgres"** y selecciónalo
3. Llena así:

   | Campo | Valor | Explicación |
   |-------|-------|-------------|
   | Host | `postgres` | Es el nombre del servicio en docker-compose, NO `localhost`. Dentro de Docker los servicios se ven por nombre |
   | Database | `finanzas_db` | O el valor que pusiste en `POSTGRES_DB` en tu `.env` |
   | User | `finanzas_user` | O el valor de `POSTGRES_USER` |
   | Password | (tu contraseña) | El valor de `POSTGRES_PASSWORD` |
   | Port | `5432` | Puerto por defecto de PostgreSQL |
   | SSL | Desactivado | No necesitamos SSL en desarrollo local |

4. Click en **"Test Connection"** — debe decir **"Connection successful"**
5. **Save** y dale nombre: `PostgreSQL Finanzas`

**¿Por qué el host es `postgres` y no `localhost`?**
Porque n8n y PostgreSQL corren en contenedores Docker separados. Docker les crea una red interna donde se identifican por el nombre del servicio definido en `docker-compose.yml`. Desde el punto de vista de n8n, PostgreSQL "vive" en un host llamado `postgres`.

---

## Paso 2 — Crear el workflow

1. Ve a **Workflows** (menú izquierdo)
2. Click en **"Add Workflow"**
3. Nómbralo: **`bot_finanzas_principal`**

Ahora tienes un canvas vacío. Aquí vas a arrastrar y conectar nodos.

---

## Paso 3 — Nodo Trigger (punto de entrada)

### ¿Qué es un Trigger?

Es el nodo que **inicia** el workflow. Sin trigger, el workflow no se ejecuta nunca. Existen muchos tipos: webhook, cron, email, etc.

Para nuestro caso usamos el **Telegram Trigger**, que se activa cada vez que alguien le envía un mensaje al bot.

### Cómo crearlo

1. Click en el **"+"** del canvas
2. Busca **"Telegram Trigger"** (NO "Telegram" a secas, ese es para enviar, no recibir)
3. Configúralo así:

   | Campo | Valor | Explicación |
   |-------|-------|-------------|
   | Credential | `Telegram Finanzas Bot` | La credencial que creaste en paso 1a |
   | Updates | `message` | Queremos recibir mensajes de texto |

4. **Save** el nodo

### ¿Qué datos produce este nodo?

Cuando alguien escribe al bot, este nodo genera un JSON con información como:

```json
{
  "message": {
    "text": "/sueldo 5000000",
    "chat": {
      "id": 123456789,
      "first_name": "Tu Nombre"
    },
    "date": 1709424000
  }
}
```

Lo importante es:
- `message.text` → el texto que escribió el usuario
- `message.chat.id` → el identificador único del chat (lo usamos para identificar al usuario en la BD)
- `message.chat.first_name` → el nombre del usuario

---

## Paso 4 — Nodo Switch (enrutador de comandos)

### ¿Qué es un Switch?

Es un nodo que evalúa condiciones y envía los datos por diferentes "caminos" según el resultado. Es como un `if/else if/else` en programación.

### Cómo crearlo

1. Agrega un nodo **"Switch"**
2. Conéctalo al Telegram Trigger (arrastra la línea)
3. Configura las reglas (Rules). El valor a evaluar es:

   ```
   {{ $json.message.text }}
   ```

   Esto es una **expresión n8n**. El `$json` se refiere a los datos que llegan del nodo anterior. Estamos accediendo al texto del mensaje.

4. Crea estas reglas:

   | Regla # | Operación | Valor | Salida (Output Name) |
   |---------|-----------|-------|----------------------|
   | 1 | Starts With | `/start` | start |
   | 2 | Starts With | `/sueldo` | sueldo |
   | 3 | Starts With | `/fijo` | fijo |
   | 4 | Starts With | `/banco` | banco |
   | Fallback | (se activa si ninguna regla coincide) | — | desconocido |

5. Activa la opción **"Fallback Output"** para que los mensajes que no coincidan con nada vayan a una salida por defecto.

**¿Por qué "Starts With" y no "Equals"?**
Porque los comandos llevan parámetros: `/sueldo 5000000` empieza con `/sueldo` pero no es igual a `/sueldo`. Con "Starts With" capturamos el comando sin importar lo que venga después.

---

## Paso 5 — Rama `/start` (registro de usuario)

### ¿Qué debe pasar?

Cuando alguien escribe `/start`, debemos:
1. Verificar si el usuario ya existe en la BD
2. Si no existe, crearlo
3. Responder con un mensaje de bienvenida

### Nodos necesarios

**5a. Nodo PostgreSQL — "Buscar Usuario"**
1. Agrega un nodo **"Postgres"**
2. Credencial: `PostgreSQL Finanzas`
3. Operation: **Execute Query**
4. Query:

   ```sql
   SELECT id, nombre FROM users WHERE chat_id = '{{ $('Telegram Trigger').item.json.message.chat.id }}';
   ```

   **¿Qué hace?** Busca si ya existe un usuario con ese chat_id en la tabla `users`.

**5b. Nodo IF — "¿Usuario existe?"**
1. Agrega un nodo **"IF"**
2. Condición: verificar si el query anterior devolvió resultados
   - Value 1: `{{ $json.length }}` (o la cantidad de filas del resultado)
   - Operation: `Equal`
   - Value 2: `0`
   - Si es 0 → el usuario NO existe → rama TRUE para crearlo
   - Si no → ya existe → rama FALSE para solo saludar

**5c. Nodo PostgreSQL — "Crear Usuario" (rama TRUE del IF)**
1. Agrega otro nodo **"Postgres"**
2. Operation: **Execute Query**
3. Query:

   ```sql
   INSERT INTO users (chat_id, canal, nombre)
   VALUES (
     '{{ $('Telegram Trigger').item.json.message.chat.id }}',
     'telegram',
     '{{ $('Telegram Trigger').item.json.message.chat.first_name }}'
   )
   RETURNING id;
   ```

   Al crearse el usuario, también necesitas crear su perfil financiero:

   ```sql
   INSERT INTO finance_profiles (user_id, sueldo_mensual, saldo_real)
   VALUES (
     (SELECT id FROM users WHERE chat_id = '{{ $('Telegram Trigger').item.json.message.chat.id }}'),
     0,
     0
   );
   ```

   Puedes hacerlo en 2 nodos Postgres separados o en una sola query con `;` — como te resulte más claro.

**5d. Nodo Telegram — "Responder Bienvenida"**
1. Agrega un nodo **"Telegram"** (NO el Trigger, sino el de enviar)
2. Credencial: `Telegram Finanzas Bot`
3. Operation: **Send Message**
4. Chat ID: `{{ $('Telegram Trigger').item.json.message.chat.id }}`
5. Text:

   ```
   ¡Bienvenido a tu agente de finanzas! 💰

   Comandos disponibles:
   /sueldo <monto> — Configurar tu sueldo mensual
   /fijo <nombre> <monto> — Agregar gasto fijo
   /banco <monto> — Actualizar saldo real del banco
   /resumen — Ver resumen del mes
   ```

---

## Paso 6 — Rama `/sueldo` (configurar sueldo)

### ¿Qué debe pasar?

El usuario escribe algo como `/sueldo 5000000`. Debemos:
1. Extraer el monto del texto
2. Actualizar el campo `sueldo_mensual` en `finance_profiles`
3. Responder con confirmación

### Nodos necesarios

**6a. Nodo Code (Function) — "Extraer Monto"**
1. Agrega un nodo **"Code"** (antes se llamaba "Function")
2. Lenguaje: JavaScript
3. Código:

   ```javascript
   const texto = $input.first().json.message.text;
   const partes = texto.split(' ');
   const monto = parseFloat(partes[1]) || 0;
   const chatId = $input.first().json.message.chat.id;

   return [{ json: { monto, chatId, textoOriginal: texto } }];
   ```

   **¿Qué hace?** Toma el texto `/sueldo 5000000`, lo divide por espacios, y extrae el segundo elemento como número. Este es un parser muy básico que iremos mejorando.

**6b. Nodo IF — "¿Monto válido?"**
- Condición: `{{ $json.monto }}` > 0
- Si es inválido (0 o negativo), respondemos con error

**6c. Nodo PostgreSQL — "Actualizar Sueldo"**
- Operation: Execute Query
- Query:

  ```sql
  UPDATE finance_profiles
  SET sueldo_mensual = {{ $json.monto }}
  WHERE user_id = (SELECT id FROM users WHERE chat_id = '{{ $json.chatId }}');
  ```

**6d. Nodo Telegram — "Confirmar Sueldo"**
- Chat ID: `{{ $json.chatId }}`
- Text: `✅ Sueldo actualizado a ${{ $json.monto.toLocaleString() }} COP`

---

## Paso 7 — Rama `/fijo` (agregar gasto fijo)

### Formato esperado: `/fijo netflix 30000`

**7a. Nodo Code — "Extraer Nombre y Monto"**

```javascript
const texto = $input.first().json.message.text;
const partes = texto.split(' ');
// /fijo <nombre> <monto>
const nombre = partes[1] || '';
const monto = parseFloat(partes[2]) || 0;
const chatId = $input.first().json.message.chat.id;

return [{ json: { nombre, monto, chatId } }];
```

**7b. Nodo IF — Validar que nombre no esté vacío y monto > 0**

**7c. Nodo PostgreSQL — "Upsert Gasto Fijo"**

```sql
INSERT INTO fixed_expenses (user_id, nombre, valor)
VALUES (
  (SELECT id FROM users WHERE chat_id = '{{ $json.chatId }}'),
  '{{ $json.nombre }}',
  {{ $json.monto }}
)
ON CONFLICT (user_id, nombre)
DO UPDATE SET valor = {{ $json.monto }}, updated_at = NOW();
```

**¿Qué es UPSERT (ON CONFLICT)?**
Es una de las features más potentes de PostgreSQL. Significa: "intenta insertar, pero si ya existe un registro con ese `user_id` + `nombre` (nuestra constraint única), entonces actualiza el valor en vez de fallar". Así puedes usar el mismo comando para crear Y actualizar gastos fijos.

**7d. Nodo Telegram — Confirmar**

---

## Paso 8 — Rama `/banco` (actualizar saldo real)

### Formato esperado: `/banco 3200000`

Misma lógica que `/sueldo`:
1. Extraer monto
2. Validar
3. Actualizar `saldo_real` en `finance_profiles`
4. Responder confirmación

Query de actualización:

```sql
UPDATE finance_profiles
SET saldo_real = {{ $json.monto }}
WHERE user_id = (SELECT id FROM users WHERE chat_id = '{{ $json.chatId }}');
```

---

## Paso 9 — Rama Fallback (comando no reconocido)

Un solo nodo **Telegram** que responda:

```
❓ Comando no reconocido.

Comandos disponibles:
/sueldo <monto>
/fijo <nombre> <monto>
/banco <monto>
/resumen
```

---

## Paso 10 — Activar el workflow

### ¿Qué significa "activar"?

Un workflow en n8n puede estar en 2 estados:
- **Inactivo** (default): solo se ejecuta si lo corres manualmente desde el editor
- **Activo**: se ejecuta automáticamente cada vez que llega un evento (en nuestro caso, un mensaje de Telegram)

1. En la esquina superior derecha del workflow, hay un toggle **"Active"**
2. Actívalo → n8n empieza a escuchar mensajes de tu bot en tiempo real

### Probar

1. Abre Telegram
2. Busca tu bot por el username que le pusiste
3. Envía `/start`
4. Deberías recibir el mensaje de bienvenida
5. Envía `/sueldo 5000000`
6. Deberías recibir confirmación
7. Envía `/fijo netflix 30000`
8. Deberías recibir confirmación

### Verificar en la BD

```bash
docker compose exec postgres psql -U finanzas_user -d finanzas_db
```

Y dentro de psql:

```sql
SELECT * FROM users;
SELECT * FROM finance_profiles;
SELECT * FROM fixed_expenses;
```

Deberías ver tus datos recién creados.

---

## 🏗️ Resumen de la arquitectura del workflow

```
[Telegram Trigger]
        │
    [Switch] ── evalúa $json.message.text
        │
        ├── /start ──► [Buscar Usuario] ► [IF existe?]
        │                                     ├─ NO ► [Crear Usuario] ► [Crear Perfil] ► [Responder Bienvenida]
        │                                     └─ SÍ ► [Responder Bienvenida]
        │
        ├── /sueldo ► [Extraer Monto] ► [IF válido?]
        │                                  ├─ SÍ ► [UPDATE sueldo] ► [Confirmar]
        │                                  └─ NO ► [Responder Error]
        │
        ├── /fijo ──► [Extraer Nombre+Monto] ► [IF válido?]
        │                                        ├─ SÍ ► [UPSERT gasto fijo] ► [Confirmar]
        │                                        └─ NO ► [Responder Error]
        │
        ├── /banco ─► [Extraer Monto] ► [IF válido?]
        │                                 ├─ SÍ ► [UPDATE saldo_real] ► [Confirmar]
        │                                 └─ NO ► [Responder Error]
        │
        └── fallback ► [Responder "comando no reconocido"]
```

---

## 🧠 Conceptos clave que aprendiste

| Concepto | Qué es |
|----------|--------|
| **Trigger** | Nodo que inicia un workflow cuando ocurre un evento externo |
| **Switch** | Enrutador condicional (equivale a if/else if/else) |
| **Expresiones n8n** | `{{ $json.campo }}` para acceder a datos entre nodos |
| **Code Node** | JavaScript personalizado para transformar datos |
| **UPSERT** | INSERT + UPDATE en una sola query (ON CONFLICT) |
| **Credenciales n8n** | Conexiones cifradas a servicios externos |
| **Activar workflow** | Pasar de modo manual a ejecución automática |

---

## ✅ Checklist de cierre Fase 1

- [ ] Credencial Telegram creada y funcionando
- [ ] Credencial PostgreSQL creada y test exitoso
- [ ] Workflow `bot_finanzas_principal` creado
- [ ] `/start` registra usuario en BD y responde bienvenida
- [ ] `/sueldo 5000000` actualiza sueldo y confirma
- [ ] `/fijo netflix 30000` crea/actualiza gasto fijo y confirma
- [ ] `/banco 3200000` actualiza saldo real y confirma
- [ ] Mensaje random responde "comando no reconocido"
- [ ] Datos verificados en PostgreSQL con queries directos
- [ ] Workflow exportado como JSON en `workflows/bot_finanzas_principal.json`

### Cómo exportar el workflow

1. Dentro del workflow, click en los **3 puntos** (menú) arriba
2. **Download** → te descarga un `.json`
3. Guárdalo en `workflows/bot_finanzas_principal.json`

Esto es importante para:
- Tener backup del workflow
- Poder importarlo si recreas n8n
- Mostrar el código en tu portafolio de GitHub

---

> **Cuando tengas el checklist completo**, avísame y pasamos a la **Fase 2: Registro de gastos diarios** donde el bot entenderá mensajes como "almuerzo 18000" y "uber 12000 y café 9000". 🚀
