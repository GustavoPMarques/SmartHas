import { auth } from './firebaseConfig';

// Defina o IP da sua máquina em um arquivo .env na raiz do mobile-app (veja .env.example).
// Assim você não precisa editar o código toda vez que o IP da sua rede mudar.
const API_URL = `${process.env.EXPO_PUBLIC_API_URL || 'http://192.168.15.3:8080'}/api/v1/transacoes`;


async function getAuthHeaders() {
  const usuario = auth.currentUser;
  if (!usuario) {
    throw new Error('Usuário não autenticado.');
  }
  const token = await usuario.getIdToken();
  return {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
  };
}

export async function buscarResumoMensal(ano, mes) {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_URL}/resumo/${ano}/${mes}`, { headers });
    if (!response.ok) throw new Error('Erro ao buscar resumo financeiro');
    return await response.json();
  } catch (error) {
    console.error(error);
    return null;
  }
}

export async function listarTransacoesPorMes(ano, mes) {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_URL}/mes/${ano}/${mes}`, { headers });
    if (!response.ok) throw new Error('Erro ao listar transações');
    return await response.json();
  } catch (error) {
    console.error(error);
    return [];
  }
}

export async function cadastrarTransacao(dadosTransacao) {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(API_URL, {
      method: 'POST',
      headers,
      body: JSON.stringify(dadosTransacao),
    });
    if (!response.ok) throw new Error('Erro ao cadastrar transação');
    return await response.json();
  } catch (error) {
    console.error(error);
    return null;
  }
}

export async function listarPorTipo(tipo) {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_URL}/tipo/${tipo}`, { headers });
    if (!response.ok) throw new Error('Erro ao listar por tipo');
    return await response.json();
  } catch (error) {
    console.error(error);
    return [];
  }
}

export async function atualizarTransacao(id, dadosTransacao) {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_URL}/${id}`, {
      method: 'PUT',
      headers,
      body: JSON.stringify(dadosTransacao),
    });
    if (!response.ok) throw new Error('Erro ao atualizar transação');
    return await response.json();
  } catch (error) {
    console.error(error);
    return null;
  }
}

export async function excluirTransacao(id) {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_URL}/${id}`, { method: 'DELETE', headers });
    return response.ok;
  } catch (error) {
    console.error(error);
    return false;
  }
}
