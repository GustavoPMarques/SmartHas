-- =====================================================================
-- 07_testes.sql: testes integrados do Smart HAS (Etapa 4)
--
-- 05_packages.sql e 06_triggers.sql ja executados.
-- =====================================================================
SET SERVEROUTPUT ON;

DELETE FROM shas_alerta        WHERE id_usuario = 'uid-teste-001';
DELETE FROM shas_transacao     WHERE id_usuario = 'uid-teste-001';
DELETE FROM shas_log_transacao WHERE id_usuario = 'uid-teste-001';
DELETE FROM shas_usuario       WHERE id_usuario = 'uid-teste-001';
COMMIT;

VARIABLE v_max_alerta NUMBER;
BEGIN
  SELECT NVL(MAX(id_alerta), 0) INTO :v_max_alerta FROM shas_alerta;
  DBMS_OUTPUT.PUT_LINE('Preparacao concluida. Maior id_alerta antes dos testes: ' || :v_max_alerta);
END;
/

-- ---------------------------------------------------------------------
-- T1) prc_registra_transacao: transacao simples (RENDA de 1.000,00)
--     esperado: qtd_gerada = 1 | alerta = OK
-- ---------------------------------------------------------------------
DECLARE
  v_qtd    NUMBER;
  v_alerta VARCHAR2(30);
BEGIN
  pkg_shas_operacao.prc_registra_transacao(
    'uid-teste-001', 'Salario teste', 1000, DATE '2026-10-05',
    'RENDA', 'Salario', 'N', 1, v_qtd, v_alerta);
  DBMS_OUTPUT.PUT_LINE('T1 | qtd_gerada=' || v_qtd || ' | alerta=' || v_alerta);
END;
/

-- ---------------------------------------------------------------------
-- T2) Despesa PARCELADA: 600,00 em 3x (uma linha por mes)
--     esperado: qtd_gerada = 3 | alerta = OK (saldo de 10/2026 = 800,00)
-- ---------------------------------------------------------------------
DECLARE
  v_qtd    NUMBER;
  v_alerta VARCHAR2(30);
BEGIN
  pkg_shas_operacao.prc_registra_transacao(
    'uid-teste-001', 'Celular teste', 600, DATE '2026-10-10',
    'DESPESA', 'Tecnologia', 'N', 3, v_qtd, v_alerta);
  DBMS_OUTPUT.PUT_LINE('T2 | qtd_gerada=' || v_qtd || ' | alerta=' || v_alerta);
END;
/

-- ---------------------------------------------------------------------
-- T3) Despesa RECORRENTE: 700,00 por mes
--     esperado: qtd_gerada = 1 | alerta = OK (saldo de 10/2026 = 100,00)
-- ---------------------------------------------------------------------
DECLARE
  v_qtd    NUMBER;
  v_alerta VARCHAR2(30);
BEGIN
  pkg_shas_operacao.prc_registra_transacao(
    'uid-teste-001', 'Aluguel teste', 700, DATE '2026-10-01',
    'DESPESA', 'Moradia', 'S', 1, v_qtd, v_alerta);
  DBMS_OUTPUT.PUT_LINE('T3 | qtd_gerada=' || v_qtd || ' | alerta=' || v_alerta);
END;
/

-- esperado: 5 linhas = salario 1.000,00 | aluguel 700,00 (recorrente S) |
--           Celular (1/3) 200,00 em 10/10 | (2/3) em 10/11 | (3/3) em 10/12
SELECT ds_titulo, vl_transacao, tp_transacao, fl_recorrente, nr_parcelas,
       TO_CHAR(dt_transacao, 'DD/MM/YYYY') AS dt_transacao
FROM   shas_transacao
WHERE  id_usuario = 'uid-teste-001'
ORDER  BY dt_transacao, ds_titulo;

