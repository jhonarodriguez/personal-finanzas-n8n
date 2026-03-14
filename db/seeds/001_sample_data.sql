-- ============================================================
-- Seed 001 — Datos de ejemplo para desarrollo
-- ============================================================
-- NOTA: Este archivo NO se ejecuta automáticamente.
-- Ejecútalo manualmente cuando quieras datos de prueba:
--
--   docker compose exec postgres psql -U finanzas_user -d finanzas_db \
--     -f /docker-entrypoint-initdb.d/../seeds/001_sample_data.sql
--
-- O desde dentro del contenedor:
--   \i /seeds/001_sample_data.sql
-- ============================================================

-- Usuario de prueba (simula tu chat de Telegram)
INSERT INTO users (id, chat_id, canal, nombre, timezone, moneda)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    '123456789',
    'telegram',
    'Usuario Demo',
    'America/Bogota',
    'COP'
) ON CONFLICT (chat_id) DO NOTHING;

-- Perfil financiero
INSERT INTO finance_profiles (user_id, sueldo_mensual, saldo_real, mes_referencia)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    5000000,
    3500000,
    TO_CHAR(NOW(), 'YYYY-MM')
) ON CONFLICT (user_id) DO NOTHING;

-- Gastos fijos de ejemplo
INSERT INTO fixed_expenses (user_id, nombre, valor, categoria, frecuencia, dia_cargo) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'Arriendo',          1200000, 'Vivienda',         'mensual', 1),
    ('a0000000-0000-0000-0000-000000000001', 'Netflix',           30000,   'Entretenimiento',  'mensual', 15),
    ('a0000000-0000-0000-0000-000000000001', 'YouTube Premium',   23000,   'Entretenimiento',  'mensual', 10),
    ('a0000000-0000-0000-0000-000000000001', 'Google Drive',      5000,    'Entretenimiento',  'mensual', 10),
    ('a0000000-0000-0000-0000-000000000001', 'Internet Movistar', 85000,   'Servicios',        'mensual', 5),
    ('a0000000-0000-0000-0000-000000000001', 'Gas',               45000,   'Servicios',        'mensual', 20),
    ('a0000000-0000-0000-0000-000000000001', 'Gimnasio',          80000,   'Salud',            'mensual', 1),
    ('a0000000-0000-0000-0000-000000000001', 'Mercado Quincenal', 400000,  'Alimentación',     'quincenal', 1),
    ('a0000000-0000-0000-0000-000000000001', 'Game Pass',         45000,   'Entretenimiento',  'mensual', 15)
ON CONFLICT (user_id, nombre) DO NOTHING;

-- Gastos variables de ejemplo (mes actual)
INSERT INTO expense_entries (user_id, fecha_gasto, concepto, categoria, valor, origen) VALUES
    ('a0000000-0000-0000-0000-000000000001', CURRENT_DATE, 'Almuerzo restaurante', 'Alimentación', 18000, 'bot'),
    ('a0000000-0000-0000-0000-000000000001', CURRENT_DATE, 'Uber al trabajo',      'Transporte',   12000, 'bot'),
    ('a0000000-0000-0000-0000-000000000001', CURRENT_DATE - INTERVAL '1 day', 'Café',            'Alimentación', 9000,  'bot'),
    ('a0000000-0000-0000-0000-000000000001', CURRENT_DATE - INTERVAL '2 days', 'Farmacia',       'Salud',        23000, 'bot');
