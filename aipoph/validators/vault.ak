//// this will control where the lost deposits go

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
        // implicit data validation
        expect _: Void = find.output_datum_by_addr(this_tx.outputs, this_addr)
        when redeemer is {
          // anyone can add funds to the vault
          AddToVault { incoming } -> {
            // add the incoming token data to this value
            let that_value: Value =
              value.add(this_value, incoming.pid, incoming.tkn, incoming.amt)
            and {
              // can only add here
              incoming.amt > 0,
              // use at least here so the min ada can be increased
              payout.at_least(this_addr, that_value, this_tx.outputs),
              // single script input
              count.inputs_by_addr(this_tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 1),
            }
          }
          // only those with enough dao tokens may subtract from the vault
          SubFromVault { outgoing } -> {
            let that_value: Value =
              value.add(this_value, outgoing.pid, outgoing.tkn, outgoing.amt)
            // get reference utxo
            let (dao_datum, dao_input): (DAODatum, Input) =
              reference.get_data(this_tx.reference_inputs, dao_hash_data)
            let dao_utxo_must_have_pointer_token: Bool =
              values.prove_exact_nft(
                pointer_pid,
                pointer_tkn,
                dao_input.output.value,
              )
            // the threshold to change data
            let extract_vault_threshold: Int =
              reference.get_extract_vault_threshold(dao_datum)
            // how much they have inside the tx
            let must_have_enough_tokens_for_threshold: Bool =
              tx.total_token_amount(
                this_tx.inputs,
                dao_pid,
                dao_tkn,
                extract_vault_threshold,
              )
            and {
              // can only subtract here
              outgoing.amt < 0,
              // hold right token
              dao_utxo_must_have_pointer_token,
              // has enough token to do this action
              must_have_enough_tokens_for_threshold,
              // removing a token will keep the min ada so use exact here
              payout.exact(this_addr, that_value, this_tx.outputs),
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
