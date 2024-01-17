use assist/types.{Wallet}

pub type VerificationData {
  question: Data,
  answer: Data,
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
