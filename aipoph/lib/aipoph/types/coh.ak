use aipoph/types.{OwnerInfo}

pub type VerificationData {
  question: Data,
  answer: Data,
}

pub type CoHDatum {
  owner: OwnerInfo,
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
