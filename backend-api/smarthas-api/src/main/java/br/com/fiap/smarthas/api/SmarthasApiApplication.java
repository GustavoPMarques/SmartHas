package br.com.fiap.smarthas.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.resilience.annotation.EnableResilientMethods;

@EnableResilientMethods
@SpringBootApplication
public class SmarthasApiApplication {

	public static void main(String[] args) {
		SpringApplication.run(SmarthasApiApplication.class, args);
	}

}
