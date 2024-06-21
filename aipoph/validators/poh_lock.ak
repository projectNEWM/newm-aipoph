//// This controls the locking of the proof of humanity token and contains all
//// of the proof of humanity test logic. A user with a successful test will be
//// issued a certificate of humanity inside the coh lock contract. The test
//// taking process is interactive and requires interacting with a external 
//// website for the actual test taking part. A failed test or leaving 
//// prematurely from an acive test results in a lost deposit that is sent to
//// the vault.
////

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/query
use aipoph/token_names
use aipoph/types/poh.{
  EndTest, PoHDatum, PoHLockRedeemer, Quit, StartTest, VerifyTest,
}
use aipoph/types/prove
use aipoph/types/reference.{ReferenceDatum}
use assist/addresses
use assist/count
use assist/data
use assist/find
use assist/minting
use assist/payout
use assist/signing
use assist/types/hashes.{ValidatorHash}
use assist/types/moment
use assist/types/token.{Token}
use assist/values

validator(
  // the proof of humanity pid
  poh_pid: PolicyId,
  // the certificate of humanity pid
  coh_pid: PolicyId,
  // the reference contract hash
  ref_data_hash: ValidatorHash,
) {
  fn params(
    this_datum: PoHDatum,
    redeemer: PoHLockRedeemer,
    context: ScriptContext,
  ) -> Bool {
    expect Spend(output_reference) = context.purpose
    // the transaction being validated
    let Transaction {
      inputs,
      outputs,
      reference_inputs,
      mint,
      extra_signatories,
      validity_range,
      fee,
      ..
    } = context.transaction
    // the input being spent
    let this_input: Input = find.input_by_ref(inputs, output_reference)
    // this address being spent from
    let this_addr: Address = this_input.output.address
    // this value being spent
    let this_value: Value = this_input.output.value
    // something will be minted and burned
    let mint_list: List<(PolicyId, AssetName, Int)> =
      mint
        |> value.from_minted_value()
        |> value.flatten()
    when redeemer is {
      // This starts the poh test by issuesing a poh token to the utxo. Its designed
      // so a threshold actor gets an incentive for setting up a test for the owner
      // of this utxo. The owner does need to sign it so a test technically starts 
      // when they want it to start.
      StartTest -> {
        // that datum must be correct structure
        expect that_datum: PoHDatum =
          find.output_datum_by_addr(outputs, this_addr)
        //
        // If the utxo doesnt have a poh token and is in the correct datum state
        // then mint a poh token to a UTxO and begin the test.
        // This is ran with MintPohToken which holds value logic.
        //
        and {
          // must not have poh token already
          !values.prove_exact_nft(
            this_value,
            poh_pid,
            token_names.poh_token_name,
          )?,
          // the poh token is being minted
          minting.is_occurring(mint_list, poh_pid, token_names.poh_token_name)?,
          // single script output
          count.outputs_by_addr(outputs, this_addr, 1)?,
          // this datum must be in a specific state to start the test
          poh.start_test_datum_validation(this_datum, that_datum)?,
          // must have the deposit
          values.contains(this_value, values.from_token(this_datum.deposit))?,
          // must have 2 units of incentive for start test and verify test
          values.contains(
            this_value,
            values.from_token(this_datum.incentive) |> values.multiply(2),
          )?,
          // owner must sign it to prevent miss starts,
          signing.verify_sig(extra_signatories, this_datum.owner.pkh)?,
        }
      }
      // This will end a test with the user submitting an answer to the question.
      // This endpoint is paid by the owner. They can submit their answer anytime
      // within the validity range of the test. If they miss the deadline to submit
      // then they lose their deposit.
      EndTest(answer) -> {
        // that datum must be correct structure
        expect that_datum: PoHDatum =
          find.output_datum_by_addr(outputs, this_addr)
        //
        // The user submits what they think the answer is. The datum changes
        // into the test ended state and the user will wait for a threshold
        // actor to verify the result.
        //
        and {
          // the test must have been started via minting the poh token
          values.prove_exact_nft(
            this_value,
            poh_pid,
            token_names.poh_token_name,
          )?,
          // single script input
          count.inputs_by_addr(inputs, this_addr, 1)?,
          // single script output
          count.outputs_by_addr(outputs, this_addr, 1)?,
          // owner must sign it
          signing.verify_sig(extra_signatories, this_datum.owner.pkh)?,
          // this value must go back to this address
          payout.exact(this_addr, this_value, outputs)?,
          // the datum must change into the end test state
          poh.end_test_datum_validation(this_datum, that_datum, answer)?,
          // test period must still be valid
          moment.is_contained(
            this_datum.test_data.validity_range,
            validity_range,
          )?,
        }
      }
      // A threshold actor will verify the test. This will result in either a coh token
      // being minted into the coh lock contract or the test deposit will be lost to the
      // vault.
      VerifyTest -> {
        // get the reference utxo and datum
        let ref_data_addr: Address = credential.from_script(ref_data_hash)
        let ref_data_input: Input =
          find.input_by_addr(reference_inputs, ref_data_addr)
        expect ref_data_datum: ReferenceDatum = data.input_datum(ref_data_input)
        // the test owner address
        let owner_address: Address =
          addresses.create_address(this_datum.owner.pkh, this_datum.owner.sc)
        // check if they have the poh token, pass as a human, and ended the test
        if and {
          // this checks if the test started
          values.prove_exact_nft(
            this_value,
            poh_pid,
            token_names.poh_token_name,
          )?,
          // this proves you are a human via the question and answer
          prove.you_are_a_human(
            this_datum.test_data.question,
            this_datum.test_data.answer,
          )?,
          // prove that the answer is signed correctly
          prove.correct_signers(
            this_datum.test_data.answer,
            this_datum.public_key,
            query.get_website_hot_key(ref_data_datum),
          )?,
          // this means the test must have ended
          (this_datum.test_data.cur_stage == 1)?,
        } {
          //
          // The user passed!
          //
          // subtract the token to be burned, the fee, and the incentive
          // then subtract the min lovelace for the coh token
          let owner_value: Value =
            value.add(this_value, poh_pid, token_names.poh_token_name, -1)
              |> value.merge(value.negate(fee))
              |> value.add(
                  this_datum.incentive.pid,
                  this_datum.incentive.tkn,
                  -this_datum.incentive.amt,
                )
              |> value.add(
                  value.ada_policy_id,
                  value.ada_asset_name,
                  -this_datum.min_lovelace,
                )
          //
          // You are a human so burn the poh token and mint the coh token.
          // The deposit is not taken here and the test utxo goes back to
          // the owner automatically. The incentive is left open for the taking.
          //
          and {
            // test needs to be over
            moment.is_after(this_datum.test_data.validity_range, validity_range)?,
            // single script output
            count.outputs_by_addr(outputs, this_addr, 0)?,
            // mint the coh token
            minting.is_occurring(mint_list, coh_pid, token_names.coh_token_name)?,
            // burn the poh token
            minting.is_occurring(mint_list, poh_pid, token_names.poh_token_name)?,
            // owner gets success test utxo back
            payout.exact(owner_address, owner_value, outputs)?,
          }
        } else {
          //
          // The user failed!
          //
          // remove the deposit, burn the poh token
          // remove the fee and an incentive
          // send deposit to the vault, this happens automatically
          let deposit: Token = this_datum.deposit
          let owner_value: Value =
            value.add(this_value, poh_pid, token_names.poh_token_name, -1)
              |> value.add(deposit.pid, deposit.tkn, -deposit.amt)
              |> value.merge(value.negate(fee))
              |> value.add(
                  this_datum.incentive.pid,
                  this_datum.incentive.tkn,
                  -this_datum.incentive.amt,
                )
          //
          // You are not a human so burn the poh token and do not mint a coh token.
          // The deposit is taken here and sent to the vault. The test utxo goes back
          // to the owner automatically.
          //
          and {
            // test needs to be over
            moment.is_after(this_datum.test_data.validity_range, validity_range)?,
            // single script output
            count.outputs_by_addr(outputs, this_addr, 0)?,
            // do not mint the coh token
            !minting.is_occurring(
              mint_list,
              coh_pid,
              token_names.coh_token_name,
            )?,
            // burn the poh token
            minting.is_occurring(mint_list, poh_pid, token_names.poh_token_name)?,
            // owner gets success test utxo back
            payout.exact(owner_address, owner_value, outputs)?,
          }
        }
      }
      // The test owner may quit the test during specific times. If the 
      // test has not started or if they failed to submit the answer
      // in time.
      Quit -> {
        // the test owner address
        let owner_address: Address =
          addresses.create_address(this_datum.owner.pkh, this_datum.owner.sc)
        //
        // Make sure the utxo doesn't contain the poh token.
        // Is the UTxO holding the poh test token?
        //
        if
        value.quantity_of(this_value, poh_pid, token_names.poh_token_name) == 0{
        
          //
          // The test did not start yet so just send the value
          // back to test owner with a signature.
          //
          and {
            // single script input
            count.inputs_by_addr(inputs, this_addr, 1)?,
            // single script output
            count.outputs_by_addr(outputs, this_addr, 0)?,
            // send this value back to the owner address
            payout.exact(owner_address, this_value, outputs)?,
            // owner must sign it
            signing.verify_sig(extra_signatories, this_datum.owner.pkh)?,
          }
        } else {
          //
          // The poh token is on the utxo so the test did start.
          // Leaving the test for any reason after it started will result in a 
          // loss of the deposit.
          //
          //
          // Send the deposit to the vault and burn the poh token.
          let deposit: Token = this_datum.deposit
          // remove the poh token and take the deposit
          let owner_value: Value =
            value.add(this_value, poh_pid, token_names.poh_token_name, -1)
              |> value.add(deposit.pid, deposit.tkn, -deposit.amt)
          //
          // The user loses their deposit due to never finishing the test.
          // The poh token will be burned and the owner must sign it.
          // 
          //
          and {
            // single script output
            count.outputs_by_addr(outputs, this_addr, 0)?,
            // burn the poh token
            minting.is_occurring(mint_list, poh_pid, token_names.poh_token_name)?,
            // the owner gets the left over value
            payout.exact(owner_address, owner_value, outputs)?,
            // owner must sign it
            signing.verify_sig(extra_signatories, this_datum.owner.pkh)?,
          }
        }
      }
    }
  }
}
