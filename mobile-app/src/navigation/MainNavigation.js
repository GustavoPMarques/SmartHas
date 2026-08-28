import React, { useEffect, useState } from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import { NavigationContainer } from '@react-navigation/native';
import { View, ActivityIndicator } from 'react-native';
import { onAuthStateChanged } from 'firebase/auth';
import { auth } from '../services/firebaseConfig';

import LoginScreen from '../screens/LoginScreen';
import CadastroScreen from '../screens/CadastroScreen';
import HomeScreen from '../screens/HomeScreen';
import CadastrarTransacaoScreen from '../screens/CadastrarTransacao';
import GerenciarTransacoesScreen from '../screens/GerenciarTransacoes';
import EditarTransacaoScreen from '../screens/EditarTransacao';

const Stack = createStackNavigator();

export default function MainNavigation() {
  const [usuario, setUsuario] = useState(null);
  const [carregando, setCarregando] = useState(true);

  useEffect(() => {
    const cancelarInscricao = onAuthStateChanged(auth, (usuarioLogado) => {
      setUsuario(usuarioLogado);
      setCarregando(false);
    });
    return cancelarInscricao;
  }, []);

  if (carregando) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#f5f5f5' }}>
        <ActivityIndicator size="large" color="#007AFF" />
      </View>
    );
  }

  return (
    <NavigationContainer>
      <Stack.Navigator>
        {!usuario ? (
          // Não logado: só existe Login e Cadastro. Impossível acessar o resto do app.
          <>
            <Stack.Screen name="Login" component={LoginScreen} options={{ headerShown: false }} />
            <Stack.Screen name="Cadastro" component={CadastroScreen} options={{ title: 'Criar Conta' }} />
          </>
        ) : (
          // Logado: usuarioId real (uid do Firebase) já injetado automaticamente na Home.
          <>
            <Stack.Screen
              name="Home"
              component={HomeScreen}
              options={{ title: 'Minhas Finanças' }}
              initialParams={{ usuarioId: usuario.uid }}
            />
            <Stack.Screen name="CadastrarTransacao" component={CadastrarTransacaoScreen} options={{ title: 'Nova Transação' }} />
            <Stack.Screen name="GerenciarTransacoes" component={GerenciarTransacoesScreen} options={{ title: 'Gerenciar' }} />
            <Stack.Screen name="EditarTransacao" component={EditarTransacaoScreen} options={{ title: 'Editar Transação' }} />
          </>
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
}