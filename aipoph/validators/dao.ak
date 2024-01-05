//// This is a threshold-based data script for a dao.

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
  // the dao pointer token
  pointer_pid: PolicyId,
  pointer_tkn: AssetName,
  // the dao vote token
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
        //
        // check if the utxo is has the correct datum and that the petition threshold exists,
        // it must be holding the correct pointer token, the inputs must contain enough threshold,
        // and the dao utxo must be paid exactly back to the contract.
        // 
        and {
          // the petition threshold has to exist and be positive
          reference.does_petition_threshold_exist(that_datum),
          // this value must be holding the pointer token
          values.prove_exact_nft(pointer_pid, pointer_tkn, this_value),
          // must be spending enough of the dao vote token
          tx.total_token_amount(
            this_tx.inputs,
            dao_pid,
            dao_tkn,
            petition_threshold,
          ),
          // send that value exactly back to this address.
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
