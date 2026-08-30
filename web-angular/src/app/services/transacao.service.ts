import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, forkJoin } from 'rxjs';
import { map } from 'rxjs/operators';
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

 
  listarTodas(): Observable<Transacao[]> {
    return forkJoin([
      this.listarPorTipo('RENDA'),
      this.listarPorTipo('DESPESA')
    ]).pipe(
      map(([rendas, despesas]) => [...rendas, ...despesas])
    );
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