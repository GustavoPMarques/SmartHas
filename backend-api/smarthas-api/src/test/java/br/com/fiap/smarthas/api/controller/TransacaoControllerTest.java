package br.com.fiap.smarthas.api.controller;

import br.com.fiap.smarthas.api.dto.ResumoMensalDTO;
import br.com.fiap.smarthas.api.dto.TransacaoRequestDTO;
import br.com.fiap.smarthas.api.dto.TransacaoResponseDTO;
import br.com.fiap.smarthas.api.exception.AcessoNegadoException;
import br.com.fiap.smarthas.api.exception.TransacaoNaoEncontradaException;
import br.com.fiap.smarthas.api.model.TipoTransacao;
import br.com.fiap.smarthas.api.service.TransacaoService;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import tools.jackson.databind.json.JsonMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDate;
import java.util.List;

import static org.hamcrest.Matchers.hasSize;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;



@WebMvcTest(TransacaoController.class)
@AutoConfigureMockMvc(addFilters = false)
class TransacaoControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper objectMapper;

    @MockitoBean
    private TransacaoService transacaoService;

    private TransacaoRequestDTO criarRequestValido() {
        TransacaoRequestDTO dto = new TransacaoRequestDTO();
        dto.setTitulo("Salário");
        dto.setValor(3000.0);
        dto.setData(LocalDate.of(2026, 8, 27));
        dto.setTipo(TipoTransacao.RENDA);
        dto.setCategoria("Trabalho");
        return dto;
    }

    private TransacaoResponseDTO criarResponse() {
        TransacaoResponseDTO dto = new TransacaoResponseDTO();
        dto.setId("abc-123");
        dto.setTitulo("Salário");
        dto.setValor(3000.0);
        dto.setData(LocalDate.of(2026, 8, 27));
        dto.setTipo(TipoTransacao.RENDA);
        dto.setCategoria("Trabalho");
        dto.setIsRecorrente(false);
        dto.setParcelas(1);
        return dto;
    }

    @Test
    void deveCadastrarTransacaoComSucesso() throws Exception {
        when(transacaoService.salvarTransacao(any())).thenReturn(List.of(criarResponse()));

        mockMvc.perform(post("/api/v1/transacoes")
                        .requestAttr("usuarioId", "usuario-teste")
                        .contentType("application/json")
                        .content(objectMapper.writeValueAsString(criarRequestValido())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$[0].titulo").value("Salário"))
                .andExpect(jsonPath("$[0].valor").value(3000.0));
    }

    @Test
    void deveRetornarErroDeValidacaoQuandoTituloEstiverEmBranco() throws Exception {
        TransacaoRequestDTO dto = criarRequestValido();
        dto.setTitulo("");

        mockMvc.perform(post("/api/v1/transacoes")
                        .requestAttr("usuarioId", "usuario-teste")
                        .contentType("application/json")
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.titulo").exists());

        verify(transacaoService, never()).salvarTransacao(any());
    }

    @Test
    void deveRetornarErroDeValidacaoQuandoValorForNulo() throws Exception {
        TransacaoRequestDTO dto = criarRequestValido();
        dto.setValor(null);

        mockMvc.perform(post("/api/v1/transacoes")
                        .requestAttr("usuarioId", "usuario-teste")
                        .contentType("application/json")
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void deveListarTransacoesDoMes() throws Exception {
        when(transacaoService.listarPorMes(eq("usuario-teste"), eq(2026), eq(8)))
                .thenReturn(List.of(criarResponse()));

        mockMvc.perform(get("/api/v1/transacoes/mes/2026/8")
                        .requestAttr("usuarioId", "usuario-teste"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)));
    }

    @Test
    void deveRetornarResumoMensal() throws Exception {
        ResumoMensalDTO resumo = new ResumoMensalDTO(1000.0, 1500.0, 3000.0, 1500.0);
        when(transacaoService.calcularResumo(eq("usuario-teste"), eq(2026), eq(8))).thenReturn(resumo);

        mockMvc.perform(get("/api/v1/transacoes/resumo/2026/8")
                        .requestAttr("usuarioId", "usuario-teste"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.saldoAtual").value(1000.0))
                .andExpect(jsonPath("$.saldoPrevisto").value(1500.0));
    }

    @Test
    void deveAtualizarTransacaoComSucesso() throws Exception {
        when(transacaoService.atualizarTransacao(eq("usuario-teste"), eq("abc-123"), any()))
                .thenReturn(criarResponse());

        mockMvc.perform(put("/api/v1/transacoes/abc-123")
                        .requestAttr("usuarioId", "usuario-teste")
                        .contentType("application/json")
                        .content(objectMapper.writeValueAsString(criarRequestValido())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("abc-123"));
    }

    @Test
    void deveRetornar404AoAtualizarTransacaoInexistente() throws Exception {
        when(transacaoService.atualizarTransacao(anyString(), anyString(), any()))
                .thenThrow(new TransacaoNaoEncontradaException("id-fake"));

        mockMvc.perform(put("/api/v1/transacoes/id-fake")
                        .requestAttr("usuarioId", "usuario-teste")
                        .contentType("application/json")
                        .content(objectMapper.writeValueAsString(criarRequestValido())))
                .andExpect(status().isNotFound());
    }

    @Test
    void deveRetornar403AoAtualizarTransacaoDeOutroUsuario() throws Exception {
        when(transacaoService.atualizarTransacao(anyString(), anyString(), any()))
                .thenThrow(new AcessoNegadoException());

        mockMvc.perform(put("/api/v1/transacoes/abc-123")
                        .requestAttr("usuarioId", "usuario-invasor")
                        .contentType("application/json")
                        .content(objectMapper.writeValueAsString(criarRequestValido())))
                .andExpect(status().isForbidden());
    }

    @Test
    void deveExcluirTransacaoComSucesso() throws Exception {
        doNothing().when(transacaoService).excluirTransacao(eq("usuario-teste"), eq("abc-123"));

        mockMvc.perform(delete("/api/v1/transacoes/abc-123")
                        .requestAttr("usuarioId", "usuario-teste"))
                .andExpect(status().isNoContent());
    }

    @Test
    void deveListarTransacoesPorTipo() throws Exception {
        when(transacaoService.listarPorTipo(eq("usuario-teste"), eq("RENDA")))
                .thenReturn(List.of(criarResponse()));

        mockMvc.perform(get("/api/v1/transacoes/tipo/RENDA")
                        .requestAttr("usuarioId", "usuario-teste"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].tipo").value("RENDA"));
    }
}