-- ---------------------------------------------------------------------
-- T4) Validacoes da procedure (cada chamada deve falhar)
--     esperado: ORA-20010, ORA-20011, ORA-20012 e ORA-20013
-- ---------------------------------------------------------------------
DECLARE
  v_qtd    NUMBER;
  v_alerta VARCHAR2(30);

  PROCEDURE tenta (p_desc VARCHAR2, p_usr VARCHAR2, p_valor NUMBER,
                   p_tipo VARCHAR2, p_parc NUMBER) IS
  BEGIN
    pkg_shas_operacao.prc_registra_transacao(
      p_usr, 'Teste erro', p_valor, DATE '2026-10-05',
      p_tipo, 'Teste', 'N', p_parc, v_qtd, v_alerta);
    DBMS_OUTPUT.PUT_LINE('T4 | ' || p_desc || ' -> SEM ERRO (inesperado)');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('T4 | ' || p_desc || ' -> ' || SQLERRM);
  END tenta;
BEGIN
  tenta('tipo invalido ', 'uid-teste-001', 100, 'X',       1);
  tenta('valor zero    ', 'uid-teste-001', 0,   'DESPESA', 1);
  tenta('parcelas zero ', 'uid-teste-001', 100, 'DESPESA', 0);
  tenta('usuario nulo  ', NULL,            100, 'DESPESA', 1);
END;
/

-- ---------------------------------------------------------------------
-- T5) PKG_SHAS_CALCULO sobre os dados de teste
--     esperado: 10/2026 | Rendas: R$ 1.000,00 | Despesas: R$ 900,00 |
--               Saldo do mes: R$ 100,00 | Previsto acumulado: R$ 100,00
-- ---------------------------------------------------------------------
SELECT pkg_shas_calculo.fun_resumo_mes('uid-teste-001', 2026, 10) AS resumo FROM dual;

-- ---------------------------------------------------------------------
-- T6) prc_gera_alertas_mensais
--     Despesas (900) = 90% da renda (1.000): deve gerar LIMITE_80_PCT.
--     esperado 1a chamada: qtd >= 1 (pode ser maior se Ana/Bruno ainda
--                          nao tiverem alerta de 10/2026; os extras sao
--                          removidos na limpeza final)
--     esperado 2a chamada: qtd = 0 (nao duplica alertas)
-- ---------------------------------------------------------------------
DECLARE
  v_qtd NUMBER;
BEGIN
  pkg_shas_operacao.prc_gera_alertas_mensais(2026, 10, v_qtd);
  DBMS_OUTPUT.PUT_LINE('T6 | 1a chamada: alertas criados=' || v_qtd);
  pkg_shas_operacao.prc_gera_alertas_mensais(2026, 10, v_qtd);
  DBMS_OUTPUT.PUT_LINE('T6 | 2a chamada: alertas criados=' || v_qtd || ' (esperado 0)');
END;
/

-- esperado: 1 linha LIMITE_80_PCT, ST_ALERTA = NOVO
--           ("Voce ja comprometeu 90% da renda em 10/2026")
SELECT tp_alerta, st_alerta, ds_mensagem
FROM   shas_alerta
WHERE  id_usuario = 'uid-teste-001'
ORDER  BY id_alerta;

-- ---------------------------------------------------------------------
-- T7) Saldo NEGATIVO: despesa de 2.000,00 estoura o mes
--     esperado: qtd_gerada = 1 | alerta = SALDO_NEGATIVO
--     Depois a rotina em lote deve criar DESPESAS_MAIOR_QUE_RENDA
-- ---------------------------------------------------------------------
DECLARE
  v_qtd    NUMBER;
  v_alerta VARCHAR2(30);
BEGIN
  pkg_shas_operacao.prc_registra_transacao(
    'uid-teste-001', 'Imprevisto teste', 2000, DATE '2026-10-20',
    'DESPESA', 'Saude', 'N', 1, v_qtd, v_alerta);
  DBMS_OUTPUT.PUT_LINE('T7 | qtd_gerada=' || v_qtd || ' | alerta=' || v_alerta);

  pkg_shas_operacao.prc_gera_alertas_mensais(2026, 10, v_qtd);
  DBMS_OUTPUT.PUT_LINE('T7 | rotina em lote: alertas criados=' || v_qtd || ' (esperado >= 1)');
END;
/

