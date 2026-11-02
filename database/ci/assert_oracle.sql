WHENEVER SQLERROR EXIT FAILURE
WHENEVER OSERROR EXIT FAILURE
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET SQLBLANKLINES ON

DECLARE
  c_user       CONSTANT VARCHAR2(20) := 'uid-ci-001';
  v_total      NUMBER := 0;
  v_falhas     NUMBER := 0;
  v_ano        NUMBER := EXTRACT(YEAR  FROM SYSDATE);
  v_mes        NUMBER := EXTRACT(MONTH FROM SYSDATE);
  v_ini        DATE   := TRUNC(SYSDATE, 'MM');
  v_max_alerta NUMBER;
  v_qtd        NUMBER;
  v_alerta     VARCHAR2(30);
  v_n          NUMBER;
  v_dt         DATE;
  v_rc         SYS_REFCURSOR;
  v_grupo      VARCHAR2(60);
  v_q          NUMBER;
  v_t          NUMBER;
  v_p          NUMBER;


  PROCEDURE check_ (p_desc IN VARCHAR2, p_ok IN BOOLEAN) IS
  BEGIN
    v_total := v_total + 1;
    IF p_ok THEN
      DBMS_OUTPUT.PUT_LINE('[OK]    ' || p_desc);
    ELSE
      v_falhas := v_falhas + 1;
      DBMS_OUTPUT.PUT_LINE('[FALHA] ' || p_desc);
    END IF;
  END check_;


  FUNCTION cnt (p_sql IN VARCHAR2) RETURN NUMBER IS
    v NUMBER;
  BEGIN
    EXECUTE IMMEDIATE p_sql INTO v;
    RETURN v;
  END cnt;


  PROCEDURE limpa IS
  BEGIN
    DELETE FROM shas_alerta WHERE id_usuario = c_user OR id_alerta > v_max_alerta;
    DELETE FROM shas_transacao     WHERE id_usuario = c_user;
    DELETE FROM shas_log_transacao WHERE id_usuario = c_user;
    DELETE FROM shas_usuario       WHERE id_usuario = c_user;
    COMMIT;
  END limpa;

