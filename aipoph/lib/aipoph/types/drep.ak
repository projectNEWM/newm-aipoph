use aipoph/types.{OwnerInfo}

pub type DRepDatum {
  owner: OwnerInfo,
}

pub type DRepLockRedeemer {
  LockTokens
  Represent
  Retire
}

pub type DRepMintRedeemer {
  MintTokens { mint_amt: Int }
  BurnTokens { burn_amt: Int }
}
