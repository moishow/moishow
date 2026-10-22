package com.moishow.settlement;

import org.springframework.context.annotation.Profile;
import org.springframework.web.bind.annotation.*;

@RestController
@Profile("dev")
@RequestMapping("/api/v1/settlements")
public class SettlementPreviewController {
    private final SettlementCalculator calculator = new SettlementCalculator();
    @PostMapping("/preview")
    public SettlementCalculator.EventResult preview(@RequestBody SettlementCalculator.EventInput input) {
        return calculator.settleEvent(input);
    }
}
