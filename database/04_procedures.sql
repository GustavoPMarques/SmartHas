-- =====================================================================
-- Executar DEPOIS do 03_functions.sql.
-- =====================================================================
SET SERVEROUTPUT ON;

-- ---------------------------------------------------------------------
-- PROCEDURE 1: registra a transacao, gera as parcelas
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE prc_shas_registra_transacao (
  p_id_usuario  IN  shas_usuario.id_usuario%TYPE,
  p_titulo      IN  shas_transacao.ds_titulo%TYPE,
  p_valor       IN  NUMBER,
  p_data        IN  DATE,
  p_tipo        IN  VARCHAR2,
  p_categoria   IN  shas_transacao.ds_categoria%TYPE,
  p_recorrente  IN  VARCHAR2 DEFAULT 'N',
  p_parcelas    IN  NUMBER   DEFAULT 1,
  p_qtd_gerada  OUT NUMBER,
  p_alerta      OUT VARCHAR2)
IS
  v_parcelas    NUMBER := NVL(p_parcelas, 1);
  v_vl_parcela  NUMBER;
  v_titulo      shas_transacao.ds_titulo%TYPE;
  v_saldo       NUMBER;
  v_ano         NUMBER;
  v_mes         NUMBER;
BEGIN
  
  IF p_id_usuario IS NULL OR p_data IS NULL THEN
    RAISE_APPLICATION_ERROR(-20013, 'Usuario e data sao obrigatorios');
  END IF;
  IF p_tipo NOT IN ('RENDA','DESPESA') THEN
    RAISE_APPLICATION_ERROR(-20010, 'Tipo deve ser RENDA ou DESPESA');
  END IF;
  IF p_valor IS NULL OR p_valor <= 0 THEN
    RAISE_APPLICATION_ERROR(-20011, 'Valor deve ser maior que zero');
  END IF;
  IF v_parcelas < 1 THEN
    RAISE_APPLICATION_ERROR(-20012, 'Parcelas deve ser no minimo 1');
  END IF;

  v_ano := EXTRACT(YEAR  FROM p_data);
  v_mes := EXTRACT(MONTH FROM p_data);

  
  MERGE INTO shas_usuario u
  USING (SELECT p_id_usuario AS id FROM dual) s
  ON (u.id_usuario = s.id)
  WHEN NOT MATCHED THEN INSERT (id_usuario) VALUES (s.id);

  
  v_vl_parcela := ROUND(p_valor / v_parcelas, 2);
  FOR i IN 1..v_parcelas LOOP
    v_titulo := CASE WHEN v_parcelas > 1
                     THEN p_titulo || ' (' || i || '/' || v_parcelas || ')'
                     ELSE p_titulo END;
    INSERT INTO shas_transacao
      (id_transacao, id_usuario, ds_titulo, vl_transacao, dt_transacao,
       tp_transacao, ds_categoria, fl_recorrente, nr_parcelas)
    VALUES
      (LOWER(RAWTOHEX(SYS_GUID())), p_id_usuario, v_titulo, v_vl_parcela,
       ADD_MONTHS(p_data, i - 1), p_tipo, p_categoria,
       CASE WHEN v_parcelas = 1 THEN p_recorrente ELSE 'N' END, v_parcelas);
  END LOOP;
  p_qtd_gerada := v_parcelas;

  
  v_saldo := fun_shas_saldo_previsto(p_id_usuario, v_ano, v_mes);
  IF v_saldo < 0 THEN
    INSERT INTO shas_alerta (id_usuario, nr_ano, nr_mes, tp_alerta, ds_mensagem)
    VALUES (p_id_usuario, v_ano, v_mes, 'SALDO_NEGATIVO',
            'Saldo previsto negativo em ' || TO_CHAR(p_data, 'MM/YYYY') || ': R$ ' ||
            TO_CHAR(v_saldo, 'FM999G999G990D00', 'NLS_NUMERIC_CHARACTERS='',.'''));
    p_alerta := 'SALDO_NEGATIVO';
  ELSE
    p_alerta := 'OK';
  END IF;

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;                                  -- mantem os erros de validacao
    END IF;
    RAISE_APPLICATION_ERROR(-20019, 'Erro ao registrar transacao: ' || SQLERRM);
END prc_shas_registra_transacao;
/

-- ---------------------------------------------------------------------
-- PROCEDURE 2: gera alertas mensais para todos os usuarios.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE prc_shas_gera_alertas_mensais (
  p_ano         IN  NUMBER,
  p_mes         IN  NUMBER,
  p_qtd_alertas OUT NUMBER)
IS
  CURSOR c_usuarios IS
    SELECT id_usuario FROM shas_usuario;

  v_ini      DATE;
  v_rendas   NUMBER;
  v_despesas NUMBER;
  v_total    NUMBER := 0;


  PROCEDURE grava (l_id VARCHAR2, l_tipo VARCHAR2, l_msg VARCHAR2) IS
    v_qtd NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_qtd
    FROM   shas_alerta
    WHERE  id_usuario = l_id AND nr_ano = p_ano AND nr_mes = p_mes AND tp_alerta = l_tipo;

    IF v_qtd = 0 THEN
      INSERT INTO shas_alerta (id_usuario, nr_ano, nr_mes, tp_alerta, ds_mensagem)
      VALUES (l_id, p_ano, p_mes, l_tipo, l_msg);
      v_total := v_total + 1;
    END IF;
  END grava;
