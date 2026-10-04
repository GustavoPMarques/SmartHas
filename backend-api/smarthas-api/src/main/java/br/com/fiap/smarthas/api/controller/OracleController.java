package br.com.fiap.smarthas.api.controller;

import br.com.fiap.smarthas.api.repository.OracleFinanceiroRepository;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/oracle")
@CrossOrigin(origins = "*")
public class OracleController {

    private static final Logger log = LoggerFactory.getLogger(OracleController.class);

    /** Alerta gerado pelas procedures PL/SQL. */
    public record AlertaDTO(long id, String tipo, String mensagem, int ano, int mes, String data) {}

    @Autowired
    private OracleFinanceiroRepository oracle;

    private String usuarioAutenticado(HttpServletRequest request) {
        return (String) request.getAttribute("usuarioId");
    }


    @GetMapping("/resumo/{ano}/{mes}")
    public ResponseEntity<Map<String, Object>> resumo(
            @PathVariable int ano, @PathVariable int mes, HttpServletRequest request) {
        if (mes < 1 || mes > 12) {
            return resposta(HttpStatus.BAD_REQUEST, "erro", "Mês deve estar entre 1 e 12");
        }
        String uid = usuarioAutenticado(request);
        BigDecimal saldo = oracle.saldoPrevisto(uid, ano, mes);
        String texto = oracle.resumoFormatado(uid, ano, mes);

        Map<String, Object> corpo = new LinkedHashMap<>();
        corpo.put("resumo", texto);
        corpo.put("saldoPrevisto", saldo);
        return ResponseEntity.ok(corpo);
    }


    @GetMapping("/alertas")
    public ResponseEntity<List<AlertaDTO>> alertas(HttpServletRequest request) {
        List<AlertaDTO> lista = oracle.alertas(usuarioAutenticado(request))
                .stream().map(this::paraDTO).toList();
        return ResponseEntity.ok(lista);
    }


    @PostMapping("/alertas/gerar/{ano}/{mes}")
    public ResponseEntity<Map<String, Object>> gerarAlertas(@PathVariable int ano, @PathVariable int mes) {
        if (mes < 1 || mes > 12) {
            return resposta(HttpStatus.BAD_REQUEST, "erro", "Mês deve estar entre 1 e 12");
        }
        int criados = oracle.gerarAlertasMensais(ano, mes);
        return resposta(HttpStatus.OK, "alertasCriados", criados);
    }


    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, Object>> oracleIndisponivel(DataAccessException ex) {
        log.warn("Erro ao acessar o Oracle: {}", ex.getMostSpecificCause().getMessage());
        Map<String, Object> corpo = new LinkedHashMap<>();
        corpo.put("erro", "Oracle indisponível ou erro na rotina PL/SQL");
        corpo.put("detalhe", ex.getMostSpecificCause().getMessage());
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(corpo);
    }

    private AlertaDTO paraDTO(Map<String, Object> m) {
        Object dt = m.get("DT_ALERTA");
        String data = dt instanceof java.sql.Timestamp ts ? ts.toLocalDateTime().toString() : String.valueOf(dt);
        return new AlertaDTO(
                ((Number) m.get("ID_ALERTA")).longValue(),
                (String) m.get("TP_ALERTA"),
                (String) m.get("DS_MENSAGEM"),
                ((Number) m.get("NR_ANO")).intValue(),
                ((Number) m.get("NR_MES")).intValue(),
                data);
    }

    private static ResponseEntity<Map<String, Object>> resposta(HttpStatus status, String chave, Object valor) {
        Map<String, Object> corpo = new LinkedHashMap<>();
        corpo.put(chave, valor);
        return ResponseEntity.status(status).body(corpo);
    }
}