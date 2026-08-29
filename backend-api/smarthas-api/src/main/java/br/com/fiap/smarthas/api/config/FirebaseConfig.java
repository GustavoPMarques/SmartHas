package br.com.fiap.smarthas.api.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.context.annotation.Configuration;

import jakarta.annotation.PostConstruct;
import java.io.FileInputStream;
import java.io.InputStream;

@Configuration
public class FirebaseConfig {

    @PostConstruct
    public void init() {
        try {
            InputStream serviceAccount;
            String credenciaisPath = System.getenv("FIREBASE_CREDENTIALS_PATH");

            if (credenciaisPath != null && !credenciaisPath.isBlank()) {
                
                serviceAccount = new FileInputStream(credenciaisPath);
            } else {
                
                serviceAccount = getClass().getClassLoader().getResourceAsStream("ServiceAccountKey.json");
            }

            if (serviceAccount == null) {
                throw new RuntimeException("Credenciais do Firebase não encontradas.");
            }

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
                System.out.println("Firebase inicializado com sucesso!");
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}