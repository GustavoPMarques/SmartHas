# Smart HAS: camada Oracle (Fase 6)

Esta pasta traz a camada de banco **Oracle PL/SQL** do Smart HAS: modelo de dados, carga de dados simulados, **3 functions** e **3 procedures**. Ela convive com o Firestore: o app continua gravando no Firestore e, quando a integração está ligada, o back-end Java também registra no Oracle cada transação e cada meta nova, e as regras de saldo, alertas e relatórios são calculadas em PL/SQL.

## Conteúdo da pasta

| Arquivo | O que faz |
|---|---|
| `01_ddl.sql` | Cria as 4 tabelas, chaves, restrições, índice e comentários |
| `02_dados.sql` | Carga de dados simulados: 3 usuários, 165 transações e 3 metas |
| `03_functions.sql` | As 3 functions, com testes de uso dentro de consultas SQL |
| `04_procedures.sql` | As 3 procedures, com 7 testes e a consulta dos alertas gerados |
| `modelo/DER_SmartHAS.png` | Diagrama entidade-relacionamento (modelo relacional) |

> Os scripts estão **sem acentos de propósito**, para evitar problemas de codificação no SQL Developer.

## Modelo de dados

![DER](modelo/DER%20-%20SmartHas.png)

| Tabela | Descrição |
|---|---|
| `SHAS_USUARIO` | Usuários. A chave `id_usuario` é o **UID do Firebase** |
| `SHAS_TRANSACAO` | Rendas e despesas, com categoria, recorrência e parcelas |
| `SHAS_META` | Metas financeiras do usuário |
| `SHAS_ALERTA` | Alertas gerados pelas procedures |

Um usuário tem várias transações, metas e alertas (relacionamentos 1:N).

## Como executar

Pré-requisito: Oracle SQL Developer conectado ao Oracle (no ambiente da FIAP: host `oracle.fiap.com.br`, porta `1521`, SID `ORCL`, usuário `RM` + matrícula).

Execute cada arquivo como **script** (F5), nesta ordem:

1. **`01_ddl.sql`**: deve criar as 4 tabelas. Confira com:
   ```sql
   SELECT table_name FROM user_tables WHERE table_name LIKE 'SHAS%';
   ```
2. **`02_dados.sql`**: carrega os dados. A consulta ao final deve mostrar **3 usuários, 165 transações e 3 metas**. Os valores em reais variam a cada carga, porque as despesas são geradas aleatoriamente.
3. **`03_functions.sql`**: compila as 3 functions e roda as consultas de exemplo.
4. **`04_procedures.sql`**: compila as 3 procedures e executa os testes.

Para recomeçar do zero, descomente as linhas `DROP TABLE` no início do `01_ddl.sql`.

## Functions

| Function | Retorno | O que faz |
|---|---|---|
| `fun_shas_saldo_previsto(p_id_usuario, p_ano, p_mes)` | `NUMBER` | **Indicador:** saldo previsto até o fim do mês. Renda soma, despesa subtrai, e transações recorrentes contam uma vez por mês (mesma regra do `calcularResumo` do back-end Java) |
| `fun_shas_resumo_mes(p_id_usuario, p_ano, p_mes)` | `VARCHAR2` | **Dado formatado:** texto com rendas, despesas, saldo do mês e saldo previsto, em reais |
| `fun_shas_progresso_meta(p_id_meta)` | `NUMBER` | **Indicador:** percentual (de 0 a 100, com 1 casa decimal) da meta coberto pelo saldo previsto do mês atual do dono dela. Reaproveita a function 1 |

Uso em consulta SQL:

```sql
SELECT u.nm_usuario,
       fun_shas_saldo_previsto(u.id_usuario, 2026, 10) AS saldo_previsto,
       fun_shas_resumo_mes(u.id_usuario, 2026, 10)     AS resumo
FROM   shas_usuario u;

SELECT m.nm_meta, m.vl_alvo, fun_shas_progresso_meta(m.id_meta) AS progresso_pct
FROM   shas_meta m;
```

Tratamento de erros: mês fora de 1 a 12 gera `ORA-20001` na primeira function; a segunda devolve a mensagem em texto, para não derrubar uma consulta com várias linhas; meta inexistente gera `ORA-20040` na terceira.

## Procedures

### `prc_shas_registra_transacao` (acionada pelo Java)

Registra uma transação, gera uma linha por parcela (`LOOP`) e confere o saldo previsto do mês. Se ficar negativo, grava um alerta `SALDO_NEGATIVO`. Cria o usuário no Oracle se for o primeiro acesso.

- **Entrada:** usuário, título, valor, data, tipo (`RENDA`/`DESPESA`), categoria, recorrente (`S`/`N`) e parcelas.
- **Saída (`OUT`):** `p_qtd_gerada` (parcelas criadas) e `p_alerta` (`OK` ou `SALDO_NEGATIVO`).

### `prc_shas_gera_alertas_mensais` (rotina em lote)

Percorre todos os usuários com um `CURSOR` e cria alertas do mês informado:

| Alerta | Condição |
|---|---|
| `DESPESAS_MAIOR_QUE_RENDA` | despesas do mês superam as rendas |
| `LIMITE_80_PCT` | despesas chegam a 80% ou mais da renda |

