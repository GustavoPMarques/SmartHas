package br.com.fiap.smarthas.api.dto;

import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;
import java.util.List;

@Getter
@Setter
public class MetaResponseDTO {

    private String id;
    private String nome;
    private Double valorAlvo;
    private LocalDate dataCriacao;


    private Double progresso;
    private Integer percentual;
    private Double ritmoMedioMensal;
    private Integer mesesRestantesEstimados;
    private LocalDate dataPrevista;

    // Gerados pela IA
    private String previsaoTexto;
    private List<String> dicas;
    private LocalDate dataUltimaPrevisao;
    //


}