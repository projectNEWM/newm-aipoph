//// This is a threshold-based datum script. Users with enough dao tokens may
//// petition the dao for a datum update. The Datum is generalized to allow
//// for a dynamic data structures and infinite undateablililty.

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
  // the dao pointer token from the genesis contract
  pointer_pid: PolicyId,
  pointer_tkn: AssetName,
  // the dao vote token that already exists
  dao_pid: PolicyId,
  dao_tkn: AssetName,
) {
  fn params(
    this_datum: DAODatum,
    redeemer: Petition,
    context: ScriptContext,
  ) -> Bool {
    expect Spend(output_reference) = context.purpose
    // the transaction being validated
    let Transaction { inputs, outputs, .. } = context.transaction
    // This brings `lovelace` into scope to adjust the required lovelace 
    // on the utxo being spent
    let Petition(lovelace) = redeemer
    // the input being spent
    let this_input: Input = find.input_by_ref(inputs, output_reference)
    // this value being spent
    let this_value: Value = this_input.output.value
    // this address being spent from
    let this_addr: Address = this_input.output.address
    // that datum must have the DAODatum Structure
    expect that_datum: DAODatum = find.output_datum_by_addr(outputs, this_addr)
    // add or subtract from the required lovelace if necessary
    let that_value: Value =
      value.add(this_value, value.ada_policy_id, value.ada_asset_name, lovelace)
    // the petition threshold to change data
    let petition_threshold: Int = reference.get_petition_threshold(this_datum)
    // the drep address to allow dreps to participate in the dao
    let drep_addr: Address = reference.get_drep_lock_contract(this_datum)
    //
    // check if the utxo is has the correct datum and that the petition threshold exists,
    // it must be holding the correct pointer token, the inputs must contain enough threshold,
    // and the dao utxo must be paid exactly back to the contract.
    // 
    and {
      // at least the initial state has to exist
      reference.does_the_intial_state_exist(this_addr, that_datum)?,
      // this value must be holding the pointer token
      values.prove_exact_nft(this_value, pointer_pid, pointer_tkn)?,
      // must be spending enough of the dao vote token
      tx.total_token_amount(inputs, dao_pid, dao_tkn, petition_threshold)?,
      // send that value exactly back to this address.
      payout.exact(this_addr, that_value, outputs)?,
      // single script input + many dreps; anything else being spent with this should fail
      count.single_input_with_bypass(inputs, this_addr, [drep_addr])?,
      // single script output
      count.outputs_by_addr(outputs, this_addr, 1)?,
    }
  }
}
