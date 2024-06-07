//// this controls the locking of a certificate of humanity.

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/token_names
use aipoph/types/coh.{CoHDatum, CoHLockRedeemer, Revoke, Verify}
use assist/count
use assist/find
use assist/minting
use assist/payout
use assist/types/token.{Token}

validator(
  // the certificate of humanity pid
  coh_pid: PolicyId,
) {
  fn params(
    this_datum: CoHDatum,
    redeemer: CoHLockRedeemer,
    context: ScriptContext,
  ) -> Bool {
    expect Spend(output_reference) = context.purpose
    // the transaction being validated
    let Transaction { inputs, outputs, mint, validity_range, .. } =
      context.transaction
    // the input being spent
    let this_input: Input = find.input_by_ref(inputs, output_reference)
    // this address being spent from
    let this_addr: Address = this_input.output.address
    // this value being spent
    let this_value: Value = this_input.output.value
    when redeemer is {
      // verify that the coh is real
      Verify -> {
        // that datum cont must be correct structure
        expect that_datum: CoHDatum =
          find.output_datum_by_addr(outputs, this_addr)
        //
        // Just send the value back to itself and run the auth function.
        //
        and {
          // datum stays constant
          this_datum == that_datum,
          // this value must go back to this address
          payout.exact(this_addr, this_value, outputs),
          // single script input
          count.inputs_by_addr(inputs, this_addr, 1),
          // single script output
          count.outputs_by_addr(outputs, this_addr, 1),
          // pass authentication
          coh.authenticity_of_verification_data(
            this_datum.verification,
            this_value,
            validity_range,
          ),
        }
      }
      // this will end a test with the user submitting an answer
      Revoke -> {
        // something will be minted and burned
        let mint_list: List<(PolicyId, AssetName, Int)> =
          mint
            |> value.from_minted_value()
            |> value.flatten()
        //
        // The user submits what they think the answer is.
        //
        and {
          // single script output
          count.outputs_by_addr(outputs, this_addr, 0),
          // must burn the pointer
          minting.is_occurring(
            mint_list,
            coh_pid,
            this_datum.verification.pointer.tkn,
          ),
          // must burn the coh token
          minting.is_occurring(mint_list, coh_pid, token_names.coh_token_name),
        }
      }
    }
  }
}
