use assist/types/token.{Tokens}

pub type VaultRedeemer {
  AddToVault { incoming: Tokens }
  SubFromVault { outgoing: Tokens }
}
