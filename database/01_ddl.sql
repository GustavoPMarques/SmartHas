-- para recriar do zero:
-- DROP TABLE shas_alerta    CASCADE CONSTRAINTS PURGE;
-- DROP TABLE shas_meta      CASCADE CONSTRAINTS PURGE;
-- DROP TABLE shas_transacao CASCADE CONSTRAINTS PURGE;
-- DROP TABLE shas_usuario   CASCADE CONSTRAINTS PURGE;

-- Usuário (chave = UID do Firebase)
CREATE TABLE shas_usuario (
  id_usuario   VARCHAR2(128) NOT NULL,
  nm_usuario   VARCHAR2(100),
  ds_email     VARCHAR2(100),
  dt_cadastro  DATE DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_shas_usuario       PRIMARY KEY (id_usuario),
  CONSTRAINT uk_shas_usuario_email UNIQUE (ds_email)
);


CREATE TABLE shas_transacao (
  id_transacao   VARCHAR2(36)  NOT NULL,
  id_usuario     VARCHAR2(128) NOT NULL,
  ds_titulo      VARCHAR2(120) NOT NULL,
  vl_transacao   NUMBER(12,2)  NOT NULL,
  dt_transacao   DATE          NOT NULL,
  tp_transacao   VARCHAR2(10)  NOT NULL,
  ds_categoria   VARCHAR2(60)  NOT NULL,
  fl_recorrente  CHAR(1) DEFAULT 'N' NOT NULL,
  nr_parcelas    NUMBER(3) DEFAULT 1 NOT NULL,
  CONSTRAINT pk_shas_transacao       PRIMARY KEY (id_transacao),
  CONSTRAINT fk_shas_transacao_usr   FOREIGN KEY (id_usuario) REFERENCES shas_usuario (id_usuario),
  CONSTRAINT ck_shas_transacao_valor CHECK (vl_transacao > 0),
  CONSTRAINT ck_shas_transacao_tipo  CHECK (tp_transacao IN ('RENDA','DESPESA')),
  CONSTRAINT ck_shas_transacao_rec   CHECK (fl_recorrente IN ('S','N')),
  CONSTRAINT ck_shas_transacao_parc  CHECK (nr_parcelas >= 1)
);

CREATE INDEX ix_shas_transacao_usr_dt ON shas_transacao (id_usuario, dt_transacao);


CREATE TABLE shas_meta (
  id_meta     VARCHAR2(36)  NOT NULL,
  id_usuario  VARCHAR2(128) NOT NULL,
  nm_meta     VARCHAR2(100) NOT NULL,
  vl_alvo     NUMBER(12,2)  NOT NULL,
  dt_criacao  DATE DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_shas_meta     PRIMARY KEY (id_meta),
  CONSTRAINT fk_shas_meta_usr FOREIGN KEY (id_usuario) REFERENCES shas_usuario (id_usuario),
  CONSTRAINT ck_shas_meta_vl  CHECK (vl_alvo > 0)
);


CREATE TABLE shas_alerta (
  id_alerta    NUMBER GENERATED ALWAYS AS IDENTITY,
  id_usuario   VARCHAR2(128) NOT NULL,
  nr_ano       NUMBER(4)     NOT NULL,
  nr_mes       NUMBER(2)     NOT NULL,
  tp_alerta    VARCHAR2(30)  NOT NULL,
  ds_mensagem  VARCHAR2(200) NOT NULL,
  dt_alerta    DATE DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_shas_alerta     PRIMARY KEY (id_alerta),
  CONSTRAINT fk_shas_alerta_usr FOREIGN KEY (id_usuario) REFERENCES shas_usuario (id_usuario)
);

COMMENT ON TABLE shas_usuario   IS 'Usuários do Smart HAS (UID do Firebase)';
COMMENT ON TABLE shas_transacao IS 'Rendas e despesas, com recorrência e parcelas';
COMMENT ON TABLE shas_meta      IS 'Metas financeiras do usuário';
COMMENT ON TABLE shas_alerta    IS 'Alertas gerados pelas procedures PL/SQL';
