package br.com.fiap.smarthas.api.service;

import br.com.fiap.smarthas.api.dto.MetaRequestDTO;
import br.com.fiap.smarthas.api.dto.MetaResponseDTO;
import br.com.fiap.smarthas.api.exception.AcessoNegadoException;
import br.com.fiap.smarthas.api.exception.MetaNaoEncontradaException;
import br.com.fiap.smarthas.api.model.Meta;
import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.*;
import com.google.firebase.cloud.FirestoreClient;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.concurrent.ExecutionException;


@Service
public class MetaService {

    private static final String COLLECTION_METAS = "metas";
    private static final String COLLECTION_TRANSACOES = "transacoes";

    private final GeminiService geminiService;

    public MetaService(GeminiService geminiService) {
        this.geminiService = geminiService;
    }

    public MetaResponseDTO criar(String usuarioId, MetaRequestDTO dto) throws ExecutionException, InterruptedException {
        Firestore db = FirestoreClient.getFirestore();

        Meta meta = new Meta();
        meta.setId(UUID.randomUUID().toString());
        meta.setUsuarioId(usuarioId);
        meta.setNome(dto.getNome());
        meta.setValorAlvo(dto.getValorAlvo());
        meta.setDataCriacao(LocalDate.now().toString());

        MetaResponseDTO resposta = calcularProgresso(meta, db);
        gerarEcachearPrevisao(meta, resposta, db);

        db.collection(COLLECTION_METAS).document(meta.getId()).set(meta).get();

        return montarResposta(meta, resposta);
    }

    public List<MetaResponseDTO> listar(String usuarioId) throws ExecutionException, InterruptedException {
        Firestore db = FirestoreClient.getFirestore();
        List<MetaResponseDTO> lista = new ArrayList<>();

        for (QueryDocumentSnapshot doc : buscarMetasDoUsuario(db, usuarioId)) {
            Meta meta = mapearMeta(doc);
            MetaResponseDTO progresso = calcularProgresso(meta, db);
            lista.add(montarResposta(meta, progresso));
        }

        return lista;
    }

    public MetaResponseDTO atualizarPrevisao(String usuarioId, String id) throws ExecutionException, InterruptedException {
        Firestore db = FirestoreClient.getFirestore();
        DocumentReference docRef = db.collection(COLLECTION_METAS).document(id);
        DocumentSnapshot snapshot = docRef.get().get();

        if (!snapshot.exists()) {
            throw new MetaNaoEncontradaException(id);
        }

        Meta meta = mapearMeta(snapshot);

        if (!usuarioId.equals(meta.getUsuarioId())) {
            throw new AcessoNegadoException();
        }

        MetaResponseDTO progresso = calcularProgresso(meta, db);
        gerarEcachearPrevisao(meta, progresso, db);
        docRef.set(meta).get();

        return montarResposta(meta, progresso);
    }

    public void excluir(String usuarioId, String id) throws ExecutionException, InterruptedException {
        Firestore db = FirestoreClient.getFirestore();
        DocumentReference docRef = db.collection(COLLECTION_METAS).document(id);
        DocumentSnapshot snapshot = docRef.get().get();

        if (!snapshot.exists()) {
            throw new MetaNaoEncontradaException(id);
        }

        Meta meta = mapearMeta(snapshot);

        if (!usuarioId.equals(meta.getUsuarioId())) {
            throw new AcessoNegadoException();
        }

        docRef.delete().get();
    }


