//// This handles the oracle random data

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/keys
use aipoph/types.{ValidatorHash}
use aipoph/types/dao.{DAODatum, Thresholds}
use aipoph/types/oracle.{OracleDatum}
use assist/count
use assist/data
use assist/find
use assist/payout
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
        // tx being validated
        let tx: Transaction = context.transaction
        let this_input: Input = find.input_by_ref(tx.inputs, output_reference)
        // this value
        let this_value: Value = this_input.output.value
        let this_addr: Address = this_input.output.address
        // the datum cont must be correct structure
        expect that_datum: OracleDatum =
          find.output_datum_by_addr(tx.outputs, this_addr)
        // get reference utxo
        expect dao_hash: ValidatorHash = dao_hash_data
        let dao_addr: Address = credential.from_script(dao_hash)
        let dao_input: Input = find.input_by_addr(tx.reference_inputs, dao_addr)
        // check if the ref input has the correct starter token
        let pointer_token_check: Bool =
          values.prove_exact_nft(
            pointer_pid,
            pointer_tkn,
            dao_input.output.value,
          )
        // get the reference datum
        expect dao_datum: DAODatum = data.input_datum(dao_input)
        // this will fail if it doesn't exist
        expect threshold_data: Thresholds =
          dao.find_data(dao_datum, keys.thresholds)
        // the threshold to change data
        // this will fail if it doesn't exist
        let oracle_threshold: Int =
          dao.find_threshold(threshold_data, keys.oracle_threshold)
        // how much they have inside the tx
        let enough_for_threshold: Bool =
          values.total_token_amount(tx.inputs, dao_pid, dao_tkn, 0) >= oracle_threshold
        // the random data must change when an oracle is used
        and {
          // send back to script but a change in the lovelace
          payout.exact(this_addr, this_value, tx.outputs)?,
          // single script input
          count.inputs_by_addr(tx.inputs, this_addr, 1),
          // single script output
          count.outputs_by_addr(tx.outputs, this_addr, 1),
          // holding the pointer token
          pointer_token_check?,
          // holding enough dao token
          enough_for_threshold?,
          // datums must not equal
          this_datum != that_datum,
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