Não duplica alertas (se já existe no mês, ignora) e o erro de um usuário não interrompe os demais. Devolve em `p_qtd_alertas` quantos alertas novos foram criados.

### `prc_shas_relatorio_categorias` (relatório)

Gera o relatório de **despesas do mês por categoria** de um usuário e devolve o resultado em um `SYS_REFCURSOR` (`p_relatorio`), ordenado do maior para o menor gasto. Cada linha traz a categoria, a quantidade de lançamentos, o total e o percentual do total de despesas. Despesas recorrentes contam uma vez no mês, como nas functions.

- **Entrada:** usuário, ano e mês.
- **Saída (`OUT`):** `p_relatorio` (cursor com categoria, quantidade, total e percentual).

### Códigos de erro

| Código | Significado |
|---|---|
| `-20001` | Mês inválido (function de saldo) |
| `-20010` / `-20011` / `-20012` / `-20013` | Tipo, valor, parcelas ou parâmetros obrigatórios inválidos |
| `-20019` | Erro inesperado ao registrar a transação |
| `-20030` / `-20039` | Mês inválido / erro inesperado na rotina de alertas |
| `-20040` / `-20041` | Meta não encontrada / erro no progresso da meta |
| `-20050` / `-20059` | Mês inválido / erro inesperado no relatório por categoria |

> Os testes do `04_procedures.sql` **inserem linhas** (parcelas de exemplo e alertas). Para repetir, use as linhas de limpeza comentadas no final do arquivo: elas só apagam dados dos usuários de teste (`uid-...`).

## Integração com o back-end Java

```
App (React Native) / Angular
        │  POST /api/v1/transacoes   |   POST /api/v1/metas
        ▼
  Spring Boot (TransacaoService / MetaService)
        │  1) grava no Firestore
        │  2) JDBC → Oracle (procedure de transação / registro da meta)
        ▼
     Oracle  →  tabelas, functions e procedures
        ▲
        │  GET /api/v1/oracle/...  (OracleController)
```

Classes envolvidas no back-end (`backend-api/smarthas-api`):

- `repository/OracleFinanceiroRepository`: chama as procedures e as functions via JDBC.
- `service/TransacaoService`: após salvar a transação no Firestore, aciona a procedure.
- `service/MetaService`: após salvar a meta no Firestore, espelha a meta no Oracle.
- `controller/OracleController`: expõe os resultados do Oracle por API.

Endpoints (todos exigem o token do Firebase no cabeçalho `Authorization: Bearer ...`):

| Método | Rota | Usa | Retorno |
|---|---|---|---|
| GET | `/api/v1/oracle/resumo/{ano}/{mes}` | functions 1 e 2 | resumo formatado e saldo previsto |
| GET | `/api/v1/oracle/alertas` | tabela `shas_alerta` | alertas do usuário |
| POST | `/api/v1/oracle/alertas/gerar/{ano}/{mes}` | procedure 2 (lote) | quantidade de alertas criados |
| GET | `/api/v1/oracle/categorias/{ano}/{mes}` | procedure 3 | lista com `categoria`, `lancamentos`, `total` e `percentual` |
| GET | `/api/v1/oracle/metas/progresso` | function 3 | lista com `id`, `nome`, `valorAlvo` e `progresso` |

### Quem aciona cada rotina

| Rotina | Acionada por |
|---|---|
| `prc_shas_registra_transacao` | `POST /api/v1/transacoes` (automático, ao cadastrar uma transação) |
| `prc_shas_gera_alertas_mensais` | `POST /api/v1/oracle/alertas/gerar/{ano}/{mes}` |
| `prc_shas_relatorio_categorias` | `GET /api/v1/oracle/categorias/{ano}/{mes}` |
| `fun_shas_saldo_previsto` | `GET /api/v1/oracle/resumo/{ano}/{mes}` e dentro das demais rotinas |
| `fun_shas_resumo_mes` | `GET /api/v1/oracle/resumo/{ano}/{mes}` |
| `fun_shas_progresso_meta` | `GET /api/v1/oracle/metas/progresso` |

### Ligando a integração

A integração vem **desligada por padrão**. Para ligar, defina estas variáveis de ambiente ao rodar o back-end (no IntelliJ: *Run > Edit Configurations > Environment variables*):

| Variável | Valor |
|---|---|
| `ORACLE_ENABLED` | `true` |
| `ORACLE_USER` | usuário do Oracle (ex.: `RM` + matrícula) |
| `ORACLE_PASSWORD` | senha do Oracle |
| `ORACLE_URL` | opcional (padrão: `jdbc:oracle:thin:@oracle.fiap.com.br:1521:ORCL`) |

**Nunca versione senha ou credenciais.** Se o Oracle estiver indisponível, o app continua funcionando normalmente: a falha é só registrada no log, e os endpoints `/api/v1/oracle/...` respondem 503.

## Limitações conhecidas

- O Oracle recebe apenas transações e metas **novas**. Edição e exclusão feitas no app não são sincronizadas, e dados que já estavam no Firestore antes da integração não foram carregados.
- O Oracle guarda só o UID do usuário: o nome e o e-mail ficam vazios para contas reais do Firebase.
- O alerta de saldo negativo avalia apenas o mês da primeira parcela, não os meses seguintes de uma compra parcelada.
- O endpoint em lote vale para todos os usuários, não só para o logado.
