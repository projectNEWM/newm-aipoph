//// This handles the oracle for random data

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/reference
use aipoph/types/dao.{DAODatum}
use aipoph/types/oracle.{OracleDatum}
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
  // the dao contract hash
  dao_hash_data: Data,
) {
  fn params(
    this_datum: OracleDatum,
    _redeemer: Void,
    context: ScriptContext,
  ) -> Bool {
    when context.purpose is {
      Spend(output_reference) -> {
        // this_tx being validated
        let this_tx: Transaction = context.transaction
        let this_input: Input =
          find.input_by_ref(this_tx.inputs, output_reference)
        // this value
        let this_value: Value = this_input.output.value
        let this_addr: Address = this_input.output.address
        // the continuing datum must have the correct data structure
        expect that_datum: OracleDatum =
          find.output_datum_by_addr(this_tx.outputs, this_addr)
        // get reference utxo
        let (dao_datum, dao_input): (DAODatum, Input) =
          reference.get_data(this_tx.reference_inputs, dao_hash_data)
        // check that its holding the correct dao datum utxo
        let dao_utxo_must_have_pointer_token: Bool =
          values.prove_exact_nft(
            pointer_pid,
            pointer_tkn,
            dao_input.output.value,
          )
        // the threshold to change data
        let oracle_threshold: Int = reference.get_oracle_threshold(dao_datum)
        // how much they have inside the this_tx
        let must_have_enough_tokens_for_threshold: Bool =
          tx.total_token_amount(
            this_tx.inputs,
            dao_pid,
            dao_tkn,
            oracle_threshold,
          )
        // the random data must change when an oracle is used
        and {
          // send back to script without any change to the value
          payout.exact(this_addr, this_value, this_tx.outputs),
          // single script input
          count.inputs_by_addr(this_tx.inputs, this_addr, 1),
          // single script output
          count.outputs_by_addr(this_tx.outputs, this_addr, 1),
          // holding the pointer token
          dao_utxo_must_have_pointer_token,
          // holding enough dao token
          must_have_enough_tokens_for_threshold,
          // datums must not equal, something has to change
          this_datum != that_datum,
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