    private MetaResponseDTO calcularProgresso(Meta meta, Firestore db) throws ExecutionException, InterruptedException {
        LocalDate dataCriacao = LocalDate.parse(meta.getDataCriacao());
        LocalDate hoje = LocalDate.now();

        List<QueryDocumentSnapshot> transacoes = buscarTransacoesDoUsuario(db, meta.getUsuarioId());

        double economiaAcumulada = 0.0;
        Map<String, Double> gastosPorCategoria = new HashMap<>();

        for (QueryDocumentSnapshot doc : transacoes) {
            String dataStr = doc.getString("data");
            String tipo = doc.getString("tipo");
            Boolean recorrente = doc.getBoolean("isRecorrente");
            Double valor = doc.getDouble("valor");
            String categoria = doc.getString("categoria");

            if (dataStr == null || tipo == null || valor == null) continue;

            LocalDate dataOriginal = LocalDate.parse(dataStr);
            double sinal = "RENDA".equalsIgnoreCase(tipo) ? 1.0 : -1.0;

            if (Boolean.TRUE.equals(recorrente)) {
                YearMonth mesOriginal = YearMonth.from(dataOriginal);
                YearMonth mesInicioMeta = YearMonth.from(dataCriacao);
                YearMonth mesInicioContagem = mesOriginal.isAfter(mesInicioMeta) ? mesOriginal : mesInicioMeta;
                YearMonth mesHoje = YearMonth.from(hoje);

                if (!mesInicioContagem.isAfter(mesHoje)) {
                    long ocorrencias = ChronoUnit.MONTHS.between(mesInicioContagem, mesHoje) + 1;
                    economiaAcumulada += sinal * valor * ocorrencias;
                    if (sinal < 0 && categoria != null) {
                        gastosPorCategoria.merge(categoria, valor * ocorrencias, Double::sum);
                    }
                }
            } else {

                if (!dataOriginal.isBefore(dataCriacao) && !dataOriginal.isAfter(hoje)) {
                    economiaAcumulada += sinal * valor;
                    if (sinal < 0 && categoria != null) {
                        gastosPorCategoria.merge(categoria, valor, Double::sum);
                    }
                }
            }
        }

        double progresso = Math.max(0.0, economiaAcumulada);
        long mesesDecorridos = Math.max(1, ChronoUnit.MONTHS.between(YearMonth.from(dataCriacao), YearMonth.from(hoje)) + 1);
        double ritmoMedioMensal = economiaAcumulada / mesesDecorridos;

        int percentual = meta.getValorAlvo() > 0
                ? (int) Math.min(100, Math.round((progresso / meta.getValorAlvo()) * 100))
                : 0;

        Integer mesesRestantes = null;
        LocalDate dataPrevista = null;
        if (ritmoMedioMensal > 0 && progresso < meta.getValorAlvo()) {
            mesesRestantes = (int) Math.ceil((meta.getValorAlvo() - progresso) / ritmoMedioMensal);
            dataPrevista = hoje.plusMonths(mesesRestantes);
        } else if (progresso >= meta.getValorAlvo()) {
            mesesRestantes = 0;
            dataPrevista = hoje;
        }

        String categoriaMaiorGasto = gastosPorCategoria.entrySet().stream()
                .max(Map.Entry.comparingByValue())
                .map(Map.Entry::getKey)
                .orElse(null);

        MetaResponseDTO dto = new MetaResponseDTO();
        dto.setProgresso(progresso);
        dto.setPercentual(percentual);
        dto.setRitmoMedioMensal(ritmoMedioMensal);
        dto.setMesesRestantesEstimados(mesesRestantes);
        dto.setDataPrevista(dataPrevista);
        dto.setPrevisaoTexto(categoriaMaiorGasto);

        return dto;
    }



    private void gerarEcachearPrevisao(Meta meta, MetaResponseDTO progresso, Firestore db) {
        String categoriaMaiorGasto = progresso.getPrevisaoTexto();

        GeminiService.PrevisaoIA previsao = geminiService.gerarPrevisao(
                meta.getNome(),
                meta.getValorAlvo(),
                progresso.getProgresso(),
                progresso.getPercentual(),
                progresso.getRitmoMedioMensal(),
                progresso.getMesesRestantesEstimados(),
                categoriaMaiorGasto
        );

        meta.setPrevisaoTexto(previsao.mensagem());
        meta.setDicas(previsao.dicas());
        meta.setDataUltimaPrevisao(LocalDate.now().toString());


        progresso.setPrevisaoTexto(previsao.mensagem());
    }



    private List<QueryDocumentSnapshot> buscarMetasDoUsuario(Firestore db, String usuarioId) throws ExecutionException, InterruptedException {
        ApiFuture<QuerySnapshot> future = db.collection(COLLECTION_METAS).whereEqualTo("usuarioId", usuarioId).get();
        return future.get().getDocuments();
    }

    private List<QueryDocumentSnapshot> buscarTransacoesDoUsuario(Firestore db, String usuarioId) throws ExecutionException, InterruptedException {
        ApiFuture<QuerySnapshot> future = db.collection(COLLECTION_TRANSACOES).whereEqualTo("usuarioId", usuarioId).get();
        return future.get().getDocuments();
    }

    private Meta mapearMeta(DocumentSnapshot doc) {
        Meta meta = new Meta();
        meta.setId(doc.getString("id"));
        meta.setUsuarioId(doc.getString("usuarioId"));
        meta.setNome(doc.getString("nome"));
        meta.setValorAlvo(doc.getDouble("valorAlvo"));
        meta.setDataCriacao(doc.getString("dataCriacao"));
        meta.setPrevisaoTexto(doc.getString("previsaoTexto"));
        meta.setDataUltimaPrevisao(doc.getString("dataUltimaPrevisao"));
        @SuppressWarnings("unchecked")
        List<String> dicas = (List<String>) doc.get("dicas");
        meta.setDicas(dicas);
        return meta;
    }

    private MetaResponseDTO montarResposta(Meta meta, MetaResponseDTO progresso) {
        MetaResponseDTO dto = new MetaResponseDTO();
        dto.setId(meta.getId());
        dto.setNome(meta.getNome());
        dto.setValorAlvo(meta.getValorAlvo());
        dto.setDataCriacao(LocalDate.parse(meta.getDataCriacao()));
        dto.setProgresso(progresso.getProgresso());
        dto.setPercentual(progresso.getPercentual());
        dto.setRitmoMedioMensal(progresso.getRitmoMedioMensal());
        dto.setMesesRestantesEstimados(progresso.getMesesRestantesEstimados());
        dto.setDataPrevista(progresso.getDataPrevista());
        dto.setPrevisaoTexto(meta.getPrevisaoTexto());
        dto.setDicas(meta.getDicas());
        dto.setDataUltimaPrevisao(meta.getDataUltimaPrevisao() != null ? LocalDate.parse(meta.getDataUltimaPrevisao()) : null);
        return dto;
    }
}