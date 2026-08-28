import React, { useState, useCallback, useLayoutEffect } from 'react';
import { View, Text, StyleSheet, FlatList, ActivityIndicator, TouchableOpacity } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { signOut } from 'firebase/auth';
import { auth } from '../services/firebaseConfig';
import { buscarResumoMensal, listarTransacoesPorMes } from '../services/api';

const NOMES_MESES = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
];

export default function HomeScreen({ route, navigation }) {
  const usuarioId = route.params.usuarioId; // sempre vem do login real, sem fallback mocado

  const hoje = new Date();
  const [ano, setAno] = useState(hoje.getFullYear());
  const [mes, setMes] = useState(hoje.getMonth() + 1);

  const [resumo, setResumo] = useState({ saldoAtual: 0, saldoPrevisto: 0 });
  const [transacoes, setTransacoes] = useState([]);
  const [loading, setLoading] = useState(true);

  useFocusEffect(
    useCallback(() => {
      carregarDados();
    }, [usuarioId, ano, mes])
  );

  async function carregarDados() {
    setLoading(true);
    try {
      const dadosResumo = await buscarResumoMensal(ano, mes);
      const dadosTransacoes = await listarTransacoesPorMes(ano, mes);

      setResumo(dadosResumo || { saldoAtual: 0, saldoPrevisto: 0 });
      setTransacoes(Array.isArray(dadosTransacoes) ? dadosTransacoes : []);
    } catch (error) {
      console.log('Erro ao carregar dados da API:', error);
      setTransacoes([]);
    } finally {
      setLoading(false);
    }
  }

  function mesAnterior() {
    if (mes === 1) { setMes(12); setAno(ano - 1); } else { setMes(mes - 1); }
  }

  function mesSeguinte() {
    if (mes === 12) { setMes(1); setAno(ano + 1); } else { setMes(mes + 1); }
  }

  async function handleSair() {
    await signOut(auth);
    // O MainNavigation detecta a saída e volta pra tela de Login automaticamente.
  }

  // Coloca o botão "Sair" no cabeçalho de navegação, do lado direito do título.
  useLayoutEffect(() => {
    navigation.setOptions({
      headerRight: () => (
        <TouchableOpacity style={styles.botaoSairHeader} onPress={handleSair}>
          <Text style={styles.textoBotaoSairHeader}>Sair</Text>
        </TouchableOpacity>
      ),
    });
  }, [navigation]);

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#007AFF" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.cardContainer}>
        <View style={[styles.card, { backgroundColor: '#e3f2fd' }]}>
          <Text style={styles.cardTitle}>Saldo Atual</Text>
          <Text style={styles.cardValue}>R$ {resumo?.saldoAtual?.toFixed(2) || '0.00'}</Text>
        </View>
        <View style={[styles.card, { backgroundColor: '#e8f5e9' }]}>
          <Text style={styles.cardTitle}>Saldo Previsto</Text>
          <Text style={styles.cardValue}>R$ {resumo?.saldoPrevisto?.toFixed(2) || '0.00'}</Text>
        </View>
      </View>

      <View style={styles.linksGerenciar}>
        <TouchableOpacity
          style={[styles.chipGerenciar, styles.chipRenda]}
          onPress={() => navigation.navigate('GerenciarTransacoes', { usuarioId, tipo: 'RENDA' })}
        >
          <Text style={styles.chipIcone}>↑</Text>
          <Text style={styles.chipTexto}>Gerenciar Rendas</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.chipGerenciar, styles.chipDespesa]}
          onPress={() => navigation.navigate('GerenciarTransacoes', { usuarioId, tipo: 'DESPESA' })}
        >
          <Text style={styles.chipIcone}>↓</Text>
          <Text style={styles.chipTexto}>Gerenciar Despesas</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.seletorMes}>
        <TouchableOpacity onPress={mesAnterior} style={styles.setaMes}>
          <Text style={styles.textoSeta}>◀</Text>
        </TouchableOpacity>
        <Text style={styles.textoMes}>{NOMES_MESES[mes - 1]} / {ano}</Text>
        <TouchableOpacity onPress={mesSeguinte} style={styles.setaMes}>
          <Text style={styles.textoSeta}>▶</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.sectionTitle}>Histórico de transações</Text>

      <FlatList
        data={transacoes}
        keyExtractor={(item) => item?.id || Math.random().toString()}
        renderItem={({ item }) => (
          <View style={styles.itemContainer}>
            <View>
              <Text style={styles.itemTitulo}>{item?.titulo || ''}</Text>
              <Text style={styles.itemCategoria}>{item?.categoria || ''} • {item?.data || ''}</Text>
            </View>
            <Text style={[styles.itemValor, { color: item?.tipo === 'RENDA' ? '#2e7d32' : '#c62828' }]}>
              {item?.tipo === 'RENDA' ? '+' : '-'} R$ {(item?.valor || 0).toFixed(2)}
            </Text>
          </View>
        )}
        ListEmptyComponent={<Text style={styles.emptyText}>Nenhuma transação encontrada para este mês.</Text>}
      />

      <TouchableOpacity
        style={styles.botaoNovaTransacao}
        onPress={() => navigation.navigate('CadastrarTransacao', { usuarioId })}
      >
        <Text style={styles.textoBotaoNovaTransacao}>+ Nova Transação</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f5f5', padding: 16 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  botaoSairHeader: { paddingHorizontal: 14, paddingVertical: 6, marginRight: 8 },
  textoBotaoSairHeader: { color: '#c62828', fontSize: 16, fontWeight: '700' },
  cardContainer: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 12 },
  card: { flex: 1, padding: 16, borderRadius: 8, marginHorizontal: 4, elevation: 2 },
  cardTitle: { fontSize: 14, color: '#555', marginBottom: 6 },
  cardValue: { fontSize: 18, fontWeight: 'bold', color: '#222' },
  linksGerenciar: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 16 },
  chipGerenciar: {
    flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
    paddingVertical: 10, borderRadius: 20, marginHorizontal: 4, borderWidth: 1.5,
  },
  chipRenda: { backgroundColor: '#e8f5e9', borderColor: '#2e7d32' },
  chipDespesa: { backgroundColor: '#fdecea', borderColor: '#c62828' },
  chipIcone: { fontSize: 14, fontWeight: 'bold', marginRight: 6, color: '#333' },
  chipTexto: { fontSize: 13, fontWeight: '600', color: '#333' },
  seletorMes: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', marginBottom: 16 },
  setaMes: { padding: 10 },
  textoSeta: { fontSize: 18, color: '#007AFF', fontWeight: 'bold' },
  textoMes: { fontSize: 18, fontWeight: 'bold', color: '#333', marginHorizontal: 20 },
  sectionTitle: { fontSize: 16, fontWeight: 'bold', marginBottom: 12, color: '#333' },
  itemContainer: { backgroundColor: '#fff', padding: 14, borderRadius: 8, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, elevation: 1 },
  itemTitulo: { fontSize: 16, fontWeight: '600', color: '#333' },
  itemCategoria: { fontSize: 12, color: '#777', marginTop: 2 },
  itemValor: { fontSize: 16, fontWeight: 'bold' },
  emptyText: { textAlign: 'center', color: '#888', marginTop: 40 },
  botaoNovaTransacao: { backgroundColor: '#007AFF', padding: 15, borderRadius: 8, alignItems: 'center', marginTop: 10 },
  textoBotaoNovaTransacao: { color: '#fff', fontSize: 16, fontWeight: 'bold' }
});