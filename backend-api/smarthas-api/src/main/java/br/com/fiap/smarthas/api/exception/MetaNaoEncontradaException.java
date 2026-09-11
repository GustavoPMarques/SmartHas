package br.com.fiap.smarthas.api.exception;

public class MetaNaoEncontradaException extends RuntimeException {
    public MetaNaoEncontradaException(String id) {
        super("Meta não encontrada: " + id);
    }
}