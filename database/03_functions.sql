-- ---------------------------------------------------------------------
-- FUNCTION 1: saldo previsto ate o fim do mes informado
--   Renda soma, despesa subtrai.
--   Transacao recorrente conta 1 vez por mes, desde o mes em que comecou.
--   (mesma regra do metodo calcularResumo do Java)
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
--   Exemplo: 10/2026 | Rendas: R$ 4.200,00 | Despesas: R$ 3.420,10 |
--   Usa a function 1 para o saldo previsto acumulado.
--   Em caso de erro devolve a mensagem.
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