# Smart HAS — Backend API

API REST em Java/Spring Boot responsável por toda a lógica de negócio e persistência do Smart HAS. Consumida tanto pelo app mobile quanto pelo dashboard Angular.

## Tecnologias

- Java 21
- Spring Boot 4 (Spring MVC)
- Firebase Admin SDK (autenticação e Firestore como banco de dados)
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


