use aiken/builtin
use assist/types/hashes.{PublicKeyHash}

/// A data type to prive a signature but also a method of bringing in signed 
/// data into a contract.
pub type SignedData {
  verification_key: PublicKeyHash,
  message: ByteArray,
  signature: ByteArray,
}

// this should do cip8 verification
pub fn ed25519(sd: SignedData) -> Bool {
  builtin.verify_ed25519_signature(
    sd.verification_key,
    sd.message,
    sd.signature,
  )
}

test good_ed25519_sig1() {
  let sd: SignedData =
    SignedData {
      verification_key: #"0b801082eed269a74c30857bbcf91888865987bb599d00fb9b2f60ba4b58438f",
      message: #"48656c6c6f2c20576f726c6421",
      signature: #"1e55545d89f4e149828f8e3810bffeba9cbb5644d9578cb29592c235ba8945870c305cbd4510811c5aa2b8e71d157a907817c708934b6b9dbab7e0406ccf9e0b",
    }
  ed25519(sd)
}

test good_ed25519_sig2() {
  let sd: SignedData =
    SignedData {
      verification_key: #"97e22bd3e1048c303122723e2235304bc4bb2e09c8fa67d48171e91bfadf52d4",
      message: #"398c36e82ee7a6d7a2bee6fde26fc0c9df373f687b9ec73b5968f9fae8ff92de",
      signature: #"bfe7c7455eef0dca49af3f4ba4d12670253d4724d868c59643da98c3b1271c023162b4275230411f42fc34b308c800f67beb606af354a47d6e659ea65f7c910b",
    }
  ed25519(sd)
}
