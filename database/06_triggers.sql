-- =====================================================================
-- 06_triggers.sql: triggers do Smart HAS (Etapa 2)
-- Execute DEPOIS do 05_packages.sql, como SCRIPT (F5).
-- =====================================================================
SET SERVEROUTPUT ON;

-- =====================================================================
-- 1) Tabela de log de auditoria
-- =====================================================================
DECLARE
  v_qtd NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_qtd FROM user_tables WHERE table_name = 'SHAS_LOG_TRANSACAO';
  IF v_qtd = 0 THEN
    EXECUTE IMMEDIATE '
      CREATE TABLE shas_log_transacao (
        id_log            NUMBER GENERATED ALWAYS AS IDENTITY,
        id_transacao      VARCHAR2(36)  NOT NULL,
        id_usuario        VARCHAR2(128) NOT NULL,
        tp_operacao       VARCHAR2(10)  NOT NULL,
        ds_titulo_antigo  VARCHAR2(120),
        ds_titulo_novo    VARCHAR2(120),
        vl_antigo         NUMBER(12,2),
        vl_novo           NUMBER(12,2),
        ds_categoria_ant  VARCHAR2(60),
        ds_categoria_nova VARCHAR2(60),
        ds_usuario_bd     VARCHAR2(128) NOT NULL,
        dt_log            TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
        CONSTRAINT pk_shas_log_transacao PRIMARY KEY (id_log),
        CONSTRAINT ck_shas_log_operacao  CHECK (tp_operacao IN (''INSERT'',''UPDATE'',''DELETE''))
      )';
    EXECUTE IMMEDIATE 'CREATE INDEX ix_shas_log_transacao_id ON shas_log_transacao (id_transacao)';
    DBMS_OUTPUT.PUT_LINE('Tabela SHAS_LOG_TRANSACAO criada.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Tabela SHAS_LOG_TRANSACAO ja existe: nada a fazer.');
  END IF;
END;
/

COMMENT ON TABLE shas_log_transacao IS 'Auditoria de INSERT/UPDATE/DELETE em SHAS_TRANSACAO (preenchida pela trigger TRG_SHAS_AUDITA_TRANSACAO)';

-- =====================================================================
-- 2) TRG_SHAS_AUDITA_TRANSACAO
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_shas_audita_transacao
AFTER INSERT OR UPDATE OR DELETE ON shas_transacao
FOR EACH ROW
DECLARE
  v_operacao shas_log_transacao.tp_operacao%TYPE;
BEGIN
  IF INSERTING THEN
    v_operacao := 'INSERT';
  ELSIF UPDATING THEN
    v_operacao := 'UPDATE';
  ELSE
    v_operacao := 'DELETE';
  END IF;

  INSERT INTO shas_log_transacao
    (id_transacao, id_usuario, tp_operacao,
     ds_titulo_antigo, ds_titulo_novo,
     vl_antigo, vl_novo,
     ds_categoria_ant, ds_categoria_nova,
     ds_usuario_bd)
  VALUES
    (COALESCE(:NEW.id_transacao, :OLD.id_transacao),
     COALESCE(:NEW.id_usuario,   :OLD.id_usuario),
     v_operacao,
     :OLD.ds_titulo,    :NEW.ds_titulo,
     :OLD.vl_transacao, :NEW.vl_transacao,
     :OLD.ds_categoria, :NEW.ds_categoria,
     SYS_CONTEXT('USERENV', 'SESSION_USER'));
END trg_shas_audita_transacao;
/

-- =====================================================================
-- status do alerta
-- =====================================================================
DECLARE
  v_qtd NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_qtd
  FROM   user_tab_columns
  WHERE  table_name = 'SHAS_ALERTA' AND column_name = 'ST_ALERTA';

  IF v_qtd = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE shas_alerta ADD (st_alerta VARCHAR2(10) DEFAULT ''NOVO'' NOT NULL, dt_leitura DATE)';
    EXECUTE IMMEDIATE 'ALTER TABLE shas_alerta ADD CONSTRAINT ck_shas_alerta_status CHECK (st_alerta IN (''NOVO'',''LIDO''))';
    DBMS_OUTPUT.PUT_LINE('Colunas ST_ALERTA e DT_LEITURA adicionadas em SHAS_ALERTA.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Colunas ja existem em SHAS_ALERTA: nada a fazer.');
  END IF;
END;
/

COMMENT ON COLUMN shas_alerta.st_alerta  IS 'Status do alerta: NOVO ou LIDO';
COMMENT ON COLUMN shas_alerta.dt_leitura IS 'Data/hora em que o alerta foi marcado como LIDO (preenchida pela trigger)';

