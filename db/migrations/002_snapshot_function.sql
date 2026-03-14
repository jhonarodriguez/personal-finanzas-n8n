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
  out_mes VARCHAR(7),
  out_saldo_inicio_mes NUMERIC,
  out_total_ingresos NUMERIC,
  out_total_fijos NUMERIC,
  out_total_variables NUMERIC,
  out_saldo_proyectado NUMERIC,
  out_saldo_real NUMERIC,
  out_diferencia NUMERIC
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
    saldo_inicio_mes = EXCLUDED.saldo_inicio_mes,
    total_ingresos = EXCLUDED.total_ingresos,
    total_ingresos_extra = EXCLUDED.total_ingresos_extra,
    total_fijos = EXCLUDED.total_fijos,
    total_variables = EXCLUDED.total_variables,
    saldo_proyectado = EXCLUDED.saldo_proyectado,
    saldo_real = EXCLUDED.saldo_real,
    diferencia = EXCLUDED.diferencia,
    recalculated_at = EXCLUDED.recalculated_at;

  -- 9. Retornar el snapshot actualizado
  RETURN QUERY
  SELECT 
    s.mes::VARCHAR(7) AS out_mes,
    s.saldo_inicio_mes AS out_saldo_inicio_mes,
    s.total_ingresos AS out_total_ingresos,
    s.total_fijos AS out_total_fijos,
    s.total_variables AS out_total_variables,
    s.saldo_proyectado AS out_saldo_proyectado,
    s.saldo_real AS out_saldo_real,
    s.diferencia AS out_diferencia
  FROM monthly_snapshots s
  WHERE s.user_id = p_user_id AND s.mes = p_mes;

END;
$$;

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