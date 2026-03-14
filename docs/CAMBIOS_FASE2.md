# Cambios Fase 2 - Eliminación de Google Sheets

## Fecha: 2026-03-06

## Motivo del cambio
Se eliminó la dependencia de Google Sheets debido a dificultades de manipulación. El sistema ahora trabaja 100% con PostgreSQL como fuente única de verdad.

## Arquitectura anterior (CON Google Sheets)
```
Usuario → Telegram → AI Agent → Parser → PostgreSQL → Google Sheets → Confirmación
```

## Arquitectura nueva (SOLO PostgreSQL)
```
Usuario → Telegram → AI Agent → Parser → PostgreSQL → Confirmación
```

## Cambios principales

### 1. Archivos actualizados

#### `plan-codex.md`
- ✅ Eliminado objetivo #4 (Sincronización a Google Sheets)
- ✅ Eliminado objetivo #5 (Creación automática de hoja mensual)
- ✅ Eliminado componente "Google Sheets" de la arquitectura
- ✅ Agregada sección "Reportes y consultas desde PostgreSQL"
- ✅ Workflow WF-05 cambiado de `sheet_sync_month` a `generate_report`
- ✅ Workflow WF-06 simplificado (ya no crea hojas, solo snapshots)
- ✅ Actualizado sección de entregables (sin plantilla Sheets)

#### `docs/FASE_2_REGISTRO_GASTOS.md`
- ✅ **Eliminados 3 módulos completos**:
  - Módulo 1: Configuración de Google Sheets API (OAuth2, credenciales)
  - Módulo 2: Diseño y creación de la plantilla mensual
  - Módulo 6: Sincronización a Google Sheets
- ✅ **Reducido de 7 a 4 módulos**:
  1. Actualización del AI Agent
  2. Parser avanzado de gastos
  3. Inserción en PostgreSQL
  4. Respuesta de confirmación + Consultas
- ✅ Arquitectura simplificada (sin bloque de Google Sheets)
- ✅ Agregada capacidad de generar reportes desde SQL
- ✅ Documento más corto y enfocado

### 2. TODOs actualizados en BD

#### Eliminados (5 tareas):
- ❌ `configurar-google-api`
- ❌ `crear-credencial-n8n-google`
- ❌ `crear-spreadsheet-plantilla`
- ❌ `disenar-plantilla-mensual`
- ❌ `implementar-sync-sheets`

#### Mantenidos (14 tareas):
- ✅ actualizar-system-prompt
- ✅ crear-tool-registrar-gastos
- ✅ implementar-parser-gastos
- ✅ implementar-categorizador
- ✅ implementar-insert-postgres
- ✅ implementar-respuesta-confirmacion
- ✅ pruebas-un-gasto
- ✅ pruebas-multiples-gastos
- ✅ pruebas-formatos-monto
- ✅ pruebas-categorias
- ✅ pruebas-fechas-pasadas
- ✅ refinamiento-prompts
- ✅ exportar-workflow
- ✅ documentar-fase2

## Ventajas del nuevo enfoque

### ✅ Más simple
- Sin configuración de OAuth2 de Google
- Sin manejo de APIs externas
- Sin sincronización entre sistemas

### ✅ Más rápido
- Menos pasos en el workflow
- No hay llamadas a APIs externas
- Respuestas instantáneas

### ✅ Más confiable
- Una sola fuente de verdad (PostgreSQL)
- No hay problemas de sincronización
- No hay rate limits de Google API

### ✅ Más flexible
- Los reportes se generan dinámicamente desde SQL
- Puedes consultar cualquier dato con queries
- Fácil agregar nuevos comandos

## Lo que mantuviste

### ✅ Funcionalidad core
- Registro de gastos con lenguaje natural
- Múltiples gastos en un mensaje
- Normalización de montos (18k, $18,000, etc.)
- Categorización automática
- Validación y manejo de errores

### ✅ Capacidades nuevas agregadas
- Comandos de consulta (`/resumen`, `/gastos`)
- Reportes dinámicos desde PostgreSQL
- Análisis por categoría
- Historial de meses anteriores
- Exportación opcional (futura)

## Lo que perdiste (y cómo compensarlo)

### ❌ Visualización en hojas de cálculo
**Compensación**: 
- Generar reportes formateados en Telegram con Markdown
- Agregar comando `/exportar` que genere CSV o Excel bajo demanda
- Futura integración con dashboard web (opcional)

### ❌ Fórmulas automáticas de Excel
**Compensación**:
- Todas las fórmulas ahora son queries SQL en PostgreSQL
- Más potentes y flexibles que fórmulas de Excel
- Ejemplo: `SUM(valor) WHERE categoria = 'alimentacion'`

### ❌ Formato visual bonito
**Compensación**:
- Mensajes de Telegram con formato Markdown
- Emojis para categorías (🍽️ 🚗 💊)
- Reportes en texto bien estructurados

## Roadmap futuro (opcional)

Si más adelante quieres agregar visualización:

### Opción 1: Exportación bajo demanda
- Comando `/exportar` que genera un Excel desde PostgreSQL
- Se envía como archivo por Telegram
- No requiere sincronización continua

### Opción 2: Dashboard web simple
- Mini webapp que lee PostgreSQL
- Gráficos con Chart.js o similar
- Más potente que Excel

### Opción 3: Volver a Google Sheets (pero mejor)
- Crear hoja solo cuando el usuario la pida explícitamente
- Sincronización manual, no automática
- Sheet como "foto" del mes cerrado

## Próximos pasos

1. ✅ Continuar con Módulo 1 de `FASE_2_REGISTRO_GASTOS.md`
2. ✅ Implementar el parser de gastos
3. ✅ Implementar INSERT batch en PostgreSQL
4. ✅ Implementar confirmaciones
5. ✅ Probar todo el flujo end-to-end
6. ✅ Agregar comandos de consulta (`/resumen`, `/gastos`)

---

**Resumen**: Simplificaste el sistema eliminando una dependencia externa compleja y ganaste velocidad, simplicidad y confiabilidad. Puedes agregar visualización después si realmente la necesitas.
