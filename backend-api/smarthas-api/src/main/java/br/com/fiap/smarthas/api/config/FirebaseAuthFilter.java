package br.com.fiap.smarthas.api.config;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Verifica o token do Firebase enviado pelo app no header "Authorization: Bearer <idToken>".
 * Se válido, o UID autenticado fica em request.getAttribute("usuarioId") para os
 * controllers usarem — nunca confiamos em um usuarioId vindo de query param ou body.
 */
@Component
public class FirebaseAuthFilter extends OncePerRequestFilter {

    private static final String[] CAMINHOS_PUBLICOS = {
            "/v3/api-docs", "/swagger-ui", "/swagger-ui.html"
    };

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String caminho = request.getRequestURI();

        if ("OPTIONS".equalsIgnoreCase(request.getMethod()) || ehCaminhoPublico(caminho)) {
            filterChain.doFilter(request, response);
            return;
        }

        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            enviarNaoAutorizado(response, "Token de autenticação ausente.");
            return;
        }

        String idToken = authHeader.substring(7);

        try {
            FirebaseToken tokenDecodificado = FirebaseAuth.getInstance().verifyIdToken(idToken);
            request.setAttribute("usuarioId", tokenDecodificado.getUid());
            filterChain.doFilter(request, response);
        } catch (FirebaseAuthException e) {
            enviarNaoAutorizado(response, "Token de autenticação inválido ou expirado.");
        }
    }

    private boolean ehCaminhoPublico(String caminho) {
        for (String publico : CAMINHOS_PUBLICOS) {
            if (caminho.startsWith(publico)) return true;
        }
        return false;
    }

    private void enviarNaoAutorizado(HttpServletResponse response, String mensagem) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType("application/json");
        response.getWriter().write("{\"erro\": \"" + mensagem + "\"}");
    }
}
