# AIPoPh Internal Audit

The aim of this internal audit is to conduct thorough system testing on AIPoPh to ensure it functions as intended, identify any potential vulnerabilities, analyze performance across various scenarios, assess system robustness, and verify compliance with privacy regulations. The audit will result in a detailed report outlining our findings, proposed strategies for addressing any issues uncovered, and potential mitigations.

## Findings

The findings of our internal audit is below in no particular order.

### IA-1: *All single validators need to switch from `when is` into `expect`*

#### Severity: Low Risk

#### Status:

#### Files Affected: All Validators

#### Description:

All of the validators destruct the script context purpose with a `when is` statement causing redundant code that increases execution cost.  

#### Recommendation:

Change validators in this format:

```rust
when context.purpose is {
    Spend(output_reference) -> {..}
    _ -> False
}
```

into this format

```rust
expect Spend(output_reference) = context.purpose
..
```

The `expect` keyword should be used since it will auto fail instead of returning `False`.

---

### IA-2: *Transaction context should be destructured instead of using `.access`*

#### Severity: Medium Risk

#### Status:

#### Files Affected: All Validators

#### Description:

The transaction context is an expensive data structure to reference many times. If the validator references the Transaction type once then using the `.access` method is valid. If many fields need to be accessed from the Transaction type then the transaction context should be destructured.

#### Recommendation:

Change the transaction context from this

```rust
let tx: Transaction = context.transaction
..
```

into this

```rust
let Transaction {
  inputs,
  outputs,
  ..
} = context.transaction
```

This greatly reduces execution costs when traces are turned off.

---

### IA-3: *Change dao validator into reference validator*

#### Severity: Information

#### Status:

#### Files Affected: dao.ak

#### Description:

The DAO contract is not a dao but rather just a reference data contract used to store data required for AIPoPh to operate. The naming convention is confusing.

#### Recommendation:

Change dao into reference for the validator, type, and scripts. The DAO token used to perform actions should have a name that reflects the purpose of the token, like threshold token, vote token, action token, etc. The reference.ak file should be renamed to query.ak since it contains functions for querying the reference data.

---

### IA-4: *Remove explicit Lovelace addition to values when datum change*

#### Severity: Low Risk

#### Status:

#### Files Affected: dao.ak

#### Description:

The explicit use of a Lovelace term inside the redeemer is redundant. It increases complexity and cost without gaiing any security benefits.

#### Recommendation:

Use `value.without_lovelace` on this value from the dao contract then use an `payout.at_least` to allow for the minimum required Lovelace to scale naturally.

---

### IA-5: *Remove dRep system entirely from the AIPoPh ecosystem*

#### Severity: High Risk

#### Status:

#### Files Affected: dao.ak, oracle.ak, vault.ak, poh_mint.ak, coh_mint.ak

#### Description:

The dRep system is not defined in the intial scope and adds too much complexity to the system. The current implementation of the dRep system is incomplete and will cause security issues if allowed to stay inside the ecosystem at this time.

#### Recommendation:

The contracts will still need to have a single input with a specific script bypass but without the drep contract. The count function should be counting by address which will allow for two different contracts to be spent as intended.

---

### IA-6: *Vault should allow adding and removing Tokens instead of a Token*

#### Severity: Low Risk

#### Status:

#### Files Affected: vault.ak

#### Description:

The vault contract only allows a single Token to be added or removed from the UTxO. This limits functionality and will cause an increase to cost when adding or removing many tokens from the UTxO.

#### Recommendation:

Switch the Token type into Tokens, and make sure all the Tokens are adding or subtracting. This will cover the single token case and improve functionality.

---

### IA-7: *Add documentation to utility functions inside the library*

#### Severity: Informational

#### Status:

#### Files Affected: types/prove.ak, types/graph.ak, types/coh.ak, types/dao.ak types/poh.ak reference.ak

#### Description:

Documentation is missing from key functions inside various files. These utility functions need proper documentation to describe their purpose and use case.

#### Recommendation:

Add in some `///` top level function comments to all public functions.

---

### IA-8: *Potential stuck UTxO during VerifyTest redeemer due to lack of gas*

#### Severity: High Risk

#### Status:

#### Files Affected: poh_lock.ak

#### Description:

If a user does not place enough Lovelace onto the test UTxO then during the VerifyTest state where a threshold actor comes to verify the test taken by the user. The UTxO may become perma stuck due to the validation logic of Quit demanding that the verification process finish before removing.

#### Recommendation:

A simple fix is making any premature leave of the test result in a lost deposit as if the user failed the test. Then not having enough gas will just throw the UTxO into the Quit state with a lost deposit and not a perma lock.

---

### IA-#: **

#### Severity:

#### Status:

#### Files Affected: All Validators

#### Description:

#### Recommendation:

---

## Conclusion

- TODO