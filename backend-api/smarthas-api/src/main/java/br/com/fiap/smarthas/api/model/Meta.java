package br.com.fiap.smarthas.api.model;

import lombok.Getter;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
public class Meta {

    private String id;
    private String usuarioId;
    private String nome;
    private Double valorAlvo;
    private String dataCriacao;


    private String previsaoTexto;
    private List<String> dicas;
    private String dataUltimaPrevisao;


}