-- =====================================================================
-- 4) TRG_SHAS_ALERTA_STATUS
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_shas_alerta_status
BEFORE UPDATE OF st_alerta ON shas_alerta
FOR EACH ROW
BEGIN
  IF :NEW.st_alerta = 'LIDO' AND :OLD.st_alerta <> 'LIDO' THEN
    :NEW.dt_leitura := SYSDATE;
  ELSIF :NEW.st_alerta = 'NOVO' THEN
    :NEW.dt_leitura := NULL;
  END IF;
END trg_shas_alerta_status;
/

-- =====================================================================
-- VERIFICACAO
-- =====================================================================

-- V1: esperado 2 triggers ENABLED / VALID
SELECT trigger_name, table_name, triggering_event, trigger_type, status
FROM   user_triggers
WHERE  trigger_name LIKE 'TRG_SHAS%'
ORDER  BY trigger_name;

-- V2: esperado NENHUMA linha (sem erros de compilacao)
SELECT name, type, line, position, text
FROM   user_errors
WHERE  name LIKE 'TRG_SHAS%'
ORDER  BY name, sequence;

-- V3: o Java continua lendo os alertas normalmente (colunas novas com padrao NOVO)
SELECT id_alerta, tp_alerta, st_alerta, dt_leitura FROM shas_alerta ORDER BY id_alerta;

-- =====================================================================
-- TESTE DA TRIGGER DE AUDITORIA
-- Faz INSERT, UPDATE e DELETE de uma transacao de teste, mostra o log e
-- termina com ROLLBACK, entao NAO deixa dados no banco.
-- (rode o bloco inteiro, do INSERT ate o ROLLBACK, de uma vez)
-- =====================================================================
INSERT INTO shas_transacao
  (id_transacao, id_usuario, ds_titulo, vl_transacao, dt_transacao, tp_transacao, ds_categoria)
VALUES
  ('teste-trg-001', 'uid-ana-001', 'Teste auditoria', 100.00, SYSDATE, 'DESPESA', 'Lazer');

UPDATE shas_transacao
SET    vl_transacao = 150.00, ds_titulo = 'Teste auditoria (editado)'
WHERE  id_transacao = 'teste-trg-001';

DELETE FROM shas_transacao WHERE id_transacao = 'teste-trg-001';

-- esperado: 3 linhas (INSERT, UPDATE, DELETE), nessa ordem
SELECT id_log, tp_operacao, ds_titulo_antigo, ds_titulo_novo, vl_antigo, vl_novo,
       ds_usuario_bd, TO_CHAR(dt_log, 'DD/MM/YYYY HH24:MI:SS') AS dt_log
FROM   shas_log_transacao
WHERE  id_transacao = 'teste-trg-001'
ORDER  BY id_log;

ROLLBACK;

-- esperado: 0 (o ROLLBACK desfez a transacao de teste E o seu log)
SELECT COUNT(*) AS logs_restantes FROM shas_log_transacao WHERE id_transacao = 'teste-trg-001';

-- =====================================================================
-- TESTE DA TRIGGER DE STATUS DO ALERTA (tambem termina com ROLLBACK)
-- =====================================================================
INSERT INTO shas_alerta (id_usuario, nr_ano, nr_mes, tp_alerta, ds_mensagem)
VALUES ('uid-ana-001', 2026, 10, 'TESTE_TRG', 'Alerta de teste da trigger');

-- esperado: ST_ALERTA = NOVO, DT_LEITURA vazia
SELECT tp_alerta, st_alerta, dt_leitura FROM shas_alerta WHERE tp_alerta = 'TESTE_TRG';

UPDATE shas_alerta SET st_alerta = 'LIDO' WHERE tp_alerta = 'TESTE_TRG';

-- esperado: ST_ALERTA = LIDO, DT_LEITURA preenchida automaticamente
SELECT tp_alerta, st_alerta, TO_CHAR(dt_leitura, 'DD/MM/YYYY HH24:MI:SS') AS dt_leitura
FROM   shas_alerta WHERE tp_alerta = 'TESTE_TRG';

UPDATE shas_alerta SET st_alerta = 'NOVO' WHERE tp_alerta = 'TESTE_TRG';

-- esperado: ST_ALERTA = NOVO, DT_LEITURA vazia de novo
SELECT tp_alerta, st_alerta, dt_leitura FROM shas_alerta WHERE tp_alerta = 'TESTE_TRG';

ROLLBACK;

-- esperado: 0
SELECT COUNT(*) AS alertas_teste_restantes FROM shas_alerta WHERE tp_alerta = 'TESTE_TRG';
