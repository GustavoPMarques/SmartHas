import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { TransacaoService } from '../../services/transacao.service';
import { Transacao, ResumoMensal } from '../../models/transacao.model';

const NOMES_MESES = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
];

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './home.html',
  styleUrl: './home.css'
})
export class Home implements OnInit {
  private authService = inject(AuthService);
  private transacaoService = inject(TransacaoService);
  private router = inject(Router);

  nomesMeses = NOMES_MESES;

  hoje = new Date();
  ano = signal(this.hoje.getFullYear());
  mes = signal(this.hoje.getMonth() + 1);

  resumo = signal<ResumoMensal>({
    saldoAtual: 0,
    saldoPrevisto: 0,
    totalRendasMes: 0,
    totalDespesasMes: 0
  });
  transacoes = signal<Transacao[]>([]);
  carregando = signal(true);
  erro = signal('');

  ngOnInit() {
    this.carregarDados();
  }

  carregarDados() {
    this.carregando.set(true);
    this.erro.set('');

    this.transacaoService.buscarResumo(this.ano(), this.mes()).subscribe({
      next: (dados) => this.resumo.set(dados),
      error: () => this.erro.set('Não foi possível carregar o resumo. Confira se o backend está no ar.')
    });

    this.transacaoService.listarPorMes(this.ano(), this.mes()).subscribe({
      next: (dados) => {
        this.transacoes.set(dados);
        this.carregando.set(false);
      },
      error: () => {
        this.transacoes.set([]);
        this.carregando.set(false);
        this.erro.set('Não foi possível carregar as transações. Confira se o backend está no ar.');
      }
    });
  }

  mesAnterior() {
    if (this.mes() === 1) {
      this.mes.set(12);
      this.ano.update((a) => a - 1);
    } else {
      this.mes.update((m) => m - 1);
    }
    this.carregarDados();
  }

  mesSeguinte() {
    if (this.mes() === 12) {
      this.mes.set(1);
      this.ano.update((a) => a + 1);
    } else {
      this.mes.update((m) => m + 1);
    }
    this.carregarDados();
  }

  async sair() {
    await this.authService.logout();
    this.router.navigate(['/login']);
  }
}