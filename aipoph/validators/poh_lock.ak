//// this controls the locking of the poh pointer token and contains all of the
//// poh test logic. a successful test will issue a certificate of humanity

use aiken/interval
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
use assist/types.{Token}
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
          // this starts the poh test by issuesing a poh token to the utxo
          StartTest -> {
            // that datum cont must be correct structure
            expect that_datum: PoHDatum =
              find.output_datum_by_addr(this_tx.outputs, this_addr)
            //
            // If the utxo doesnt have a poh token and is in the correct state
            // then mint a poh token to a UTxO and begin the test.
            // This is ran with MintPohToken.
            //
            and {
              // must not have poh token already
              !values.prove_exact_nft(
                poh_pid,
                token_names.poh_token_name,
                this_value,
              ),
              // the poh token is being minted
              minting.is_occurring(mint, poh_pid, token_names.poh_token_name),
              // single script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 1),
              // this datum must be in a specific state to start
              poh.start_test_datum_validation(this_datum, that_datum),
              // owner must sign it to prevent miss starts
              signing.verify_sig(
                this_tx.extra_signatories,
                this_datum.owner.pkh,
              ),
            }
          }
          // this will end a test with the user submitting a proof
          EndTest { proof } -> {
            // that datum cont must be correct structure
            expect that_datum: PoHDatum =
              find.output_datum_by_addr(this_tx.outputs, this_addr)
            //
            // The user submits what they think the proof is.
            //
            and {
              // the test must have been started via minting the poh token
              values.prove_exact_nft(
                poh_pid,
                token_names.poh_token_name,
                this_value,
              ),
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
              poh.end_test_datum_validation(this_datum, that_datum, proof),
              // test period must still be valid
              poh.valid_test_entry(
                this_datum.test_data.validity_range,
                this_tx.validity_range,
              ),
            }
          }
          // some user with enough threshold will verify the test
          VerifyTest -> {
            // the drep owner address
            let owner_address: Address =
              addresses.create_address(
                this_datum.owner.pkh,
                this_datum.owner.sc,
              )
            // check if they have the poh token, pass as a human, and ended the test
            if and {
              // must have poh token
              values.prove_exact_nft(
                poh_pid,
                token_names.poh_token_name,
                this_value,
              ),
              // prove you are a human
              prove.you_are_a_human(
                this_datum.test_data.question,
                this_datum.test_data.answer,
              ),
              // test must have ended
              this_datum.test_data.cur_stage == 1,
            } {
              let owner_value: Value =
                value.add(this_value, poh_pid, token_names.poh_token_name, -1)
                  |> value.merge(value.negate(this_tx.fee))
              //
              // You are a human so burn the poh token and mint the coh token.
              // The deposit is not taken here and the test utxo goes back to
              // the owner automatically.
              //
              and {
                // single script input
                count.inputs_by_addr(this_tx.inputs, this_addr, 1),
                // single script output
                count.outputs_by_addr(this_tx.outputs, this_addr, 0),
                // mint the coh token
                minting.is_occurring(mint, coh_pid, token_names.coh_token_name),
                // burn the poh token
                minting.is_occurring(mint, poh_pid, token_names.poh_token_name),
                // owner gets success test utxo back
                payout.exact(owner_address, owner_value, this_tx.outputs),
              }
            } else {
              // you have failed the test. take the deposit, burn the poh token
              // send deposit to the vault, this happens automatically
              let deposit: Token = this_datum.deposit
              let owner_value: Value =
                value.add(this_value, poh_pid, token_names.poh_token_name, -1)
                  |> value.add(deposit.pid, deposit.tkn, -deposit.amt)
                  |> value.merge(value.negate(this_tx.fee))
              //
              // You are not a human so burn the poh token and no not mint a coh token.
              // The deposit is taken here and sent to the vault. The test utxo goes back
              // to the owner automatically.
              //
              and {
                // single script input
                count.inputs_by_addr(this_tx.inputs, this_addr, 1),
                // single script output
                count.outputs_by_addr(this_tx.outputs, this_addr, 0),
                // do not mint the coh token
                !minting.is_occurring(mint, coh_pid, token_names.coh_token_name),
                // burn the poh token
                minting.is_occurring(mint, poh_pid, token_names.poh_token_name),
                // owner gets success test utxo back
                payout.exact(owner_address, owner_value, this_tx.outputs),
              }
            }
          }
          // this quits if the test hasnt started or the user ends teh test successfully
          Quit -> {
            // the drep owner address
            let owner_address: Address =
              addresses.create_address(
                this_datum.owner.pkh,
                this_datum.owner.sc,
              )
            // make sure there isnt poh token here else burn it
            let utxo_is_missing_poh_token: Bool =
              value.quantity_of(this_value, poh_pid, token_names.poh_token_name) == 0
            // Is the UTxO holding the poh test token?
            if utxo_is_missing_poh_token {
              // no poh token found so the test didnt start
              // send everything back to the owner with a sig
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
              // the poh token is on the utxo so the test did start
              // Is the test currently live?
              if
              interval.is_entirely_after(
                this_tx.validity_range,
                this_datum.test_data.validity_range.end,
              ){
              
                // the test period has passed
                // Did the user end their test?
                if this_datum.test_data.cur_stage == 1 {
                  // The user must wait for their test to be verified
                  fail @"No Leaving During Verification"
                } else {
                  // user failed to submit the test in time
                  // send deposit to the vault and burn the poh token
                  let deposit: Token = this_datum.deposit
                  let owner_value: Value =
                    value.add(
                      this_value,
                      poh_pid,
                      token_names.poh_token_name,
                      -1,
                    )
                      |> value.add(deposit.pid, deposit.tkn, -deposit.amt)
                  and {
                    // single script input
                    count.inputs_by_addr(this_tx.inputs, this_addr, 1),
                    // single script output
                    count.outputs_by_addr(this_tx.outputs, this_addr, 0),
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
                // the user must take the test
                fail @"No Leaving During A Test"
              }
            }
          }
        }
      }

      // can only spend
      _ -> False
    }
  }
}
