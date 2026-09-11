import { useState } from 'react';
import { Alert, Platform, ScrollView, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { cadastrarMeta } from '../services/api';

function mostrarAlerta(titulo, mensagem) {
  if (Platform.OS === 'web') {
    window.alert(`${titulo}\n\n${mensagem}`);
  } else {
    Alert.alert(titulo, mensagem);
  }
}

export default function CadastrarMetaScreen({ navigation }) {
  const insets = useSafeAreaInsets();

  const [nome, setNome] = useState('');
  const [valorAlvo, setValorAlvo] = useState('');
  const [salvando, setSalvando] = useState(false);

  async function handleSalvar() {
    if (salvando) return;

    if (!nome || !valorAlvo) {
      mostrarAlerta('Atenção', 'Preencha o nome e o valor da meta.');
      return;
    }

    const valorNumerico = parseFloat(valorAlvo.replace(',', '.'));
    if (isNaN(valorNumerico) || valorNumerico <= 0) {
      mostrarAlerta('Atenção', 'Informe um valor válido, maior que zero.');
      return;
    }

    setSalvando(true);

    try {
      const resultado = await cadastrarMeta({ nome, valorAlvo: valorNumerico });

      if (!resultado) throw new Error('Falha ao cadastrar');

      mostrarAlerta('Meta criada!', 'A previsão da IA já foi gerada — confira na lista de metas.');
      navigation.goBack();
    } catch (error) {
      console.log('Erro ao cadastrar meta:', error);
      mostrarAlerta('Erro', 'Não foi possível criar a meta agora.');
      setSalvando(false);
    }
  }

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.label}>Nome da meta</Text>
      <TextInput
        style={styles.input}
        placeholder="Ex: Viagem para SP"
        placeholderTextColor="#888"
        value={nome}
        onChangeText={setNome}
      />

      <Text style={styles.label}>Valor alvo (R$)</Text>
      <TextInput
        style={styles.input}
        placeholder="2000.00"
        placeholderTextColor="#888"
        keyboardType="numeric"
        value={valorAlvo}
        onChangeText={setValorAlvo}
      />

      <Text style={styles.aviso}>
        Assim que a meta for criada, a IA vai calcular uma previsão de prazo baseada no seu
        ritmo de economia atual, além de sugerir dicas pra você chegar lá mais rápido.
      </Text>

      <TouchableOpacity
        style={[styles.botaoSalvar, salvando && styles.botaoDesabilitado]}
        onPress={handleSalvar}
        disabled={salvando}
      >
        <Text style={styles.textoBotaoSalvar}>
          {salvando ? 'Gerando previsão com IA...' : 'Criar meta'}
        </Text>
      </TouchableOpacity>

      <View style={{ height: 40 + insets.bottom }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f5f5', padding: 20 },
  label: { fontSize: 14, fontWeight: '600', color: '#333', marginBottom: 6, marginTop: 12 },
  input: {
    backgroundColor: '#fff',
    padding: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#ddd',
    fontSize: 16,
    color: '#333',
  },
  aviso: { fontSize: 12, color: '#777', marginTop: 16, lineHeight: 18 },
  botaoSalvar: {
    backgroundColor: '#007AFF',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 24,
  },
  botaoDesabilitado: { backgroundColor: '#99c2ff' },
  textoBotaoSalvar: { color: '#fff', fontSize: 16, fontWeight: 'bold' },
});