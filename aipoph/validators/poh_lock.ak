//// this controls the locking of the poh pointer token and contains all of the
//// poh test logic. a successful test will issue a certificate of humanity

use aiken/interval
use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/prove
use aipoph/token_names
use aipoph/types/poh.{EndTest, PoHDatum, PoHLockRedeemer, Quit, StartTest}
use assist/addresses
use assist/count
use assist/find
use assist/minting
use assist/payout
use assist/signing
use assist/types.{Token}
use assist/values

validator(poh_pid: PolicyId, coh_pid: PolicyId) {
  fn params(
    this_datum: PoHDatum,
    redeemer: PoHLockRedeemer,
    context: ScriptContext,
  ) -> Bool {
    when context.purpose is {
      Spend(output_reference) -> {
        // this_tx being validated
        let this_tx: Transaction = context.transaction
        let this_input: Input =
          find.input_by_ref(this_tx.inputs, output_reference)
        let this_addr: Address = this_input.output.address
        let this_value: Value = this_input.output.value
        // something will be minted burned 
        let mint: List<(PolicyId, AssetName, Int)> =
          this_tx.mint
            |> value.from_minted_value()
            |> value.flatten()
        when redeemer is {
          // this starts the poh test
          StartTest -> {
            // the datum cont must be correct structure
            expect that_datum: PoHDatum =
              find.output_datum_by_addr(this_tx.outputs, this_addr)
            and {
              // must not have poh token
              !values.prove_exact_nft(
                poh_pid,
                token_names.poh_token_name,
                this_value,
              ),
              // something is being minted
              minting.is_occurring(mint, poh_pid, token_names.poh_token_name),
              // single script input
              count.inputs_by_addr(this_tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 1),
              // datums must change a specific way
              poh.start_test_datum_validation(this_datum, that_datum),
              // owner must sign it
              signing.verify_sig(
                this_tx.extra_signatories,
                this_datum.owner.pkh,
              ),
            }
          }
          // this will end the test and mint a stage 0 coh token
          EndTest { proof } -> {
            // the datum cont must be correct structure
            expect that_datum: PoHDatum =
              find.output_datum_by_addr(this_tx.outputs, this_addr)
            and {
              // must have poh token
              values.prove_exact_nft(
                poh_pid,
                token_names.poh_token_name,
                this_value,
              ),
              // something is being minted  and burned
              minting.is_occurring(mint, coh_pid, token_names.coh_token_name),
              // single script input
              count.inputs_by_addr(this_tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 1),
              // owner must sign it
              signing.verify_sig(
                this_tx.extra_signatories,
                this_datum.owner.pkh,
              ),
              // must go back
              payout.exact(this_addr, this_value, this_tx.outputs),
              // datums must change a specific way
              poh.end_test_datum_validation(this_datum, that_datum, proof),
              // the coh datum needs to be based from the poh datum
              // test must still be valid
              poh.valid_test_entry(
                this_datum.test_data.validity_range,
                this_tx.validity_range,
              ),
              // prove you are a human
              prove.you_are_a_human(this_datum.test_data.question, proof.answer),
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
            let did_the_test_start: Bool =
              // Is the UTxO holding the poh test token?
              if utxo_is_missing_poh_token {
                // no token, test did not start, send everything back with a signature
                and {
                  payout.exact(owner_address, this_value, this_tx.outputs),
                  signing.verify_sig(
                    this_tx.extra_signatories,
                    this_datum.owner.pkh,
                  ),
                }
              } else {
                // the poh token is on the utxo
                // Is the test currently live?
                if
                interval.is_entirely_after(
                  this_tx.validity_range,
                  this_datum.test_data.validity_range.end,
                ){
                
                  // the test has ended
                  // Did the user pass the test?
                  if this_datum.test_data.cur_stage == 1 {
                    // user passed
                    // burn the poh token and return deposit
                    let owner_value: Value =
                      value.add(
                        this_value,
                        poh_pid,
                        token_names.poh_token_name,
                        -1,
                      )
                    // anyone can do this, typically the user
                    and {
                      minting.is_occurring(
                        mint,
                        poh_pid,
                        token_names.poh_token_name,
                      ),
                      payout.exact(owner_address, owner_value, this_tx.outputs),
                    }
                  } else {
                    // user failed
                    // send deposit to the vault
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
                      // this needs to send the deposit to the vault contract
                      minting.is_occurring(
                        mint,
                        poh_pid,
                        token_names.poh_token_name,
                      ),
                      payout.exact(owner_address, owner_value, this_tx.outputs),
                    }
                  }
                } else {
                  // The test has begun.
                  // this can be removed if quiting after a test begins but before it ends
                  // behaves as if you failed the test then the deposit will be removed
                  // and the value is sent back to the owner
                  // this as a fail means no leaving during a test, 
                  // ie they paid for the test so they have to take it. 
                  // They can choose to not do it but they still gotta wait
                  fail @"No Leaving During A Test"
                }
              }
            and {
              // check if you have to burn
              did_the_test_start,
              // single script input
              count.inputs_by_addr(this_tx.inputs, this_addr, 1),
              // zero script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 0),
            }
          }
        }
      }

      // can only spend
      _ -> False
    }
  }
}
