//// this controls the locking of the poh pointer token and contains all of the
//// poh test logic. a successful test will issue a certificate of humanity

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/prove
use aipoph/token_names
use aipoph/types/poh.{
  EndTest, PoHDatum, PoHLockRedeemer, Quit, StartTest, VerifyTest,
}
use assist/addresses
use assist/count
use assist/find
use assist/minting
use assist/payout
use assist/signing
use assist/types/moment
use assist/types/token.{Token}
use assist/values

validator(
  // the proof of humanity pid
  poh_pid: PolicyId,
  // the certificate of humanity pid
  coh_pid: PolicyId,
) {
  fn params(
    this_datum: PoHDatum,
    redeemer: PoHLockRedeemer,
    context: ScriptContext,
  ) -> Bool {
    when context.purpose is {
      Spend(output_reference) -> {
        // this_tx being validated
        let this_tx: Transaction = context.transaction
        // the input being spent
        let this_input: Input =
          find.input_by_ref(this_tx.inputs, output_reference)
        // this address being spent from
        let this_addr: Address = this_input.output.address
        // this value being spent
        let this_value: Value = this_input.output.value
        // something will be minted and burned
        let mint: List<(PolicyId, AssetName, Int)> =
          this_tx.mint
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
              find.output_datum_by_addr(this_tx.outputs, this_addr)
            //
            // If the utxo doesnt have a poh token and is in the correct datum state
            // then mint a poh token to a UTxO and begin the test.
            // This is ran with MintPohToken.
            //
            and {
              // must not have poh token already
              !values.prove_exact_nft(
                poh_pid,
                token_names.poh_token_name,
                this_value,
              )?,
              // the poh token is being minted
              minting.is_occurring(mint, poh_pid, token_names.poh_token_name),
              // single script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 1),
              // this datum must be in a specific state to start the test
              poh.start_test_datum_validation(this_datum, that_datum),
              // must have the deposit
              values.contains(values.from_token(this_datum.deposit), this_value),
              // must have 2 units of incentive for start test and verify test
              values.contains(
                values.from_token(this_datum.incentive) |> values.multiply(2),
                this_value,
              ),
              // owner must sign it to prevent miss starts,
              signing.verify_sig(
                this_tx.extra_signatories,
                this_datum.owner.pkh,
              ),
            }
          }
          // This will end a test with the user submitting an answer to the question.
          // This endpoint is paid by the owner. They can submit their answer anytime
          // within the validity range of the test. If they miss the deadline to submit
          // then they lose their deposit.
          EndTest { answer } -> {
            // that datum must be correct structure
            expect that_datum: PoHDatum =
              find.output_datum_by_addr(this_tx.outputs, this_addr)
            //
            // The user submits what they think the answer is. The datum changes
            // into the test ended state and the user will wait for a threshold
            // actor to verify the result.
            //
            and {
              // the test must have been started via minting the poh token
              values.prove_exact_nft(
                poh_pid,
                token_names.poh_token_name,
                this_value,
              )?,
              // single script input
              count.inputs_by_addr(this_tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 1),
              // owner must sign it
              signing.verify_sig(
                this_tx.extra_signatories,
                this_datum.owner.pkh,
              ),
              // this value must go back to this address
              payout.exact(this_addr, this_value, this_tx.outputs),
              // the datum must change into the end test state
              poh.end_test_datum_validation(this_datum, that_datum, answer)?,
              // test period must still be valid
              moment.is_contained(
                this_datum.test_data.validity_range,
                this_tx.validity_range,
              )?,
            }
          }
          // A threshold actor will verify the test. This will result in either a coh token
          // being minted into the coh lock contract or the test deposit will be lost to the
          // dao vault.
          VerifyTest -> {
            // the test owner address
            let owner_address: Address =
              addresses.create_address(
                this_datum.owner.pkh,
                this_datum.owner.sc,
              )
            // check if they have the poh token, pass as a human, and ended the test
            if and {
              // this checks if the test started
              values.prove_exact_nft(
                poh_pid,
                token_names.poh_token_name,
                this_value,
              ),
              // this proves you are a human via the question and answer
              prove.you_are_a_human(
                this_datum.test_data.question,
                this_datum.test_data.answer,
              ),
              // this means the test must have ended
              this_datum.test_data.cur_stage == 1,
            } {
              //
              // The user passed!
              //
              // subtract the burn token, the fee, and the incentive
              // then subtract the min lovelace for the coh token
              let owner_value: Value =
                value.add(this_value, poh_pid, token_names.poh_token_name, -1)
                  |> value.merge(value.negate(this_tx.fee))
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
                // single script output
                count.outputs_by_addr(this_tx.outputs, this_addr, 0),
                // mint the coh token
                minting.is_occurring(mint, coh_pid, token_names.coh_token_name),
                // burn the poh token
                minting.is_occurring(mint, poh_pid, token_names.poh_token_name),
                // owner gets success test utxo back
                payout.exact(owner_address, owner_value, this_tx.outputs),
                // test needs to be over
                moment.is_after(
                  this_datum.test_data.validity_range,
                  this_tx.validity_range,
                ),
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
                  |> value.merge(value.negate(this_tx.fee))
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
                // single script output
                count.outputs_by_addr(this_tx.outputs, this_addr, 0),
                // do not mint the coh token
                !minting.is_occurring(mint, coh_pid, token_names.coh_token_name),
                // burn the poh token
                minting.is_occurring(mint, poh_pid, token_names.poh_token_name),
                // owner gets success test utxo back
                payout.exact(owner_address, owner_value, this_tx.outputs),
                // test needs to be over
                moment.is_after(
                  this_datum.test_data.validity_range,
                  this_tx.validity_range,
                ),
              }
            }
          }
          // The test owner may quit the test during specific times. If the 
          // test has not started or if they failed to submit the answer
          // in time.
          Quit -> {
            // the test owner address
            let owner_address: Address =
              addresses.create_address(
                this_datum.owner.pkh,
                this_datum.owner.sc,
              )
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
                count.inputs_by_addr(this_tx.inputs, this_addr, 1),
                // single script output
                count.outputs_by_addr(this_tx.outputs, this_addr, 0),
                // send this value back to the owner address
                payout.exact(owner_address, this_value, this_tx.outputs),
                // owner must sign it
                signing.verify_sig(
                  this_tx.extra_signatories,
                  this_datum.owner.pkh,
                ),
              }
            } else {
              //
              // The poh token is on the utxo so the test did start.
              // Is the test currently live?
              //
              if
              moment.is_after(
                this_datum.test_data.validity_range,
                this_tx.validity_range,
              ){
              
                //
                // The test period is over.
                // Did the user end their test?
                if this_datum.test_data.cur_stage == 1 {
                  //
                  // The user must wait for their test to be verified by a threshold actor.
                  //
                  fail @"No Leaving During Verification"
                } else {
                  //
                  // The user failed to submit an answer during the test period.
                  // Send the deposit to the vault and burn the poh token.
                  let deposit: Token = this_datum.deposit
                  // remove the poh token and take the deposit
                  let owner_value: Value =
                    value.add(
                      this_value,
                      poh_pid,
                      token_names.poh_token_name,
                      -1,
                    )
                      |> value.add(deposit.pid, deposit.tkn, -deposit.amt)
                  //
                  // The user loses their deposit due to never finishing the test.
                  // The poh token will be burned and the owner must sign it.
                  // 
                  //
                  and {
                    // single script output
                    count.outputs_by_addr(this_tx.outputs, this_addr, 0)?,
                    // burn the poh token
                    minting.is_occurring(
                      mint,
                      poh_pid,
                      token_names.poh_token_name,
                    ),
                    // the owner gets the left over value
                    payout.exact(owner_address, owner_value, this_tx.outputs),
                    // owner must sign it
                    signing.verify_sig(
                      this_tx.extra_signatories,
                      this_datum.owner.pkh,
                    ),
                  }
                }
              } else {
                //
                // The test is currently live, The user must take the test.
                //
                fail @"No Leaving During A Test"
              }
            }
          }
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
