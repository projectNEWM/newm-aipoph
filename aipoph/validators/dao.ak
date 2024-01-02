//// This handles the dao data

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/reference
use aipoph/types/dao.{DAODatum, Petition}
use assist/count
use assist/find
use assist/payout
use assist/tx
use assist/values

validator(
  // the pointer token for pointing at
  pointer_pid: PolicyId,
  pointer_tkn: AssetName,
  // the dao token for voting
  dao_pid: PolicyId,
  dao_tkn: AssetName,
) {
  fn params(
    this_datum: DAODatum,
    redeemer: Petition,
    context: ScriptContext,
  ) -> Bool {
    when context.purpose is {
      Spend(output_reference) -> {
        // This brings `lovelace` into scope.
        let Petition(lovelace) = redeemer
        // this_tx being validated
        let this_tx: Transaction = context.transaction
        // the input being spent
        let this_input: Input =
          find.input_by_ref(this_tx.inputs, output_reference)
        // this value being spent
        let this_value: Value = this_input.output.value
        // this address being spent from
        let this_addr: Address = this_input.output.address
        // the continuing datum must have the correct data structure
        expect that_datum: DAODatum =
          find.output_datum_by_addr(this_tx.outputs, this_addr)
        // the datum continuing needs to have the petition threshold
        let petition_threshold_must_exist_in_that_datum: Bool =
          reference.does_petition_threshold_exist(that_datum)
        // utxo must have pointer token
        let dao_utxo_must_have_pointer_token: Bool =
          values.prove_exact_nft(pointer_pid, pointer_tkn, this_value)
        // add or subtract from the required lovelace if necessary
        let that_value: Value =
          value.add(
            this_value,
            value.ada_policy_id,
            value.ada_asset_name,
            lovelace,
          )
        // the threshold to change data
        let petition_threshold: Int =
          reference.get_petition_threshold(this_datum)
        // how much they have inside the tx
        let must_have_enough_tokens_for_threshold: Bool =
          tx.total_token_amount(
            this_tx.inputs,
            dao_pid,
            dao_tkn,
            petition_threshold,
          )
        // check if correct pointer and enough threshold with an exact payment going back
        and {
          // the petition threshold has to exist and be positive
          petition_threshold_must_exist_in_that_datum,
          // holding the pointer token
          dao_utxo_must_have_pointer_token,
          // holding enough dao token
          must_have_enough_tokens_for_threshold,
          // send back to script but a change in the lovelace
          payout.exact(this_addr, that_value, this_tx.outputs),
          // single script input
          count.inputs_by_addr(this_tx.inputs, this_addr, 1),
          // single script output
          count.outputs_by_addr(this_tx.outputs, this_addr, 1),
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