BEGIN
  IF p_mes NOT BETWEEN 1 AND 12 THEN
    RAISE_APPLICATION_ERROR(-20030, 'Mes invalido: ' || p_mes);
  END IF;
  v_ini := TO_DATE(p_ano || '-' || LPAD(p_mes, 2, '0') || '-01', 'YYYY-MM-DD');

  FOR u IN c_usuarios LOOP
    BEGIN
      SELECT NVL(SUM(CASE WHEN tp_transacao = 'RENDA'   THEN vl_transacao END), 0),
             NVL(SUM(CASE WHEN tp_transacao = 'DESPESA' THEN vl_transacao END), 0)
      INTO   v_rendas, v_despesas
      FROM   shas_transacao
      WHERE  id_usuario = u.id_usuario
      AND  ( (fl_recorrente = 'N' AND dt_transacao >= v_ini AND dt_transacao < ADD_MONTHS(v_ini, 1))
          OR (fl_recorrente = 'S' AND dt_transacao < ADD_MONTHS(v_ini, 1)) );

      IF v_despesas > v_rendas THEN
        grava(u.id_usuario, 'DESPESAS_MAIOR_QUE_RENDA',
              'Despesas superam as rendas em ' || TO_CHAR(v_ini, 'MM/YYYY'));
      ELSIF v_rendas > 0 AND v_despesas >= 0.8 * v_rendas THEN
        grava(u.id_usuario, 'LIMITE_80_PCT',
              'Voce ja comprometeu ' || ROUND(v_despesas / v_rendas * 100) ||
              '% da renda em ' || TO_CHAR(v_ini, 'MM/YYYY'));
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Falha no usuario ' || u.id_usuario || ': ' || SQLERRM);
    END;
  END LOOP;

  p_qtd_alertas := v_total;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;
    END IF;
    RAISE_APPLICATION_ERROR(-20039, 'Erro na rotina de alertas: ' || SQLERRM);
END prc_shas_gera_alertas_mensais;
/

-- ---------------------------------------------------------------------
-- TESTES 
-- ---------------------------------------------------------------------

-- Teste 1: Ana compra um notebook parcelado em 10x (esperado: 10 parcelas, alerta OK)
DECLARE
  v_qtd    NUMBER;
  v_alerta VARCHAR2(30);
BEGIN
  prc_shas_registra_transacao('uid-ana-001', 'Notebook', 6000, SYSDATE,
                              'DESPESA', 'Tecnologia', 'N', 10, v_qtd, v_alerta);
  DBMS_OUTPUT.PUT_LINE('Ana   -> parcelas: ' || v_qtd || ' | alerta: ' || v_alerta);
END;
/

-- Teste 2: Bruno compra um celular em 3x (esperado: 3 parcelas, alerta SALDO_NEGATIVO)
DECLARE
  v_qtd    NUMBER;
  v_alerta VARCHAR2(30);
BEGIN
  prc_shas_registra_transacao('uid-bruno-002', 'Celular', 1200, SYSDATE,
                              'DESPESA', 'Tecnologia', 'N', 3, v_qtd, v_alerta);
  DBMS_OUTPUT.PUT_LINE('Bruno -> parcelas: ' || v_qtd || ' | alerta: ' || v_alerta);
END;
/

-- Teste 3: rotina em lote para out/2026 (esperado: 2 alertas novos)
DECLARE
  v_qtd NUMBER;
BEGIN
  prc_shas_gera_alertas_mensais(2026, 10, v_qtd);
  DBMS_OUTPUT.PUT_LINE('Alertas novos (1a execucao): ' || v_qtd);
END;
/

-- Teste 4: rodar de novo nao duplica (esperado: 0)
DECLARE
  v_qtd NUMBER;
BEGIN
  prc_shas_gera_alertas_mensais(2026, 10, v_qtd);
  DBMS_OUTPUT.PUT_LINE('Alertas novos (2a execucao): ' || v_qtd);
END;
/

-- Teste 5: validacao (esperado: erro ORA-20011)
DECLARE
  v_qtd    NUMBER;
  v_alerta VARCHAR2(30);
BEGIN
  prc_shas_registra_transacao('uid-ana-001', 'Teste erro', -50, SYSDATE,
                              'DESPESA', 'Teste', 'N', 1, v_qtd, v_alerta);
END;
/

-- Resultado: alertas gerados
SELECT a.id_alerta, u.nm_usuario, a.tp_alerta, a.ds_mensagem
FROM   shas_alerta a JOIN shas_usuario u ON u.id_usuario = a.id_usuario
ORDER  BY a.id_alerta;

-- para desfazer os testes e poder rodar de novo, descomente:
-- DELETE FROM shas_alerta;
-- DELETE FROM shas_transacao WHERE ds_titulo LIKE 'Notebook%' OR ds_titulo LIKE 'Celular%';
-- COMMIT;
