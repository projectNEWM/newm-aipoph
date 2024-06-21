//// This controls the locking of a certificate of humanity. It allows any user
//// to verify the certificate by running the Verify endpoint. Any user with
//// action tokens may revoke a certificate of humanity for any reason at any
//// time. The leftover lovelace from a cerificate of humanity UTxO is sent to
//// the vault upon a successfull revoke.
////

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/query
use aipoph/token_names
use aipoph/types/coh.{CoHDatum, CoHLockRedeemer, Revoke, Verify}
use aipoph/types/prove
use aipoph/types/reference.{ReferenceDatum}
use assist/count
use assist/data
use assist/find
use assist/minting
use assist/payout
use assist/types/hashes.{ValidatorHash}
use assist/types/token.{Token}

validator(
  // the certificate of humanity pid
  coh_pid: PolicyId,
  // the reference contract hash
  ref_data_hash: ValidatorHash,
) {
  fn params(
    this_datum: CoHDatum,
    redeemer: CoHLockRedeemer,
    context: ScriptContext,
  ) -> Bool {
    expect Spend(output_reference) = context.purpose
    // the transaction being validated
    let Transaction {
      inputs,
      outputs,
      reference_inputs,
      mint,
      validity_range,
      ..
    } = context.transaction
    // the input being spent
    let this_input: Input = find.input_by_ref(inputs, output_reference)
    // this address being spent from
    let this_addr: Address = this_input.output.address
    // this value being spent
    let this_value: Value = this_input.output.value
    when redeemer is {
      // verify that the coh is real
      Verify -> {
        // get the reference utxo and datum
        let ref_data_addr: Address = credential.from_script(ref_data_hash)
        let ref_data_input: Input =
          find.input_by_addr(reference_inputs, ref_data_addr)
        expect ref_data_datum: ReferenceDatum = data.input_datum(ref_data_input)
        // search the contracts for the poh lock
        // that datum cont must be correct structure
        expect that_datum: CoHDatum =
          find.output_datum_by_addr(outputs, this_addr)
        //
        // Send the UTxO back to the contract and run the authenticity
        // verification function. Anyone can run this at any time.
        //
        and {
          // datum stays constant
          (this_datum == that_datum)?,
          // this value must go back to this address
          payout.exact(this_addr, this_value, outputs)?,
          // single script input
          count.inputs_by_addr(inputs, this_addr, 1)?,
          // single script output
          count.outputs_by_addr(outputs, this_addr, 1)?,
          // pass authentication
          coh.authenticity_of_verification_data(
            this_datum.verification,
            this_value,
            validity_range,
          )?,
          // prove that the answer is signed correctly
          prove.correct_signers(
            this_datum.verification.answer,
            this_datum.public_key,
            query.get_website_hot_key(ref_data_datum),
          )?,
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
        // A certificate of humanity is revoke for some reason. The pointer and
        // the coh are burned and left over UTxO value is sent to the vault.
        //
        and {
          // single script output
          count.outputs_by_addr(outputs, this_addr, 0)?,
          // must burn the pointer
          minting.is_occurring(
            mint_list,
            coh_pid,
            this_datum.verification.pointer.tkn,
          )?,
          // must burn the coh token
          minting.is_occurring(mint_list, coh_pid, token_names.coh_token_name)?,
        }
      }
    }
  }
}
