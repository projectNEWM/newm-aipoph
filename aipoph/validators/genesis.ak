//// Mint an nft

use aiken/hash.{Blake2b_256, Hash}
use aiken/transaction.{Mint, ScriptContext, Transaction}
use aiken/transaction/value.{AssetName, PolicyId}
use aipoph/types
use assist/minting
use assist/values

validator(tx_id_hash: Hash<Blake2b_256, Transaction>, tx_id_idx: Int) {
  fn params(_redeemer: Void, context: ScriptContext) -> Bool {
    when context.purpose is {
      // Mint 1 to 1 tokens
      Mint(currency_symbol) -> {
        // the transaction being validated
        let tx: Transaction = context.transaction
        let mint: List<(PolicyId, AssetName, Int)> =
          tx.mint
            |> value.from_minted_value()
            |> value.flatten()
        let token_name: AssetName =
          values.unique_token_name(tx_id_hash, tx_id_idx, types.prefix)
        minting.exact(mint, currency_symbol, token_name, 1)
      }
      // Minting Only
      _ -> False
    }
  }
}
