package br.com.fiap.smarthas.api.dto;

import br.com.fiap.smarthas.api.model.TipoTransacao;
import lombok.Data;

import java.time.LocalDate;

@Data
public class TransacaoResponseDTO {
    private String id;
    private String titulo;
    private Double valor;
    private LocalDate data;
    private TipoTransacao tipo;
    private String categoria;
    private Boolean isRecorrente;
    private Integer parcelas;
}