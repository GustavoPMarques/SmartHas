# Smart HAS — App Mobile

Aplicativo React Native (Expo) para gestão de finanças pessoais: cadastro de rendas e despesas, resumo mensal, transações recorrentes e parceladas, além de metas de economia com previsão de prazo e dicas geradas por IA.

## Tecnologias

- React Native + Expo
- React Navigation (navegação entre telas)
- Firebase Authentication (login/cadastro)
- @react-native-community/datetimepicker (seletor de data nativo)

## Pré-requisitos

- Node.js instalado
- App Expo Go instalado no celular (Android: Play Store / iOS: App Store)

## Configuração

1. Instale as dependências:
   npm install

2. Copie o arquivo de exemplo de variáveis de ambiente:
   cp .env.example .env

   O .env.example já vem apontando para o backend hospedado (https://smarthas.onrender.com), então na maioria dos casos você não precisa editar nada. Só troque a URL se for rodar o backend localmente (veja o README do backend-api).

## Rodando o projeto

npx expo start

Escaneie o QR code exibido no terminal com o app Expo Go. Se estiver testando em uma rede diferente da sua máquina de desenvolvimento, use:

npx expo start --tunnel

Se mudar o .env, sempre reinicie com -c para limpar o cache:

npx expo start -c

## Estrutura de pastas

src/
├── components/       → Componentes reutilizáveis (ex: DatePickerField)
├── navigation/        → Configuração de rotas (MainNavigation.js)
├── screens/           → Telas do app (Login, Home, Cadastrar/Editar Transação, etc.)
└── services/          → Comunicação com Firebase e com a API (api.js, firebaseConfig.js)

## Funcionalidades

- Cadastro e login de usuários (Firebase Auth)
- Sessão persistente entre reinicializações do app
- Cadastro de transações (renda/despesa), com suporte a:
  - Parcelamento (divide o valor em N transações mensais)
  - Recorrência (repete todo mês, sem data final)
- Seletor de data nativo (calendário do sistema operacional)
- Resumo mensal (saldo atual x saldo previsto)
- Edição e exclusão de transações
- Navegação por mês (setas para avançar/voltar)
- Metas de economia:
  - Cadastro de meta com nome e valor alvo
  - Progresso calculado automaticamente a partir do histórico de transações (valor acumulado, % concluído, ritmo médio mensal, previsão de prazo)
  - Previsão e dicas geradas por IA (Google Gemini via backend), com mensagem motivacional e até 3 sugestões práticas exibidas em um dropdown expansível
  - Atualização manual da previsão sob demanda, com indicador de última atualização
  - Card com destaque visual quando a meta é concluída
