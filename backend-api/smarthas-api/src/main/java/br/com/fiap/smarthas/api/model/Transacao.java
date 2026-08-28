package br.com.fiap.smarthas.api.model;


import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class Transacao {
    private String id;
    private String usuarioId;
    private String titulo;
    private Double valor;
    private String data;
    private String tipo;
    private String categoria;
    private Boolean isRecorrente;
    private Integer parcelas;

}