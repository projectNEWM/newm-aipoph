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
  MintRepTokens { mint_amt: Int }
  BurnRepTokens { burn_amt: Int }
}
