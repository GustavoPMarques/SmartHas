import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TransacaoService } from '../../services/transacao.service';
import { Transacao, TipoTransacao } from '../../models/transacao.model';

@Component({
  selector: 'app-transacoes',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './transacoes.html',
  styleUrl: './transacoes.css'
})
export class Transacoes implements OnInit {
  private transacaoService = inject(TransacaoService);

  todasTransacoes = signal<Transacao[]>([]);
  carregando = signal(true);
  erro = signal('');

  anoSelecionado: number = new Date().getFullYear();
  filtroTipo: 'TODOS' | TipoTransacao = 'TODOS';

  ngOnInit() {
    this.carregarDados();
  }

  carregarDados() {
    this.carregando.set(true);
    this.erro.set('');
    this.transacaoService.listarTodas().subscribe({
      next: (dados) => {
        this.todasTransacoes.set(dados);
        this.carregando.set(false);
      },
      error: () => {
        this.erro.set('Não foi possível carregar suas transações.');
        this.carregando.set(false);
      }
    });
  }

  anoAnterior() {
    this.anoSelecionado--;
  }

  anoSeguinte() {
    this.anoSelecionado++;
  }


  private ocorreNoAno(t: Transacao, ano: number): boolean {
    const anoOriginal = Number(t.data.substring(0, 4));
    return t.isRecorrente ? ano >= anoOriginal : ano === anoOriginal;
  }

  get transacoesFiltradas(): Transacao[] {
    return this.todasTransacoes()
      .filter((t) => this.ocorreNoAno(t, this.anoSelecionado))
      .filter((t) => this.filtroTipo === 'TODOS' || t.tipo === this.filtroTipo)
      .sort((a, b) => b.data.localeCompare(a.data));
  }
}