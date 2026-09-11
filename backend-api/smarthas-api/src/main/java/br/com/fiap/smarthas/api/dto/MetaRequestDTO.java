package br.com.fiap.smarthas.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Data;

@Data
public class MetaRequestDTO {

    @NotBlank(message = "O nome da meta é obrigatório")
    private String nome;

    @NotNull(message = "O valor alvo é obrigatório")
    @Positive(message = "O valor alvo deve ser maior que zero")
    private Double valorAlvo;
}