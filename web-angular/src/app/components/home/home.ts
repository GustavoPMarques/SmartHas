import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { TransacaoService } from '../../services/transacao.service';
import { Transacao } from '../../models/transacao.model';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './home.html',
  styleUrl: './home.css'
})
export class Home implements OnInit {
  private authService = inject(AuthService);
  private transacaoService = inject(TransacaoService);
  private router = inject(Router);

  todasTransacoes = signal<Transacao[]>([]);
  carregando = signal(true);
  erro = signal('');

  anoSelecionado: number = new Date().getFullYear();

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
        this.erro.set('Não foi possível carregar suas transações. Confira se o backend está no ar.');
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

  get transacoesDoAno(): Transacao[] {
    return this.todasTransacoes().filter((t) => this.ocorreNoAno(t, this.anoSelecionado));
  }

  get totalRenda(): number {
    return this.transacoesDoAno.filter((t) => t.tipo === 'RENDA').reduce((soma, t) => soma + t.valor, 0);
  }

  get totalDespesa(): number {
    return this.transacoesDoAno.filter((t) => t.tipo === 'DESPESA').reduce((soma, t) => soma + t.valor, 0);
  }

  get percentualRenda(): number {
    const total = this.totalRenda + this.totalDespesa;
    return total === 0 ? 0 : Math.round((this.totalRenda / total) * 100);
  }

  get graficoBackground(): string {
    const total = this.totalRenda + this.totalDespesa;
    if (total === 0) return '#e0e0e0';
    const percentRenda = (this.totalRenda / total) * 100;
    return `conic-gradient(#2e7d32 0% ${percentRenda}%, #c62828 ${percentRenda}% 100%)`;
  }

  async sair() {
    await this.authService.logout();
    this.router.navigate(['/login']);
  }
}