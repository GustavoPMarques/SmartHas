import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert, Platform, ScrollView, Switch } from 'react-native';
import { atualizarTransacao } from '../services/api';

function mostrarAlerta(titulo, mensagem) {
  if (Platform.OS === 'web') {
    window.alert(`${titulo}\n\n${mensagem}`);
  } else {
    Alert.alert(titulo, mensagem);
  }
}

export default function EditarTransacaoScreen({ route, navigation }) {
  const { usuarioId, transacao } = route.params;

  const [titulo, setTitulo] = useState(transacao.titulo);
  const [valor, setValor] = useState(String(transacao.valor));
  const [data, setData] = useState(transacao.data);
  const [tipo, setTipo] = useState(transacao.tipo);
  const [categoria, setCategoria] = useState(transacao.categoria);
  const [isRecorrente, setIsRecorrente] = useState(!!transacao.isRecorrente);
  const [salvando, setSalvando] = useState(false);

  async function handleAtualizar() {
    
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
        valor: parseFloat(String(valor).replace(',', '.')),
        data,
        tipo,
        categoria,
        isRecorrente,
        parcelas: transacao.parcelas || 1
      };

      const resultado = await atualizarTransacao(transacao.id, payload);

      if (!resultado) throw new Error('Falha ao atualizar');

      mostrarAlerta('Sucesso', 'Transação atualizada com sucesso!');
      navigation.goBack();
    } catch (error) {
      console.log('Erro ao atualizar:', error);
      mostrarAlerta('Erro', 'Não foi possível atualizar a transação.');
      setSalvando(false);
    }
  }

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.label}>Título</Text>
      <TextInput style={styles.input} value={titulo} onChangeText={setTitulo} />

      <Text style={styles.label}>Valor (R$)</Text>
      <TextInput style={styles.input} keyboardType="numeric" value={valor} onChangeText={setValor} />

      <Text style={styles.label}>Data (AAAA-MM-DD)</Text>
      <TextInput style={styles.input} value={data} onChangeText={setData} />

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
      <TextInput style={styles.input} value={categoria} onChangeText={setCategoria} />

      {transacao.parcelas > 1 && (
        <Text style={styles.avisoParcela}>
          Esta é a parcela {transacao.titulo.match(/\((\d+\/\d+)\)/)?.[1] || ''} de uma compra parcelada.
          Editar aqui altera somente esta parcela.
        </Text>
      )}

      <View style={styles.switchRow}>
        <Text style={styles.labelSwitch}>Recorrente</Text>
        <Switch value={isRecorrente} onValueChange={setIsRecorrente} />
      </View>

      <TouchableOpacity
        style={[styles.botaoSalvar, salvando && styles.botaoDesabilitado]}
        onPress={handleAtualizar}
        disabled={salvando}
      >
        <Text style={styles.textoBotaoSalvar}>{salvando ? 'Salvando...' : 'Salvar Alterações'}</Text>
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
  avisoParcela: { fontSize: 12, color: '#f57c00', marginTop: 14, fontStyle: 'italic' },
  switchRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', backgroundColor: '#fff', padding: 12, borderRadius: 8, borderWidth: 1, borderColor: '#ddd', marginTop: 14 },
  labelSwitch: { fontSize: 16, fontWeight: '600', color: '#333' },
  botaoSalvar: { backgroundColor: '#007AFF', padding: 15, borderRadius: 8, alignItems: 'center', marginTop: 24 },
  botaoDesabilitado: { backgroundColor: '#99c2ff' },
  textoBotaoSalvar: { color: '#fff', fontSize: 16, fontWeight: 'bold' }
});