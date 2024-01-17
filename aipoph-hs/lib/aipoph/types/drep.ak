use assist/types.{Wallet}

pub type DRepDatum {
  owner: Wallet,
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