-- esperado: 3 linhas = LIMITE_80_PCT, SALDO_NEGATIVO ("... R$ -1.900,00"),
--           DESPESAS_MAIOR_QUE_RENDA
SELECT tp_alerta, st_alerta, ds_mensagem
FROM   shas_alerta
WHERE  id_usuario = 'uid-teste-001'
ORDER  BY id_alerta;

-- ---------------------------------------------------------------------
-- T8) TRIGGER DE AUDITORIA em acao via package
--     6 INSERTs: salario(1) + celular(3 parcelas) + aluguel(1) + imprevisto(1)
--     esperado: INSERT = 6 (nenhum UPDATE/DELETE ate aqui)
-- ---------------------------------------------------------------------
SELECT tp_operacao, COUNT(*) AS qtd_logs
FROM   shas_log_transacao
WHERE  id_usuario = 'uid-teste-001'
GROUP  BY tp_operacao
ORDER  BY tp_operacao;

-- ---------------------------------------------------------------------
-- T9) TRIGGER DE STATUS em acao: marcar o alerta de saldo como LIDO
--     esperado: ST_ALERTA = LIDO e DT_LEITURA preenchida automaticamente
-- ---------------------------------------------------------------------
UPDATE shas_alerta
SET    st_alerta = 'LIDO'
WHERE  id_usuario = 'uid-teste-001' AND tp_alerta = 'SALDO_NEGATIVO';

SELECT tp_alerta, st_alerta, TO_CHAR(dt_leitura, 'DD/MM/YYYY HH24:MI:SS') AS dt_leitura
FROM   shas_alerta
WHERE  id_usuario = 'uid-teste-001'
ORDER  BY id_alerta;

-- ---------------------------------------------------------------------
-- T10) DYNAMIC SQL sobre os dados de teste
--      esperado (CATEGORIA / DESPESA / TOTAL):
--        Saude 1 2000,00 69% | Moradia 1 700,00 24,1% | Tecnologia 1 200,00 6,9%
--      esperado (fun_contar_registros): SHAS_TRANSACAO = total anterior + 6
-- ---------------------------------------------------------------------
DECLARE
  v_rc    SYS_REFCURSOR;
  v_grupo VARCHAR2(60);
  v_qtd   NUMBER;
  v_total NUMBER;
  v_perc  NUMBER;
BEGIN
  pkg_shas_relatorio.prc_resumo_dinamico(
    'uid-teste-001', 2026, 10, 'CATEGORIA', 'DESPESA', 'TOTAL', v_rc);
  DBMS_OUTPUT.PUT_LINE('T10 | resumo dinamico (CATEGORIA / DESPESA / TOTAL)');
  LOOP
    FETCH v_rc INTO v_grupo, v_qtd, v_total, v_perc;
    EXIT WHEN v_rc%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('   ' || RPAD(v_grupo, 14) || RPAD(v_qtd, 6) ||
                         RPAD(TO_CHAR(v_total, 'FM999990D00'), 12) || v_perc || '%');
  END LOOP;
  CLOSE v_rc;

  DBMS_OUTPUT.PUT_LINE('T10 | registros em SHAS_TRANSACAO agora: ' ||
                       pkg_shas_relatorio.fun_contar_registros('SHAS_TRANSACAO'));
END;
/

-- ---------------------------------------------------------------------
-- LIMPEZA: remove TUDO que o teste criou (inclusive alertas gerados
-- para usuarios reais durante a rotina em lote) e confere o resultado
-- ---------------------------------------------------------------------
DELETE FROM shas_alerta
WHERE  id_usuario = 'uid-teste-001' OR id_alerta > :v_max_alerta;
DELETE FROM shas_transacao     WHERE id_usuario = 'uid-teste-001';
DELETE FROM shas_log_transacao WHERE id_usuario = 'uid-teste-001';
DELETE FROM shas_usuario       WHERE id_usuario = 'uid-teste-001';
COMMIT;

-- esperado: alerta 3, log 0, meta 3, transacao 178, usuario 3
SELECT table_name,
       pkg_shas_relatorio.fun_contar_registros(table_name) AS qtd_registros
FROM   user_tables
WHERE  table_name LIKE 'SHAS\_%' ESCAPE '\'
ORDER  BY table_name;
