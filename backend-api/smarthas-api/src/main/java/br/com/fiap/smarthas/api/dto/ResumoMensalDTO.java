package br.com.fiap.smarthas.api.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ResumoMensalDTO {
    private Double saldoAtual;
    private Double saldoPrevisto;
    private Double totalRendas;
    private Double totalDespesas;
}