//// This is a random integer and bytearray oracle.

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/query
use aipoph/types/oracle.{OracleDatum}
use aipoph/types/reference.{ReferenceDatum}
use assist/count
use assist/find
use assist/payout
use assist/tx
use assist/values

validator(
  // the pointer token
  pointer_pid: PolicyId,
  pointer_tkn: AssetName,
  // the action token
  action_pid: PolicyId,
  action_tkn: AssetName,
  // the reference contract hash
  reference_hash_data: Data,
) {
  fn params(
    this_datum: OracleDatum,
    _redeemer: Void,
    context: ScriptContext,
  ) -> Bool {
    expect Spend(output_reference) = context.purpose
    // the transaction being validated
    let Transaction { inputs, outputs, reference_inputs, .. } =
      context.transaction
    // the input being spent
    let this_input: Input = find.input_by_ref(inputs, output_reference)
    // this value being spent
    let this_value: Value = this_input.output.value
    // this address being spent from
    let this_addr: Address = this_input.output.address
    // that datum must have the correct data structure
    expect that_datum: OracleDatum =
      find.output_datum_by_addr(outputs, this_addr)
    // get the reference reference utxo
    let (reference_datum, reference_input): (ReferenceDatum, Input) =
      query.get_data(reference_inputs, reference_hash_data)
    // the threshold to change data
    let oracle_threshold: Int = query.get_oracle_threshold(reference_datum)
    // the drep address that can be spent from
    let drep_addr: Address = query.get_drep_lock_contract(reference_datum)
    let poh_lock_addr: Address = query.get_poh_lock_contract(reference_datum)
    //
    // The value should never change and it just returns to the script.
    // The oracle threshold must be met and something always has to change
    // when using the oracle.
    //
    and {
      // send back this value to this address
      payout.exact(this_addr, this_value, outputs),
      // the reference input value must be holding the pointer token
      values.prove_exact_nft(
        reference_input.output.value,
        pointer_pid,
        pointer_tkn,
      ),
      // must be spending enough of the action token
      tx.total_token_amount(inputs, action_pid, action_tkn, oracle_threshold),
      // datums must not equal, the value has to change
      this_datum.number != that_datum.number,
      this_datum.string != that_datum.string,
      // single script input + many dreps + poh test generation
      count.single_input_with_bypass(
        inputs,
        this_addr,
        [drep_addr, poh_lock_addr],
      ),
      // single script output
      count.outputs_by_addr(outputs, this_addr, 1),
    }
  }
}
