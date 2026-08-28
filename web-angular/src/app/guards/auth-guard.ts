import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { filter, map, take } from 'rxjs/operators';
import { AuthService } from '../services/auth.service';


export const authGuard: CanActivateFn = () => {
  const authService = inject(AuthService);
  const router = inject(Router);

  return authService.usuarioPronto$.pipe(
    filter((pronto) => pronto),
    take(1),
    map(() => {
      if (authService.usuarioAtual) {
        return true;
      }
      router.navigate(['/login']);
      return false;
    })
  );
};