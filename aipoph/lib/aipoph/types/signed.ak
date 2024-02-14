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

test good_ed25519_sig() {
  let sd: SignedData =
    SignedData {
      verification_key: #"0b801082eed269a74c30857bbcf91888865987bb599d00fb9b2f60ba4b58438f",
      message: #"48656c6c6f2c20576f726c6421",
      signature: #"1e55545d89f4e149828f8e3810bffeba9cbb5644d9578cb29592c235ba8945870c305cbd4510811c5aa2b8e71d157a907817c708934b6b9dbab7e0406ccf9e0b",
    }
  ed25519(sd)
}
