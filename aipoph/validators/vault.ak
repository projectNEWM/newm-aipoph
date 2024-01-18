//// This is a lost deposit vault.

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/catch
use aipoph/reference
use aipoph/types/dao.{DAODatum}
use aipoph/types/vault.{AddToVault, SubFromVault, VaultRedeemer}
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
    _datum: Void,
    redeemer: VaultRedeemer,
    context: ScriptContext,
  ) -> Bool {
    when context.purpose is {
      Spend(output_reference) -> {
        // this tx being validated
        let this_tx: Transaction = context.transaction
        // the input being spent
        let this_input: Input =
          find.input_by_ref(this_tx.inputs, output_reference)
        // this value being spent
        let this_value: Value = this_input.output.value
        // this address being spent from
        let this_addr: Address = this_input.output.address
        // the datum going back to the vault
        // implicit data validation, prevents empty datum attacks
        expect _: Void = find.output_datum_by_addr(this_tx.outputs, this_addr)
        //
        when redeemer is {
          // anyone can add funds to the vault
          AddToVault { incoming } -> {
            // add the incoming token data to this value
            let that_value: Value =
              value.add(this_value, incoming.pid, incoming.tkn, incoming.amt)
            //
            // Tokens can only be added to the UTxO which may cause the minimum
            // required lovelace to increase.
            //
            and {
              // can only add a token
              incoming.amt > 0,
              // send at least that value to this address
              payout.at_least(this_addr, that_value, this_tx.outputs),
              // single script input
              count.inputs_by_addr(this_tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 1),
            }
          }
          // only those with enough dao tokens may subtract from the vault
          SubFromVault { outgoing } -> {
            // subtract the outgoing token data from this value
            let that_value: Value =
              value.add(this_value, outgoing.pid, outgoing.tkn, outgoing.amt)
            // get the dao reference utxo
            let (dao_datum, dao_input): (DAODatum, Input) =
              reference.get_data(this_tx.reference_inputs, dao_hash_data)
            // the threshold to change data
            let extract_vault_threshold: Int =
              reference.get_extract_vault_threshold(dao_datum)
            // get the addresses that 
            let drep_addr: Address = reference.get_drep_lock_contract(dao_datum)
            //
            // Tokens can only be subtracted from the UTxO if and only if there
            // is enough of the dao vote token being spent inside the transaction.
            // The UTxO must always exist so some value has to come back to the
            // contract.
            //
            and {
              // can only subtract a token
              outgoing.amt < 0,
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
                extract_vault_threshold,
              ),
              // send that value to this address
              payout.exact(this_addr, that_value, this_tx.outputs),
              // single script input + many dreps
              catch.specific_inputs_only(this_tx.inputs, this_addr, [drep_addr]),
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
