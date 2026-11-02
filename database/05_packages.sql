-- =====================================================================
-- 05_packages.sql: packages PL/SQL do Smart HAS (Etapa 1)
--
-- Execute DEPOIS do 04_procedures.sql, como SCRIPT (F5).
-- =====================================================================
SET SERVEROUTPUT ON;

-- =====================================================================
-- PACKAGE 1: PKG_SHAS_CALCULO (specification)
-- =====================================================================
CREATE OR REPLACE PACKAGE pkg_shas_calculo AS

  
  c_limite_alerta CONSTANT NUMBER       := 0.8;
  c_fmt_moeda     CONSTANT VARCHAR2(30) := 'FM999G999G990D00';
  c_nls_moeda     CONSTANT VARCHAR2(60) := 'NLS_NUMERIC_CHARACTERS='',.''';

  PROCEDURE prc_totais_mes (
    p_id_usuario IN  shas_usuario.id_usuario%TYPE,
    p_ano        IN  NUMBER,
    p_mes        IN  NUMBER,
    p_rendas     OUT NUMBER,
    p_despesas   OUT NUMBER);

  FUNCTION fun_saldo_previsto (
    p_id_usuario IN shas_usuario.id_usuario%TYPE,
    p_ano        IN NUMBER,
    p_mes        IN NUMBER)
  RETURN NUMBER;

  FUNCTION fun_resumo_mes (
    p_id_usuario IN shas_usuario.id_usuario%TYPE,
    p_ano        IN NUMBER,
    p_mes        IN NUMBER)
  RETURN VARCHAR2;

  FUNCTION fun_progresso_meta (
    p_id_meta IN shas_meta.id_meta%TYPE)
  RETURN NUMBER;

END pkg_shas_calculo;
/

-- =====================================================================
-- PACKAGE 1: PKG_SHAS_CALCULO (body)
-- =====================================================================
CREATE OR REPLACE PACKAGE BODY pkg_shas_calculo AS


  FUNCTION f_inicio_mes (
    p_ano IN NUMBER,
    p_mes IN NUMBER)
  RETURN DATE
  IS
  BEGIN
    RETURN TO_DATE(p_ano || '-' || LPAD(p_mes, 2, '0') || '-01', 'YYYY-MM-DD');
  END f_inicio_mes;

  ---------------------------------------------------------------------
  PROCEDURE prc_totais_mes (
    p_id_usuario IN  shas_usuario.id_usuario%TYPE,
    p_ano        IN  NUMBER,
    p_mes        IN  NUMBER,
    p_rendas     OUT NUMBER,
    p_despesas   OUT NUMBER)
  IS
    v_ini DATE := f_inicio_mes(p_ano, p_mes);
  BEGIN
    SELECT NVL(SUM(CASE WHEN tp_transacao = 'RENDA'   THEN vl_transacao END), 0),
           NVL(SUM(CASE WHEN tp_transacao = 'DESPESA' THEN vl_transacao END), 0)
    INTO   p_rendas, p_despesas
    FROM   shas_transacao
    WHERE  id_usuario = p_id_usuario
    AND  ( (fl_recorrente = 'N' AND dt_transacao >= v_ini AND dt_transacao < ADD_MONTHS(v_ini, 1))
        OR (fl_recorrente = 'S' AND dt_transacao < ADD_MONTHS(v_ini, 1)) );
  END prc_totais_mes;

  ---------------------------------------------------------------------
  FUNCTION fun_saldo_previsto (
    p_id_usuario IN shas_usuario.id_usuario%TYPE,
    p_ano        IN NUMBER,
    p_mes        IN NUMBER)
  RETURN NUMBER
  IS
    v_ini   DATE;
    v_saldo NUMBER;
  BEGIN
    IF p_mes NOT BETWEEN 1 AND 12 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Mes invalido: ' || p_mes);
    END IF;

    v_ini := f_inicio_mes(p_ano, p_mes);

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
    WHEN OTHERS THEN
      IF SQLCODE = -20001 THEN
        RAISE;
      END IF;
      RAISE_APPLICATION_ERROR(-20002, 'Erro no saldo previsto: ' || SQLERRM);
  END fun_saldo_previsto;

  ---------------------------------------------------------------------
  FUNCTION fun_resumo_mes (
    p_id_usuario IN shas_usuario.id_usuario%TYPE,
    p_ano        IN NUMBER,
    p_mes        IN NUMBER)
  RETURN VARCHAR2
  IS
    v_ini      DATE;
    v_rendas   NUMBER;
    v_despesas NUMBER;
  BEGIN
    IF p_mes NOT BETWEEN 1 AND 12 THEN
      RETURN 'Mes invalido: ' || p_mes;
    END IF;

    v_ini := f_inicio_mes(p_ano, p_mes);
    prc_totais_mes(p_id_usuario, p_ano, p_mes, v_rendas, v_despesas);

    RETURN TO_CHAR(v_ini, 'MM/YYYY')
        || ' | Rendas: R$ '          || TO_CHAR(v_rendas, c_fmt_moeda, c_nls_moeda)
        || ' | Despesas: R$ '        || TO_CHAR(v_despesas, c_fmt_moeda, c_nls_moeda)
        || ' | Saldo do mes: R$ '    || TO_CHAR(v_rendas - v_despesas, c_fmt_moeda, c_nls_moeda)
        || ' | Previsto acumulado: R$ '
        || TO_CHAR(fun_saldo_previsto(p_id_usuario, p_ano, p_mes), c_fmt_moeda, c_nls_moeda);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'Erro ao gerar resumo: ' || SQLERRM;
  END fun_resumo_mes;

  ---------------------------------------------------------------------
  FUNCTION fun_progresso_meta (
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

    v_saldo := fun_saldo_previsto(v_id_usuario,
                                  EXTRACT(YEAR  FROM SYSDATE),
                                  EXTRACT(MONTH FROM SYSDATE));
    RETURN ROUND(GREATEST(0, LEAST(100, v_saldo / v_alvo * 100)), 1);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20040, 'Meta nao encontrada: ' || p_id_meta);
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20041, 'Erro no progresso da meta: ' || SQLERRM);
  END fun_progresso_meta;

