# Smart HAS — Painel Web (Angular)

Dashboard administrativo em Angular para gerenciar as transações do Smart HAS pelo navegador, consumindo a mesma API REST usada pelo app mobile.

## Tecnologias

- Angular (standalone components, signals)
- Firebase Authentication (login/cadastro)
- HttpClient + Interceptor (comunicação autenticada com a API)

## Pré-requisitos

- Node.js instalado
- Angular CLI instalado globalmente:
  npm install -g @angular/cli

## Configuração

1. Instale as dependências:
   npm install

2. Copie os arquivos de exemplo de ambiente:
   cp src/environments/environment.example.ts src/environments/environment.ts
   cp src/environments/environment.example.ts src/environments/environment.development.ts

   Ambos já vêm apontando para o backend hospedado (https://smarthas.onrender.com), então normalmente não é necessário editar nada — só troque a apiUrl se for rodar o backend localmente.

## Rodando o projeto

ng serve

Abra http://localhost:4200 no navegador. O Angular só lê o environment.ts na inicialização — se você editar esse arquivo, é preciso parar (Ctrl+C) e rodar ng serve novamente.

## Estrutura de pastas

src/app/
├── components/
│   ├── login/       → Tela de login/cadastro
│   ├── home/        → Dashboard com resumo mensal e histórico
│   └── admin/        → Gerenciamento de transações (cadastro, edição, exclusão)
├── guards/            → Proteção de rotas autenticadas (auth-guard)
├── interceptors/      → Anexa o token do Firebase em toda chamada HTTP
├── services/          → AuthService e TransacaoService
└── models/            → Interfaces TypeScript (Transacao, ResumoMensal, etc.)

## Rotas

| Rota | Descrição | Protegida? |
|---|---|---|
| /login | Login e cadastro de usuário | Não |
| /home | Resumo mensal e histórico de transações | Sim |
| /admin | Cadastro, edição e exclusão de transações | Sim |

Rotas protegidas exigem um usuário autenticado (verificado pelo authGuard); sem sessão ativa, o usuário é redirecionado para /login.

## Funcionalidades demonstradas

- Data binding: interpolação ({{ }}), property binding ([ ]), event binding (( )) e two-way binding ([( )])
- Diretivas estruturais *ngIf e *ngFor
- Formulário reativo simples com [(ngModel)] (cadastro/edição de transação)
- Feedback visual de carregamento, sucesso e erro em todas as telas
