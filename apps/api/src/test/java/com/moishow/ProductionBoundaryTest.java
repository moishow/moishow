package com.moishow;

import org.junit.jupiter.api.Test;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.server.context.WebServerApplicationContext;
import java.net.URI;
import java.net.http.*;
import static org.junit.jupiter.api.Assertions.*;

class ProductionBoundaryTest {
    @Test void previewIsNotPublicWithoutDevProfile() throws Exception {
        try(var context=new SpringApplicationBuilder(MoishowServerApplication.class)
            .properties("server.port=0","server.address=127.0.0.1","spring.main.banner-mode=off","logging.level.root=ERROR").run()) {
            int port=((WebServerApplicationContext)context).getWebServer().getPort();
            var response=HttpClient.newHttpClient().send(HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/api/v1/settlements/preview"))
                .header("Content-Type","application/json").POST(HttpRequest.BodyPublishers.ofString("{}")).build(),HttpResponse.BodyHandlers.ofString());
            assertEquals(403,response.statusCode());
        }
    }
}
