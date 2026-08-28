import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert, Platform } from 'react-native';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../services/firebaseConfig';

function mostrarAlerta(titulo, mensagem) {
  if (Platform.OS === 'web') {
    window.alert(`${titulo}\n\n${mensagem}`);
  } else {
    Alert.alert(titulo, mensagem);
  }
}

function traduzirErro(codigo) {
  switch (codigo) {
    case 'auth/invalid-email':
      return 'E-mail inválido.';
    case 'auth/user-not-found':
    case 'auth/invalid-credential':
      return 'E-mail ou senha incorretos.';
    case 'auth/wrong-password':
      return 'E-mail ou senha incorretos.';
    case 'auth/too-many-requests':
      return 'Muitas tentativas. Tente novamente mais tarde.';
    default:
      return 'Não foi possível fazer login. Tente novamente.';
  }
}

export default function LoginScreen({ navigation }) {
  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [carregando, setCarregando] = useState(false);

  async function handleLogin() {
    if (!email || !senha) {
      mostrarAlerta('Atenção', 'Preencha e-mail e senha.');
      return;
    }

    setCarregando(true);
    try {
      await signInWithEmailAndPassword(auth, email.trim(), senha);
      // Não precisa navegar manualmente: o MainNavigation detecta o login
      // automaticamente via onAuthStateChanged e troca de tela sozinho.
    } catch (error) {
      mostrarAlerta('Erro no Login', traduzirErro(error.code));
    } finally {
      setCarregando(false);
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.titulo}>Smart HAS</Text>

      <TextInput
        style={styles.input}
        placeholder="E-mail"
        placeholderTextColor="#888"
        value={email}
        onChangeText={setEmail}
        autoCapitalize="none"
        keyboardType="email-address"
      />

      <TextInput
        style={styles.input}
        placeholder="Senha"
        placeholderTextColor="#888"
        value={senha}
        onChangeText={setSenha}
        secureTextEntry
      />

      <TouchableOpacity
        style={[styles.botaoEntrar, carregando && styles.botaoDesabilitado]}
        onPress={handleLogin}
        disabled={carregando}
      >
        <Text style={styles.textoBotao}>{carregando ? 'Entrando...' : 'Entrar'}</Text>
      </TouchableOpacity>

      <TouchableOpacity style={styles.botaoCadastrar} onPress={() => navigation.navigate('Cadastro')}>
        <Text style={styles.textoBotaoCadastrar}>Criar Conta</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 20, backgroundColor: '#f5f5f5' },
  titulo: { fontSize: 28, fontWeight: 'bold', textAlign: 'center', marginBottom: 30, color: '#333' },
  input: { backgroundColor: '#fff', padding: 15, borderRadius: 8, marginBottom: 15, borderWidth: 1, borderColor: '#ddd' },
  botaoEntrar: { backgroundColor: '#007AFF', padding: 15, borderRadius: 8, alignItems: 'center', marginBottom: 10 },
  botaoDesabilitado: { opacity: 0.6 },
  textoBotao: { color: '#fff', fontSize: 16, fontWeight: 'bold' },
  botaoCadastrar: { backgroundColor: 'transparent', padding: 15, borderRadius: 8, alignItems: 'center', borderWidth: 1, borderColor: '#007AFF' },
  textoBotaoCadastrar: { color: '#007AFF', fontSize: 16, fontWeight: 'bold' }
});