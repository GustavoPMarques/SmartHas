# Smart HAS

Sistema de gestão financeira pessoal (Smart Household Accounting System), desenvolvido como projeto acadêmico (FIAP). O projeto é dividido em três frentes que consomem a mesma API REST:

- 📱 App mobile (React Native + Expo) — cadastro e acompanhamento de rendas/despesas, além de metas financeiras com previsão e dicas geradas por IA
- 🌐 Painel web (Angular) — visualização de dados via dashboard e lista completa de transações
- ⚙️ Backend (Spring Boot + Firebase) — API REST compartilhada pelos dois clientes, incluindo integração com a IA do Google (Gemini)

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

## Divisão de responsabilidades entre os clientes

O app mobile é a interface completa: cadastro, edição, exclusão e acompanhamento de transações (rendas e despesas), incluindo parcelamento e recorrência.

O painel web (Angular) é somente leitura, pensado como um painel de acompanhamento visual:
- Dashboard com gráfico de pizza (Receitas x Despesas) do ano selecionado
- Lista completa de transações, filtrável por ano e por tipo
- Não é possível cadastrar, editar ou excluir transações pelo navegador — isso é feito exclusivamente pelo app mobile

## Metas financeiras com IA

O app mobile permite criar metas de economia (ex: "Celular novo", "Viagem"). A cada meta o backend:

- Calcula o progresso real com base no histórico de transações do usuário (economia acumulada, ritmo médio mensal, previsão de prazo) — **feito 100% em Java, sem envolver a IA nesse cálculo**
- Usa o **Google Gemini** apenas para gerar, a partir dos números já calculados, uma mensagem motivacional curta e até 3 dicas práticas e personalizadas para a pessoa alcançar a meta mais rápido
- Se o Gemini estiver indisponível (ex: pico de demanda, erro 503), o backend tenta novamente automaticamente (retry nativo do Spring Framework 7) e, se ainda assim falhar, devolve uma mensagem de fallback — a meta e o progresso continuam funcionando normalmente, sem dependência dura da IA

## Backend hospedado

A API já está publicada e disponível publicamente:

- URL base: https://smarthas.onrender.com
- Documentação (Swagger): https://smarthas.onrender.com/swagger-ui/index.html

⚠️ O backend usa o plano gratuito do Render, que "dorme" após um tempo sem uso. A primeira requisição depois de um período parado pode levar de 30 a 90 segundos para responder — não é um erro, é o serviço "acordando".

## Como rodar cada parte

Cada subprojeto tem seu próprio README com instruções detalhadas de configuração:

- mobile-app/README.md
- backend-api/smarthas-api/README.md
- web-angular/README.md

Resumo rápido: como o backend já está hospedado, não é necessário rodar o backend localmente para testar o mobile ou o web — basta configurar o .env/environment.ts de cada um apontando para a URL pública acima.

## Tecnologias principais

| Camada | Tecnologias |
|---|---|
| Mobile | React Native, Expo, React Navigation, Firebase Auth |
| Backend | Java 21, Spring Boot 4, Firebase Admin SDK (Firestore), springdoc-openapi, Google Gemini API (previsões de metas) |
| Web | Angular (standalone components, signals), Firebase Auth |
| Infraestrutura | Docker, Render (deploy do backend) |

## Testes automatizados

O backend possui testes unitários e de integração (JUnit 5 + Mockito), cobrindo os endpoints da API (camada web) e a regra de negócio do serviço de transações (parcelamento, recorrência, checagem de propriedade). Veja detalhes no README do backend-api.

## Segurança

- Autenticação via Firebase Auth (e-mail/senha), com verificação de token em toda chamada à API
- Cada usuário só acessa as próprias transações (verificação de propriedade no backend)
- Credenciais sensíveis (ServiceAccountKey.json, .env, environment.ts) nunca são versionadas — veja os .gitignore de cada subprojeto
