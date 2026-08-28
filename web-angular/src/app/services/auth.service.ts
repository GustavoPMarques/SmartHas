import { Injectable } from '@angular/core';
import { initializeApp } from 'firebase/app';
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
  User
} from 'firebase/auth';
import { BehaviorSubject, Observable } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private app = initializeApp(environment.firebaseConfig);
  private auth = getAuth(this.app);

  // Guarda o usuário logado atual — qualquer componente pode "escutar" mudanças aqui.
  private usuarioSubject = new BehaviorSubject<User | null>(null);
  usuario$: Observable<User | null> = this.usuarioSubject.asObservable();
  private usuarioProntoSubject = new BehaviorSubject<boolean>(false);
  usuarioPronto$: Observable<boolean> = this.usuarioProntoSubject.asObservable();

  constructor() {
  
  onAuthStateChanged(this.auth, (usuario) => {
    this.usuarioSubject.next(usuario);
    this.usuarioProntoSubject.next(true); 
  });
}

  login(email: string, senha: string) {
    return signInWithEmailAndPassword(this.auth, email, senha);
  }

  cadastrar(email: string, senha: string) {
    return createUserWithEmailAndPassword(this.auth, email, senha);
  }

  logout() {
    return signOut(this.auth);
  }

  get usuarioAtual(): User | null {
    return this.usuarioSubject.value;
  }

  /** Pega o token do Firebase pra anexar nas chamadas à API (usado pelo interceptor abaixo). */
  async obterToken(): Promise<string | null> {
    const usuario = this.usuarioAtual;
    if (!usuario) return null;
    return usuario.getIdToken();
  }
}