
SET SERVEROUTPUT ON;

--para recarregar do zero, descomente:
-- DELETE FROM shas_alerta;
-- DELETE FROM shas_meta;
-- DELETE FROM shas_transacao;
-- DELETE FROM shas_usuario;
-- COMMIT;


INSERT INTO shas_usuario (id_usuario, nm_usuario, ds_email) VALUES ('uid-ana-001',   'Ana Souza',  'ana@email.com');
INSERT INTO shas_usuario (id_usuario, nm_usuario, ds_email) VALUES ('uid-bruno-002', 'Bruno Lima', 'bruno@email.com');
INSERT INTO shas_usuario (id_usuario, nm_usuario, ds_email) VALUES ('uid-carla-003', 'Carla Dias', 'carla@email.com');


INSERT INTO shas_meta (id_meta, id_usuario, nm_meta, vl_alvo) VALUES (LOWER(RAWTOHEX(SYS_GUID())), 'uid-ana-001',   'Viagem de ferias',  8000);
INSERT INTO shas_meta (id_meta, id_usuario, nm_meta, vl_alvo) VALUES (LOWER(RAWTOHEX(SYS_GUID())), 'uid-bruno-002', 'Reserva de emergencia', 15000);
INSERT INTO shas_meta (id_meta, id_usuario, nm_meta, vl_alvo) VALUES (LOWER(RAWTOHEX(SYS_GUID())), 'uid-carla-003', 'Entrada do apartamento', 40000);


DECLARE
  v_ini DATE;
  v_cat VARCHAR2(30);
BEGIN
  FOR u IN (SELECT id_usuario,
                   CASE id_usuario WHEN 'uid-ana-001'   THEN 4200
                                   WHEN 'uid-bruno-002' THEN 2800
                                   ELSE 6500 END AS vl_salario
            FROM   shas_usuario) LOOP

    
    INSERT INTO shas_transacao
      (id_transacao, id_usuario, ds_titulo, vl_transacao, dt_transacao,
       tp_transacao, ds_categoria, fl_recorrente, nr_parcelas)
    VALUES
      (LOWER(RAWTOHEX(SYS_GUID())), u.id_usuario, 'Aluguel', 1500,
       ADD_MONTHS(TRUNC(SYSDATE,'MM'), -5) + 4, 'DESPESA', 'Moradia', 'S', 1);

    FOR m IN 0..5 LOOP
      v_ini := ADD_MONTHS(TRUNC(SYSDATE,'MM'), -m);

      
      INSERT INTO shas_transacao
        (id_transacao, id_usuario, ds_titulo, vl_transacao, dt_transacao,
         tp_transacao, ds_categoria, fl_recorrente, nr_parcelas)
      VALUES
        (LOWER(RAWTOHEX(SYS_GUID())), u.id_usuario, 'Salario', u.vl_salario,
         v_ini + 4, 'RENDA', 'Salario', 'N', 1);

      
      FOR d IN 1..8 LOOP
        v_cat := CASE MOD(d,4) WHEN 0 THEN 'Alimentacao'
                               WHEN 1 THEN 'Transporte'
                               WHEN 2 THEN 'Lazer'
                               ELSE 'Saude' END;
        INSERT INTO shas_transacao
          (id_transacao, id_usuario, ds_titulo, vl_transacao, dt_transacao,
           tp_transacao, ds_categoria, fl_recorrente, nr_parcelas)
        VALUES
          (LOWER(RAWTOHEX(SYS_GUID())), u.id_usuario, v_cat || ' ' || d,
           ROUND(DBMS_RANDOM.VALUE(30,450),2),
           v_ini + TRUNC(DBMS_RANDOM.VALUE(0,27)),
           'DESPESA', v_cat, 'N', 1);
      END LOOP;
    END LOOP;
  END LOOP;
  COMMIT;
END;
/


SELECT 'USUARIOS' AS tabela, COUNT(*) AS qtd FROM shas_usuario
UNION ALL SELECT 'TRANSACOES', COUNT(*) FROM shas_transacao
UNION ALL SELECT 'METAS',      COUNT(*) FROM shas_meta;


SELECT u.nm_usuario,
       COUNT(*)                                                  AS qtd_transacoes,
       SUM(CASE WHEN t.tp_transacao = 'RENDA'   THEN t.vl_transacao END) AS total_rendas,
       SUM(CASE WHEN t.tp_transacao = 'DESPESA' THEN t.vl_transacao END) AS total_despesas
FROM   shas_usuario u JOIN shas_transacao t ON t.id_usuario = u.id_usuario
GROUP  BY u.nm_usuario
ORDER  BY u.nm_usuario;
