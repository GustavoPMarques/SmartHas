import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { Transacao, TransacaoRequest, ResumoMensal, TipoTransacao } from '../models/transacao.model';

@Injectable({
  providedIn: 'root'
})
export class TransacaoService {
  private http = inject(HttpClient);
  private apiUrl = environment.apiUrl;

  listarPorMes(ano: number, mes: number): Observable<Transacao[]> {
    return this.http.get<Transacao[]>(`${this.apiUrl}/mes/${ano}/${mes}`);
  }

  buscarResumo(ano: number, mes: number): Observable<ResumoMensal> {
    return this.http.get<ResumoMensal>(`${this.apiUrl}/resumo/${ano}/${mes}`);
  }

  listarPorTipo(tipo: TipoTransacao): Observable<Transacao[]> {
    return this.http.get<Transacao[]>(`${this.apiUrl}/tipo/${tipo}`);
  }

  cadastrar(dados: TransacaoRequest): Observable<Transacao[]> {
    return this.http.post<Transacao[]>(this.apiUrl, dados);
  }

  atualizar(id: string, dados: TransacaoRequest): Observable<Transacao> {
    return this.http.put<Transacao>(`${this.apiUrl}/${id}`, dados);
  }

  excluir(id: string): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}`);
  }
}