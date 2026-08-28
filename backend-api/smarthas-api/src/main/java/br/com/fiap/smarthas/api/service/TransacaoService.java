package br.com.fiap.smarthas.api.service;

import br.com.fiap.smarthas.api.dto.ResumoMensalDTO;
import br.com.fiap.smarthas.api.dto.TransacaoRequestDTO;
import br.com.fiap.smarthas.api.dto.TransacaoResponseDTO;
import br.com.fiap.smarthas.api.exception.AcessoNegadoException;
import br.com.fiap.smarthas.api.exception.TransacaoNaoEncontradaException;
import br.com.fiap.smarthas.api.model.TipoTransacao;
import br.com.fiap.smarthas.api.model.Transacao;
import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.*;
import com.google.firebase.cloud.FirestoreClient;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutionException;

@Service
public class TransacaoService {

    private static final String COLLECTION_NAME = "transacoes";

    public List<TransacaoResponseDTO> salvarTransacao(TransacaoRequestDTO dto) throws ExecutionException, InterruptedException {
        Firestore dbFirestore = FirestoreClient.getFirestore();
        List<TransacaoResponseDTO> respostas = new ArrayList<>();
        int quantidadeParcelas = dto.getParcelas() != null && dto.getParcelas() > 0 ? dto.getParcelas() : 1;
        double valorParcela = dto.getValor() / quantidadeParcelas;

        for (int i = 0; i < quantidadeParcelas; i++) {
            Transacao transacao = new Transacao();
            String idUnico = UUID.randomUUID().toString();
            transacao.setId(idUnico);
            transacao.setUsuarioId(dto.getUsuarioId());

            String titulo = quantidadeParcelas > 1 ? dto.getTitulo() + " (" + (i + 1) + "/" + quantidadeParcelas + ")" : dto.getTitulo();
            transacao.setTitulo(titulo);

            transacao.setValor(valorParcela);
            transacao.setData(dto.getData().plusMonths(i).toString());
            transacao.setTipo(dto.getTipo() != null ? dto.getTipo().name() : null);
            transacao.setCategoria(dto.getCategoria());

            transacao.setIsRecorrente(quantidadeParcelas == 1 && Boolean.TRUE.equals(dto.getIsRecorrente()));
            transacao.setParcelas(quantidadeParcelas);

            dbFirestore.collection(COLLECTION_NAME).document(idUnico).set(transacao).get();
            respostas.add(converterParaDTO(transacao, LocalDate.parse(transacao.getData())));
        }

        return respostas;
    }

    public List<TransacaoResponseDTO> listarPorMes(String usuarioId, int ano, int mes) throws ExecutionException, InterruptedException {
        Firestore dbFirestore = FirestoreClient.getFirestore();
        List<TransacaoResponseDTO> lista = new ArrayList<>();
        YearMonth mesConsultado = YearMonth.of(ano, mes);

        List<QueryDocumentSnapshot> documents = buscarTodasTransacoes(dbFirestore, usuarioId);

        for (DocumentSnapshot doc : documents) {
            Transacao t = mapearDocumentoParaTransacao(doc);
            if (t.getData() == null) continue;

            LocalDate dataOriginal = LocalDate.parse(t.getData());
            YearMonth mesOriginal = YearMonth.from(dataOriginal);

            boolean ocorreNesseMes = mesOriginal.equals(mesConsultado)
                    || (Boolean.TRUE.equals(t.getIsRecorrente()) && mesConsultado.isAfter(mesOriginal));

            if (ocorreNesseMes) {
                LocalDate dataProjetada = projetarDataNoMes(dataOriginal, mesConsultado);
                lista.add(converterParaDTO(t, dataProjetada));
            }
        }

        lista.sort((a, b) -> a.getData().compareTo(b.getData()));
        return lista;
    }

