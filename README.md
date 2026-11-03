# Smart HAS

![CI/CD](https://github.com/GustavoPMarques/SmartHas/actions/workflows/ci-cd.yml/badge.svg?branch=main)

Sistema de gestão financeira pessoal (Smart Household Accounting System), desenvolvido como projeto acadêmico (FIAP). O projeto é dividido em quatro frentes:

- 📱 **App mobile** (React Native + Expo): cadastro e acompanhamento de rendas/despesas
- 🌐 **Painel web administrativo** (Angular): gerenciamento de transações via navegador
- ⚙️ **Backend** (Spring Boot + Firebase): API REST compartilhada pelos dois clientes
- 🗄️ **Banco Oracle** (PL/SQL): tabelas, packages, triggers e Dynamic SQL com regras de negócio no banco (saldo previsto, resumo do mês, progresso de metas, alertas e auditoria)

Tudo é validado e publicado automaticamente por um [pipeline CI/CD](PIPELINE.md) no GitHub Actions.

## Arquitetura

<!-- CONFIRMAR: como o backend se conecta ao Oracle hoje (JDBC/JPA, ou o Oracle é uma camada paralela entregue à parte)? Ajuste o diagrama conforme o caso. -->

```
                    ┌─────────────────┐
                    │  Firebase Auth   │
                    │  (autenticação)  │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                     │
┌───────▼────────┐  ┌────────▼────────┐  ┌─────────▼────────┐
│  mobile-app      │  │  web-angular    │  │  (futuro: outros  │
│  React Native    │  │  Angular        │  │  clientes)         │
└───────┬────────┘  └────────┬────────┘  └───────────────────┘
        │                    │
        └─────────┬──────────┘
                   │  HTTPS + Bearer Token
          ┌────────▼─────────┐
          │   backend-api     │
          │  Spring Boot      │
          └───┬──────────┬───┘
              │          │
   ┌──────────▼───┐  ┌───▼──────────────┐
   │  Firestore    │  │  Oracle (FIAP)    │
   │  (Firebase)   │  │  PL/SQL: packages │
   └──────────────┘  │  triggers, tabelas │
                      └──────────────────┘
```

## Estrutura do repositório

```
SmartHas/
├── .github/workflows/ → Pipeline CI/CD (ci-cd.yml)
├── backend-api/       → API Spring Boot (ver README próprio)
├── database/          → Scripts Oracle PL/SQL e verificações de CI (ver README próprio)
├── mobile-app/        → App React Native (Expo) (ver README próprio)
├── web-angular/       → Dashboard Angular (ver README próprio)
├── PIPELINE.md        → Documentação do pipeline CI/CD
└── README.md          → este arquivo
```

## Backend hospedado

A API já está publicada e disponível publicamente:

- **URL base**: <https://smarthas.onrender.com>
- **Documentação (Swagger)**: <https://smarthas.onrender.com/swagger-ui/index.html>

> ⚠️ O backend usa o plano gratuito do Render, que "dorme" após um tempo sem uso. A primeira requisição depois de um período parado pode levar de 30 a 90 segundos para responder. Não é um erro, é o serviço "acordando".

## Como rodar cada parte

Cada subprojeto tem seu próprio README com instruções detalhadas:

- [mobile-app/README.md](mobile-app/README.md)
- [backend-api/smarthas-api/README.md](backend-api/smarthas-api/README.md)
- [web-angular/README.md](web-angular/README.md)
- [database/README.md](database/README.md)

Resumo rápido: como o backend já está hospedado, **não é necessário rodar o backend localmente** para testar o mobile ou o web. Basta configurar o `.env`/`environment.ts` de cada um apontando para a URL pública acima.

## Tecnologias principais

| Camada         | Tecnologias                                                               |
| -------------- | ------------------------------------------------------------------------- |
| Mobile         | React Native, Expo, React Navigation, Firebase Auth                       |
| Backend        | Java 21, Spring Boot 4, Firebase Admin SDK (Firestore), springdoc-openapi |
| Web            | Angular (standalone components, signals), Firebase Auth                   |
| Banco de dados | Oracle (Free 23ai no CI, Oracle da FIAP em produção), PL/SQL, SQL\*Plus   |
| Infraestrutura | Docker, GitHub Container Registry (GHCR), Render (deploy do backend)      |
| CI/CD          | GitHub Actions, Maven, JUnit, Trivy                                       |

## CI/CD

A cada push na `main`, o [pipeline](PIPELINE.md) executa quatro jobs encadeados:

| Job | O que faz |
|---|---|
| `build-test` | Compila o back-end e executa os 15 testes JUnit |
| `oracle-db` | Sobe um Oracle descartável, roda os scripts `01` a `07` e 40 verificações automáticas |
| `docker-build` | Constrói a imagem, varre vulnerabilidades (Trivy) e publica no GHCR |
| `deploy` | Aplica os scripts no Oracle da FIAP, dispara o deploy no Render e faz um teste de fumaça |

Pull requests só rodam build e testes; o deploy acontece apenas na `main`. Detalhes, evidências e configuração em [PIPELINE.md](PIPELINE.md).

## Segurança

- Autenticação via Firebase Auth (e-mail/senha), com verificação de token em toda chamada à API
- Cada usuário só acessa as próprias transações (verificação de propriedade no backend)
- Credenciais sensíveis (ServiceAccountKey.json, .env, environment.ts) nunca são versionadas; veja os `.gitignore` de cada subprojeto
- Credenciais do Oracle e do Render ficam em *secrets* do ambiente `production` do GitHub, nunca no código
- Varredura Trivy da imagem Docker a cada execução do pipeline
- Dynamic SQL do banco valida entradas e rejeita tentativas de injeção (ver [database/README.md](database/README.md))