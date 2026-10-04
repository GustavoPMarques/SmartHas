package br.com.fiap.smarthas.api.repository;

import br.com.fiap.smarthas.api.dto.TransacaoRequestDTO;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Types;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Camada de acesso ao Oracle
 */
@Repository
public class OracleFinanceiroRepository {


    public record ResultadoRegistro(int parcelasGeradas, String alerta) {}

    private final JdbcTemplate jdbc;
    private final SimpleJdbcCall registraTransacao;
    private final SimpleJdbcCall geraAlertasMensais;

    public OracleFinanceiroRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.registraTransacao = new SimpleJdbcCall(jdbc)
                .withProcedureName("PRC_SHAS_REGISTRA_TRANSACAO");
        this.geraAlertasMensais = new SimpleJdbcCall(jdbc)
                .withProcedureName("PRC_SHAS_GERA_ALERTAS_MENSAIS");
    }


    public ResultadoRegistro registrarTransacao(TransacaoRequestDTO dto) {
        Map<String, Object> out = registraTransacao.execute(new MapSqlParameterSource()
                .addValue("P_ID_USUARIO", dto.getUsuarioId())
                .addValue("P_TITULO", dto.getTitulo())
                .addValue("P_VALOR", BigDecimal.valueOf(dto.getValor()))
                .addValue("P_DATA", java.sql.Date.valueOf(dto.getData()))
                .addValue("P_TIPO", dto.getTipo().name())
                .addValue("P_CATEGORIA", dto.getCategoria())
                .addValue("P_RECORRENTE", Boolean.TRUE.equals(dto.getIsRecorrente()) ? "S" : "N")
                .addValue("P_PARCELAS", dto.getParcelas()));

        int parcelas = ((Number) out.get("P_QTD_GERADA")).intValue();
        String alerta = (String) out.get("P_ALERTA");
        return new ResultadoRegistro(parcelas, alerta);
    }


    public int gerarAlertasMensais(int ano, int mes) {
        Map<String, Object> out = geraAlertasMensais.execute(new MapSqlParameterSource()
                .addValue("P_ANO", ano)
                .addValue("P_MES", mes));
        return ((Number) out.get("P_QTD_ALERTAS")).intValue();
    }


    public String resumoFormatado(String usuarioId, int ano, int mes) {
        return jdbc.queryForObject(
                "SELECT fun_shas_resumo_mes(?, ?, ?) FROM dual",
                String.class, usuarioId, ano, mes);
    }


    public BigDecimal saldoPrevisto(String usuarioId, int ano, int mes) {
        return jdbc.queryForObject(
                "SELECT fun_shas_saldo_previsto(?, ?, ?) FROM dual",
                BigDecimal.class, usuarioId, ano, mes);
    }


    public List<Map<String, Object>> alertas(String usuarioId) {
        return jdbc.queryForList("""
                SELECT id_alerta, tp_alerta, ds_mensagem, nr_ano, nr_mes, dt_alerta
                FROM   shas_alerta
                WHERE  id_usuario = ?
                ORDER  BY dt_alerta DESC, id_alerta DESC
                """, usuarioId);
    }


    public List<Map<String, Object>> relatorioCategorias(String usuarioId, int ano, int mes) {
        return jdbc.execute((Connection con) -> {
            List<Map<String, Object>> linhas = new ArrayList<>();
            try (CallableStatement cs = con.prepareCall("{call prc_shas_relatorio_categorias(?, ?, ?, ?)}")) {
                cs.setString(1, usuarioId);
                cs.setInt(2, ano);
                cs.setInt(3, mes);
                cs.registerOutParameter(4, Types.REF_CURSOR);
                cs.execute();
                try (ResultSet rs = (ResultSet) cs.getObject(4)) {
                    while (rs.next()) {
                        Map<String, Object> linha = new LinkedHashMap<>();
                        linha.put("categoria", rs.getString("DS_CATEGORIA"));
                        linha.put("lancamentos", rs.getInt("QTD_LANCAMENTOS"));
                        linha.put("total", rs.getBigDecimal("TOTAL"));
                        linha.put("percentual", rs.getBigDecimal("PERC_DO_TOTAL"));
                        linhas.add(linha);
                    }
                }
            }
            return linhas;
        });
    }


    public List<Map<String, Object>> progressoMetas(String usuarioId) {
        return jdbc.queryForList("""
                SELECT id_meta, nm_meta, vl_alvo, fun_shas_progresso_meta(id_meta) AS progresso
                FROM   shas_meta
                WHERE  id_usuario = ?
                ORDER  BY dt_criacao DESC, nm_meta
                """, usuarioId);
    }


    public void registrarMeta(String id, String usuarioId, String nome, double valorAlvo) {
        jdbc.update("""
                MERGE INTO shas_usuario u
                USING (SELECT ? AS id FROM dual) s ON (u.id_usuario = s.id)
                WHEN NOT MATCHED THEN INSERT (id_usuario) VALUES (s.id)
                """, usuarioId);
        jdbc.update("INSERT INTO shas_meta (id_meta, id_usuario, nm_meta, vl_alvo) VALUES (?, ?, ?, ?)",
                id, usuarioId, nome, BigDecimal.valueOf(valorAlvo));
    }
}