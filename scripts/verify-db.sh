#!/bin/bash
# ============================================================
# verify-db.sh — Verifica que la BD esté correctamente creada
# ============================================================
# Uso: bash scripts/verify-db.sh
# ============================================================

echo "=== Verificando conexión a PostgreSQL ==="
docker compose exec -T postgres psql -U finanzas_user -d finanzas_db -c "SELECT version();"

echo ""
echo "=== Tablas creadas ==="
docker compose exec -T postgres psql -U finanzas_user -d finanzas_db -c "
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
"

echo ""
echo "=== Conteo de registros por tabla ==="
docker compose exec -T postgres psql -U finanzas_user -d finanzas_db -c "
SELECT 'users' AS tabla, COUNT(*) FROM users
UNION ALL SELECT 'finance_profiles', COUNT(*) FROM finance_profiles
UNION ALL SELECT 'fixed_expenses', COUNT(*) FROM fixed_expenses
UNION ALL SELECT 'expense_entries', COUNT(*) FROM expense_entries
UNION ALL SELECT 'income_entries', COUNT(*) FROM income_entries
UNION ALL SELECT 'monthly_snapshots', COUNT(*) FROM monthly_snapshots
UNION ALL SELECT 'sync_logs', COUNT(*) FROM sync_logs;
"

echo ""
echo "=== Verificación completada ==="
