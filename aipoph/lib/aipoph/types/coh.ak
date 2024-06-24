use aiken/transaction.{ValidityRange}
use aiken/transaction/value.{Value}
use aipoph/types/poh.{PoHDatum}
use aipoph/types/prove.{Answer, Question}
use assist/types/moment.{Moment}
use assist/types/token.{Token}
use assist/types/wallet.{Wallet}
use assist/values

pub type VerificationData {
  question: Question,
  answer: Answer,
  pointer: Token,
  validity_range: Moment,
}

fn value_has_pointer(this_value: Value, pointer: Token) -> Bool {
  values.prove_exact_nft(this_value, pointer.pid, pointer.tkn)
}

fn is_time_valid(validity: Moment, a_range: ValidityRange) -> Bool {
  and {
    moment.is_logical(validity)?,
    moment.is_contained(validity, a_range)?,
  }
}

/// This checks if the ceritificate of humanity is authentic. It is ran inside
/// the Verify endpoint of coh_lock.ak. A certificate is authentic if and only
/// if the UTxO holds the pointer token, the certificate is still inside the
/// time validity period, and if the Question is satisfied by the Answer.
///
/// ```aiken
/// coh.authenticity_of_verification_data(datum.verification_data, this_value, validity_range)
/// ```
pub fn authenticity_of_verification_data(
  verification_data: VerificationData,
  this_value: Value,
  this_range: ValidityRange,
) -> Bool {
  and {
    value_has_pointer(this_value, verification_data.pointer),
    is_time_valid(verification_data.validity_range, this_range),
    prove.you_are_a_human(verification_data.question, verification_data.answer),
  }
}

pub type CoHDatum {
  owner: Wallet,
  verification: VerificationData,
  // this is the publicKey for signing data
  public_key: ByteArray,
}

pub type CoHLockRedeemer {
  Revoke
  Verify
}

pub type CoHMintRedeemer {
  MintCoHToken
  BurnCoHToken
}

/// When a test is verified and passes the poh datum needs to be transitioned
/// into the coh datum. This ensures the owner remains constant, the 
/// verification data remains constant, and certificate validity period is 
/// valid with respect to the transaction validity period. This is ran during
/// the VerifyTest endpoint of coh_mint.ak.
///
/// ```aiken
/// coh.poh_into_coh(poh_datum, coh_datum, pointer_token, validity_range)
/// ```
pub fn poh_into_coh(
  a: PoHDatum,
  b: CoHDatum,
  t: Token,
  r: ValidityRange,
) -> Bool {
  and {
    (a.owner == b.owner)?,
    (a.test_data.question == b.verification.question)?,
    (a.test_data.answer == b.verification.answer)?,
    (b.verification.pointer == t)?,
    is_time_valid(b.verification.validity_range, r)?,
    (a.public_key == b.public_key)?,
  }
}
