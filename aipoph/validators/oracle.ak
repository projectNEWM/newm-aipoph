//// This is a random integer and bytearray oracle. It can only be used by a
//// user with enough action tokens. The only requirement for the oracle is the
//// previous values for the integer and bytearray are changed into some new
//// value. Proving and verifying the oracle's randomness is not included.

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/query
use aipoph/types/oracle.{OracleDatum}
use aipoph/types/reference.{ReferenceDatum}
use assist/count
use assist/data
use assist/find
use assist/payout
use assist/tx
use assist/types/hashes.{ValidatorHash}
use assist/values

validator(
  // the pointer token
  pointer_pid: PolicyId,
  pointer_tkn: AssetName,
  // the action token
  action_pid: PolicyId,
  action_tkn: AssetName,
  // the reference contract hash
  ref_data_hash: ValidatorHash,
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
    // get the reference utxo and datum
    let ref_data_addr: Address = credential.from_script(ref_data_hash)
    let ref_data_input: Input =
      find.input_by_addr(reference_inputs, ref_data_addr)
    expect ref_data_datum: ReferenceDatum = data.input_datum(ref_data_input)
    // the threshold to change data
    let oracle_threshold: Int = query.get_oracle_threshold(ref_data_datum)
    // the poh locking address
    let poh_lock_addr: Address = query.get_poh_lock_contract(ref_data_datum)
    //
    // The value should never change and it just returns to the script.
    // The oracle threshold must be met and the datum always has to change
    // when using the oracle.
    //
    and {
      // send back this value to this address
      payout.exact(this_addr, this_value, outputs),
      // the reference input value must be holding the pointer token
      values.prove_exact_nft(
        ref_data_input.output.value,
        pointer_pid,
        pointer_tkn,
      ),
      // must be spending enough of the action token
      tx.total_token_amount(inputs, action_pid, action_tkn, oracle_threshold),
      // datums must not equal, the value has to change
      this_datum.number != that_datum.number,
      this_datum.string != that_datum.string,
      // single script input + poh test generation
      count.single_input_with_bypass(inputs, this_addr, [poh_lock_addr]),
      // single script output
      count.outputs_by_addr(outputs, this_addr, 1),
    }
  }
}
