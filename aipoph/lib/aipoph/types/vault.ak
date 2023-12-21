use aipoph/types.{TokenInfo}

pub type VaultRedeemer {
  AddToVault { incoming: TokenInfo }
  SubFromVault { outgoing: TokenInfo }
}
