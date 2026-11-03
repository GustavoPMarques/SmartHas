WHENEVER SQLERROR EXIT FAILURE
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

DECLARE
  v_total  NUMBER := 0;
  v_falhas NUMBER := 0;

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
BEGIN
  check_('3 packages + 3 package bodies VALID',
         cnt(q'[SELECT COUNT(*) FROM user_objects
                WHERE object_name IN ('PKG_SHAS_CALCULO','PKG_SHAS_OPERACAO','PKG_SHAS_RELATORIO')
                AND object_type IN ('PACKAGE','PACKAGE BODY') AND status = 'VALID']') = 6);
  check_('2 triggers ENABLED',
         cnt(q'[SELECT COUNT(*) FROM user_triggers
                WHERE trigger_name IN ('TRG_SHAS_AUDITA_TRANSACAO','TRG_SHAS_ALERTA_STATUS')
                AND status = 'ENABLED']') = 2);
  check_('nenhum objeto SHAS fora de VALID',
         cnt(q'[SELECT COUNT(*) FROM user_objects
                WHERE object_name LIKE '%SHAS%' AND status <> 'VALID']') = 0);
  check_('nenhum erro de compilacao nos objetos SHAS',
         cnt(q'[SELECT COUNT(*) FROM user_errors WHERE name LIKE '%SHAS%']') = 0);
  check_('tabelas SHAS_* existem (5)',
         cnt(q'[SELECT COUNT(*) FROM user_tables WHERE table_name LIKE 'SHAS\_%' ESCAPE '\']') = 5);

  DBMS_OUTPUT.PUT_LINE('RESULTADO: ' || v_total || ' verificacoes, ' || v_falhas || ' falha(s)');
  IF v_falhas > 0 THEN
    RAISE_APPLICATION_ERROR(-20999, v_falhas || ' verificacao(oes) falharam');
  END IF;
END;
/

EXIT 0
