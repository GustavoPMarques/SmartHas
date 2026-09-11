package br.com.fiap.smarthas.api.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.resilience.annotation.Retryable;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.RestClient;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class GeminiService {

    private static final String MODELO = "gemini-flash-latest";
    private static final String URL = "https://generativelanguage.googleapis.com/v1beta/models/"
            + MODELO + ":generateContent";

    private final RestClient restClient = RestClient.create();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public record PrevisaoIA(String mensagem, List<String> dicas) {}

    public PrevisaoIA gerarPrevisao(String nomeMeta, double valorAlvo, double progresso, int percentual,
                                    double ritmoMedioMensal, Integer mesesRestantes, String categoriaMaiorGasto) {

        String apiKey = System.getenv("GEMINI_API_KEY");
        if (apiKey == null || apiKey.isBlank()) {
            return new PrevisaoIA(
                    "Configuração de IA pendente — defina a variável GEMINI_API_KEY para ver dicas personalizadas.",
                    List.of()
            );
        }

        String prompt = montarPrompt(nomeMeta, valorAlvo, progresso, percentual, ritmoMedioMensal, mesesRestantes, categoriaMaiorGasto);

        try {
            return chamarGeminiComRetry(prompt, apiKey);
        } catch (HttpServerErrorException.ServiceUnavailable e) {
            // esgotou as tentativas de retry, cai aqui
            System.out.println("Gemini indisponível após múltiplas tentativas: " + e.getMessage());
            return new PrevisaoIA(
                    "O serviço de IA está com alta demanda no momento. Tente atualizar a previsão em alguns minutos.",
                    List.of()
            );
        } catch (Exception e) {
            e.printStackTrace();
            return new PrevisaoIA(
                    "Não foi possível gerar dicas personalizadas agora. Tente atualizar a previsão mais tarde.",
                    List.of()
            );
        }
    }

    @Retryable(
            includes = HttpServerErrorException.ServiceUnavailable.class,
            maxRetries = 2,
            delay = 1000,
            multiplier = 2
    )
    protected PrevisaoIA chamarGeminiComRetry(String prompt, String apiKey) throws Exception {
        Map<String, Object> corpo = Map.of(
                "contents", List.of(Map.of(
                        "parts", List.of(Map.of("text", prompt))
                )),
                "generationConfig", Map.of(
                        "responseMimeType", "application/json",
                        "responseSchema", Map.of(
                                "type", "OBJECT",
                                "properties", Map.of(
                                        "mensagem", Map.of("type", "STRING"),
                                        "dicas", Map.of(
                                                "type", "ARRAY",
                                                "items", Map.of("type", "STRING")
                                        )
                                ),
                                "required", List.of("mensagem", "dicas")
                        )
                )
        );

        String respostaBruta = restClient.post()
                .uri(URL)
                .header("x-goog-api-key", apiKey)
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .body(corpo)
                .retrieve()
                .body(String.class);

        return extrairPrevisao(respostaBruta);
    }

    private String montarPrompt(String nomeMeta, double valorAlvo, double progresso, int percentual,
                                double ritmoMedioMensal, Integer mesesRestantes, String categoriaMaiorGasto) {
        StringBuilder prompt = new StringBuilder();
        prompt.append("Você é um assistente financeiro do app Smart HAS. ");
        prompt.append("Com base nos dados reais abaixo (já calculados, não invente nem altere números), ");
        prompt.append("gere uma mensagem curta e motivadora (1-2 frases) e até 3 dicas práticas e específicas ");
        prompt.append("para essa pessoa alcançar a meta mais rápido. Responda em português do Brasil.\n\n");

        prompt.append("Meta: \"").append(nomeMeta).append("\"\n");
        prompt.append("Valor alvo: R$ ").append(String.format("%.2f", valorAlvo)).append("\n");
        prompt.append("Progresso atual: R$ ").append(String.format("%.2f", progresso))
                .append(" (").append(percentual).append("%)\n");
        prompt.append("Ritmo médio de economia: R$ ").append(String.format("%.2f", ritmoMedioMensal)).append("/mês\n");

        if (mesesRestantes != null) {
            prompt.append("Previsão: ").append(mesesRestantes).append(" mês(es) restante(s)\n");
        } else {
            prompt.append("Previsão: não é possível estimar no ritmo atual (economia zerada ou negativa)\n");
        }

        if (categoriaMaiorGasto != null) {
            prompt.append("Categoria de maior despesa no período: ").append(categoriaMaiorGasto).append("\n");
        }

        return prompt.toString();
    }

    private PrevisaoIA extrairPrevisao(String respostaBruta) throws Exception {
        JsonNode raiz = objectMapper.readTree(respostaBruta);
        String textoJson = raiz.at("/candidates/0/content/parts/0/text").asText();

        JsonNode conteudo = objectMapper.readTree(textoJson);
        String mensagem = conteudo.path("mensagem").asText("");

        List<String> dicas = new ArrayList<>();
        conteudo.path("dicas").forEach(no -> dicas.add(no.asText()));

        return new PrevisaoIA(mensagem, dicas);
    }
}