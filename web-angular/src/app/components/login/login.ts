import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './login.html',
  styleUrl: './login.css'
})
export class Login {
  private authService = inject(AuthService);
  private router = inject(Router);

  email = '';
  senha = '';
  modoCadastro = false;
  carregando = false;
  mensagemErro = '';

  async enviar() {
    if (!this.email || !this.senha) {
      this.mensagemErro = 'Preencha e-mail e senha.';
      return;
    }

    this.carregando = true;
    this.mensagemErro = '';

    try {
      if (this.modoCadastro) {
        await this.authService.cadastrar(this.email, this.senha);
      } else {
        await this.authService.login(this.email, this.senha);
      }
      this.router.navigate(['/home']);
    } catch (erro: any) {
      this.mensagemErro = this.traduzirErro(erro?.code);
    } finally {
      this.carregando = false;
    }
  }

  alternarModo() {
    this.modoCadastro = !this.modoCadastro;
    this.mensagemErro = '';
  }

  private traduzirErro(codigo: string): string {
    switch (codigo) {
      case 'auth/invalid-email': return 'E-mail inválido.';
      case 'auth/email-already-in-use': return 'Este e-mail já está cadastrado.';
      case 'auth/weak-password': return 'A senha precisa ter pelo menos 6 caracteres.';
      case 'auth/invalid-credential':
      case 'auth/wrong-password':
      case 'auth/user-not-found': return 'E-mail ou senha incorretos.';
      default: return 'Não foi possível concluir. Tente novamente.';
    }
  }
}