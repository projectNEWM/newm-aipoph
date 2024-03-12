use assist/types/token.{Token}

pub type VaultRedeemer {
  AddToVault { incoming: Token }
  SubFromVault { outgoing: Token }
}
