package com.moishow.identity;
import java.util.UUID;
/** A provider implementation must verify ownership, not trust a client boolean. */
public interface BankOwnershipVerifier {String verify(UUID userId,String bank,String accountNumber,String holderName);}
