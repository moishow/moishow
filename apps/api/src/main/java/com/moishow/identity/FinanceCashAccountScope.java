package com.moishow.identity;
import java.util.UUID;
/** Internal verified-bank resolver. A caller cannot choose a free-form uniqueness namespace. */
public interface FinanceCashAccountScope {
 record Scope(String namespace,UUID accountId){}
 Scope resolve(UUID actualActorId,UUID selectedAccountId);
}
