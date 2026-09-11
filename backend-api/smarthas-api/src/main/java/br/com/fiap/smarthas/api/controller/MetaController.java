package br.com.fiap.smarthas.api.controller;

import br.com.fiap.smarthas.api.dto.MetaRequestDTO;
import br.com.fiap.smarthas.api.dto.MetaResponseDTO;
import br.com.fiap.smarthas.api.service.MetaService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.concurrent.ExecutionException;

@RestController
@RequestMapping("/api/v1/metas")
@CrossOrigin(origins = "*")
public class MetaController {

    @Autowired
    private MetaService service;

    /** UID já verificado pelo FirebaseAuthFilter — mesmo padrão do TransacaoController. */
    private String usuarioAutenticado(HttpServletRequest request) {
        return (String) request.getAttribute("usuarioId");
    }

    @PostMapping
    public ResponseEntity<MetaResponseDTO> criar(
            @Valid @RequestBody MetaRequestDTO dto,
            HttpServletRequest request) throws ExecutionException, InterruptedException {
        MetaResponseDTO nova = service.criar(usuarioAutenticado(request), dto);
        return ResponseEntity.status(HttpStatus.CREATED).body(nova);
    }

    @GetMapping
    public ResponseEntity<List<MetaResponseDTO>> listar(HttpServletRequest request)
            throws ExecutionException, InterruptedException {
        return ResponseEntity.ok(service.listar(usuarioAutenticado(request)));
    }

    @PostMapping("/{id}/atualizar-previsao")
    public ResponseEntity<MetaResponseDTO> atualizarPrevisao(
            @PathVariable String id,
            HttpServletRequest request) throws ExecutionException, InterruptedException {
        return ResponseEntity.ok(service.atualizarPrevisao(usuarioAutenticado(request), id));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> excluir(@PathVariable String id, HttpServletRequest request)
            throws ExecutionException, InterruptedException {
        service.excluir(usuarioAutenticado(request), id);
        return ResponseEntity.noContent().build();
    }
}