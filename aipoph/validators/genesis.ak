//// Mint an nft

use aiken/transaction.{Mint, OutputReference, ScriptContext, Transaction}
use aiken/transaction/value.{AssetName, PolicyId}
use aipoph/reference
use aipoph/token_names
use aipoph/types/dao.{DAODatum}
use assist/find
use assist/minting
use assist/std
use assist/tx
use assist/types.{TxHash}
use assist/values

validator(
  // transaction id hash
  tx_id_hash: TxHash,
  // the transaction id index
  tx_id_idx: Int,
) {
  fn params(_redeemer: Void, context: ScriptContext) -> Bool {
    when context.purpose is {
      // Mint 1 to 1 tokens, no burning
      Mint(currency_symbol) -> {
        // the transaction being validated
        let this_tx: Transaction = context.transaction
        // we need to mint the dao pointer token
        let mint: List<(PolicyId, AssetName, Int)> =
          this_tx.mint
            |> value.from_minted_value()
            |> value.flatten()
        // generate the name from the compiled data
        let token_name: AssetName =
          values.unique_token_name(tx_id_hash, tx_id_idx, token_names.prefix)
        // this output reference must be spent
        let this_out_ref: OutputReference = std.out_ref(tx_id_hash, tx_id_idx)
        // the continuing datum must have the correct data structure
        expect datum: DAODatum = find.first_output_datum(this_tx.outputs)
        // check if the dao threshold exists
        let petition_threshold_must_exist: Bool =
          reference.does_petition_threshold_exist(datum)
        and {
          // petition must exist and be positive
          petition_threshold_must_exist,
          // must be spending the utxo
          tx.is_spending_input(this_tx.inputs, this_out_ref),
          // mint exactly 1 token
          minting.exact(mint, currency_symbol, token_name, 1),
        }
      }
      // Minting Only
      _ -> False
    }
  }
}
