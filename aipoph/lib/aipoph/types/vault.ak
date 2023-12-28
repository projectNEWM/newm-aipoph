use assist/types.{Token}

pub type VaultRedeemer {
  AddToVault { incoming: Token }
  SubFromVault { outgoing: Token }
}
