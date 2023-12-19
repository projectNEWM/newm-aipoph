//// This handles the dao data

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/keys
use aipoph/types/dao.{DAODatum, Petition, Thresholds}
use assist/count
use assist/find
use assist/payout
// use assist/signing
use assist/values

validator(
  // the pointer token for pointing at
  pointer_pid: PolicyId,
  pointer_tkn: AssetName,
  // the dao token for voting
  dao_pid: PolicyId,
  dao_tkn: AssetName,
) {
  fn params(datum: DAODatum, redeemer: Petition, context: ScriptContext) -> Bool {
    when context.purpose is {
      Spend(output_reference) -> {
        // This brings `lovelace` in scope.
        let Petition(lovelace) = redeemer
        // tx being validated
        let tx: Transaction = context.transaction
        let this_input: Input = find.input_by_ref(tx.inputs, output_reference)
        // this value
        let this_value: Value = this_input.output.value
        let this_addr: Address = this_input.output.address
        // the datum cont must be correct structure
        expect _: DAODatum = find.output_datum_by_addr(tx.outputs, this_addr)
        // utxo must have pointer token
        let pointer_token_check: Bool =
          values.prove_exact_nft(pointer_pid, pointer_tkn, this_value)
        // set a direction for add and remove
        let cont_value: Value =
          value.add(
            this_value,
            value.ada_policy_id,
            value.ada_asset_name,
            lovelace,
          )
        // this will fail if it doesn't exist
        expect threshold_data: Thresholds =
          dao.find_data(datum, keys.thresholds)
        // the threshold to change data
        // this will fail if it doesn't exist
        let petition_threshold: Int =
          dao.find_threshold(threshold_data, keys.petition_threshold)
        // how much they have inside the tx
        let enough_for_threshold: Bool =
          values.total_token_amount(tx.inputs, dao_pid, dao_tkn, 0) >= petition_threshold
        and {
          // send back to script but a change in the lovelace
          payout.exact(this_addr, cont_value, tx.outputs)?,
          // single script input
          count.inputs_by_addr(tx.inputs, this_addr, 1),
          // single script output
          count.outputs_by_addr(tx.outputs, this_addr, 1),
          // holding the pointer token
          pointer_token_check?,
          // holding enough dao token
          enough_for_threshold?,
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
