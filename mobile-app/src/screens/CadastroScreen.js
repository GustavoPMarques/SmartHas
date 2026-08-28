import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert, Platform } from 'react-native';
import { createUserWithEmailAndPassword } from 'firebase/auth';
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
    case 'auth/email-already-in-use':
      return 'Este e-mail já está cadastrado.';
    case 'auth/invalid-email':
      return 'E-mail inválido.';
    case 'auth/weak-password':
      return 'A senha precisa ter pelo menos 6 caracteres.';
    default:
      return 'Não foi possível criar a conta. Tente novamente.';
  }
}

export default function CadastroScreen({ navigation }) {
  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [confirmarSenha, setConfirmarSenha] = useState('');
  const [carregando, setCarregando] = useState(false);

  async function handleCadastro() {
    if (!email || !senha || !confirmarSenha) {
      mostrarAlerta('Atenção', 'Preencha todos os campos.');
      return;
    }

    if (senha.length < 6) {
      mostrarAlerta('Atenção', 'A senha precisa ter pelo menos 6 caracteres.');
      return;
    }

    if (senha !== confirmarSenha) {
      mostrarAlerta('Atenção', 'As senhas não coincidem.');
      return;
    }

    setCarregando(true);
    try {
      await createUserWithEmailAndPassword(auth, email.trim(), senha);
      // A conta já entra logada automaticamente pelo Firebase.
      // O MainNavigation detecta isso via onAuthStateChanged e leva para a Home sozinho.
    } catch (error) {
      mostrarAlerta('Erro no Cadastro', traduzirErro(error.code));
    } finally {
      setCarregando(false);
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.titulo}>Criar Conta</Text>

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
        placeholder="Senha (mínimo 6 caracteres)"
        placeholderTextColor="#888"
        value={senha}
        onChangeText={setSenha}
        secureTextEntry
      />

      <TextInput
        style={styles.input}
        placeholder="Confirmar Senha"
        placeholderTextColor="#888"
        value={confirmarSenha}
        onChangeText={setConfirmarSenha}
        secureTextEntry
      />

      <TouchableOpacity
        style={[styles.botaoCriar, carregando && styles.botaoDesabilitado]}
        onPress={handleCadastro}
        disabled={carregando}
      >
        <Text style={styles.textoBotao}>{carregando ? 'Criando conta...' : 'Criar Conta'}</Text>
      </TouchableOpacity>

      <TouchableOpacity style={styles.botaoVoltar} onPress={() => navigation.goBack()}>
        <Text style={styles.textoBotaoVoltar}>Já tenho conta</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 20, backgroundColor: '#f5f5f5' },
  titulo: { fontSize: 24, fontWeight: 'bold', textAlign: 'center', marginBottom: 30, color: '#333' },
  input: { backgroundColor: '#fff', padding: 15, borderRadius: 8, marginBottom: 15, borderWidth: 1, borderColor: '#ddd' },
  botaoCriar: { backgroundColor: '#2e7d32', padding: 15, borderRadius: 8, alignItems: 'center', marginBottom: 10 },
  botaoDesabilitado: { opacity: 0.6 },
  textoBotao: { color: '#fff', fontSize: 16, fontWeight: 'bold' },
  botaoVoltar: { padding: 15, alignItems: 'center' },
  textoBotaoVoltar: { color: '#007AFF', fontSize: 14, fontWeight: '600' }
});