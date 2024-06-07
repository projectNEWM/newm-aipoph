//// This is a lost deposit vault.

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/query
use aipoph/types/reference.{ReferenceDatum}
use aipoph/types/vault.{AddToVault, SubFromVault, VaultRedeemer}
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
    _datum: Void,
    redeemer: VaultRedeemer,
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
    // the datum going back to the vault
    // implicit data validation, prevents empty datum attacks
    expect _: Void = find.output_datum_by_addr(outputs, this_addr)
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
          payout.at_least(this_addr, that_value, outputs)?,
          // single script input
          count.inputs_by_addr(inputs, this_addr, 1)?,
          // single script output
          count.outputs_by_addr(outputs, this_addr, 1)?,
        }
      }
      // only those with enough action tokens may subtract from the vault
      SubFromVault { outgoing } -> {
        // subtract the outgoing token data from this value
        let that_value: Value =
          value.add(this_value, outgoing.pid, outgoing.tkn, outgoing.amt)
        // get the reference utxo
        let (reference_datum, reference_input): (ReferenceDatum, Input) =
          query.get_data(reference_inputs, reference_hash_data)
        // the threshold to change data
        let extract_vault_threshold: Int =
          query.get_extract_vault_threshold(reference_datum)
        // get the addresses that 
        let drep_addr: Address = query.get_drep_lock_contract(reference_datum)
        //
        // Tokens can only be subtracted from the UTxO if and only if there
        // is enough of the action token being spent inside the transaction.
        // The UTxO must always exist so some value has to come back to the
        // contract.
        //
        and {
          // can only subtract a token
          outgoing.amt < 0,
          // the reference input value must be holding the pointer token
          values.prove_exact_nft(
            reference_input.output.value,
            pointer_pid,
            pointer_tkn,
          ),
          // must be spending enough of the action token
          tx.total_token_amount(
            inputs,
            action_pid,
            action_tkn,
            extract_vault_threshold,
          ),
          // send that value to this address
          payout.at_least(this_addr, that_value, outputs),
          // single script input + many dreps
          count.single_input_with_bypass(inputs, this_addr, [drep_addr]),
          // single script output
          count.outputs_by_addr(outputs, this_addr, 1),
        }
      }
    }
  }
}
