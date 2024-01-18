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
aiken build
# aiken build --keep-traces

# the locking token information
tx_id_hash=$(jq -r '.tx_id_hash' start_info.json)
tx_id_idx=$(jq -r '.tx_id_idx' start_info.json)

# one liner for correct cbor
# requires cbor2
tx_id_hash_cbor=$(python3 -c "import cbor2;hex_string='${tx_id_hash}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")
tx_id_idx_cbor=$(python3 -c "import cbor2;encoded=cbor2.dumps(${tx_id_idx});print(encoded.hex())")

echo -e "\033[1;33m\nBuilding Genesis Contract \033[0m"
aiken blueprint apply -o plutus.json -v genesis.params "${tx_id_hash_cbor}"
aiken blueprint apply -o plutus.json -v genesis.params "${tx_id_idx_cbor}"
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
dao_pid=$(jq -r '.dao_pid' start_info.json)
dao_tkn=$(jq -r '.dao_tkn' start_info.json)

# one liner for correct cbor
# requires cbor2
dao_pid_cbor=$(python3 -c "import cbor2;hex_string='${dao_pid}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")
dao_tkn_cbor=$(python3 -c "import cbor2;hex_string='${dao_tkn}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

echo -e "\033[1;33m\nBuilding DAO Contract \033[0m"
aiken blueprint apply -o plutus.json -v dao.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v dao.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v dao.params "${dao_pid_cbor}"
aiken blueprint apply -o plutus.json -v dao.params "${dao_tkn_cbor}"
aiken blueprint convert -v dao.params > contracts/dao_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/dao_contract.plutus > hashes/dao.hash
echo -e "\033[1;33m DAO Contract Hash: $(cat hashes/dao.hash) \033[0m"

echo -e "\033[1;33m\nBuilding Oracle Contract \033[0m"

dao_hash=$(cat hashes/dao.hash)
dao_hash_cbor=$(python3 -c "import cbor2;hex_string='${dao_hash}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

aiken blueprint apply -o plutus.json -v oracle.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v oracle.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v oracle.params "${dao_pid_cbor}"
aiken blueprint apply -o plutus.json -v oracle.params "${dao_tkn_cbor}"
aiken blueprint apply -o plutus.json -v oracle.params "${dao_hash_cbor}"
aiken blueprint convert -v oracle.params > contracts/oracle_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/oracle_contract.plutus > hashes/oracle.hash
echo -e "\033[1;33m Oracle Contract Hash: $(cat hashes/oracle.hash) \033[0m"

echo -e "\033[1;33m\nBuilding dRep Contract \033[0m"

aiken blueprint apply -o plutus.json -v drep_mint.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v drep_mint.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v drep_mint.params "${dao_pid_cbor}"
aiken blueprint apply -o plutus.json -v drep_mint.params "${dao_tkn_cbor}"
aiken blueprint apply -o plutus.json -v drep_mint.params "${dao_hash_cbor}"
aiken blueprint convert -v drep_mint.params > contracts/drep_mint_contract.plutus


# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/drep_mint_contract.plutus > hashes/drep_mint.hash
echo -e "\033[1;33m dRep Mint Contract Hash: $(cat hashes/drep_mint.hash) \033[0m"

# the pointer token
drep_pid=$(cat hashes/drep_mint.hash)
drep_pid_cbor=$(python3 -c "import cbor2;hex_string='${drep_pid}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

aiken blueprint apply -o plutus.json -v drep_lock.params "${drep_pid_cbor}"
aiken blueprint convert -v drep_lock.params > contracts/drep_lock_contract.plutus

cardano-cli transaction policyid --script-file contracts/drep_lock_contract.plutus > hashes/drep_lock.hash
echo -e "\033[1;33m dRep Lock Contract Hash: $(cat hashes/drep_lock.hash) \033[0m"

echo -e "\033[1;33m\nBuilding Vault Contract \033[0m"

aiken blueprint apply -o plutus.json -v vault.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v vault.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v vault.params "${dao_pid_cbor}"
aiken blueprint apply -o plutus.json -v vault.params "${dao_tkn_cbor}"
aiken blueprint apply -o plutus.json -v vault.params "${dao_hash_cbor}"
aiken blueprint convert -v vault.params > contracts/vault_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/vault_contract.plutus > hashes/vault.hash
echo -e "\033[1;33m Vault Contract Hash: $(cat hashes/vault.hash) \033[0m"

echo -e "\033[1;33m\nBuilding Proof Of Humanity Mint Contract \033[0m"

aiken blueprint apply -o plutus.json -v poh_mint.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v poh_mint.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v poh_mint.params "${dao_pid_cbor}"
aiken blueprint apply -o plutus.json -v poh_mint.params "${dao_tkn_cbor}"
aiken blueprint apply -o plutus.json -v poh_mint.params "${dao_hash_cbor}"
aiken blueprint convert -v poh_mint.params > contracts/poh_mint_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/poh_mint_contract.plutus > hashes/poh_mint.hash
echo -e "\033[1;33m Proof of Humanity Mint Contract Hash: $(cat hashes/poh_mint.hash) \033[0m"

echo -e "\033[1;33m\nBuilding Certificate Of Humanity Mint Contract \033[0m"

aiken blueprint apply -o plutus.json -v coh_mint.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v coh_mint.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v coh_mint.params "${dao_pid_cbor}"
aiken blueprint apply -o plutus.json -v coh_mint.params "${dao_tkn_cbor}"
aiken blueprint apply -o plutus.json -v coh_mint.params "${dao_hash_cbor}"
aiken blueprint convert -v coh_mint.params > contracts/coh_mint_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/coh_mint_contract.plutus > hashes/coh_mint.hash
echo -e "\033[1;33m Certificate of Humanity Mint Contract Hash: $(cat hashes/coh_mint.hash) \033[0m"

# the pointer token
poh_pid=$(cat hashes/poh_mint.hash)
poh_pid_cbor=$(python3 -c "import cbor2;hex_string='${poh_pid}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

coh_pid=$(cat hashes/coh_mint.hash)
coh_pid_cbor=$(python3 -c "import cbor2;hex_string='${coh_pid}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

echo -e "\033[1;33m\nBuilding Proof Of Humanity Lock Contract \033[0m"

aiken blueprint apply -o plutus.json -v poh_lock.params "${poh_pid_cbor}"
aiken blueprint apply -o plutus.json -v poh_lock.params "${coh_pid_cbor}"
aiken blueprint convert -v poh_lock.params > contracts/poh_lock_contract.plutus

cardano-cli transaction policyid --script-file contracts/poh_lock_contract.plutus > hashes/poh_lock.hash
echo -e "\033[1;33m Proof of Humanity Lock Contract Hash: $(cat hashes/poh_lock.hash) \033[0m"

echo -e "\033[1;33m\nBuilding Certificate Of Humanity Lock Contract \033[0m"

aiken blueprint apply -o plutus.json -v coh_lock.params "${coh_pid_cbor}"
aiken blueprint convert -v coh_lock.params > contracts/coh_lock_contract.plutus

cardano-cli transaction policyid --script-file contracts/coh_lock_contract.plutus > hashes/coh_lock.hash
echo -e "\033[1;33m Certificate of Humanity Lock Contract Hash: $(cat hashes/coh_lock.hash) \033[0m"

# end of build
echo -e "\033[1;32m\nBuilding Complete! \033[0m"