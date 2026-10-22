package com.moishow.identity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

final class PersonalBankModels {
 @Entity(name="PersonalBankAccount") @Table(name="personal_bank_account")
 static class Account extends Models.Row {
  UUID userId;
  String bankName;
  String accountCipher;
  String holderCipher;
  String verificationReference;
  Instant verifiedAt;
  boolean current=true;
 }
}