    public ResumoMensalDTO calcularResumo(String usuarioId, int ano, int mes) throws ExecutionException, InterruptedException {
        Firestore dbFirestore = FirestoreClient.getFirestore();
        LocalDate hoje = LocalDate.now();
        YearMonth mesHoje = YearMonth.from(hoje);
        YearMonth mesSelecionado = YearMonth.of(ano, mes);
        LocalDate fimDoMesSelecionado = mesSelecionado.atEndOfMonth();

        double saldoAtual = 0.0;
        double saldoPrevisto = 0.0;
        double totalRendasMes = 0.0;
        double totalDespesasMes = 0.0;

        List<QueryDocumentSnapshot> documents = buscarTodasTransacoes(dbFirestore, usuarioId);

        for (DocumentSnapshot doc : documents) {
            Transacao t = mapearDocumentoParaTransacao(doc);
            if (t.getData() == null) continue;

            LocalDate dataOriginal = LocalDate.parse(t.getData());
            YearMonth mesOriginal = YearMonth.from(dataOriginal);
            double sinal = "RENDA".equalsIgnoreCase(t.getTipo()) ? 1.0 : -1.0;
            boolean recorrente = Boolean.TRUE.equals(t.getIsRecorrente());

            if (!recorrente) {

                if (!dataOriginal.isAfter(hoje)) {
                    saldoAtual += sinal * t.getValor();
                }
                if (!dataOriginal.isAfter(fimDoMesSelecionado)) {
                    saldoPrevisto += sinal * t.getValor();
                }
                if (mesOriginal.equals(mesSelecionado)) {
                    if (sinal > 0) totalRendasMes += t.getValor(); else totalDespesasMes += t.getValor();
                }
            } else {
                // Recorrente: conta uma ocorrência para cada mês, do mês original até o limite.
                if (!mesOriginal.isAfter(mesHoje)) {
                    long ocorrenciasAteHoje = contarOcorrencias(dataOriginal, mesOriginal, mesHoje, hoje);
                    saldoAtual += sinal * t.getValor() * ocorrenciasAteHoje;
                }
                if (!mesOriginal.isAfter(mesSelecionado)) {
                    long ocorrenciasAteFimMes = ChronoUnit.MONTHS.between(mesOriginal, mesSelecionado) + 1;
                    saldoPrevisto += sinal * t.getValor() * ocorrenciasAteFimMes;
                }
                if (!mesOriginal.isAfter(mesSelecionado)) {
                    if (sinal > 0) totalRendasMes += t.getValor(); else totalDespesasMes += t.getValor();
                }
            }
        }

        return new ResumoMensalDTO(saldoAtual, saldoPrevisto, totalRendasMes, totalDespesasMes);
    }


    private long contarOcorrencias(LocalDate dataOriginal, YearMonth mesOriginal, YearMonth mesHoje, LocalDate hoje) {
        long mesesCompletos = ChronoUnit.MONTHS.between(mesOriginal, mesHoje); // meses anteriores ao atual, todos contam
        LocalDate dataProjetadaNoMesAtual = projetarDataNoMes(dataOriginal, mesHoje);
        boolean ocorrenciaDoMesAtualJaPassou = !dataProjetadaNoMesAtual.isAfter(hoje);
        return mesesCompletos + (ocorrenciaDoMesAtualJaPassou ? 1 : 0);
    }


    private LocalDate projetarDataNoMes(LocalDate dataOriginal, YearMonth mesDestino) {
        int dia = Math.min(dataOriginal.getDayOfMonth(), mesDestino.lengthOfMonth());
        return mesDestino.atDay(dia);
    }

    private List<QueryDocumentSnapshot> buscarTodasTransacoes(Firestore dbFirestore, String usuarioId) throws ExecutionException, InterruptedException {
        ApiFuture<QuerySnapshot> future = dbFirestore.collection(COLLECTION_NAME)
                .whereEqualTo("usuarioId", usuarioId)
                .get();
        return future.get().getDocuments();
    }

