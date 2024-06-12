//// This is a lost deposit vault.

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/query
use aipoph/types/reference.{ReferenceDatum}
use aipoph/types/vault.{AddToVault, SubFromVault, VaultRedeemer}
use assist/count
use assist/data
use assist/find
use assist/payout
use assist/tx
use assist/types/hashes.{ValidatorHash}
use assist/types/token
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
    when redeemer is {
      // anyone can add funds to the vault
      AddToVault { incoming } -> {
        // add the incoming token data to this value
        let that_value: Value =
          this_value |> token.add_tokens_to_value(incoming)
        //
        // Tokens can only be added to the UTxO which may cause the minimum
        // required lovelace to increase.
        //
        and {
          // can only add a token
          token.addition_only(incoming),
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
          this_value |> token.add_tokens_to_value(outgoing)
        // get the reference utxo and datum
        let ref_data_addr: Address = credential.from_script(ref_data_hash)
        let ref_data_input: Input =
          find.input_by_addr(reference_inputs, ref_data_addr)
        expect ref_data_datum: ReferenceDatum = data.input_datum(ref_data_input)
        // the threshold to change data
        let extract_vault_threshold: Int =
          query.get_extract_vault_threshold(ref_data_datum)
        //
        // Tokens can only be subtracted from the UTxO if and only if there
        // is enough of the action token being spent inside the transaction.
        // The UTxO must always exist so some value has to come back to the
        // contract.
        //
        and {
          // can only subtract a token
          token.subtraction_only(outgoing),
          // the reference input value must be holding the pointer token
          values.prove_exact_nft(
            ref_data_input.output.value,
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
          payout.exact(this_addr, that_value, outputs),
          // single script input
          count.inputs_by_addr(inputs, this_addr, 1),
          // single script output
          count.outputs_by_addr(outputs, this_addr, 1),
        }
      }
    }
  }
}
