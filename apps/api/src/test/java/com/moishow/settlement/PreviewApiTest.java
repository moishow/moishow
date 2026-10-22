package com.moishow.settlement;

import com.moishow.MoishowServerApplication;
import org.junit.jupiter.api.*;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.server.context.WebServerApplicationContext;
import org.springframework.context.ConfigurableApplicationContext;
import java.net.URI;
import java.net.http.*;
import java.time.Duration;
import static org.junit.jupiter.api.Assertions.*;

class PreviewApiTest {
    private static ConfigurableApplicationContext context;
    private static int port;
    private static final HttpClient CLIENT=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
    @BeforeAll static void start() {
        context=new SpringApplicationBuilder(MoishowServerApplication.class).profiles("dev")
            .properties("server.port=0","server.address=127.0.0.1","spring.main.banner-mode=off","logging.level.root=ERROR").run();
        port=((WebServerApplicationContext)context).getWebServer().getPort();
    }
    @AfterAll static void stop() { if(context!=null)context.close(); }
    private HttpResponse<String> post(String body) throws Exception {
        return CLIENT.send(HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/api/v1/settlements/preview"))
            .timeout(Duration.ofSeconds(10)).header("Content-Type","application/json").POST(HttpRequest.BodyPublishers.ofString(body)).build(),HttpResponse.BodyHandlers.ofString());
    }
    private String request(String amount) {
        return "{\"hostId\":\"host\",\"rounds\":[{\"id\":\"r\",\"expense\":"+amount+",\"attendeeIds\":[\"a\"],\"cancellations\":[]}],\"receipts\":[{\"id\":\"p\",\"userId\":\"a\",\"amount\":30000,\"confirmed\":true}],\"refunds\":[]}";
    }
    @Test void returnsNetRefundUsingActualReceipt() throws Exception {
        var response=post(request("25000"));assertEquals(200,response.statusCode());
        assertTrue(response.body().contains("\"refund\":5000"),response.body());
        assertTrue(response.body().contains("\"obligation\":25000"),response.body());
    }
    @Test void rejectsNegativeMoney() throws Exception { assertEquals(400,post(request("-1")).statusCode()); }
    @Test void rejectsFractionalMoneyInsteadOfRounding() throws Exception { assertEquals(400,post(request("1.5")).statusCode()); }
    @Test void rejectsStringCoercion() throws Exception { assertEquals(400,post(request("\"25000\"")).statusCode()); }
    @Test void rejectsMissingCollectionsAndMalformedJson() throws Exception {
        assertEquals(400,post("{\"hostId\":\"host\"}").statusCode());assertEquals(400,post("{invalid").statusCode());
    }
    @Test void healthIsAvailableButOtherPathsAreNotPublic() throws Exception {
        var health=CLIENT.send(HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/actuator/health")).GET().build(),HttpResponse.BodyHandlers.ofString());
        assertEquals(200,health.statusCode());
        var forbidden=CLIENT.send(HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/api/private")).GET().build(),HttpResponse.BodyHandlers.ofString());
        assertEquals(403,forbidden.statusCode());
    }
}
