# Smart HAS

Sistema de gestão financeira pessoal (Smart Household Accounting System), desenvolvido como projeto acadêmico (FIAP). O projeto é dividido em três frentes que consomem a mesma API REST:

- 📱 **App mobile** (React Native + Expo) — cadastro e acompanhamento de rendas/despesas
- 🌐 **Painel web administrativo** (Angular) — gerenciamento de transações via navegador
- ⚙️ **Backend** (Spring Boot + Firebase) — API REST compartilhada pelos dois clientes

## Arquitetura

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
          └────────┬─────────┘
                    │
          ┌─────────▼─────────┐
          │ Firebase Firestore │
          │   (banco de dados) │
          └────────────────────┘
```

## Estrutura do repositório

```
SmartHas/
├── mobile-app/       → App React Native (Expo) — ver README próprio
├── backend-api/      → API Spring Boot — ver README próprio
├── web-angular/       → Dashboard Angular — ver README próprio
└── README.md          → este arquivo
```

## Backend hospedado

A API já está publicada e disponível publicamente:

- **URL base**: https://smarthas.onrender.com
- **Documentação (Swagger)**: https://smarthas.onrender.com/swagger-ui/index.html

> ⚠️ O backend usa o plano gratuito do Render, que "dorme" após um tempo sem uso. A primeira requisição depois de um período parado pode levar de 30 a 90 segundos para responder — não é um erro, é o serviço "acordando".

## Como rodar cada parte

Cada subprojeto tem seu próprio README com instruções detalhadas de configuração:

- mobile-app/README.md
- backend-api/smarthas-api/README.md
- web-angular/README.md

Resumo rápido: como o backend já está hospedado, **não é necessário rodar o backend localmente** para testar o mobile ou o web — basta configurar o `.env`/`environment.ts` de cada um apontando para a URL pública acima.

## Tecnologias principais

| Camada | Tecnologias |
|---|---|
| Mobile | React Native, Expo, React Navigation, Firebase Auth |
| Backend | Java 21, Spring Boot 4, Firebase Admin SDK (Firestore), springdoc-openapi |
| Web | Angular (standalone components, signals), Firebase Auth |
| Infraestrutura | Docker, Render (deploy do backend) |

## Segurança

- Autenticação via Firebase Auth (e-mail/senha), com verificação de token em toda chamada à API
- Cada usuário só acessa as próprias transações (verificação de propriedade no backend)
- Credenciais sensíveis (ServiceAccountKey.json, .env, environment.ts) nunca são versionadas — veja os .gitignore de cada subprojeto
