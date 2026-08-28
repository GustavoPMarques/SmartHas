export type TipoTransacao = 'RENDA' | 'DESPESA';

export interface Transacao {
  id: string;
  titulo: string;
  valor: number;
  data: string; // formato yyyy-MM-dd
  tipo: TipoTransacao;
  categoria: string;
  isRecorrente: boolean;
  parcelas: number;
}

export interface TransacaoRequest {
  titulo: string;
  valor: number;
  data: string;
  tipo: TipoTransacao;
  categoria: string;
  isRecorrente: boolean;
  parcelas: number;
}

export interface ResumoMensal {
  saldoAtual: number;
  saldoPrevisto: number;
  totalRendasMes: number;
  totalDespesasMes: number;
}