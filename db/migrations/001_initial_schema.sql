-- ============================================================
-- Migración 001 — Esquema inicial de finanzas personales
-- ============================================================
-- Este archivo se ejecuta automáticamente cuando PostgreSQL
-- se inicia por primera vez (docker-entrypoint-initdb.d).
--
-- Principios de diseño:
--   1. BD es fuente de verdad (Google Sheets es solo reporte)
--   2. Cada tabla tiene created_at/updated_at para auditoría
--   3. UUIDs como PK para evitar colisiones y ser más seguros
--   4. Constraints explícitos para integridad de datos
-- ============================================================

-- Extensión para generar UUIDs automáticamente
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------
-- 1. USERS — Usuarios del bot
-- ----------------------------------------------------------
-- Un usuario = una persona que interactúa con el bot.
-- El chat_id es el identificador único de Telegram/WhatsApp.
-- ----------------------------------------------------------
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chat_id     VARCHAR(100) NOT NULL UNIQUE,
    canal       VARCHAR(20)  NOT NULL DEFAULT 'telegram'
                CHECK (canal IN ('telegram', 'whatsapp')),
    nombre      VARCHAR(200),
    timezone    VARCHAR(50)  NOT NULL DEFAULT 'America/Bogota',
    moneda      VARCHAR(10)  NOT NULL DEFAULT 'COP',
    activo      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Índice para buscar usuario por chat_id rápidamente
CREATE INDEX idx_users_chat_id ON users(chat_id);

-- ----------------------------------------------------------
-- 2. FINANCE_PROFILES — Perfil financiero del usuario
-- ----------------------------------------------------------
-- Almacena la configuración financiera "estable":
--   - Sueldo mensual (no cambia muy seguido)
--   - Saldo real reportado del banco
--   - Mes de referencia activo
--
-- ¿Por qué separar de users?
--   Porque el perfil financiero puede cambiar
--   independientemente de los datos del bot.
-- ----------------------------------------------------------
CREATE TABLE finance_profiles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sueldo_mensual  NUMERIC(15, 2) NOT NULL DEFAULT 0,
    saldo_real      NUMERIC(15, 2) NOT NULL DEFAULT 0,
    mes_referencia  VARCHAR(7) NOT NULL DEFAULT TO_CHAR(NOW(), 'YYYY-MM'),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Un solo perfil activo por usuario
    CONSTRAINT uq_finance_profile_user UNIQUE (user_id)
);

-- ----------------------------------------------------------
-- 3. FIXED_EXPENSES — Gastos fijos configurados
-- ----------------------------------------------------------
-- Son los gastos que se repiten cada mes y rara vez cambian:
--   Netflix, arriendo, internet, gimnasio, etc.
--
-- Se configuran una vez y se cargan automáticamente
-- en cada hoja mensual nueva.
-- ----------------------------------------------------------
CREATE TABLE fixed_expenses (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    nombre      VARCHAR(200) NOT NULL,
    valor       NUMERIC(15, 2) NOT NULL CHECK (valor >= 0),
    categoria   VARCHAR(100) DEFAULT 'General',
    frecuencia  VARCHAR(20) NOT NULL DEFAULT 'mensual'
                CHECK (frecuencia IN ('mensual', 'quincenal', 'semanal')),
    dia_cargo   SMALLINT CHECK (dia_cargo IS NULL OR (dia_cargo >= 1 AND dia_cargo <= 31)),
    activo      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- No duplicar el mismo gasto fijo por nombre para un usuario
    CONSTRAINT uq_fixed_expense_name UNIQUE (user_id, nombre)
);

CREATE INDEX idx_fixed_expenses_user ON fixed_expenses(user_id, activo);

