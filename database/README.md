# Smart HAS: camada Oracle (Fase 6)

Esta pasta traz a camada de banco **Oracle PL/SQL** do Smart HAS: modelo de dados, carga de dados simulados, **functions** e **procedures**. Ela convive com o Firestore: o app continua gravando no Firestore e, quando a integração está ligada, o back-end Java também registra cada transação nova no Oracle, onde as regras de saldo e de alertas são calculadas em PL/SQL.

## Conteúdo da pasta

| Arquivo | O que faz |
|---|---|
| `01_ddl.sql` | Cria as 4 tabelas, chaves, restrições, índice e comentários |
| `02_dados.sql` | Carga de dados simulados: 3 usuários, 165 transações e 3 metas |
| `03_functions.sql` | As 2 functions, com testes de uso dentro de consultas SQL |
| `04_procedures.sql` | As 2 procedures, com 5 testes e a consulta dos alertas gerados |
| `modelo/DER_SmartHAS.png` | Diagrama entidade-relacionamento (modelo relacional) |

> Os scripts estão **sem acentos de propósito**, para evitar problemas de codificação no SQL Developer.

## Modelo de dados

![DER](modelo/DER-SmartHas.png)

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
3. **`03_functions.sql`**: compila as 2 functions e roda a consulta de exemplo.
4. **`04_procedures.sql`**: compila as 2 procedures e executa os testes.

Para recomeçar do zero, descomente as linhas `DROP TABLE` no início do `01_ddl.sql`.

## Functions

| Function | Retorno | O que faz |
|---|---|---|
| `fun_shas_saldo_previsto(p_id_usuario, p_ano, p_mes)` | `NUMBER` | **Indicador:** saldo previsto até o fim do mês. Renda soma, despesa subtrai, e transações recorrentes contam uma vez por mês (mesma regra do `calcularResumo` do back-end Java) |
| `fun_shas_resumo_mes(p_id_usuario, p_ano, p_mes)` | `VARCHAR2` | **Dado formatado:** texto com rendas, despesas, saldo do mês e saldo previsto, em reais |

Uso em consulta SQL:

```sql
SELECT u.nm_usuario,
       fun_shas_saldo_previsto(u.id_usuario, 2026, 10) AS saldo_previsto,
       fun_shas_resumo_mes(u.id_usuario, 2026, 10)     AS resumo
FROM   shas_usuario u;
```

Tratamento de erros: mês fora de 1 a 12 gera `ORA-20001` na primeira function, e a segunda devolve a mensagem em texto, para não derrubar uma consulta com várias linhas.

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

### Códigos de erro

| Código | Significado |
|---|---|
| `-20001` | Mês inválido (function de saldo) |
| `-20010` / `-20011` / `-20012` / `-20013` | Tipo, valor, parcelas ou parâmetros obrigatórios inválidos |
| `-20019` | Erro inesperado ao registrar a transação |
| `-20030` / `-20039` | Mês inválido / erro inesperado na rotina de alertas |

> Os testes do `04_procedures.sql` **inserem linhas** (parcelas de exemplo e alertas). Para repetir, use as linhas de limpeza comentadas no final do arquivo.

## Integração com o back-end Java

```
App (React Native) / Angular
        │  POST /api/v1/transacoes
        ▼
  Spring Boot (TransacaoService)
        │  1) grava no Firestore
        │  2) JDBC → prc_shas_registra_transacao (Oracle)
        ▼
     Oracle  →  tabelas, functions e procedures
```

Classes envolvidas no back-end (`backend-api/smarthas-api`):

- `repository/OracleFinanceiroRepository`: chama as procedures e as functions via JDBC.
- `service/TransacaoService`: após salvar no Firestore, aciona a procedure.
- `controller/OracleController`: expõe os resultados do Oracle por API.

Endpoints (todos exigem o token do Firebase no cabeçalho `Authorization: Bearer ...`):

| Método | Rota | Usa |
|---|---|---|
| GET | `/api/v1/oracle/resumo/{ano}/{mes}` | as 2 functions |
| GET | `/api/v1/oracle/alertas` | consulta os alertas do usuário |
| POST | `/api/v1/oracle/alertas/gerar/{ano}/{mes}` | procedure em lote |

### Ligando a integração

A integração vem **desligada por padrão**. Para ligar, defina estas variáveis de ambiente ao rodar o back-end (no IntelliJ: *Run > Edit Configurations > Environment variables*):

| Variável | Valor |
|---|---|
| `ORACLE_ENABLED` | `true` |
| `ORACLE_USER` | usuário do Oracle (ex.: `RM` + matrícula) |
| `ORACLE_PASSWORD` | senha do Oracle |
| `ORACLE_URL` | opcional (padrão: `jdbc:oracle:thin:@oracle.fiap.com.br:1521:ORCL`) |

**Nunca versione senha ou credenciais.** Se o Oracle estiver indisponível, o app continua funcionando normalmente: a falha é só registrada no log.

## Limitações conhecidas

- O Oracle recebe apenas transações **novas**. Edição e exclusão feitas no app não são sincronizadas, e dados antigos do Firestore não foram carregados.
- O alerta de saldo negativo avalia apenas o mês da primeira parcela, não os meses seguintes de uma compra parcelada.
- O endpoint em lote vale para todos os usuários, não só para o logado.