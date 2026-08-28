package br.com.fiap.smarthas.api.controller;

import br.com.fiap.smarthas.api.dto.ResumoMensalDTO;
import br.com.fiap.smarthas.api.dto.TransacaoRequestDTO;
import br.com.fiap.smarthas.api.dto.TransacaoResponseDTO;
import br.com.fiap.smarthas.api.service.TransacaoService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.concurrent.ExecutionException;

@RestController
@RequestMapping("/api/v1/transacoes")
@CrossOrigin(origins = "*")
public class TransacaoController {

    @Autowired
    private TransacaoService service;


    private String usuarioAutenticado(HttpServletRequest request) {
        return (String) request.getAttribute("usuarioId");
    }

    @PostMapping
    public ResponseEntity<List<TransacaoResponseDTO>> cadastrar(
            @Valid @RequestBody TransacaoRequestDTO dto,
            HttpServletRequest request) throws ExecutionException, InterruptedException {
        dto.setUsuarioId(usuarioAutenticado(request));
        List<TransacaoResponseDTO> novasTransacoes = service.salvarTransacao(dto);
        return ResponseEntity.status(HttpStatus.CREATED).body(novasTransacoes);
    }

    @GetMapping("/mes/{ano}/{mes}")
    public ResponseEntity<List<TransacaoResponseDTO>> listarPorMes(
            @PathVariable int ano,
            @PathVariable int mes,
            HttpServletRequest request) throws ExecutionException, InterruptedException {
        List<TransacaoResponseDTO> transacoes = service.listarPorMes(usuarioAutenticado(request), ano, mes);
        return ResponseEntity.ok(transacoes);
    }

    @GetMapping("/resumo/{ano}/{mes}")
    public ResponseEntity<ResumoMensalDTO> calcularResumo(
            @PathVariable int ano,
            @PathVariable int mes,
            HttpServletRequest request) throws ExecutionException, InterruptedException {
        ResumoMensalDTO resumo = service.calcularResumo(usuarioAutenticado(request), ano, mes);
        return ResponseEntity.ok(resumo);
    }

    @PutMapping("/{id}")
    public ResponseEntity<TransacaoResponseDTO> atualizar(
            @PathVariable String id,
            @Valid @RequestBody TransacaoRequestDTO dto,
            HttpServletRequest request) throws ExecutionException, InterruptedException {
        TransacaoResponseDTO atualizada = service.atualizarTransacao(usuarioAutenticado(request), id, dto);
        return ResponseEntity.ok(atualizada);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> excluir(@PathVariable String id, HttpServletRequest request)
            throws ExecutionException, InterruptedException {
        service.excluirTransacao(usuarioAutenticado(request), id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/tipo/{tipo}")
    public ResponseEntity<List<TransacaoResponseDTO>> listarPorTipo(
            @PathVariable String tipo,
            HttpServletRequest request) throws ExecutionException, InterruptedException {
        List<TransacaoResponseDTO> transacoes = service.listarPorTipo(usuarioAutenticado(request), tipo);
        return ResponseEntity.ok(transacoes);
    }
}
