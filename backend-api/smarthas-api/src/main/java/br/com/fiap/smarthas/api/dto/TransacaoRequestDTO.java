package br.com.fiap.smarthas.api.dto;

import br.com.fiap.smarthas.api.model.TipoTransacao;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Data;

import java.time.LocalDate;

@Data
public class TransacaoRequestDTO {

    // Sobrescrito pelo backend com o UID verificado do token — não precisa ser validado aqui.
    private String usuarioId;

    @NotBlank(message = "O título é obrigatório")
    private String titulo;

    @NotNull(message = "O valor é obrigatório")
    @Positive(message = "O valor deve ser maior que zero")
    private Double valor;

    @NotNull(message = "A data é obrigatória")
    private LocalDate data;

    @NotNull(message = "O tipo da transação (RENDA ou DESPESA) é obrigatório")
    private TipoTransacao tipo;

    @NotBlank(message = "A categoria é obrigatória")
    private String categoria;

    private Boolean isRecorrente = false;

    @Min(value = 1, message = "O número mínimo de parcelas é 1")
    private Integer parcelas = 1;
}