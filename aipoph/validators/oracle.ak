//// This is a random integer and bytearray oracle.

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
  // the dao pointer token
  pointer_pid: PolicyId,
  pointer_tkn: AssetName,
  // the dao vote token
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
        // the input being spent
        let this_input: Input =
          find.input_by_ref(this_tx.inputs, output_reference)
        // this value being spent
        let this_value: Value = this_input.output.value
        // this address being spent from
        let this_addr: Address = this_input.output.address
        // that datum must have the correct data structure
        expect that_datum: OracleDatum =
          find.output_datum_by_addr(this_tx.outputs, this_addr)
        // get the dao reference utxo
        let (dao_datum, dao_input): (DAODatum, Input) =
          reference.get_data(this_tx.reference_inputs, dao_hash_data)
        // the threshold to change data
        let oracle_threshold: Int = reference.get_oracle_threshold(dao_datum)
        //
        // The value should never change and it just returns to the script.
        // The oracle threshold must be met and something always has to change
        // when using the oracle.
        //
        and {
          // send back this value to this address
          payout.exact(this_addr, this_value, this_tx.outputs),
          // the dao input value must be holding the dao pointer token
          values.prove_exact_nft(
            pointer_pid,
            pointer_tkn,
            dao_input.output.value,
          ),
          // must be spending enough of the dao vote token
          tx.total_token_amount(
            this_tx.inputs,
            dao_pid,
            dao_tkn,
            oracle_threshold,
          ),
          // datums must not equal, something has to change
          this_datum != that_datum,
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
