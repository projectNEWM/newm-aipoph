use aiken/builtin
use assist/types/hashes.{PublicKeyHash}

/// A data type to prove a signature but also a method of bringing in signed 
/// data into a contract.
pub type SignedData {
  verification_key: PublicKeyHash,
  message: ByteArray,
  signature: ByteArray,
}

/// This is the on-chain equalivant of CIP8 signature verification using the
/// ed25519 elliptic curve. This is used to verify the user signed into the
/// website and that the website hot key witnessed the user take the test.
///
/// ```aiken
/// signed.ed25519(this_signed_data)
/// ```
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

test good_ed25519_sig3() {
  let sd: SignedData =
    SignedData {
      verification_key: #"349be58c12c8724b9c705ecad06c435e0f9c7f0f9604833dba5fe95c37dbc9d3",
      message: #"7246a1b48b7f5a06a97f2007990b9ec42be4ffa60da01e2b7fe9d7224836cac7",
      signature: #"0e68158ffe4c92f5310c9032171d4150e08164429a8821b5601d687ddf6d30c0b92d2f664623fb2f9bc18ccbc14cdc46760dcc38ef07510240cca87e83b81204",
    }
  ed25519(sd)
}

test good_ed25519_sig4() {
  let sd: SignedData =
    SignedData {
      verification_key: #"97e22bd3e1048c303122723e2235304bc4bb2e09c8fa67d48171e91bfadf52d4",
      message: #"50e669c143fd86849b79782da019d309da582e1a909fecfbab39f3adf7639e0d",
      signature: #"ef77bc1e7180ee1a3a462121f8cb40ac14d249d78d5468e4be5e7a59a63222f63c10da9b8a32baa7548d851f91b667e7b96f3cced2cfe9c8256d3b3e1716df08",
    }
  ed25519(sd)
}
