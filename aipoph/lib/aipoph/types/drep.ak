use assist/types/wallet.{Wallet}

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
