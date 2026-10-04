import React, { useEffect, useState } from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import { NavigationContainer } from '@react-navigation/native';
import { View, ActivityIndicator, TouchableOpacity, Text } from 'react-native';
import { onAuthStateChanged } from 'firebase/auth';
import { auth } from '../services/firebaseConfig';

import LoginScreen from '../screens/LoginScreen';
import CadastroScreen from '../screens/CadastroScreen';
import HomeScreen from '../screens/HomeScreen';
import CadastrarTransacaoScreen from '../screens/CadastrarTransacao';
import GerenciarTransacoesScreen from '../screens/GerenciarTransacoes';
import EditarTransacaoScreen from '../screens/EditarTransacao';
import MetasScreen from '../screens/MetasScreen';
import CadastrarMetaScreen from '../screens/CadastrarMetaScreen';

const Stack = createStackNavigator();


const TITULOS = {
  Home: 'Minhas Finanças',
  CadastrarTransacao: 'Nova Transação',
  GerenciarTransacoes: 'Gerenciar',
  EditarTransacao: 'Editar Transação',
  Metas: 'Minhas Metas',
  CadastrarMeta: 'Nova Meta',
  Cadastro: 'Criar Conta',
};

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
      <Stack.Navigator
        screenOptions={({ navigation, route }) => ({
          headerTintColor: '#000',
          headerTitleAlign: 'center',
          headerTitle: () => (
            <Text style={{ fontSize: 17, fontWeight: '600', color: '#000' }}>
              {TITULOS[route.name] || ''}
            </Text>
          ),
          headerLeft: (props) =>
            props.canGoBack ? (
              <TouchableOpacity
                onPress={navigation.goBack}
                style={{ marginLeft: 12, padding: 4 }}
              >
                <Text style={{ fontSize: 16, color: '#007AFF' }}>Voltar</Text>
              </TouchableOpacity>
            ) : null,
        })}
      >
        {!usuario ? (
          <>
            <Stack.Screen name="Login" component={LoginScreen} options={{ headerShown: false }} />
            <Stack.Screen name="Cadastro" component={CadastroScreen} />
          </>
        ) : (
          <>
            <Stack.Screen
              name="Home"
              component={HomeScreen}
              initialParams={{ usuarioId: usuario.uid }}
            />
            <Stack.Screen name="CadastrarTransacao" component={CadastrarTransacaoScreen} />
            <Stack.Screen name="GerenciarTransacoes" component={GerenciarTransacoesScreen} />
            <Stack.Screen name="EditarTransacao" component={EditarTransacaoScreen} />
            <Stack.Screen name="Metas" component={MetasScreen} />
            <Stack.Screen name="CadastrarMeta" component={CadastrarMetaScreen} />
          </>
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
}