    private Transacao mapearDocumentoParaTransacao(DocumentSnapshot doc) {
        Transacao t = new Transacao();
        t.setId(doc.getString("id"));
        t.setUsuarioId(doc.getString("usuarioId"));
        t.setTitulo(doc.getString("titulo"));

        Double valor = doc.getDouble("valor");
        if (valor == null && doc.get("valor") instanceof Long) {
            valor = ((Long) doc.get("valor")).doubleValue();
        }
        t.setValor(valor != null ? valor : 0.0);

        t.setData(doc.getString("data"));
        t.setTipo(doc.getString("tipo"));
        t.setCategoria(doc.getString("categoria"));
        t.setIsRecorrente(doc.getBoolean("isRecorrente"));

        Long parcelas = doc.getLong("parcelas");
        t.setParcelas(parcelas != null ? parcelas.intValue() : 1);

        return t;
    }

    public List<TransacaoResponseDTO> listarPorTipo(String usuarioId, String tipo) throws ExecutionException, InterruptedException {
        Firestore dbFirestore = FirestoreClient.getFirestore();
        List<TransacaoResponseDTO> lista = new ArrayList<>();

        List<QueryDocumentSnapshot> documents = buscarTodasTransacoes(dbFirestore, usuarioId);

        for (DocumentSnapshot doc : documents) {
            Transacao t = mapearDocumentoParaTransacao(doc);
            if (t.getData() == null || t.getTipo() == null) continue;

            if (tipo.equalsIgnoreCase(t.getTipo())) {
                lista.add(converterParaDTO(t, LocalDate.parse(t.getData())));
            }
        }

        lista.sort((a, b) -> b.getData().compareTo(a.getData())); // mais recentes primeiro
        return lista;
    }

    public TransacaoResponseDTO atualizarTransacao(String usuarioIdAutenticado, String id, TransacaoRequestDTO dto) throws ExecutionException, InterruptedException {
        Firestore dbFirestore = FirestoreClient.getFirestore();
        DocumentReference docRef = dbFirestore.collection(COLLECTION_NAME).document(id);
        DocumentSnapshot snapshot = docRef.get().get();

        if (!snapshot.exists()) {
            throw new TransacaoNaoEncontradaException(id);
        }

        Transacao transacao = mapearDocumentoParaTransacao(snapshot);


        if (!usuarioIdAutenticado.equals(transacao.getUsuarioId())) {
            throw new AcessoNegadoException();
        }

        transacao.setTitulo(dto.getTitulo());
        transacao.setValor(dto.getValor());
        transacao.setData(dto.getData().toString());
        transacao.setTipo(dto.getTipo() != null ? dto.getTipo().name() : transacao.getTipo());
        transacao.setCategoria(dto.getCategoria());
        transacao.setIsRecorrente(Boolean.TRUE.equals(dto.getIsRecorrente()));


        docRef.set(transacao).get();
        return converterParaDTO(transacao, dto.getData());
    }

    public void excluirTransacao(String usuarioIdAutenticado, String id) throws ExecutionException, InterruptedException {
        Firestore dbFirestore = FirestoreClient.getFirestore();
        DocumentReference docRef = dbFirestore.collection(COLLECTION_NAME).document(id);
        DocumentSnapshot snapshot = docRef.get().get();

        if (!snapshot.exists()) {
            throw new TransacaoNaoEncontradaException(id);
        }

        Transacao transacao = mapearDocumentoParaTransacao(snapshot);


        if (!usuarioIdAutenticado.equals(transacao.getUsuarioId())) {
            throw new AcessoNegadoException();
        }

        docRef.delete().get();
    }


    private TransacaoResponseDTO converterParaDTO(Transacao transacao, LocalDate dataExibida) {
        TransacaoResponseDTO dto = new TransacaoResponseDTO();
        dto.setId(transacao.getId());
        dto.setTitulo(transacao.getTitulo());
        dto.setValor(transacao.getValor());
        dto.setData(dataExibida);
        dto.setTipo(transacao.getTipo() != null ? TipoTransacao.valueOf(transacao.getTipo()) : null);
        dto.setCategoria(transacao.getCategoria());
        dto.setIsRecorrente(transacao.getIsRecorrente());
        dto.setParcelas(transacao.getParcelas());
        return dto;
    }


}
