-- =====================================================================
-- 03_functions.sql: functions PL/SQL
-- =====================================================================

-- ---------------------------------------------------------------------
-- FUNCTION 1: saldo previsto ate o fim do mes informado
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fun_shas_saldo_previsto (
  p_id_usuario IN shas_usuario.id_usuario%TYPE,
  p_ano        IN NUMBER,
  p_mes        IN NUMBER)
RETURN NUMBER
IS
  v_ini    DATE;
  v_saldo  NUMBER;
  e_mes    EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_mes, -20001);
BEGIN
  IF p_mes NOT BETWEEN 1 AND 12 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Mes invalido: ' || p_mes);
  END IF;

  v_ini := TO_DATE(p_ano || '-' || LPAD(p_mes, 2, '0') || '-01', 'YYYY-MM-DD');

  SELECT NVL(SUM(
           CASE tp_transacao WHEN 'RENDA' THEN 1 ELSE -1 END
           * vl_transacao
           * CASE WHEN fl_recorrente = 'S'
                  THEN MONTHS_BETWEEN(v_ini, TRUNC(dt_transacao, 'MM')) + 1
                  ELSE 1 END), 0)
  INTO   v_saldo
  FROM   shas_transacao
  WHERE  id_usuario = p_id_usuario
  AND    dt_transacao < ADD_MONTHS(v_ini, 1);

  RETURN ROUND(v_saldo, 2);
EXCEPTION
  WHEN e_mes THEN
    RAISE;
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20002, 'Erro no saldo previsto: ' || SQLERRM);
END fun_shas_saldo_previsto;
/

-- ---------------------------------------------------------------------
-- FUNCTION 2: resumo do mes em texto
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fun_shas_resumo_mes (
  p_id_usuario IN shas_usuario.id_usuario%TYPE,
  p_ano        IN NUMBER,
  p_mes        IN NUMBER)
RETURN VARCHAR2
IS
  c_fmt CONSTANT VARCHAR2(30) := 'FM999G999G990D00';
  c_nls CONSTANT VARCHAR2(60) := 'NLS_NUMERIC_CHARACTERS='',.''';
  v_ini      DATE;
  v_rendas   NUMBER;
  v_despesas NUMBER;
BEGIN
  IF p_mes NOT BETWEEN 1 AND 12 THEN
    RETURN 'Mes invalido: ' || p_mes;
  END IF;

  v_ini := TO_DATE(p_ano || '-' || LPAD(p_mes, 2, '0') || '-01', 'YYYY-MM-DD');

  SELECT NVL(SUM(CASE WHEN tp_transacao = 'RENDA'   THEN vl_transacao END), 0),
         NVL(SUM(CASE WHEN tp_transacao = 'DESPESA' THEN vl_transacao END), 0)
  INTO   v_rendas, v_despesas
  FROM   shas_transacao
  WHERE  id_usuario = p_id_usuario
  AND  ( (fl_recorrente = 'N' AND dt_transacao >= v_ini AND dt_transacao < ADD_MONTHS(v_ini, 1))
      OR (fl_recorrente = 'S' AND dt_transacao < ADD_MONTHS(v_ini, 1)) );

  RETURN TO_CHAR(v_ini, 'MM/YYYY')
      || ' | Rendas: R$ '          || TO_CHAR(v_rendas, c_fmt, c_nls)
      || ' | Despesas: R$ '        || TO_CHAR(v_despesas, c_fmt, c_nls)
      || ' | Saldo do mes: R$ '    || TO_CHAR(v_rendas - v_despesas, c_fmt, c_nls)
      || ' | Previsto acumulado: R$ '
      || TO_CHAR(fun_shas_saldo_previsto(p_id_usuario, p_ano, p_mes), c_fmt, c_nls);
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'Erro ao gerar resumo: ' || SQLERRM;
END fun_shas_resumo_mes;
/

-- ---------------------------------------------------------------------
-- FUNCTION 3: progresso de uma meta (0 a 100%)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fun_shas_progresso_meta (
  p_id_meta IN shas_meta.id_meta%TYPE)
RETURN NUMBER
IS
  v_id_usuario shas_meta.id_usuario%TYPE;
  v_alvo       shas_meta.vl_alvo%TYPE;
  v_saldo      NUMBER;
BEGIN
  SELECT id_usuario, vl_alvo
  INTO   v_id_usuario, v_alvo
  FROM   shas_meta
  WHERE  id_meta = p_id_meta;

  v_saldo := fun_shas_saldo_previsto(v_id_usuario,
                                     EXTRACT(YEAR  FROM SYSDATE),
                                     EXTRACT(MONTH FROM SYSDATE));
  RETURN ROUND(GREATEST(0, LEAST(100, v_saldo / v_alvo * 100)), 1);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20040, 'Meta nao encontrada: ' || p_id_meta);
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20041, 'Erro no progresso da meta: ' || SQLERRM);
END fun_shas_progresso_meta;
/

-- ---------------------------------------------------------------------
-- Testes
-- ---------------------------------------------------------------------
SELECT SYSDATE AS data_do_banco FROM dual;

-- uso pratico: as duas functions dentro de uma consulta SQL
SELECT u.nm_usuario,
       fun_shas_saldo_previsto(u.id_usuario, 2026, 10) AS saldo_previsto,
       fun_shas_resumo_mes(u.id_usuario, 2026, 10)     AS resumo
FROM   shas_usuario u
ORDER  BY u.nm_usuario;

-- tratamento de erro (mes invalido)
SELECT fun_shas_resumo_mes('uid-ana-001', 2026, 13) AS teste_erro FROM dual;

-- function 3: progresso das metas (usa a tabela shas_meta)
SELECT u.nm_usuario,
       m.nm_meta,
       m.vl_alvo,
       fun_shas_progresso_meta(m.id_meta) AS progresso_pct
FROM   shas_meta m JOIN shas_usuario u ON u.id_usuario = m.id_usuario
ORDER  BY u.nm_usuario;

-- tratamento de erro da function 3 (esperado: ORA-20040)
SELECT fun_shas_progresso_meta('meta-inexistente') FROM dual;