//// this controls the minter for the proof of humanity test. It is used to uniquely
//// identify a specific test.

use aiken/transaction.{Input, Mint, ScriptContext, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/keys
use aipoph/reference
use aipoph/token_names
use assist/types.{ValidatorHash}
use aipoph/types/dao.{Contracts, DAODatum}
use aipoph/types/poh.{
  BurnPoHToken, MintPohToken, PoHDatum, PoHLockRedeemer, PoHMintRedeemer, Quit,
  StartTest,
}
use assist/data
use assist/find
use assist/minting
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
  fn params(redeemer: PoHMintRedeemer, context: ScriptContext) -> Bool {
    when context.purpose is {
      // Mint 1 to 1 tokens
      Mint(own_currency_symbol) -> {
        // the transaction being validated
        let this_tx: Transaction = context.transaction
        // get reference utxo
        let (dao_datum, dao_input): (DAODatum, Input) =
          reference.get_data(this_tx.reference_inputs, dao_hash_data)
        // check if the ref input has the correct starter token
        let dao_value_check: Bool =
          values.prove_exact_nft(
            pointer_pid,
            pointer_tkn,
            dao_input.output.value,
          )
        // search the contracts for the drep lock
        expect contract_data: Contracts =
          dao.find_data(dao_datum, keys.contracts)
        let lock_hash: ValidatorHash =
          dao.find_contract(contract_data, keys.drep_lock_contract)
        // we need to make sure nothing else officially is getting spent
        // build the lock address
        let lock_addr: Address = credential.from_script(lock_hash)
        // find the input being spent from it
        let lock_input: Input = find.input_by_addr(this_tx.inputs, lock_addr)
        let lock_value: Value = lock_input.output.value
        // what is being minted or burned in this transaction
        let mint: List<(PolicyId, AssetName, Int)> =
          this_tx.mint
            |> value.from_minted_value()
            |> value.flatten()
        when redeemer is {
          MintPohToken -> {
            // this is endpoint specific so check for the correct redeemer
            expect that_redeemer: PoHLockRedeemer =
              find.redeemer_by_ref(
                this_tx.redeemers,
                lock_input.output_reference,
              )
            let correct_redeemer: Bool =
              when that_redeemer is {
                // the token can only be minted when the test starts
                StartTest -> True
                // anything else fail
                _ -> fail @"Not Starting Test"
              }
            // adjust the value
            let cont_lock_value: Value =
              value.add(
                lock_value,
                own_currency_symbol,
                token_names.poh_token_name,
                1,
              )
            // check if threshold meets requirements
            // the threshold to change data
            let start_poh_test_threshold: Int =
              reference.get_poh_test_threshold(dao_datum)
            // how much they have inside the tx
            let enough_for_threshold: Bool =
              tx.total_token_amount(
                this_tx.inputs,
                dao_pid,
                dao_tkn,
                start_poh_test_threshold,
              )
            and {
              // make sure the bank lock is being spent from
              payout.exact(lock_addr, cont_lock_value, this_tx.outputs),
              // must mint 1 reference token
              minting.exact(mint, own_currency_symbol, token_names.poh_token_name, 1),
              // data reference must be holding correct token
              dao_value_check,
              // only can run this if using start test
              correct_redeemer,
              // do the this_tx meet the threshold
              enough_for_threshold,
            }
          }
          BurnPoHToken -> {
            // this is endpoint specific so check for the correct redeemer
            expect that_redeemer: PoHLockRedeemer =
              find.redeemer_by_ref(
                this_tx.redeemers,
                lock_input.output_reference,
              )
            let correct_redeemer: Bool =
              when that_redeemer is {
                // the user must be quitting the test
                Quit -> True
                // anything else fail
                _ -> fail @"Not Quitting Test"
              }
            expect datum: PoHDatum = data.input_datum(lock_input)
            // need to make sure the user passed the test or not
            let lose_deposit_check: Bool =
              if datum.test_data.cur_stage == 1 {
                // no deposit is lost here
                True
              } else {
                // the user failed the test and lost the deposit
                let vault_hash: ValidatorHash =
                  dao.find_contract(contract_data, keys.vault_contract)
                // build the vault address
                let vault_addr: Address = credential.from_script(vault_hash)
                // find the input being spent from it
                let vault_input: Input =
                  find.input_by_addr(this_tx.inputs, vault_addr)
                let vault_value: Value = vault_input.output.value
                let cont_vault_value: Value =
                  value.add(
                    vault_value,
                    datum.deposit.pid,
                    datum.deposit.tkn,
                    datum.deposit.amt,
                  )
                payout.at_least(vault_addr, cont_vault_value, this_tx.outputs)
              }
            and {
              // lose deposit to vault if fail
              lose_deposit_check,
              // must mint 1 reference token
              minting.exact(
                mint,
                own_currency_symbol,
                token_names.drep_token_name,
                -1,
              ),
              // data reference must be holding correct token
              dao_value_check,
              // must be quiting when applicable
              correct_redeemer,
            }
          }
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
