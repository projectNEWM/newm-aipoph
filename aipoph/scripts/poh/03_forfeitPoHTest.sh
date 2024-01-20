#!/bin/bash
set -e

# SET UP VARS HERE
source ../.env

# get params
${cli} query protocol-parameters ${network} --out-file ../tmp/protocol.json

# vault script
poh_lock_script_path="../../contracts/poh_lock_contract.plutus"
poh_lock_script_address=$(${cli} address build --payment-script-file ${poh_lock_script_path} ${network})

# dao script
dao_script_path="../../contracts/dao_contract.plutus"
dao_script_address=$(${cli} address build --payment-script-file ${dao_script_path} ${network})

# vault script
vault_script_path="../../contracts/vault_contract.plutus"
vault_script_address=$(${cli} address build --payment-script-file ${vault_script_path} ${network})

# collat
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# user
user_address=$(cat ../wallets/user-wallet/payment.addr)
user_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/user-wallet/payment.vkey)

poh_policy_id=$(cardano-cli transaction policyid --script-file ../../contracts/poh_mint_contract.plutus)

tx_id_hash=$(jq -r '.tx_id_hash' ../../start_info.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../../start_info.json)
pointer_prefix="5f6169706f70685f"
pointer_pid=$(cat ../../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

# asset to trade
# the locking token information

poh_token="-1 ${poh_policy_id}.426567696e205468652050726f6f66204f662048756d616e6974792054657374"

# incentive, deposit, and poh token
worst_case_tokens="9223372036854775807 632e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162b.632e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162b00000000
+ 9223372036854775807 532e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c.532e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c00000000
+ 9223372036854775807 432e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162d.432e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c00000000"
min_utxo=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ../data/poh/worst-case-poh-datum.json \
    --tx-out="${poh_lock_script_address} + 5000000 + ${worst_case_tokens}" | tr -dc '0-9')

# 3 ada for fees and 2 ada for the min utxo for the coh
user_address_out="${user_address} + ${required_lovelace}"
echo "User OUTPUT: "${user_address_out}
#
# exit
#
# get user utxo
echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${user_address} \
    --out-file ../tmp/user_utxo.json

TXNS=$(jq length ../tmp/user_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${user_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/user_utxo.json)
user_tx_in=${TXIN::-8}

# get script utxo
echo -e "\033[0;36m Gathering PoH UTxO Information  \033[0m"
${cli} query utxo \
    --address ${poh_lock_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${poh_lock_script_address} \033[0m \n";
.   exit;
fi
poh_lock_tx_in=$(jq -r 'keys[0]' ../tmp/script_utxo.json)

poh_lock_lovelace_value=$(jq -r '.[].value.lovelace' ../tmp/script_utxo.json)
user_address_out="${user_address} + $((${poh_lock_lovelace_value} - 1000000))"
echo "User OUTPUT: "${user_address_out}


# get script utxo
echo -e "\033[0;36m Gathering DAO UTxO Information  \033[0m"
${cli} query utxo \
    --address ${dao_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${dao_script_address} \033[0m \n";
.   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" --arg policy_id "$pointer_pid" --arg token_name "$pointer_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
dao_tx_in=${TXIN::-8}

# get script utxo
echo -e "\033[0;36m Gathering Vault UTxO Information  \033[0m"
${cli} query utxo \
    --address ${vault_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${vault_script_address} \033[0m \n";
.   exit;
fi
vault_tx_in=$(jq -r 'keys[0]' ../tmp/script_utxo.json)

vault_lovelace_value=$(jq -r '.[].value.lovelace' ../tmp/script_utxo.json)
vault_script_out="${vault_script_address} + $((${vault_lovelace_value} + 1000000))"
echo "Vault OUTPUT: "${vault_script_out}

# collat info
echo -e "\033[0;36m Gathering Collateral UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${collat_address} \
    --out-file ../tmp/collat_utxo.json

TXNS=$(jq length ../tmp/collat_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${collat_address} \033[0m \n";
   exit;
fi
collat_tx_in=$(jq -r 'keys[0]' ../tmp/collat_utxo.json)


# script reference utxo
poh_lock_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-poh_lock_contract.plutus.signed )
poh_mint_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-poh_mint_contract.plutus.signed)
vault_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-vault_contract.plutus.signed)

slot=$(${cli} query tip ${network} | jq .slot)
current_slot=$(($slot - 1))
final_slot=$(($slot + 250))

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --invalid-before ${current_slot} \
    --invalid-hereafter ${final_slot} \
    --change-address ${user_address} \
    --read-only-tx-in-reference ${dao_tx_in} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${user_tx_in} \
    --tx-in ${poh_lock_tx_in} \
    --spending-tx-in-reference="${poh_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/poh/quit-redeemer.json \
    --tx-out="${user_address_out}" \
    --tx-in ${vault_tx_in} \
    --spending-tx-in-reference="${vault_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/vault/add-redeemer.json \
    --tx-out="${vault_script_out}" \
    --tx-out-inline-datum-file ../data/vault/vault-datum.json \
    --required-signer-hash ${user_pkh} \
    --required-signer-hash ${collat_pkh} \
    --mint="${poh_token}" \
    --mint-tx-in-reference="${poh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${poh_policy_id}" \
    --mint-reference-tx-in-redeemer-file ../data/poh/burn-redeemer.json \
    ${network})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
FEE=${FEE[1]}
echo -e "\033[1;32m Fee: \033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../wallets/user-wallet/payment.skey \
    --signing-key-file ../wallets/collat-wallet/payment.skey \
    --tx-body-file ../tmp/tx.draft \
    --out-file ../tmp/tx.signed \
    ${network}
#
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} transaction submit \
    ${network} \
    --tx-file ../tmp/tx.signed

tx=$(cardano-cli transaction txid --tx-file ../tmp/tx.signed)
echo "Tx Hash:" $tx