BEGIN
  BEGIN
    -- -----------------------------------------------------------------
    -- A) ESTRUTURA
    -- -----------------------------------------------------------------
    check_('3 packages + 3 package bodies VALID',
           cnt(q'[SELECT COUNT(*) FROM user_objects
                  WHERE object_name IN ('PKG_SHAS_CALCULO','PKG_SHAS_OPERACAO','PKG_SHAS_RELATORIO')
                  AND object_type IN ('PACKAGE','PACKAGE BODY') AND status = 'VALID']') = 6);
    check_('2 triggers ENABLED',
           cnt(q'[SELECT COUNT(*) FROM user_triggers
                  WHERE trigger_name IN ('TRG_SHAS_AUDITA_TRANSACAO','TRG_SHAS_ALERTA_STATUS')
                  AND status = 'ENABLED']') = 2);
    check_('nenhum objeto INVALID no schema',
           cnt(q'[SELECT COUNT(*) FROM user_objects WHERE status <> 'VALID']') = 0);
    check_('USER_ERRORS vazio (sem erro de compilacao)',
           cnt('SELECT COUNT(*) FROM user_errors') = 0);
    check_('tabela SHAS_LOG_TRANSACAO existe',
           cnt(q'[SELECT COUNT(*) FROM user_tables WHERE table_name = 'SHAS_LOG_TRANSACAO']') = 1);
    check_('colunas ST_ALERTA e DT_LEITURA existem em SHAS_ALERTA',
           cnt(q'[SELECT COUNT(*) FROM user_tab_columns
                  WHERE table_name = 'SHAS_ALERTA' AND column_name IN ('ST_ALERTA','DT_LEITURA')]') = 2);

    -- -----------------------------------------------------------------
    -- B) CARGA DE DADOS (02_dados.sql)
    -- -----------------------------------------------------------------
    check_('3 usuarios carregados', cnt('SELECT COUNT(*) FROM shas_usuario') = 3);
    check_('3 metas carregadas',    cnt('SELECT COUNT(*) FROM shas_meta') = 3);
    check_('pelo menos 165 transacoes carregadas',
           cnt('SELECT COUNT(*) FROM shas_transacao') >= 165);

    -- -----------------------------------------------------------------
    -- C)rotina solta x package
    -- -----------------------------------------------------------------
    FOR u IN (SELECT id_usuario FROM shas_usuario ORDER BY id_usuario) LOOP
      check_('saldo previsto solta = package (' || u.id_usuario || ')',
             fun_shas_saldo_previsto(u.id_usuario, v_ano, v_mes)
             = pkg_shas_calculo.fun_saldo_previsto(u.id_usuario, v_ano, v_mes));
      check_('resumo do mes solta = package (' || u.id_usuario || ')',
             fun_shas_resumo_mes(u.id_usuario, v_ano, v_mes)
             = pkg_shas_calculo.fun_resumo_mes(u.id_usuario, v_ano, v_mes));
    END LOOP;
    FOR m IN (SELECT id_meta, nm_meta FROM shas_meta ORDER BY nm_meta) LOOP
      check_('progresso da meta solta = package (' || m.nm_meta || ')',
             fun_shas_progresso_meta(m.id_meta) = pkg_shas_calculo.fun_progresso_meta(m.id_meta));
    END LOOP;

    -- -----------------------------------------------------------------
    -- D) CENARIO COMPLETO com o usuario de teste (packages + triggers)
    -- -----------------------------------------------------------------
    limpa;
    SELECT NVL(MAX(id_alerta), 0) INTO v_max_alerta FROM shas_alerta;

    -- D1: renda simples
    pkg_shas_operacao.prc_registra_transacao(c_user, 'Salario ci', 1000, v_ini + 4,
                                             'RENDA', 'Salario', 'N', 1, v_qtd, v_alerta);
    check_('D1 renda: 1 transacao gerada e alerta OK', v_qtd = 1 AND v_alerta = 'OK');

    -- D2: despesa parcelada 600 em 3x (200 por mes)
    pkg_shas_operacao.prc_registra_transacao(c_user, 'Celular ci', 600, v_ini + 9,
                                             'DESPESA', 'Tecnologia', 'N', 3, v_qtd, v_alerta);
    check_('D2 parcelado: 3 parcelas geradas e alerta OK', v_qtd = 3 AND v_alerta = 'OK');
    check_('D2 saldo previsto do mes = 800,00',
           pkg_shas_calculo.fun_saldo_previsto(c_user, v_ano, v_mes) = 800);

    -- D3: despesa recorrente 700 -> despesas do mes = 900 (90% da renda)
    pkg_shas_operacao.prc_registra_transacao(c_user, 'Aluguel ci', 700, v_ini,
                                             'DESPESA', 'Moradia', 'S', 1, v_qtd, v_alerta);
    check_('D3 recorrente: saldo previsto do mes = 100,00',
           pkg_shas_calculo.fun_saldo_previsto(c_user, v_ano, v_mes) = 100);

    pkg_shas_operacao.prc_gera_alertas_mensais(v_ano, v_mes, v_qtd);
    check_('D3 alertas em lote: criou pelo menos 1 alerta', v_qtd >= 1);
    check_('D3 alerta LIMITE_80_PCT criado para o usuario de teste',
           cnt(q'[SELECT COUNT(*) FROM shas_alerta
                  WHERE id_usuario = 'uid-ci-001' AND tp_alerta = 'LIMITE_80_PCT']') = 1);
    pkg_shas_operacao.prc_gera_alertas_mensais(v_ano, v_mes, v_qtd);
    check_('D3 alertas em lote: 2a chamada nao duplica (0 novos)', v_qtd = 0);

    -- D4: validacao rejeita valor zero
    BEGIN
      pkg_shas_operacao.prc_registra_transacao(c_user, 'x', 0, v_ini, 'DESPESA', 'x', 'N', 1, v_qtd, v_alerta);
      check_('D4 valor zero deveria ser rejeitado', FALSE);
    EXCEPTION
      WHEN OTHERS THEN
        check_('D4 valor zero rejeitado com ORA-20011', SQLCODE = -20011);
    END;

    -- D5: saldo negativo
    pkg_shas_operacao.prc_registra_transacao(c_user, 'Imprevisto ci', 2000, v_ini + 19,
                                             'DESPESA', 'Saude', 'N', 1, v_qtd, v_alerta);
    check_('D5 despesa de 2.000: alerta SALDO_NEGATIVO', v_alerta = 'SALDO_NEGATIVO');
    check_('D5 alerta SALDO_NEGATIVO gravado na tabela',
           cnt(q'[SELECT COUNT(*) FROM shas_alerta
                  WHERE id_usuario = 'uid-ci-001' AND tp_alerta = 'SALDO_NEGATIVO']') = 1);

    -- D6: trigger de auditoria
    check_('D6 auditoria: 6 INSERTs no log (1 renda + 3 parcelas + 1 recorrente + 1 imprevisto)',
           cnt(q'[SELECT COUNT(*) FROM shas_log_transacao
                  WHERE id_usuario = 'uid-ci-001' AND tp_operacao = 'INSERT']') = 6);
    UPDATE shas_transacao SET vl_transacao = vl_transacao + 1
    WHERE  id_usuario = c_user AND ds_titulo = 'Salario ci';
    DELETE FROM shas_transacao
    WHERE  id_usuario = c_user AND ds_titulo = 'Imprevisto ci';
    check_('D6 auditoria: 1 UPDATE registrado no log',
           cnt(q'[SELECT COUNT(*) FROM shas_log_transacao
                  WHERE id_usuario = 'uid-ci-001' AND tp_operacao = 'UPDATE'
                  AND vl_antigo = 1000 AND vl_novo = 1001]') = 1);
    check_('D6 auditoria: 1 DELETE registrado no log',
           cnt(q'[SELECT COUNT(*) FROM shas_log_transacao
                  WHERE id_usuario = 'uid-ci-001' AND tp_operacao = 'DELETE'
                  AND vl_antigo = 2000]') = 1);

    -- D7: trigger de status do alerta
    UPDATE shas_alerta SET st_alerta = 'LIDO'
    WHERE  id_usuario = c_user AND tp_alerta = 'SALDO_NEGATIVO';
    SELECT dt_leitura INTO v_dt FROM shas_alerta
    WHERE  id_usuario = c_user AND tp_alerta = 'SALDO_NEGATIVO';
    check_('D7 trigger de status: LIDO preenche DT_LEITURA', v_dt IS NOT NULL);
    UPDATE shas_alerta SET st_alerta = 'NOVO'
    WHERE  id_usuario = c_user AND tp_alerta = 'SALDO_NEGATIVO';
    SELECT dt_leitura INTO v_dt FROM shas_alerta
    WHERE  id_usuario = c_user AND tp_alerta = 'SALDO_NEGATIVO';
    check_('D7 trigger de status: NOVO limpa DT_LEITURA', v_dt IS NULL);

    -- -----------------------------------------------------------------
    -- E) DYNAMIC SQL
    -- -----------------------------------------------------------------
    pkg_shas_relatorio.prc_resumo_dinamico(c_user, v_ano, v_mes, 'TIPO', NULL, 'TOTAL', v_rc);
    v_n := 0;
    LOOP
      FETCH v_rc INTO v_grupo, v_q, v_t, v_p;
      EXIT WHEN v_rc%NOTFOUND;
      v_n := v_n + 1;
    END LOOP;
    CLOSE v_rc;
    check_('E1 resumo dinamico por TIPO devolve 2 grupos (RENDA e DESPESA)', v_n = 2);

    BEGIN
      pkg_shas_relatorio.prc_resumo_dinamico(c_user, v_ano, v_mes,
                                             'ds_categoria; DROP TABLE shas_usuario', NULL, NULL, v_rc);
      check_('E2 agrupamento malicioso deveria ser rejeitado', FALSE);
    EXCEPTION
      WHEN OTHERS THEN
        check_('E2 agrupamento malicioso rejeitado com ORA-20052', SQLCODE = -20052);
    END;
    check_('E2 a tabela SHAS_USUARIO continua existindo',
           cnt(q'[SELECT COUNT(*) FROM user_tables WHERE table_name = 'SHAS_USUARIO']') = 1);

    check_('E3 fun_contar_registros(shas_usuario) = contagem direta',
           pkg_shas_relatorio.fun_contar_registros('shas_usuario') = cnt('SELECT COUNT(*) FROM shas_usuario'));
    BEGIN
      v_n := pkg_shas_relatorio.fun_contar_registros('USER_TABLES');
      check_('E3 tabela fora do padrao SHAS_ deveria ser rejeitada', FALSE);
    EXCEPTION
      WHEN OTHERS THEN
        check_('E3 tabela USER_TABLES rejeitada com ORA-20055', SQLCODE = -20055);
    END;

    -- -----------------------------------------------------------------
    -- F) LIMPEZA
    -- -----------------------------------------------------------------
    limpa;
    check_('F limpeza: nenhum dado do usuario de teste restou',
           cnt(q'[SELECT COUNT(*) FROM shas_transacao WHERE id_usuario = 'uid-ci-001']')
         + cnt(q'[SELECT COUNT(*) FROM shas_usuario   WHERE id_usuario = 'uid-ci-001']')
         + cnt(q'[SELECT COUNT(*) FROM shas_log_transacao WHERE id_usuario = 'uid-ci-001']') = 0);
    check_('F limpeza: base voltou a ter 3 usuarios', cnt('SELECT COUNT(*) FROM shas_usuario') = 3);
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('[ERRO]  ' || SQLERRM);
      BEGIN limpa; EXCEPTION WHEN OTHERS THEN NULL; END;
      RAISE;
  END;

  DBMS_OUTPUT.PUT_LINE('RESULTADO: ' || v_total || ' verificacoes, ' || v_falhas || ' falha(s)');
  IF v_falhas > 0 THEN
    RAISE_APPLICATION_ERROR(-20999, v_falhas || ' verificacao(oes) falharam');
  END IF;
END;
/

EXIT 0
