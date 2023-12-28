//// This handles tokens for the drep

use aiken/dict
use aiken/list
use aiken/transaction.{Input, Mint, ScriptContext, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/keys
use aipoph/prove
use aipoph/reference
use aipoph/token_names
use aipoph/types/dao.{Contracts, DAODatum}
use aipoph/types/drep.{BurnRepTokens, DRepMintRedeemer, MintRepTokens}
use assist/find
use assist/minting
use assist/payout
use assist/values
use assist/types.{ValidatorHash}

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
        let all_validator_hashes: List<ValidatorHash> =
          dict.values(contract_data) |> list.delete(lock_hash)
        // is anything being spent that shouldn't be spent
        let is_fake_d_rep: Bool =
          prove.not_being_spent_from(all_validator_hashes, this_tx.inputs)
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
          MintRepTokens { mint_amt } -> {
            let cont_lock_value: Value =
              value.add(lock_value, dao_pid, dao_tkn, mint_amt)
            and {
              // must mint something
              mint_amt > 0,
              // make sure the bank lock is being spent from
              payout.exact(lock_addr, cont_lock_value, this_tx.outputs),
              // must mint 1 reference token
              minting.exact(
                mint,
                own_currency_symbol,
                token_names.drep_token_name,
                mint_amt,
              ),
              // data reference must be holding correct token
              dao_value_check,
              // must not be spending from things you dont represent
              is_fake_d_rep,
            }
          }
          BurnRepTokens { burn_amt } -> {
            let cont_lock_value: Value =
              value.add(lock_value, dao_pid, dao_tkn, burn_amt)
            and {
              // must burn something
              burn_amt < 0,
              // make sure the bank lock is being spent from
              payout.exact(lock_addr, cont_lock_value, this_tx.outputs),
              // must mint 1 reference token
              minting.exact(
                mint,
                own_currency_symbol,
                token_names.drep_token_name,
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
