import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert, Platform, ScrollView, Switch } from 'react-native';
import { cadastrarTransacao } from '../services/api';

function mostrarAlerta(titulo, mensagem) {
  if (Platform.OS === 'web') {
    window.alert(`${titulo}\n\n${mensagem}`);
  } else {
    Alert.alert(titulo, mensagem);
  }
}

export default function CadastrarTransacaoScreen({ route, navigation }) {
  const usuarioId = route.params.usuarioId;

  const [titulo, setTitulo] = useState('');
  const [valor, setValor] = useState('');
  const [data, setData] = useState('2026-08-27');
  const [tipo, setTipo] = useState('RENDA');
  const [categoria, setCategoria] = useState('');

  const [ehParcelado, setEhParcelado] = useState(false);
  const [parcelas, setParcelas] = useState('1');

  const [isRecorrente, setIsRecorrente] = useState(false);
  const [salvando, setSalvando] = useState(false);

  async function handleSalvar() {
    
    if (salvando) return;

    if (!titulo || !valor || !categoria || !data) {
      mostrarAlerta('Atenção', 'Preencha todos os campos obrigatórios.');
      return;
    }

    setSalvando(true);

    try {
      const payload = {
        usuarioId,
        titulo,
        valor: parseFloat(valor.replace(',', '.')),
        data,
        tipo,
        categoria,
        parcelas: ehParcelado ? (parseInt(parcelas) || 1) : 1,
        isRecorrente
      };

      const resultado = await cadastrarTransacao(payload);

      if (!resultado) {
        throw new Error('Falha ao cadastrar');
      }

      mostrarAlerta('Sucesso', 'Transação cadastrada com sucesso!');
      navigation.goBack();
    } catch (error) {
      console.log('Erro ao salvar:', error);
      mostrarAlerta('Erro', 'Não foi possível salvar a transação.');
      setSalvando(false);
    }
  }

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.label}>Título</Text>
      <TextInput
        style={styles.input}
        placeholder="Ex: Salário Estágio"
        placeholderTextColor="#888"
        value={titulo}
        onChangeText={setTitulo}
      />

      <Text style={styles.label}>Valor (R$)</Text>
      <TextInput
        style={styles.input}
        placeholder="0.00"
        placeholderTextColor="#888"
        keyboardType="numeric"
        value={valor}
        onChangeText={setValor}
      />

      <Text style={styles.label}>Data (AAAA-MM-DD)</Text>
      <TextInput
        style={styles.input}
        placeholder="2026-08-27"
        placeholderTextColor="#888"
        value={data}
        onChangeText={setData}
      />

      <Text style={styles.label}>Tipo</Text>
      <View style={styles.tipoContainer}>
        <TouchableOpacity
          style={[styles.tipoBotao, tipo === 'RENDA' && styles.tipoRendaAtivo]}
          onPress={() => setTipo('RENDA')}
        >
          <Text style={[styles.tipoTexto, tipo === 'RENDA' && styles.textoAtivo]}>Renda</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tipoBotao, tipo === 'DESPESA' && styles.tipoDespesaAtivo]}
          onPress={() => setTipo('DESPESA')}
        >
          <Text style={[styles.tipoTexto, tipo === 'DESPESA' && styles.textoAtivo]}>Despesa</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.label}>Categoria</Text>
      <TextInput
        style={styles.input}
        placeholder="Ex: Alimentação, Salário"
        placeholderTextColor="#888"
        value={categoria}
        onChangeText={setCategoria}
      />

      <View style={styles.switchRow}>
        <Text style={styles.labelSwitch}>Parcelado?</Text>
        <Switch
          value={ehParcelado}
          onValueChange={setEhParcelado}
        />
      </View>

      {ehParcelado && (
        <>
          <Text style={styles.label}>Quantidade de Parcelas</Text>
          <TextInput
            style={styles.input}
            placeholder="Ex: 3"
            placeholderTextColor="#888"
            keyboardType="numeric"
            value={parcelas}
            onChangeText={setParcelas}
          />
        </>
      )}

      <View style={styles.switchRow}>
        <View>
          <Text style={styles.labelSwitch}>Recorrente</Text>
          {isRecorrente && <Text style={styles.subLabel}>Todo mês</Text>}
        </View>
        <Switch
          value={isRecorrente}
          onValueChange={setIsRecorrente}
        />
      </View>

      <TouchableOpacity
        style={[styles.botaoSalvar, salvando && styles.botaoDesabilitado]}
        onPress={handleSalvar}
        disabled={salvando}
      >
        <Text style={styles.textoBotaoSalvar}>{salvando ? 'Salvando...' : 'Salvar Transação'}</Text>
      </TouchableOpacity>

      <View style={{ height: 40 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f5f5', padding: 20 },
  label: { fontSize: 14, fontWeight: '600', color: '#333', marginBottom: 6, marginTop: 12 },
  input: { backgroundColor: '#fff', padding: 12, borderRadius: 8, borderWidth: 1, borderColor: '#ddd', fontSize: 16, color: '#333' },
  tipoContainer: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 10, marginTop: 4 },
  tipoBotao: { flex: 1, padding: 12, borderRadius: 8, borderWidth: 1, borderColor: '#ddd', alignItems: 'center', marginHorizontal: 4, backgroundColor: '#fff' },
  tipoRendaAtivo: { backgroundColor: '#2e7d32', borderColor: '#2e7d32' },
  tipoDespesaAtivo: { backgroundColor: '#c62828', borderColor: '#c62828' },
  tipoTexto: { fontSize: 16, fontWeight: 'bold', color: '#333' },
  textoAtivo: { color: '#fff' },
  switchRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', backgroundColor: '#fff', padding: 12, borderRadius: 8, borderWidth: 1, borderColor: '#ddd', marginTop: 14 },
  labelSwitch: { fontSize: 16, fontWeight: '600', color: '#333' },
  subLabel: { fontSize: 12, color: '#2e7d32', marginTop: 2, fontWeight: 'bold' },
  botaoSalvar: { backgroundColor: '#007AFF', padding: 15, borderRadius: 8, alignItems: 'center', marginTop: 24 },
  botaoDesabilitado: { backgroundColor: '#99c2ff' },
  textoBotaoSalvar: { color: '#fff', fontSize: 16, fontWeight: 'bold' }
});