//// This is a threshold-based action token dependent reference datum script. 
//// Users with enough action tokens may perform a datum update. The Datum is
//// generalized to allow for infinite undateablililty. The only requirement
//// for the datum is that the petition threshold, used to check if a user may
//// update the datum, must exist and be non-negative.
////

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/query
use aipoph/types/reference.{ReferenceDatum}
use assist/count
use assist/find
use assist/payout
use assist/tx
use assist/values

validator(
  // the pointer token from the genesis contract
  pointer_pid: PolicyId,
  pointer_tkn: AssetName,
  // the action token that already exists
  action_pid: PolicyId,
  action_tkn: AssetName,
  // maximum quantity of the action token
  action_max: Int,
) {
  fn params(
    this_datum: ReferenceDatum,
    _redeemer: Void,
    context: ScriptContext,
  ) -> Bool {
    expect Spend(output_reference) = context.purpose
    // the transaction being validated
    let Transaction { inputs, outputs, .. } = context.transaction
    // the input being spent
    let this_input: Input = find.input_by_ref(inputs, output_reference)
    // this value being spent
    let this_value: Value = this_input.output.value
    // this address being spent from
    let this_addr: Address = this_input.output.address
    // that datum must have the ReferenceDatum Structure
    expect that_datum: ReferenceDatum =
      find.output_datum_by_addr(outputs, this_addr)
    // add or subtract from the required lovelace if necessary
    let that_value: Value = this_value |> value.without_lovelace()
    // the petition threshold to change data
    let petition_threshold: Int = query.get_petition_threshold(this_datum)
    //
    // check if the utxo is has the correct datum and that the petition threshold exists,
    // it must be holding the correct pointer token, the inputs must contain enough threshold,
    // and the reference utxo must be paid exactly back to the contract.
    // 
    and {
      // at least the initial state has to exist
      query.does_the_intial_state_exist(this_addr, that_datum, action_max)?,
      // this value must be holding the pointer token
      values.prove_exact_nft(this_value, pointer_pid, pointer_tkn)?,
      // must be spending enough of the action vote token
      tx.total_token_amount(inputs, action_pid, action_tkn, petition_threshold)?,
      // send that value exactly back to this address.
      payout.at_least(this_addr, that_value, outputs)?,
      // single script input; anything else being spent with this should fail
      count.inputs_by_addr(inputs, this_addr, 1)?,
      // single script output
      count.outputs_by_addr(outputs, this_addr, 1)?,
    }
  }
}
