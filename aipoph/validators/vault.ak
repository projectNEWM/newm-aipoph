//// this will control where the lost deposits go
//// This stores profit for the casino
//// This handles locking ada for the casino

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/reference
use aipoph/types/dao.{DAODatum}
use aipoph/types/vault.{AddToVault, SubFromVault, VaultRedeemer}
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
    _datum: Void,
    redeemer: VaultRedeemer,
    context: ScriptContext,
  ) -> Bool {
    when context.purpose is {
      Spend(output_reference) -> {
        // this_tx being validated
        let this_tx: Transaction = context.transaction
        let this_input: Input =
          find.input_by_ref(this_tx.inputs, output_reference)
        let this_value: Value = this_input.output.value
        let this_addr: Address = this_input.output.address
        // the datum going back to the vault
        expect _: Void = find.output_datum_by_addr(this_tx.outputs, this_addr)
        when redeemer is {
          AddToVault { incoming } -> {
            let cont_value: Value =
              value.add(this_value, incoming.pid, incoming.tkn, incoming.amt)
            and {
              incoming.amt > 0,
              // at least the value so the min ada can be increased
              payout.at_least(this_addr, cont_value, this_tx.outputs),
              // single script input
              count.inputs_by_addr(this_tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 1),
            }
          }

          SubFromVault { outgoing } -> {
            let cont_value: Value =
              value.add(this_value, outgoing.pid, outgoing.tkn, outgoing.amt)
            // get reference utxo
            let (dao_datum, dao_input): (DAODatum, Input) =
              reference.get_data(this_tx.reference_inputs, dao_hash_data)
            let pointer_token_check: Bool =
              values.prove_exact_nft(
                pointer_pid,
                pointer_tkn,
                dao_input.output.value,
              )
            // the threshold to change data
            let extract_vault_threshold: Int =
              reference.get_extract_vault_threshold(dao_datum)
            // how much they have inside the tx
            let enough_for_threshold: Bool =
              tx.total_token_amount(
                this_tx.inputs,
                dao_pid,
                dao_tkn,
                extract_vault_threshold,
              )
            and {
              outgoing.amt < 0,
              // hold right token
              pointer_token_check,
              // has enough token to do this action
              enough_for_threshold,
              // add ada to the utxo
              payout.exact(this_addr, cont_value, this_tx.outputs),
              // single script input
              count.inputs_by_addr(this_tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 1),
            }
          }
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
