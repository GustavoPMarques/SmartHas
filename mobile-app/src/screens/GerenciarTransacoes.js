import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet, FlatList, ActivityIndicator, TouchableOpacity, Alert, Platform } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { listarPorTipo, excluirTransacao } from '../services/api';

export default function GerenciarTransacoesScreen({ route, navigation }) {
  const usuarioId = route.params.usuarioId;
  const tipo = route.params?.tipo || 'DESPESA';

  const [transacoes, setTransacoes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [excluindoId, setExcluindoId] = useState(null);

  const titulo = tipo === 'RENDA' ? 'Gerenciar Rendas' : 'Gerenciar Despesas';
  const corDestaque = tipo === 'RENDA' ? '#2e7d32' : '#c62828';

  useFocusEffect(
    useCallback(() => {
      navigation.setOptions({ title: titulo });
      carregarDados();
    }, [usuarioId, tipo])
  );

  async function carregarDados() {
    setLoading(true);
    const dados = await listarPorTipo(tipo);
    setTransacoes(Array.isArray(dados) ? dados : []);
    setLoading(false);
  }

  function confirmarExclusao(item) {
    if (Platform.OS === 'web') {
      const confirmado = window.confirm(`Deseja realmente excluir "${item.titulo}"?`);
      if (confirmado) {
        excluir(item.id);
      }
    } else {
      Alert.alert(
        'Excluir transação',
        `Deseja realmente excluir "${item.titulo}"?`,
        [
          { text: 'Cancelar', style: 'cancel' },
          { text: 'Excluir', style: 'destructive', onPress: () => excluir(item.id) }
        ]
      );
    }
  }

  async function excluir(id) {
    
    if (excluindoId === id) return;

    setExcluindoId(id);
    const sucesso = await excluirTransacao(id);

    if (sucesso) {
      setTransacoes((atual) => atual.filter((t) => t.id !== id));
      
    } else {
      setExcluindoId(null);
      if (Platform.OS === 'web') {
        window.alert('Não foi possível excluir a transação.');
      } else {
        Alert.alert('Erro', 'Não foi possível excluir a transação.');
      }
    }
  }

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#007AFF" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={transacoes}
        keyExtractor={(item) => item.id}
        contentContainerStyle={{ paddingBottom: 20 }}
        ListEmptyComponent={
          <Text style={styles.emptyText}>
            Nenhuma {tipo === 'RENDA' ? 'renda' : 'despesa'} cadastrada ainda.
          </Text>
        }
        renderItem={({ item }) => (
          <View style={styles.itemContainer}>
            <TouchableOpacity
              style={{ flex: 1 }}
              onPress={() => navigation.navigate('EditarTransacao', { usuarioId, transacao: item })}
            >
              <Text style={styles.itemTitulo}>{item.titulo}</Text>
              <Text style={styles.itemDetalhe}>{item.categoria} • {item.data}</Text>
              {item.isRecorrente && <Text style={styles.tagRecorrente}>Recorrente</Text>}
              {item.parcelas > 1 && <Text style={styles.tagParcelado}>{item.parcelas}x</Text>}
            </TouchableOpacity>

            <View style={styles.acoesContainer}>
              <Text style={[styles.itemValor, { color: corDestaque }]}>
                R$ {item.valor?.toFixed(2)}
              </Text>
              <TouchableOpacity
                onPress={() => confirmarExclusao(item)}
                style={styles.botaoExcluir}
                disabled={excluindoId === item.id}
              >
                <Text style={styles.textoExcluir}>
                  {excluindoId === item.id ? 'Excluindo...' : 'Excluir'}
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f5f5', padding: 16 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  itemContainer: {
    backgroundColor: '#fff', padding: 14, borderRadius: 8,
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    marginBottom: 10, elevation: 1
  },
  itemTitulo: { fontSize: 16, fontWeight: '600', color: '#333' },
  itemDetalhe: { fontSize: 12, color: '#777', marginTop: 2 },
  tagRecorrente: { fontSize: 11, color: '#007AFF', fontWeight: 'bold', marginTop: 4 },
  tagParcelado: { fontSize: 11, color: '#f57c00', fontWeight: 'bold', marginTop: 2 },
  acoesContainer: { alignItems: 'flex-end' },
  itemValor: { fontSize: 16, fontWeight: 'bold' },
  botaoExcluir: { marginTop: 6 },
  textoExcluir: { color: '#c62828', fontSize: 12, fontWeight: 'bold' },
  emptyText: { textAlign: 'center', color: '#888', marginTop: 40 }
});