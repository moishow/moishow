package com.moishow.identity;
import java.util.UUID;
/** A provider implementation must verify ownership, not trust a client boolean. */
public interface BankOwnershipVerifier {
 String verify(UUID userId,String bank,String accountNumber,String holderName);
 /** Old four-argument lambdas are test-only adapters; production consumes a bound proof. */
 default String verify(UUID userId,String bank,String accountNumber,String holderName,UUID verificationId,String purpose,UUID contextId){return verify(userId,bank,accountNumber,holderName);}
}
