import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TransacaoService } from '../../services/transacao.service';
import { Transacao, TransacaoRequest, TipoTransacao } from '../../models/transacao.model';

@Component({
  selector: 'app-admin',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './admin.html',
  styleUrl: './admin.css'
})
export class Admin implements OnInit {
  private transacaoService = inject(TransacaoService);

  filtroTipo = signal<TipoTransacao>('DESPESA');
  transacoes = signal<Transacao[]>([]);
  carregando = signal(true);
  erro = signal('');
  sucesso = signal('');

  // Campos do formulário — cada um ligado ao input via [(ngModel)].
  form = {
    titulo: '',
    valor: null as number | null,
    data: '',
    tipo: 'DESPESA' as TipoTransacao,
    categoria: '',
    isRecorrente: false,
    parcelas: 1
  };

  edicaoId: string | null = null;

  ngOnInit() {
    this.carregarLista();
  }

  carregarLista() {
    this.carregando.set(true);
    this.transacaoService.listarPorTipo(this.filtroTipo()).subscribe({
      next: (dados) => {
        this.transacoes.set(dados);
        this.carregando.set(false);
      },
      error: () => {
        this.erro.set('Não foi possível carregar as transações.');
        this.carregando.set(false);
      }
    });
  }

  mudarFiltro(tipo: TipoTransacao) {
    this.filtroTipo.set(tipo);
    this.form.tipo = tipo;
    this.carregarLista();
  }

  enviarForm() {
    this.erro.set('');
    this.sucesso.set('');

    if (!this.form.titulo || !this.form.valor || !this.form.data || !this.form.categoria) {
      this.erro.set('Preencha todos os campos obrigatórios.');
      return;
    }

    const payload: TransacaoRequest = {
      titulo: this.form.titulo,
      valor: this.form.valor,
      data: this.form.data,
      tipo: this.form.tipo,
      categoria: this.form.categoria,
      isRecorrente: this.form.isRecorrente,
      parcelas: this.form.parcelas || 1
    };

    if (this.edicaoId) {
      this.transacaoService.atualizar(this.edicaoId, payload).subscribe({
        next: () => {
          this.sucesso.set('Transação atualizada com sucesso!');
          this.limparForm();
          this.carregarLista();
        },
        error: () => this.erro.set('Não foi possível atualizar a transação.')
      });
    } else {
      this.transacaoService.cadastrar(payload).subscribe({
        next: () => {
          this.sucesso.set('Transação cadastrada com sucesso!');
          this.limparForm();
          this.carregarLista();
        },
        error: () => this.erro.set('Não foi possível cadastrar a transação.')
      });
    }
  }

  editar(t: Transacao) {
    this.edicaoId = t.id;
    this.form = {
      titulo: t.titulo,
      valor: t.valor,
      data: t.data,
      tipo: t.tipo,
      categoria: t.categoria,
      isRecorrente: t.isRecorrente,
      parcelas: t.parcelas
    };
  }

  cancelarEdicao() {
    this.limparForm();
  }

  excluir(t: Transacao) {
    const confirmar = window.confirm(`Excluir "${t.titulo}"? Essa ação não pode ser desfeita.`);
    if (!confirmar) return;

    this.transacaoService.excluir(t.id).subscribe({
      next: () => {
        this.sucesso.set('Transação excluída.');
        this.carregarLista();
      },
      error: () => this.erro.set('Não foi possível excluir a transação.')
    });
  }

  private limparForm() {
    this.edicaoId = null;
    this.form = {
      titulo: '',
      valor: null,
      data: '',
      tipo: this.filtroTipo(),
      categoria: '',
      isRecorrente: false,
      parcelas: 1
    };
  }
}