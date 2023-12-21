//// this will control where the lost deposits go
//// This stores profit for the casino
//// This handles locking ada for the casino

use aiken/transaction.{Input, ScriptContext, Spend}
use aiken/transaction/value.{AssetName, PolicyId}
use aipoph/reference
use aipoph/types/dao.{DAODatum}
use aipoph/types/vault.{AddToVault, SubFromVault, VaultRedeemer}
use assist/count
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
    _datum: Void,
    redeemer: VaultRedeemer,
    context: ScriptContext,
  ) -> Bool {
    when context.purpose is {
      Spend(output_reference) -> {
        // tx being validated
        let tx = context.transaction
        let this_input = find.input_by_ref(tx.inputs, output_reference)
        let this_value = this_input.output.value
        let this_addr = this_input.output.address
        // the datum going back to the vault
        expect _: Void = find.output_datum_by_addr(tx.outputs, this_addr)
        when redeemer is {
          AddToVault { incoming } -> {
            let cont_value =
              value.add(this_value, incoming.pid, incoming.tkn, incoming.amt)
            and {
              incoming.amt > 0,
              // add ada to the utxo
              payout.exact(this_addr, cont_value, tx.outputs),
              // single script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(tx.outputs, this_addr, 1),
            }
          }

          SubFromVault { outgoing } -> {
            let cont_value =
              value.add(this_value, outgoing.pid, outgoing.tkn, outgoing.amt)
            // get reference utxo
            let (dao_datum, dao_input): (DAODatum, Input) =
              reference.get_data(tx.reference_inputs, dao_hash_data)
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
              values.total_token_amount(tx.inputs, dao_pid, dao_tkn, 0) >= extract_vault_threshold
            and {
              outgoing.amt < 0,
              // hold right token
              pointer_token_check,
              // has enough token to do this action
              enough_for_threshold,
              // add ada to the utxo
              payout.exact(this_addr, cont_value, tx.outputs),
              // single script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(tx.outputs, this_addr, 1),
            }
          }
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