END pkg_shas_calculo;
/

-- =====================================================================
-- PACKAGE 2: PKG_SHAS_OPERACAO (specification)
-- =====================================================================
CREATE OR REPLACE PACKAGE pkg_shas_operacao AS

  -- registra a transacao, gera uma linha por parcela e confere o saldo
  -- previsto do mes
  PROCEDURE prc_registra_transacao (
    p_id_usuario  IN  shas_usuario.id_usuario%TYPE,
    p_titulo      IN  shas_transacao.ds_titulo%TYPE,
    p_valor       IN  NUMBER,
    p_data        IN  DATE,
    p_tipo        IN  VARCHAR2,
    p_categoria   IN  shas_transacao.ds_categoria%TYPE,
    p_recorrente  IN  VARCHAR2 DEFAULT 'N',
    p_parcelas    IN  NUMBER   DEFAULT 1,
    p_qtd_gerada  OUT NUMBER,
    p_alerta      OUT VARCHAR2);

  
  PROCEDURE prc_gera_alertas_mensais (
    p_ano         IN  NUMBER,
    p_mes         IN  NUMBER,
    p_qtd_alertas OUT NUMBER);

END pkg_shas_operacao;
/

-- =====================================================================
-- PACKAGE 2: PKG_SHAS_OPERACAO (body)
-- =====================================================================
CREATE OR REPLACE PACKAGE BODY pkg_shas_operacao AS

  ---------------------------------------------------------------------
  PROCEDURE prc_registra_transacao (
    p_id_usuario  IN  shas_usuario.id_usuario%TYPE,
    p_titulo      IN  shas_transacao.ds_titulo%TYPE,
    p_valor       IN  NUMBER,
    p_data        IN  DATE,
    p_tipo        IN  VARCHAR2,
    p_categoria   IN  shas_transacao.ds_categoria%TYPE,
    p_recorrente  IN  VARCHAR2,
    p_parcelas    IN  NUMBER,
    p_qtd_gerada  OUT NUMBER,
    p_alerta      OUT VARCHAR2)
  IS
    v_parcelas   NUMBER := NVL(p_parcelas, 1);
    v_vl_parcela NUMBER;
    v_titulo     shas_transacao.ds_titulo%TYPE;
    v_saldo      NUMBER;
    v_ano        NUMBER;
    v_mes        NUMBER;
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

    v_saldo := pkg_shas_calculo.fun_saldo_previsto(p_id_usuario, v_ano, v_mes);
    IF v_saldo < 0 THEN
      INSERT INTO shas_alerta (id_usuario, nr_ano, nr_mes, tp_alerta, ds_mensagem)
      VALUES (p_id_usuario, v_ano, v_mes, 'SALDO_NEGATIVO',
              'Saldo previsto negativo em ' || TO_CHAR(p_data, 'MM/YYYY') || ': R$ ' ||
              TO_CHAR(v_saldo, pkg_shas_calculo.c_fmt_moeda, pkg_shas_calculo.c_nls_moeda));
      p_alerta := 'SALDO_NEGATIVO';
    ELSE
      p_alerta := 'OK';
    END IF;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      IF SQLCODE BETWEEN -20999 AND -20000 THEN
        RAISE;
      END IF;
      RAISE_APPLICATION_ERROR(-20019, 'Erro ao registrar transacao: ' || SQLERRM);
  END prc_registra_transacao;

  ---------------------------------------------------------------------
  PROCEDURE prc_gera_alertas_mensais (
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

        pkg_shas_calculo.prc_totais_mes(u.id_usuario, p_ano, p_mes, v_rendas, v_despesas);

        IF v_despesas > v_rendas THEN
          grava(u.id_usuario, 'DESPESAS_MAIOR_QUE_RENDA',
                'Despesas superam as rendas em ' || TO_CHAR(v_ini, 'MM/YYYY'));
        ELSIF v_rendas > 0 AND v_despesas >= pkg_shas_calculo.c_limite_alerta * v_rendas THEN
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
  END prc_gera_alertas_mensais;

END pkg_shas_operacao;
/

-- =====================================================================
-- PACKAGE 3: PKG_SHAS_RELATORIO (specification)
-- =====================================================================
CREATE OR REPLACE PACKAGE pkg_shas_relatorio AS


  PROCEDURE prc_relatorio_categorias (
    p_id_usuario IN  shas_usuario.id_usuario%TYPE,
    p_ano        IN  NUMBER,
    p_mes        IN  NUMBER,
    p_relatorio  OUT SYS_REFCURSOR);

  -- DYNAMIC SQL: resumo do mes com agrupamento escolhido em tempo de execucao

  PROCEDURE prc_resumo_dinamico (
    p_id_usuario IN  shas_usuario.id_usuario%TYPE,
    p_ano        IN  NUMBER,
    p_mes        IN  NUMBER,
    p_agrupar_por IN VARCHAR2,
    p_tipo       IN  VARCHAR2,
    p_ordenar_por IN VARCHAR2,
    p_relatorio  OUT SYS_REFCURSOR);


  FUNCTION fun_contar_registros (
    p_tabela IN VARCHAR2)
  RETURN NUMBER;

END pkg_shas_relatorio;
/

-- =====================================================================
-- PACKAGE 3: PKG_SHAS_RELATORIO (body)
-- =====================================================================
CREATE OR REPLACE PACKAGE BODY pkg_shas_relatorio AS

  PROCEDURE prc_relatorio_categorias (
    p_id_usuario IN  shas_usuario.id_usuario%TYPE,
    p_ano        IN  NUMBER,
    p_mes        IN  NUMBER,
    p_relatorio  OUT SYS_REFCURSOR)
  IS
    v_ini DATE;
  BEGIN
    IF p_mes NOT BETWEEN 1 AND 12 THEN
      RAISE_APPLICATION_ERROR(-20050, 'Mes invalido: ' || p_mes);
    END IF;
    v_ini := TO_DATE(p_ano || '-' || LPAD(p_mes, 2, '0') || '-01', 'YYYY-MM-DD');

    OPEN p_relatorio FOR
      SELECT ds_categoria,
             COUNT(*)          AS qtd_lancamentos,
             SUM(vl_transacao) AS total,
             ROUND(SUM(vl_transacao) * 100 / SUM(SUM(vl_transacao)) OVER (), 1) AS perc_do_total
      FROM   shas_transacao
      WHERE  id_usuario = p_id_usuario
      AND    tp_transacao = 'DESPESA'
      AND  ( (fl_recorrente = 'N' AND dt_transacao >= v_ini AND dt_transacao < ADD_MONTHS(v_ini, 1))
          OR (fl_recorrente = 'S' AND dt_transacao < ADD_MONTHS(v_ini, 1)) )
      GROUP  BY ds_categoria
      ORDER  BY total DESC;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE BETWEEN -20999 AND -20000 THEN
        RAISE;
      END IF;
      RAISE_APPLICATION_ERROR(-20059, 'Erro no relatorio por categoria: ' || SQLERRM);
  END prc_relatorio_categorias;

  ---------------------------------------------------------------------
  -- DYNAMIC SQL 1: OPEN ... FOR <string> USING <binds>
  ---------------------------------------------------------------------
  PROCEDURE prc_resumo_dinamico (
    p_id_usuario  IN  shas_usuario.id_usuario%TYPE,
    p_ano         IN  NUMBER,
    p_mes         IN  NUMBER,
    p_agrupar_por IN  VARCHAR2,
    p_tipo        IN  VARCHAR2,
    p_ordenar_por IN  VARCHAR2,
    p_relatorio   OUT SYS_REFCURSOR)
  IS
    v_ini     DATE;
    -- texto longo/malicioso deve cair na
    -- validacao (ORA-20052/53/54) e nao estourar na declaracao (ORA-06502)
    v_agrupar VARCHAR2(200) := SUBSTR(UPPER(TRIM(p_agrupar_por)), 1, 200);
    v_tipo    VARCHAR2(200) := SUBSTR(UPPER(TRIM(p_tipo)), 1, 200);
    v_ordenar VARCHAR2(200) := NVL(SUBSTR(UPPER(TRIM(p_ordenar_por)), 1, 200), 'TOTAL');
    v_expr    VARCHAR2(30);
    v_order   VARCHAR2(30);
    v_sql     VARCHAR2(2000);
  BEGIN
    IF p_mes NOT BETWEEN 1 AND 12 THEN
      RAISE_APPLICATION_ERROR(-20051, 'Mes invalido: ' || p_mes);
    END IF;

   
    v_expr := CASE v_agrupar
                WHEN 'CATEGORIA'  THEN 'ds_categoria'
                WHEN 'TIPO'       THEN 'tp_transacao'
                WHEN 'RECORRENTE' THEN 'fl_recorrente'
              END;
    IF v_expr IS NULL THEN
      RAISE_APPLICATION_ERROR(-20052,
        'Agrupamento invalido. Use CATEGORIA, TIPO ou RECORRENTE.');
    END IF;

    IF v_tipo IS NOT NULL AND v_tipo NOT IN ('RENDA', 'DESPESA') THEN
      RAISE_APPLICATION_ERROR(-20053, 'Tipo invalido. Use RENDA, DESPESA ou nulo.');
    END IF;

    v_order := CASE v_ordenar
                 WHEN 'TOTAL' THEN 'total DESC'
                 WHEN 'NOME'  THEN 'grupo ASC'
               END;
    IF v_order IS NULL THEN
      RAISE_APPLICATION_ERROR(-20054, 'Ordenacao invalida. Use TOTAL ou NOME.');
    END IF;

    v_expr := DBMS_ASSERT.SIMPLE_SQL_NAME(v_expr);
    v_ini  := TO_DATE(p_ano || '-' || LPAD(p_mes, 2, '0') || '-01', 'YYYY-MM-DD');

    v_sql :=
         'SELECT ' || v_expr || ' AS grupo,'
      || '       COUNT(*)          AS qtd_lancamentos,'
      || '       SUM(vl_transacao) AS total,'
      || '       ROUND(SUM(vl_transacao) * 100 / SUM(SUM(vl_transacao)) OVER (), 1) AS perc_do_total'
      || '  FROM shas_transacao'
      || ' WHERE id_usuario = :id_usuario'
      || '   AND (:tipo_a IS NULL OR tp_transacao = :tipo_b)'
      || '   AND ((fl_recorrente = ''N'' AND dt_transacao >= :ini_a AND dt_transacao < ADD_MONTHS(:ini_b, 1))'
      || '     OR (fl_recorrente = ''S'' AND dt_transacao < ADD_MONTHS(:ini_c, 1)))'
      || ' GROUP BY ' || v_expr
      || ' ORDER BY ' || v_order;

    OPEN p_relatorio FOR v_sql
      USING p_id_usuario, v_tipo, v_tipo, v_ini, v_ini, v_ini;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE BETWEEN -20999 AND -20000 THEN
        RAISE;
      END IF;
      RAISE_APPLICATION_ERROR(-20058, 'Erro no resumo dinamico: ' || SQLERRM);
  END prc_resumo_dinamico;

  ---------------------------------------------------------------------
  -- DYNAMIC SQL 2: EXECUTE IMMEDIATE <string> INTO <variavel>
  ---------------------------------------------------------------------
  FUNCTION fun_contar_registros (
    p_tabela IN VARCHAR2)
  RETURN NUMBER
  IS
    v_tabela VARCHAR2(200) := SUBSTR(UPPER(TRIM(p_tabela)), 1, 200);
    v_existe NUMBER;
    v_qtd    NUMBER;
  BEGIN
    SELECT COUNT(*)
    INTO   v_existe
    FROM   user_tables
    WHERE  table_name = v_tabela
    AND    table_name LIKE 'SHAS\_%' ESCAPE '\';

    IF v_existe = 0 THEN
      RAISE_APPLICATION_ERROR(-20055, 'Tabela nao permitida ou inexistente: ' || p_tabela);
    END IF;

    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || DBMS_ASSERT.SIMPLE_SQL_NAME(v_tabela)
      INTO v_qtd;

    RETURN v_qtd;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE BETWEEN -20999 AND -20000 THEN
        RAISE;
      END IF;
      RAISE_APPLICATION_ERROR(-20056, 'Erro ao contar registros: ' || SQLERRM);
  END fun_contar_registros;

END pkg_shas_relatorio;
/

-- =====================================================================
-- VERIFICACAO (somente leitura)
-- =====================================================================

-- V1: esperado 6 linhas, todas VALID (3 PACKAGE + 3 PACKAGE BODY)
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_name LIKE 'PKG_SHAS%'
ORDER  BY object_name, object_type;

-- V2: esperado NENHUMA linha (sem erros de compilacao)
SELECT name, type, line, position, text
FROM   user_errors
WHERE  name LIKE 'PKG_SHAS%'
ORDER  BY name, type, sequence;

-- V3: package x rotina solta devem devolver o MESMO resultado
SELECT u.nm_usuario,
       fun_shas_saldo_previsto(u.id_usuario, 2026, 10)      AS saldo_solta,
       pkg_shas_calculo.fun_saldo_previsto(u.id_usuario, 2026, 10) AS saldo_package
FROM   shas_usuario u
ORDER  BY u.nm_usuario;

SELECT u.nm_usuario,
       pkg_shas_calculo.fun_resumo_mes(u.id_usuario, 2026, 10) AS resumo_package
FROM   shas_usuario u
ORDER  BY u.nm_usuario;

SELECT u.nm_usuario, m.nm_meta, m.vl_alvo,
       fun_shas_progresso_meta(m.id_meta)              AS progresso_solta,
       pkg_shas_calculo.fun_progresso_meta(m.id_meta)  AS progresso_package
FROM   shas_meta m JOIN shas_usuario u ON u.id_usuario = m.id_usuario
ORDER  BY u.nm_usuario;

-- V4: constantes publicas do package (variavel/constante global)
-- constante de package so pode ser lida em PL/SQL
BEGIN
  DBMS_OUTPUT.PUT_LINE('Formato de moeda : ' || pkg_shas_calculo.c_fmt_moeda);
  DBMS_OUTPUT.PUT_LINE('Limite de alerta : ' || pkg_shas_calculo.c_limite_alerta * 100 || '%');
END;
/

-- V5: tratamento de erro do package
-- esperado: texto 'Mes invalido: 13' (nao gera erro)
SELECT pkg_shas_calculo.fun_resumo_mes('uid-ana-001', 2026, 13) AS teste_erro FROM dual;
-- esperado: ORA-20001
SELECT pkg_shas_calculo.fun_saldo_previsto('uid-ana-001', 2026, 13) AS teste_erro FROM dual;
-- esperado: ORA-20040
SELECT pkg_shas_calculo.fun_progresso_meta('meta-inexistente') AS teste_erro FROM dual;

-- V6: relatorio por categoria via package
DECLARE
  v_rc    SYS_REFCURSOR;
  v_cat   shas_transacao.ds_categoria%TYPE;
  v_qtd   NUMBER;
  v_total NUMBER;
  v_perc  NUMBER;
BEGIN
  pkg_shas_relatorio.prc_relatorio_categorias('uid-ana-001', 2026, 10, v_rc);
  DBMS_OUTPUT.PUT_LINE(RPAD('CATEGORIA', 14) || RPAD('QTD', 6) || RPAD('TOTAL', 12) || '% DO TOTAL');
  LOOP
    FETCH v_rc INTO v_cat, v_qtd, v_total, v_perc;
    EXIT WHEN v_rc%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(RPAD(v_cat, 14) || RPAD(v_qtd, 6) ||
                         RPAD(TO_CHAR(v_total, 'FM999990D00'), 12) || v_perc || '%');
  END LOOP;
  CLOSE v_rc;
END;
/

-- V7: prc_resumo_dinamico com varias combinacoes (um unico bloco)
DECLARE
  PROCEDURE mostra (p_titulo VARCHAR2, p_agrupar VARCHAR2, p_tipo VARCHAR2, p_ordenar VARCHAR2) IS
    v_rc    SYS_REFCURSOR;
    v_grupo VARCHAR2(60);
    v_qtd   NUMBER;
    v_total NUMBER;
    v_perc  NUMBER;
  BEGIN
    DBMS_OUTPUT.PUT_LINE('--- ' || p_titulo);
    pkg_shas_relatorio.prc_resumo_dinamico('uid-ana-001', 2026, 10,
                                           p_agrupar, p_tipo, p_ordenar, v_rc);
    LOOP
      FETCH v_rc INTO v_grupo, v_qtd, v_total, v_perc;
      EXIT WHEN v_rc%NOTFOUND;
      DBMS_OUTPUT.PUT_LINE('   ' || RPAD(v_grupo, 14) || RPAD(v_qtd, 6) ||
                           RPAD(TO_CHAR(v_total, 'FM999990D00'), 12) || v_perc || '%');
    END LOOP;
    CLOSE v_rc;
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('   ERRO: ' || SQLERRM);
  END mostra;
BEGIN
  mostra('1) CATEGORIA / DESPESA / TOTAL', 'CATEGORIA', 'DESPESA', 'TOTAL');
  mostra('2) TIPO / todos / TOTAL',        'TIPO',      NULL,      'TOTAL');
  mostra('3) RECORRENTE / todos / NOME',   'RECORRENTE', NULL,     'NOME');
  mostra('4) agrupamento malicioso',       'ds_categoria; DROP TABLE shas_usuario', NULL, NULL);
  mostra('5) tipo invalido',               'TIPO',      'XYZ',     NULL);
  mostra('6) ordenacao maliciosa',         'TIPO',      NULL,      'total; --');
END;
/

-- V8: fun_contar_registros (EXECUTE IMMEDIATE ... INTO) chamada pelo SQL
-- esperado: as tabelas SHAS_* (incluindo SHAS_LOG_TRANSACAO) com suas contagens
SELECT table_name,
       pkg_shas_relatorio.fun_contar_registros(table_name) AS qtd_registros
FROM   user_tables
WHERE  table_name LIKE 'SHAS\_%' ESCAPE '\'
ORDER  BY table_name;

-- V9: tabelas barradas pela validacao (cada uma deve gerar ORA-20055)
SELECT pkg_shas_relatorio.fun_contar_registros('USER_TABLES') AS teste_erro FROM dual;
SELECT pkg_shas_relatorio.fun_contar_registros('SHAS_USUARIO WHERE 1=1; DROP TABLE x') AS teste_erro FROM dual;
