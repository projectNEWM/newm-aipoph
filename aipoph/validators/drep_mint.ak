//// This handles tokens for the casino

use aiken/dict
use aiken/list
use aiken/transaction.{Input, Mint, ScriptContext, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/keys
use aipoph/types.{ValidatorHash}
use aipoph/types/dao.{Contracts, DAODatum}
use aipoph/types/drep.{BurnTokens, DRepMintRedeemer, MintTokens}
use assist/data
use assist/find
use assist/minting
use assist/payout
use assist/values

/// Given a set of validator hashes prove that none of them are being spent assuming
/// every address is not staked.
fn prove_not_being_spent_from(
  validator_hashes: List<ValidatorHash>,
  inputs: List<Input>,
) -> Bool {
  when validator_hashes is {
    [vh, ..vhs] -> {
      // check if validator hash exist as an address inside the set of inputs
      let outcome =
        list.any(
          inputs,
          // may be cheaper to do ValidatorHash equality then Address equality?
          fn(input) { input.output.address == credential.from_script(vh) },
        )
      // if true then not true else continue to the next validator hash
      if outcome {
        !outcome
      } else {
        prove_not_being_spent_from(vhs, inputs)
      }
    }
    // if nothing ever hit then nothing is being spent
    [] -> True
  }
}

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
  fn params(redeemer: DRepMintRedeemer, context: ScriptContext) -> Bool {
    when context.purpose is {
      // Mint 1 to 1 tokens
      Mint(own_currency_symbol) -> {
        // the transaction being validated
        let tx: Transaction = context.transaction
        expect dao_hash: ValidatorHash = dao_hash_data
        let dao_addr: Address = credential.from_script(dao_hash)
        let dao_input: Input = find.input_by_addr(tx.reference_inputs, dao_addr)
        // check if the ref input has the correct starter token
        let dao_value_check: Bool =
          values.prove_exact_nft(
            pointer_pid,
            pointer_tkn,
            dao_input.output.value,
          )
        // get the reference datum
        expect dao_datum: DAODatum = data.input_datum(dao_input)
        // search the contracts for the drep lock
        expect contract_data: Contracts =
          dao.find_data(dao_datum, keys.contracts)
        let lock_hash: ValidatorHash =
          dao.find_contract(contract_data, keys.drep_lock_contract)
        // we need to make sure nothing else officially is getting spent
        let all_validator_hashes: List<ValidatorHash> =
          dict.values(contract_data) |> list.delete(lock_hash)
        // is anything being spent that shouldn't be spent
        let is_fake_d_rep: Bool =
          prove_not_being_spent_from(all_validator_hashes, tx.inputs)
        // build the lock address
        let lock_addr: Address = credential.from_script(lock_hash)
        // find the input being spent from it
        let lock_input: Input = find.input_by_addr(tx.inputs, lock_addr)
        let lock_value: Value = lock_input.output.value
        // what is being minted or burned in this transaction
        let mint: List<(PolicyId, AssetName, Int)> =
          tx.mint
            |> value.from_minted_value()
            |> value.flatten()
        when redeemer is {
          MintTokens { mint_amt } -> {
            let cont_lock_value: Value =
              value.add(lock_value, dao_pid, dao_tkn, mint_amt)
            and {
              // must mint something
              mint_amt > 0,
              // make sure the bank lock is being spent from
              payout.exact(lock_addr, cont_lock_value, tx.outputs),
              // must mint 1 reference token
              minting.exact(
                mint,
                own_currency_symbol,
                types.drep_token_name,
                mint_amt,
              ),
              // data reference must be holding correct token
              dao_value_check,
              // must not be spending from things you dont represent
              is_fake_d_rep,
            }
          }
          BurnTokens { burn_amt } -> {
            let cont_lock_value: Value =
              value.add(lock_value, dao_pid, dao_tkn, burn_amt)
            and {
              // must burn something
              burn_amt < 0,
              // make sure the bank lock is being spent from
              payout.exact(lock_addr, cont_lock_value, tx.outputs),
              // must mint 1 reference token
              minting.exact(
                mint,
                own_currency_symbol,
                types.drep_token_name,
                burn_amt,
              ),
              // data reference must be holding correct token
              dao_value_check,
              // must not be spending from things you dont represent
              is_fake_d_rep,
            }
          }
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
