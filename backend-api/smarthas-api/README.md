# Smart HAS — Backend API

API REST em Java/Spring Boot responsável por toda a lógica de negócio e persistência do Smart HAS. Consumida tanto pelo app mobile quanto pelo dashboard Angular.

## Tecnologias

- Java 21
- Spring Boot 4 (Spring MVC)
- Firebase Admin SDK (autenticação e Firestore como banco de dados)
- Google Gemini API (geração de previsões e dicas personalizadas para metas)
- Resiliência nativa do Spring Framework 7 (`@Retryable`) para lidar com indisponibilidade da IA
- springdoc-openapi (documentação Swagger)
- Docker (deploy)

## API hospedada

- URL base: https://smarthas.onrender.com
- Swagger UI: https://smarthas.onrender.com/swagger-ui/index.html

## Rodando localmente

### Pré-requisitos

- Java 21+
- Não é necessário instalar Maven — o projeto usa o Maven Wrapper (mvnw)

### Configuração

1. Peça o arquivo ServiceAccountKey.json (credencial do Firebase) por um canal privado — esse arquivo nunca é versionado no Git, por segurança.
2. Coloque-o em src/main/resources/ServiceAccountKey.json.
3. (Opcional) Defina a variável de ambiente GEMINI_API_KEY com uma chave da Google AI Studio para habilitar as previsões e dicas de IA nas metas. Sem essa variável, o endpoint de metas continua funcionando normalmente — apenas retorna uma mensagem informando que a IA não está configurada, no lugar da previsão personalizada.

### Executando

./mvnw spring-boot:run

Aguarde a mensagem "Started SmarthasApiApplication" no terminal. A API sobe em http://localhost:8080.

### Rodando os testes

O projeto tem testes automatizados para a camada de controllers (`@WebMvcTest`) e services (Mockito), cobrindo validação de entrada, regras de negócio e verificação de posse das transações.

./mvnw test

Não é necessário configurar o Firebase para rodar os testes — os testes de controller mockam o service, e os testes de service mockam o Firestore diretamente, sem depender de credenciais reais.

## Endpoints principais

Todos sob o prefixo /api/v1/transacoes:

| Método | Rota | Descrição |
|---|---|---|
| POST | / | Cadastra uma nova transação |
| GET | /mes/{ano}/{mes} | Lista transações de um mês |
| GET | /resumo/{ano}/{mes} | Retorna saldo atual/previsto do mês |
| GET | /tipo/{tipo} | Lista transações por tipo (RENDA/DESPESA) |
| PUT | /{id} | Atualiza uma transação |
| DELETE | /{id} | Exclui uma transação |

Todos os endpoints (exceto o Swagger) exigem um header Authorization: Bearer <token do Firebase>.

Sob o prefixo /api/v1/metas:

| Método | Rota | Descrição |
|---|---|---|
| POST | / | Cadastra uma nova meta e já gera a previsão inicial via IA |
| GET | / | Lista as metas do usuário autenticado, com progresso recalculado |
| POST | /{id}/atualizar-previsao | Recalcula o progresso e gera uma nova previsão/dicas via IA |
| DELETE | /{id} | Exclui uma meta |

## Metas e previsões com IA

Cada meta guarda um valor alvo e a data de criação. A cada consulta ou atualização, o backend:

1. Calcula o progresso real (economia acumulada, ritmo médio mensal, meses restantes estimados) a partir do histórico de transações do usuário — cálculo determinístico, feito inteiramente em Java (a IA nunca calcula números).
2. Envia esses números já calculados para o Google Gemini (modelo `gemini-flash-latest`), pedindo apenas uma mensagem motivadora curta e até 3 dicas práticas — usando "structured output" (`responseSchema`) para garantir um JSON no formato esperado, sem parsing frágil de texto livre.

### Resiliência

A chamada ao Gemini está protegida por retry nativo do Spring Framework 7 (`@Retryable`, pacote `org.springframework.resilience.annotation`): em caso de erro 503 (alta demanda, comum no tier gratuito da API), o backend tenta novamente automaticamente com backoff exponencial antes de desistir. Se todas as tentativas falharem, ou se GEMINI_API_KEY não estiver configurada, o endpoint devolve uma mensagem de fallback em vez de erro — a criação/atualização da meta nunca é bloqueada por indisponibilidade da IA.

## Segurança

- FirebaseAuthFilter valida o token do Firebase em toda requisição
- Cada usuário só pode ler/editar/excluir as próprias transações (verificação de propriedade no TransacaoService)
- GlobalExceptionHandler trata erros de validação, dados não encontrados e acesso negado com mensagens claras

## Deploy (Render)

O projeto inclui um Dockerfile pronto para deploy no Render:

- Root Directory: backend-api/smarthas-api
- Language: Docker
- Secret File: ServiceAccountKey.json (conteúdo colado diretamente no painel do Render)
- Variável de ambiente: FIREBASE_CREDENTIALS_PATH=/etc/secrets/ServiceAccountKey.json

O application.properties já está configurado para usar a porta dinâmica fornecida pelo Render (server.port=${PORT:8080}).
