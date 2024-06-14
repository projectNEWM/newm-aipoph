#!/bin/bash
set -e

# create directories if dont exist
mkdir -p contracts
mkdir -p hashes

# remove old files
rm contracts/* || true
rm hashes/* || true
rm -fr build/ || true

# build out the entire script
echo -e "\033[1;34m\nBuilding Contracts \033[0m"

# remove all traces
# aiken build --trace-level silent --filter-traces user-defined

# keep the traces for testing if required
aiken build --trace-level verbose --filter-traces all

# the locking token information
tx_id_hash=$(jq -r '.tx_id_hash' config.json)
tx_id_idx=$(jq -r '.tx_id_idx' config.json)

# one liner for correct cbor
# requires cbor2
tx_id_hash_cbor=$(python3 -c "import cbor2;hex_string='${tx_id_hash}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")
tx_id_idx_cbor=$(python3 -c "import cbor2;encoded=cbor2.dumps(${tx_id_idx});print(encoded.hex())")

# maximum quantity of the action token
action_max=$(jq -r '.action_max' config.json)
action_max_cbor=$(python3 -c "import cbor2;encoded=cbor2.dumps(${action_max});print(encoded.hex())")

echo -e "\033[1;33m\nBuilding Genesis Contract \033[0m"
aiken blueprint apply -o plutus.json -v genesis.params "${tx_id_hash_cbor}"
aiken blueprint apply -o plutus.json -v genesis.params "${tx_id_idx_cbor}"
aiken blueprint apply -o plutus.json -v genesis.params "${action_max_cbor}"
aiken blueprint convert -v genesis.params > contracts/genesis_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/genesis_contract.plutus > hashes/genesis.hash
echo -e "\033[1;33m Genesis Contract Hash: $(cat hashes/genesis.hash) \033[0m"

# the pointer token
pointer_prefix="5f6169706f70685f"
pointer_pid=$(cat hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('scripts/py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

# one liner for correct cbor
# requires cbor2
pointer_pid_cbor=$(python3 -c "import cbor2;hex_string='${pointer_pid}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")
pointer_tkn_cbor=$(python3 -c "import cbor2;hex_string='${pointer_tkn}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

# the reference token
action_pid=$(jq -r '.action_pid' config.json)
action_tkn=$(jq -r '.action_tkn' config.json)

# one liner for correct cbor
# requires cbor2
action_pid_cbor=$(python3 -c "import cbor2;hex_string='${action_pid}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")
action_tkn_cbor=$(python3 -c "import cbor2;hex_string='${action_tkn}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

echo -e "\033[1;33m\nBuilding REFERENCE Contract \033[0m"
aiken blueprint apply -o plutus.json -v reference.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v reference.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v reference.params "${action_pid_cbor}"
aiken blueprint apply -o plutus.json -v reference.params "${action_tkn_cbor}"
aiken blueprint apply -o plutus.json -v reference.params "${action_max_cbor}"
aiken blueprint convert -v reference.params > contracts/reference_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/reference_contract.plutus > hashes/reference.hash
echo -e "\033[1;33m REFERENCE Contract Hash: $(cat hashes/reference.hash) \033[0m"
jq --arg variable "$(cat hashes/reference.hash)" '.contracts.reference_contract=$variable' reference_data.json | sponge reference_data.json

echo -e "\033[1;33m\nBuilding Oracle Contract \033[0m"

reference_hash=$(cat hashes/reference.hash)
reference_hash_cbor=$(python3 -c "import cbor2;hex_string='${reference_hash}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

aiken blueprint apply -o plutus.json -v oracle.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v oracle.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v oracle.params "${action_pid_cbor}"
aiken blueprint apply -o plutus.json -v oracle.params "${action_tkn_cbor}"
aiken blueprint apply -o plutus.json -v oracle.params "${reference_hash_cbor}"
aiken blueprint convert -v oracle.params > contracts/oracle_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/oracle_contract.plutus > hashes/oracle.hash
echo -e "\033[1;33m Oracle Contract Hash: $(cat hashes/oracle.hash) \033[0m"
jq --arg variable "$(cat hashes/oracle.hash)" '.contracts.oracle_contract=$variable' reference_data.json | sponge reference_data.json

echo -e "\033[1;33m\nBuilding Vault Contract \033[0m"

aiken blueprint apply -o plutus.json -v vault.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v vault.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v vault.params "${action_pid_cbor}"
aiken blueprint apply -o plutus.json -v vault.params "${action_tkn_cbor}"
aiken blueprint apply -o plutus.json -v vault.params "${reference_hash_cbor}"
aiken blueprint convert -v vault.params > contracts/vault_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/vault_contract.plutus > hashes/vault.hash
echo -e "\033[1;33m Vault Contract Hash: $(cat hashes/vault.hash) \033[0m"
jq --arg variable "$(cat hashes/vault.hash)" '.contracts.vault_contract=$variable' reference_data.json | sponge reference_data.json

echo -e "\033[1;33m\nBuilding Proof Of Humanity Mint Contract \033[0m"

aiken blueprint apply -o plutus.json -v poh_mint.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v poh_mint.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v poh_mint.params "${action_pid_cbor}"
aiken blueprint apply -o plutus.json -v poh_mint.params "${action_tkn_cbor}"
aiken blueprint apply -o plutus.json -v poh_mint.params "${reference_hash_cbor}"
aiken blueprint convert -v poh_mint.params > contracts/poh_mint_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/poh_mint_contract.plutus > hashes/poh_mint.hash
echo -e "\033[1;33m Proof of Humanity Mint Contract Hash: $(cat hashes/poh_mint.hash) \033[0m"
jq --arg variable "$(cat hashes/poh_mint.hash)" '.contracts.poh_mint_contract=$variable' reference_data.json | sponge reference_data.json

echo -e "\033[1;33m\nBuilding Certificate Of Humanity Mint Contract \033[0m"

aiken blueprint apply -o plutus.json -v coh_mint.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v coh_mint.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v coh_mint.params "${action_pid_cbor}"
aiken blueprint apply -o plutus.json -v coh_mint.params "${action_tkn_cbor}"
aiken blueprint apply -o plutus.json -v coh_mint.params "${reference_hash_cbor}"
aiken blueprint convert -v coh_mint.params > contracts/coh_mint_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/coh_mint_contract.plutus > hashes/coh_mint.hash
echo -e "\033[1;33m Certificate of Humanity Mint Contract Hash: $(cat hashes/coh_mint.hash) \033[0m"
jq --arg variable "$(cat hashes/coh_mint.hash)" '.contracts.coh_mint_contract=$variable' reference_data.json | sponge reference_data.json

# the pointer token
poh_pid=$(cat hashes/poh_mint.hash)
poh_pid_cbor=$(python3 -c "import cbor2;hex_string='${poh_pid}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

coh_pid=$(cat hashes/coh_mint.hash)
coh_pid_cbor=$(python3 -c "import cbor2;hex_string='${coh_pid}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

echo -e "\033[1;33m\nBuilding Proof Of Humanity Lock Contract \033[0m"

aiken blueprint apply -o plutus.json -v poh_lock.params "${poh_pid_cbor}"
aiken blueprint apply -o plutus.json -v poh_lock.params "${coh_pid_cbor}"
aiken blueprint apply -o plutus.json -v poh_lock.params "${reference_hash_cbor}"
aiken blueprint convert -v poh_lock.params > contracts/poh_lock_contract.plutus

cardano-cli transaction policyid --script-file contracts/poh_lock_contract.plutus > hashes/poh_lock.hash
echo -e "\033[1;33m Proof of Humanity Lock Contract Hash: $(cat hashes/poh_lock.hash) \033[0m"
jq --arg variable "$(cat hashes/poh_lock.hash)" '.contracts.poh_lock_contract=$variable' reference_data.json | sponge reference_data.json

echo -e "\033[1;33m\nBuilding Certificate Of Humanity Lock Contract \033[0m"

aiken blueprint apply -o plutus.json -v coh_lock.params "${coh_pid_cbor}"
aiken blueprint apply -o plutus.json -v coh_lock.params "${reference_hash_cbor}"
aiken blueprint convert -v coh_lock.params > contracts/coh_lock_contract.plutus

cardano-cli transaction policyid --script-file contracts/coh_lock_contract.plutus > hashes/coh_lock.hash
echo -e "\033[1;33m Certificate of Humanity Lock Contract Hash: $(cat hashes/coh_lock.hash) \033[0m"
jq --arg variable "$(cat hashes/coh_lock.hash)" '.contracts.coh_lock_contract=$variable' reference_data.json | sponge reference_data.json

# end of build
echo -e "\033[1;32m\nBuilding Complete! \033[0m"