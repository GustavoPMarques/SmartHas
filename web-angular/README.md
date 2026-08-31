# Smart HAS — Painel Web (Angular)

Dashboard de acompanhamento financeiro em Angular, somente leitura, que consome a mesma API REST usada pelo app mobile. Ideal para visualizar de forma rápida como estão as finanças, sem precisar abrir o celular.

## Tecnologias

- Angular (standalone components, signals)
- Firebase Authentication (login/cadastro)
- HttpClient + Interceptor (comunicação autenticada com a API)
- Gráfico de pizza feito em CSS puro (conic-gradient), sem bibliotecas externas de gráficos

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
│   ├── login/         → Tela de login/cadastro
│   ├── home/           → Dashboard: gráfico de pizza + resumo do ano selecionado
│   └── transacoes/     → Lista completa de transações, somente leitura
├── guards/              → Proteção de rotas autenticadas (auth-guard)
├── interceptors/        → Anexa o token do Firebase em toda chamada HTTP
├── services/            → AuthService e TransacaoService
└── models/              → Interfaces TypeScript (Transacao, ResumoMensal, etc.)

## Rotas

| Rota | Descrição | Protegida? |
|---|---|---|
| /login | Login e cadastro de usuário | Não |
| /home | Dashboard com gráfico de pizza (Receitas x Despesas) | Sim |
| /transacoes | Lista completa de transações do usuário, filtrável | Sim |

Rotas protegidas exigem um usuário autenticado (verificado pelo authGuard); sem sessão ativa, o usuário é redirecionado para /login.

## Funcionalidades

- Login e cadastro via Firebase Auth
- Dashboard (/home):
  - Gráfico de pizza mostrando a proporção entre Receitas e Despesas do ano selecionado
  - Filtro de ano com setas de navegação (◀ ano ▶) e campo editável via [(ngModel)]
  - Transações recorrentes contam automaticamente em todos os anos seguintes ao de seu cadastro
- Lista completa (/transacoes):
  - Todas as transações do usuário logado, com o mesmo filtro de ano
  - Abas para filtrar por tipo (Todas / Receitas / Despesas)
  - Somente leitura — cadastro, edição e exclusão só são feitos pelo app mobile

## Funcionalidades demonstradas (requisitos técnicos)

- Data binding: interpolação ({{ }}), property binding ([ ]), event binding (( )) e two-way binding ([( )])
- Diretivas estruturais *ngIf e *ngFor
- Formulário funcional com [(ngModel)]: o campo de filtro por ano
- Rotas configuradas com proteção por autenticação (authGuard)
- Feedback visual de carregamento, erro e estado vazio em todas as telas
