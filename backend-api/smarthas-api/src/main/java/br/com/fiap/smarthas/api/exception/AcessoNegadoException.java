package br.com.fiap.smarthas.api.exception;

public class AcessoNegadoException extends RuntimeException {
    public AcessoNegadoException() {
        super("Você não tem permissão para acessar esta transação.");
    }
}
