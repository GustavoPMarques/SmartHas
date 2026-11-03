# Smart HAS: banco de dados Oracle

Camada Oracle PL/SQL do Smart HAS: tabelas `SHAS_*`, packages com as regras de negócio, triggers de auditoria e de status, e rotinas com Dynamic SQL. Todos os scripts são executados e verificados automaticamente pelo [pipeline CI/CD](../PIPELINE.md).

## Estrutura

```
database/
├── 01_*.sql          → criação das tabelas (recria o schema)
├── 02_*.sql          → carga inicial de dados
├── 03_*.sql          → ...
├── 04_*.sql          → ...
├── 05_packages.sql   → 3 packages + bodies (reexecutável)
├── 06_triggers.sql   → 2 triggers (reexecutável)
├── 07_*.sql          → ...
└── ci/
    ├── run_ci.sh          → sobe e aguarda o banco, executa 01 a 07 e grava um log por script
    ├── assert_oracle.sql  → 40 verificações automáticas (reprova o pipeline se alguma falhar)
    └── verify_deploy.sql  → 5 verificações somente leitura pós-deploy
```

<!-- CONFIRMAR: nome real e finalidade dos scripts 01 a 04 e 07 (preencher a tabela abaixo). -->

| Script | Conteúdo |
|---|---|
| `01` | Tabelas `SHAS_*` (5 tabelas). **Recria o schema** |
| `02` | Carga de dados: 3 usuários, 3 metas e 165+ transações. **Recarrega os dados** |
| `03`, `04` | <!-- CONFIRMAR --> Rotinas soltas (procedures/functions) equivalentes aos packages |
| `05_packages.sql` | 3 packages com seus bodies. Reexecutável |
| `06_triggers.sql` | 2 triggers e ajuste em `SHAS_ALERTA` (colunas `ST_ALERTA` e `DT_LEITURA`). Reexecutável |
| `07` | <!-- CONFIRMAR --> Dynamic SQL / cenários |

> ⚠️ Os scripts `01` e `02` **não** rodam no deploy para o Oracle da FIAP, porque recriam tabelas e recarregam dados. No deploy só `05` e `06` são aplicados.

## Modelo de dados

<!-- CONFIRMAR: nomes exatos das tabelas e colunas principais; sugestão: incluir um diagrama ER (Mermaid). -->

Tabelas `SHAS_*` (5): usuários, transações, metas, alertas (`SHAS_ALERTA`) e log de auditoria (`SHAS_LOG_TRANSACAO`).

## Regras de negócio no banco

- **Registro de transações:** simples, parcelado (gera uma transação por parcela) e recorrente. Valor zero é rejeitado com `ORA-20011`.
- **Saldo previsto e resumo do mês** por usuário.
- **Progresso das metas** (ex.: Entrada do apartamento, Reserva de emergência, Viagem de férias).
- **Alertas** (`SHAS_ALERTA`), gerados em lote sem duplicar em chamadas repetidas:
  - `LIMITE_80_PCT`: gasto chegou a 80% do limite;
  - `SALDO_NEGATIVO`: despesa deixa o saldo negativo.
- **Status do alerta:** `NOVO` ou `LIDO`. A trigger de status preenche `DT_LEITURA` ao marcar `LIDO` e limpa ao voltar para `NOVO`.
- **Auditoria:** trigger grava INSERT, UPDATE e DELETE de transações em `SHAS_LOG_TRANSACAO`.
- **Dynamic SQL seguro:** resumo por `TIPO` e `FUN_CONTAR_REGISTROS(tabela)`, com validação de entrada. Agrupamento malicioso é rejeitado com `ORA-20052` e tabela fora da lista permitida (ex.: `USER_TABLES`) com `ORA-20055`.

## Como executar

### Localmente (SQL Developer, SQL\*Plus ou SQLcl)

Conecte no seu schema e execute os scripts em ordem, de `01` a `07`. Os scripts funcionam nos três clientes.

```sql
@01_*.sql
@02_*.sql
-- ... até 07
```

### Com o mesmo fluxo do CI (Docker)

```bash
bash database/ci/run_ci.sh
```

O script sobe o container `gvenzl/oracle-free:23-slim-faststart`, espera o banco ficar pronto, executa os scripts `01` a `07` e grava um log por script. Em seguida o `assert_oracle.sql` roda as 40 verificações.

<!-- CONFIRMAR: variáveis/pré-requisitos de run_ci.sh (Docker instalado, senha, porta). -->

## Verificações automáticas

`ci/assert_oracle.sql` reprova o pipeline se qualquer item falhar:

- 3 packages + 3 bodies `VALID`, 2 triggers `ENABLED`, nenhum objeto `INVALID` e `USER_ERRORS` vazio;
- carga de dados (3 usuários, 3 metas, 165+ transações);
- equivalência entre rotinas soltas e packages (saldo previsto, resumo do mês e progresso das metas);
- cenário completo: renda, parcelado, recorrente, alertas em lote sem duplicar, saldo negativo, as duas triggers e o Dynamic SQL com entradas maliciosas, com limpeza no final.

`ci/verify_deploy.sql` roda após o deploy no Oracle da FIAP (somente leitura): packages e triggers válidos, nenhum objeto `SHAS` fora de `VALID`, nenhum erro de compilação e tabelas `SHAS_*` presentes.

## Deploy no Oracle da FIAP

Feito pelo job `deploy` do pipeline, que aplica `05_packages.sql` e `06_triggers.sql` e roda `verify_deploy.sql`. Se a verificação falhar, o back-end não é implantado. Credenciais ficam nos *secrets* `ORACLE_USER` e `ORACLE_PASSWORD` do ambiente `production`. Veja [PIPELINE.md](../PIPELINE.md#como-configurar).

## Observação de compatibilidade

O `ALTER TABLE` em `SHAS_ALERTA` (script `06`) deixava rotinas dependentes como `INVALID` até a próxima chamada. O script agora recompila os dependentes, e o pipeline garante isso a cada execução.