-- ----------------------------------------------------------
-- 4. EXPENSE_ENTRIES — Gastos variables del día a día
-- ----------------------------------------------------------
-- Cada vez que dices "almuerzo 18000" en el bot,
-- se crea un registro aquí con la fecha, concepto y monto.
--
-- El campo `origen` indica de dónde vino el registro:
--   - 'bot': registrado por mensaje del bot
--   - 'manual': registrado desde algún otro medio
--   - 'ajuste': corrección manual
-- ----------------------------------------------------------
CREATE TABLE expense_entries (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fecha_gasto     DATE NOT NULL DEFAULT CURRENT_DATE,
    concepto        VARCHAR(300) NOT NULL,
    categoria       VARCHAR(100) DEFAULT 'General',
    valor           NUMERIC(15, 2) NOT NULL CHECK (valor > 0),
    origen          VARCHAR(20) NOT NULL DEFAULT 'bot'
                    CHECK (origen IN ('bot', 'manual', 'ajuste')),
    mensaje_fuente  TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice compuesto para consultas del mes en curso
CREATE INDEX idx_expense_entries_user_fecha
    ON expense_entries(user_id, fecha_gasto DESC);

-- ----------------------------------------------------------
-- 5. INCOME_ENTRIES — Ingresos extra del mes
-- ----------------------------------------------------------
-- Para registrar ingresos adicionales al sueldo:
--   bonos, freelance, devoluciones, etc.
-- ----------------------------------------------------------
CREATE TABLE income_entries (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fecha       DATE NOT NULL DEFAULT CURRENT_DATE,
    concepto    VARCHAR(300) NOT NULL,
    valor       NUMERIC(15, 2) NOT NULL CHECK (valor > 0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_income_entries_user_fecha
    ON income_entries(user_id, fecha DESC);

-- ----------------------------------------------------------
-- 6. MONTHLY_SNAPSHOTS — Resumen mensual calculado
-- ----------------------------------------------------------
-- Cada vez que se recalcula, se actualiza este registro.
-- Guarda los totales y la comparación saldo real vs proyectado.
--
-- Fórmula clave:
--   saldo_proyectado = saldo_inicio + ingresos - fijos - variables
--   diferencia = saldo_real - saldo_proyectado
-- ----------------------------------------------------------
CREATE TABLE monthly_snapshots (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mes                  VARCHAR(7) NOT NULL,
    saldo_inicio_mes     NUMERIC(15, 2) NOT NULL DEFAULT 0,
    total_ingresos       NUMERIC(15, 2) NOT NULL DEFAULT 0,
    total_ingresos_extra NUMERIC(15, 2) NOT NULL DEFAULT 0,
    total_fijos          NUMERIC(15, 2) NOT NULL DEFAULT 0,
    total_variables      NUMERIC(15, 2) NOT NULL DEFAULT 0,
    saldo_proyectado     NUMERIC(15, 2) NOT NULL DEFAULT 0,
    saldo_real           NUMERIC(15, 2) NOT NULL DEFAULT 0,
    diferencia           NUMERIC(15, 2) NOT NULL DEFAULT 0,
    recalculated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Un solo snapshot por usuario por mes
    CONSTRAINT uq_snapshot_user_mes UNIQUE (user_id, mes)
);

CREATE INDEX idx_snapshots_user_mes ON monthly_snapshots(user_id, mes);

-- ----------------------------------------------------------
-- 7. SYNC_LOGS — Registro de sincronizaciones
-- ----------------------------------------------------------
-- Cada vez que se sincroniza con Google Sheets, se registra
-- si fue exitoso o hubo error. Esto ayuda a:
--   1. Detectar problemas rápidamente
--   2. Evitar duplicados (idempotencia)
--   3. Auditoría de operaciones
-- ----------------------------------------------------------
CREATE TABLE sync_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mes             VARCHAR(7) NOT NULL,
    destino         VARCHAR(50) NOT NULL DEFAULT 'google_sheets'
                    CHECK (destino IN ('google_sheets')),
    estado          VARCHAR(20) NOT NULL
                    CHECK (estado IN ('ok', 'error', 'en_progreso')),
    detalle_error   TEXT,
    filas_escritas   INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sync_logs_user_mes ON sync_logs(user_id, mes, created_at DESC);

-- ----------------------------------------------------------
-- Función auxiliar: actualizar updated_at automáticamente
-- ----------------------------------------------------------
-- Esta función se ejecuta como TRIGGER antes de cada UPDATE.
-- Así nunca olvidamos actualizar el campo updated_at.
-- ----------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para auto-actualizar updated_at
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_finance_profiles_updated_at
    BEFORE UPDATE ON finance_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_fixed_expenses_updated_at
    BEFORE UPDATE ON fixed_expenses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
