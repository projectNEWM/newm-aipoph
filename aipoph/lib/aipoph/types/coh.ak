use aiken/transaction.{ValidityRange}
use aiken/transaction/value.{Value}
use aipoph/prove
use aipoph/types.{TimeData} as t
use aipoph/types/poh.{PoHDatum}
use assist/types.{Token, Wallet}
use assist/values

pub type VerificationData {
  question: Data,
  answer: Data,
  pointer: Token,
  validity_range: TimeData,
}

pub fn value_has_pointer(this_value: Value, pointer: Token) -> Bool {
  values.prove_exact_nft(pointer.pid, pointer.tkn, this_value)
}

pub fn is_time_valid(validity: TimeData, a_range: ValidityRange) -> Bool {
  and {
    t.logical_time_data(validity),
    t.valid_time_entry(validity, a_range),
  }
}

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
}

pub type CoHLockRedeemer {
  Revoke
  Verify
}

pub type CoHMintRedeemer {
  MintCoHToken
  BurnCoHToken
}

pub fn poh_into_coh(
  a: PoHDatum,
  b: CoHDatum,
  t: Token,
  r: ValidityRange,
) -> Bool {
  and {
    a.owner == b.owner,
    a.test_data.question == b.verification.question,
    a.test_data.answer == b.verification.answer,
    a.test_data.validity_range.end == b.verification.validity_range.start,
    b.verification.pointer == t,
    is_time_valid(b.verification.validity_range, r),
  }
}
