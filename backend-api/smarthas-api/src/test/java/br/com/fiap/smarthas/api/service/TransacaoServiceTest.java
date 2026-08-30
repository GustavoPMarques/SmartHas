package br.com.fiap.smarthas.api.service;

import br.com.fiap.smarthas.api.dto.TransacaoRequestDTO;
import br.com.fiap.smarthas.api.dto.TransacaoResponseDTO;
import br.com.fiap.smarthas.api.exception.AcessoNegadoException;
import br.com.fiap.smarthas.api.exception.TransacaoNaoEncontradaException;
import br.com.fiap.smarthas.api.model.TipoTransacao;
import br.com.fiap.smarthas.api.model.Transacao;
import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.*;
import com.google.firebase.cloud.FirestoreClient;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.concurrent.ExecutionException;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TransacaoServiceTest {

    @Mock private Firestore firestore;
    @Mock private CollectionReference collectionReference;
    @Mock private DocumentReference documentReference;
    @Mock private ApiFuture<DocumentSnapshot> docFuture;
    @Mock private DocumentSnapshot documentSnapshot;
    @Mock private ApiFuture<WriteResult> writeFuture;

    private TransacaoService service;
    private MockedStatic<FirestoreClient> firestoreClientMock;

    @BeforeEach
    void setUp() {
        service = new TransacaoService();
        firestoreClientMock = mockStatic(FirestoreClient.class);
        firestoreClientMock.when(FirestoreClient::getFirestore).thenReturn(firestore);
    }

    @AfterEach
    void tearDown() {
        firestoreClientMock.close();
    }

    /**
     * Stuba todos os campos que TransacaoService#mapearDocumentoParaTransacao lê do
     * DocumentSnapshot. Necessário porque esse método sempre monta o objeto completo,
     * mesmo quando só o "usuarioId" é usado depois (ex: verificação de posse antes de excluir).
     */
    private void stubDocumentoCompleto(String id, String usuarioId, String titulo, double valor,
                                       LocalDate data, TipoTransacao tipo, String categoria,
                                       boolean isRecorrente, int parcelas) {
        when(documentSnapshot.getString("id")).thenReturn(id);
        when(documentSnapshot.getString("usuarioId")).thenReturn(usuarioId);
        when(documentSnapshot.getString("titulo")).thenReturn(titulo);
        when(documentSnapshot.getDouble("valor")).thenReturn(valor);
        when(documentSnapshot.getString("data")).thenReturn(data.toString());
        when(documentSnapshot.getString("tipo")).thenReturn(tipo.name());
        when(documentSnapshot.getString("categoria")).thenReturn(categoria);
        when(documentSnapshot.getBoolean("isRecorrente")).thenReturn(isRecorrente);
        when(documentSnapshot.getLong("parcelas")).thenReturn((long) parcelas);
    }

    @Test
    void deveDividirValorIgualmenteEntreAsParcelas() throws ExecutionException, InterruptedException {
        when(firestore.collection("transacoes")).thenReturn(collectionReference);
        when(collectionReference.document(any())).thenReturn(documentReference);
        // any(Transacao.class) em vez de any(): o DocumentReference.set(...) do Firestore tem
        // mais de uma sobrecarga, e o matcher genérico "any()" pode fazer o Mockito associar a
        // stub à assinatura errada em modo estrito (bug conhecido: mockito/mockito#1353).
        // Tipar o matcher elimina a ambiguidade.
        when(documentReference.set(any(Transacao.class))).thenReturn(writeFuture);
        when(writeFuture.get()).thenReturn(null);

        TransacaoRequestDTO dto = new TransacaoRequestDTO();
        dto.setTitulo("Compra parcelada");
        dto.setValor(300.0);
        dto.setData(LocalDate.of(2026, 1, 15));
        dto.setTipo(TipoTransacao.DESPESA);
        dto.setCategoria("Eletrônicos");
        dto.setParcelas(3);

        List<TransacaoResponseDTO> resultado = service.salvarTransacao(dto);

        assertEquals(3, resultado.size());
        assertEquals(100.0, resultado.get(0).getValor());
        assertTrue(resultado.get(0).getTitulo().contains("(1/3)"));
        assertEquals(LocalDate.of(2026, 3, 15), resultado.get(2).getData());
    }

    @Test
    void deveLancarExcecaoAoAtualizarTransacaoInexistente() {
        when(firestore.collection("transacoes")).thenReturn(collectionReference);
        when(collectionReference.document("id-inexistente")).thenReturn(documentReference);
        when(documentReference.get()).thenReturn(docFuture);
        assertDoesNotThrow(() -> when(docFuture.get()).thenReturn(documentSnapshot));
        when(documentSnapshot.exists()).thenReturn(false);

        TransacaoRequestDTO dto = new TransacaoRequestDTO();
        dto.setTitulo("Teste");
        dto.setValor(100.0);
        dto.setData(LocalDate.of(2026, 8, 1));
        dto.setTipo(TipoTransacao.DESPESA);
        dto.setCategoria("Casa");

        assertThrows(TransacaoNaoEncontradaException.class,
                () -> service.atualizarTransacao("usuario-1", "id-inexistente", dto));
    }

    @Test
    void deveLancarExcecaoAoExcluirTransacaoDeOutroUsuario() {
        when(firestore.collection("transacoes")).thenReturn(collectionReference);
        when(collectionReference.document("id-1")).thenReturn(documentReference);
        when(documentReference.get()).thenReturn(docFuture);
        assertDoesNotThrow(() -> when(docFuture.get()).thenReturn(documentSnapshot));
        when(documentSnapshot.exists()).thenReturn(true);

        // excluirTransacao mapeia o documento inteiro (mapearDocumentoParaTransacao) antes de
        // verificar a posse, então todos os campos lidos por esse método precisam de stub.
        stubDocumentoCompleto("id-1", "dono-verdadeiro", "Aluguel", 1500.0,
                LocalDate.of(2026, 8, 1), TipoTransacao.DESPESA, "Casa", false, 1);

        assertThrows(AcessoNegadoException.class,
                () -> service.excluirTransacao("usuario-impostor", "id-1"));

        verify(documentReference, never()).delete();
    }

    @Test
    void devePermitirExcluirTransacaoDoProprioUsuario() throws ExecutionException, InterruptedException {
        when(firestore.collection("transacoes")).thenReturn(collectionReference);
        when(collectionReference.document("id-1")).thenReturn(documentReference);
        when(documentReference.get()).thenReturn(docFuture);
        when(docFuture.get()).thenReturn(documentSnapshot);
        when(documentSnapshot.exists()).thenReturn(true);

        stubDocumentoCompleto("id-1", "dono-verdadeiro", "Aluguel", 1500.0,
                LocalDate.of(2026, 8, 1), TipoTransacao.DESPESA, "Casa", false, 1);

        when(documentReference.delete()).thenReturn(writeFuture);
        when(writeFuture.get()).thenReturn(null);

        service.excluirTransacao("dono-verdadeiro", "id-1");

        verify(documentReference, times(1)).delete();
    }
}