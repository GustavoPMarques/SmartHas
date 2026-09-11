import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet, FlatList, ActivityIndicator, TouchableOpacity, Alert, Platform } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { listarMetas, atualizarPrevisaoMeta, excluirMeta } from '../services/api';

function formatarAtualizacao(dataStr) {
  if (!dataStr) return null;
  const data = new Date(dataStr);
  const hoje = new Date();
  const diffDias = Math.floor((hoje - data) / (1000 * 60 * 60 * 24));

  if (diffDias <= 0) return 'Atualizado hoje';
  if (diffDias === 1) return 'Atualizado ontem';
  return `Atualizado há ${diffDias} dias`;
}

export default function MetasScreen({ navigation }) {
  const insets = useSafeAreaInsets();

  const [metas, setMetas] = useState([]);
  const [loading, setLoading] = useState(true);
  const [atualizandoId, setAtualizandoId] = useState(null);
  const [excluindoId, setExcluindoId] = useState(null);
  const [dicasAbertas, setDicasAbertas] = useState({});

  useFocusEffect(
    useCallback(() => {
      carregarDados();
    }, [])
  );

  async function carregarDados() {
    setLoading(true);
    const dados = await listarMetas();
    setMetas(Array.isArray(dados) ? dados : []);
    setLoading(false);
  }

  async function handleAtualizarPrevisao(id) {
    if (atualizandoId === id) return;
    setAtualizandoId(id);
    const atualizada = await atualizarPrevisaoMeta(id);
    if (atualizada) {
      setMetas((atual) => atual.map((m) => (m.id === id ? atualizada : m)));
    }
    setAtualizandoId(null);
  }

  function confirmarExclusao(meta) {
    if (Platform.OS === 'web') {
      if (window.confirm(`Excluir a meta "${meta.nome}"?`)) {
        handleExcluir(meta.id);
      }
    } else {
      Alert.alert('Excluir meta', `Excluir a meta "${meta.nome}"?`, [
        { text: 'Cancelar', style: 'cancel' },
        { text: 'Excluir', style: 'destructive', onPress: () => handleExcluir(meta.id) },
      ]);
    }
  }

  async function handleExcluir(id) {
    if (excluindoId === id) return;
    setExcluindoId(id);
    const sucesso = await excluirMeta(id);
    if (sucesso) {
      setMetas((atual) => atual.filter((m) => m.id !== id));
    } else {
      setExcluindoId(null);
    }
  }

  function toggleDicas(id) {
    setDicasAbertas((atual) => ({ ...atual, [id]: !atual[id] }));
  }

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#007AFF" />
      </View>
    );
  }

  return (
    <View style={[styles.container, { paddingBottom: 16 + insets.bottom }]}>
      <FlatList
        data={metas}
        keyExtractor={(item) => item.id}
        contentContainerStyle={{ paddingBottom: 12 }}
        ListEmptyComponent={
          <Text style={styles.emptyText}>
            Nenhuma meta cadastrada ainda. Toque em "+ Nova Meta" para criar a primeira.
          </Text>
        }
        renderItem={({ item }) => {
          const concluida = item.percentual >= 100 || item.mesesRestantesEstimados === 0;
          const temDicas = item.dicas && item.dicas.length > 0;
          const dicasVisiveis = dicasAbertas[item.id];
          const atualizacaoTexto = formatarAtualizacao(item.dataUltimaPrevisao);

          return (
            <View style={[styles.card, concluida && styles.cardConcluida]}>
              <View style={styles.cardTopo}>
                <Text style={styles.nomeMeta}>{item.nome}</Text>
                <TouchableOpacity
                  onPress={() => confirmarExclusao(item)}
                  disabled={excluindoId === item.id}
                >
                  <Text style={styles.botaoExcluir}>
                    {excluindoId === item.id ? '...' : 'Excluir'}
                  </Text>
                </TouchableOpacity>
              </View>

              <Text style={styles.valores}>
                R$ {item.progresso?.toFixed(2)} de R$ {item.valorAlvo?.toFixed(2)}
              </Text>

              <View style={styles.barraFundo}>
                <View
                  style={[
                    styles.barraPreenchida,
                    { width: `${item.percentual || 0}%` },
                    concluida && styles.barraPreenchidaConcluida,
                  ]}
                />
              </View>
              <Text style={styles.percentualTexto}>
                {concluida ? '🎉 Meta concluída!' : `${item.percentual}% concluído`}
              </Text>

              {item.mesesRestantesEstimados !== null && item.mesesRestantesEstimados !== undefined ? (
                <Text style={styles.previsaoPrazo}>
                  {item.mesesRestantesEstimados === 0
                    ? '🎉 Meta alcançada!'
                    : `Previsão: ${item.mesesRestantesEstimados} mês(es) — por volta de ${item.dataPrevista}`}
                </Text>
              ) : (
                <Text style={styles.previsaoPrazo}>
                  Ainda não é possível estimar um prazo (economia zerada ou negativa no período).
                </Text>
              )}

              {item.previsaoTexto ? (
                <Text style={styles.mensagemIA}>💡 {item.previsaoTexto}</Text>
              ) : null}

              {temDicas && (
                <>
                  <View style={styles.divisor} />

                  <TouchableOpacity
                    style={styles.dicasCabecalho}
                    onPress={() => toggleDicas(item.id)}
                  >
                    <Text style={styles.dicasTitulo}>Dicas ({item.dicas.length})</Text>
                    <Text style={styles.dicasSeta}>{dicasVisiveis ? '▲' : '▼'}</Text>
                  </TouchableOpacity>

                  {dicasVisiveis && (
                    <View style={styles.dicasContainer}>
                      {item.dicas.map((dica, index) => (
                        <Text key={index} style={styles.dicaItem}>• {dica}</Text>
                      ))}
                    </View>
                  )}
                </>
              )}

              <View style={styles.rodape}>
                <TouchableOpacity
                  style={styles.botaoAtualizar}
                  onPress={() => handleAtualizarPrevisao(item.id)}
                  disabled={atualizandoId === item.id}
                >
                  <Text style={styles.textoBotaoAtualizar}>
                    {atualizandoId === item.id ? 'Atualizando...' : 'Atualizar previsão'}
                  </Text>
                </TouchableOpacity>

                {atualizacaoTexto && (
                  <Text style={styles.atualizacaoTexto}>{atualizacaoTexto}</Text>
                )}
              </View>
            </View>
          );
        }}
      />

      <TouchableOpacity
        style={styles.botaoNovaMeta}
        onPress={() => navigation.navigate('CadastrarMeta')}
      >
        <Text style={styles.textoBotaoNovaMeta}>+ Nova Meta</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f5f5', padding: 16 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  emptyText: { textAlign: 'center', color: '#888', marginTop: 40, paddingHorizontal: 20 },
  card: {
    backgroundColor: '#fff',
    padding: 16,
    borderRadius: 10,
    marginBottom: 14,
    elevation: 1,
  },
  cardConcluida: {
    backgroundColor: '#e8f5e9',
    borderWidth: 1,
    borderColor: '#a5d6a7',
  },
  cardTopo: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  nomeMeta: { fontSize: 17, fontWeight: 'bold', color: '#222' },
  botaoExcluir: { color: '#c62828', fontSize: 13, fontWeight: '600' },
  valores: { fontSize: 14, color: '#555', marginTop: 6 },
  barraFundo: {
    height: 10,
    backgroundColor: '#e0e0e0',
    borderRadius: 5,
    marginTop: 10,
    overflow: 'hidden',
  },
  barraPreenchida: { height: '100%', backgroundColor: '#2e7d32', borderRadius: 5 },
  barraPreenchidaConcluida: { backgroundColor: '#43a047' },
  percentualTexto: { fontSize: 12, color: '#777', marginTop: 4 },
  previsaoPrazo: { fontSize: 15, color: '#007AFF', fontWeight: '600', marginTop: 10 },
  mensagemIA: { fontSize: 13, color: '#333', marginTop: 8, fontStyle: 'italic' },
  divisor: {
    height: 1,
    backgroundColor: '#eee',
    marginTop: 14,
    marginBottom: 10,
  },
  dicasCabecalho: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  dicasTitulo: { fontSize: 14, fontWeight: '600', color: '#333' },
  dicasSeta: { fontSize: 12, color: '#777' },
  dicasContainer: { marginTop: 10 },
  dicaItem: { fontSize: 13, color: '#444', marginTop: 4, lineHeight: 18 },
  rodape: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 14,
  },
  botaoAtualizar: {
    alignSelf: 'flex-start',
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#007AFF',
  },
  textoBotaoAtualizar: { color: '#007AFF', fontSize: 12, fontWeight: '600' },
  atualizacaoTexto: { fontSize: 11, color: '#999' },
  botaoNovaMeta: {
    backgroundColor: '#007AFF',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 10,
  },
  textoBotaoNovaMeta: { color: '#fff', fontSize: 16, fontWeight: 'bold' },
});