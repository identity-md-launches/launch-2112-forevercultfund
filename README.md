# ForeverCultFund (FOREVER)

An immutable ERC-20 with a single constructor mint. The complete supply goes to the immediate deployer (`msg.sender`). The token uses the vendored OpenZeppelin Contracts v5.1.0 ERC-20 implementation.

| Property | Value |
| --- | --- |
| Solidity contract | `src/ForeverCultFund.sol:ForeverCultFund` |
| Token name | `ForeverCultFund` |
| Symbol | `FOREVER` |
| Decimals | `18` |
| Supply in tokens | `1,000,000,000` |
| Supply in base units | `1000000000000000000000000000` (`10**27`) |
| Named supply constant | `INITIAL_SUPPLY = 1_000_000_000 * 10**18` |
| Constructor arguments | None |
| Deployment value | `0` ETH; constructor is nonpayable |
| Initial recipient | Immediate deployer; the factory during the IMD launch |
| Owner / administrator | None |

## Build and check

From the repository root, with Foundry and Solidity **0.8.26** installed:

```sh
forge build
forge test
forge fmt --check
```

All Solidity dependencies are included as ordinary files under `lib/`; no dependency installation, submodule checkout, RPC, account configuration, or network access is needed to run the checks. The compiler itself is supplied by the verification environment. The root configuration pins Solidity 0.8.26, Cancun EVM, optimizer enabled with 200 runs, and `bytecode_hash = "none"`. It enables neither FFI nor filesystem permissions.

The requested fuzz seed is pinned in `foundry.toml`:
`0xa0aa67c432a2f4b4c552567108b78d0dfbced00f7a77c88b8b6dd270c62305b0`.
Each fuzz test runs 1,000 cases. Stateful invariants run 128 sequences of up to 64 calls, with unexpected reverts treated as failures. Tests use fresh local deployments and require no environment variables or external chain state.

## Token behavior and assumptions

The brief specifies a standard fixed-supply token. Accordingly, transfers have no taxes, burns, fees, limits, exemptions, or callbacks. There is no minting after construction, public burning, rebasing, pause, blacklist, seizure, upgrade, ownership, or rescue facility. The constructor makes no external calls and requires no other contracts to exist.

`transfer`, `approve`, and `transferFrom` return `true` on success and revert with OpenZeppelin ERC-20 custom errors on failure. Transfers to the zero address and approvals for the zero spender revert. Transfers of zero tokens between nonzero addresses are valid and emit `Transfer`; self-transfers preserve the balance. Approvals replace the previous allowance. Finite allowances decrease when used; `type(uint256).max` means an unlimited allowance and is not decreased. Explicit approvals emit `Approval`; allowance consumption in `transferFrom` does not emit another `Approval` in this OpenZeppelin version.

Every positive delegated transfer requires the holder's approval, including transfers requested by the original deployer. A failed transfer rolls back both balances and any attempted allowance consumption. The deployment emits `Transfer(address(0), deployer, INITIAL_SUPPLY)`.

Holders are responsible for recipient selection and spender approvals. Applications should request only the allowance needed. When replacing an existing allowance, consider revoking it to zero first and waiting for confirmation to reduce the standard ERC-20 approval replacement race; a spender may still spend an existing allowance before revocation is mined. Tokens sent to this token contract or another address unable to transfer them cannot be recovered by an administrator. Ordinary ETH transfers revert, and there is no ETH withdrawal function.

## Deployment and launch responsibilities

The deployable artifact is `out/ForeverCultFund.sol/ForeverCultFund.json`. Deploy its creation bytecode with no appended constructor arguments and no ETH. A direct deployment gives the full supply to the deploying address; deployment through a factory gives it to that factory, not to the factory's caller or `tx.origin`. The launch factory must be able to distribute the supply it receives.

This assignment provides one production contract and no application contracts. It does not broadcast transactions or create a `launch.json`; the network's separate manifest and deployment steps handle admission, launch, and source verification.

The following launch parameters are supplied by the assignment. They are the external launch's configuration, not token constructor parameters or token-level fees:

| Launch parameter | Assigned value |
| --- | --- |
| Chain | Ethereum, chain ID `1` |
| Paired currency | IMD, `0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7`, 18 decimals |
| Pool fee | `12500` (1.25%) |
| Tick spacing | `60` |
| Pool share | `8500` basis points of the whole token supply (85%) |
| Initial market cap in paired base units | `3500000000000000000000` (3,500 IMD) |
| Remainder recipient | `0xff3e8d9ba776662ca6ed1420ee366afb436d2684` |
| Initial price provenance value | `79228162514264337593543950336` |

The launch factory receives 100% at deployment, forwards the swarm's 10% to its MerkleDistributor, uses the 85% pool allocation for liquidity, and forwards the remaining 5% to the assigned recipient. These allocations are not performed or reserved by the token constructor. The deployer derives the actual opening price from the assigned market cap, supply, and currency ordering; the provenance value is not the price to use blindly. No pool, router, factory, distributor, or recipient address needs to be stored in the token because all its transfers behave identically.

### After launch

There are no token settings, owner setters, initializer calls, or recurring maintenance transactions. The network's deployer is responsible for validating the manifest, deploying the verified bytecode, executing distribution and liquidity provisioning, and publishing the deployed address and verified source. Holders and integrators use the standard ERC-20 interface. The token cannot fix an erroneous distribution or upgrade its code after deployment.

## Validation scope

`test/ForeverCultFund.t.sol` covers metadata, exact supply, the mint event, direct and CREATE2 factory deployment, launch distribution and claim transfer amounts, both directions of pool-address token transfers, transfer events, self/zero/full-balance transfers, allowance replacement/revocation/consumption, unlimited approvals, unauthorized spending, invalid addresses, insufficient balances and allowances, rollback, rejected privileged selectors, rejected ETH, and forbidden runtime opcodes. Five fuzz tests exercise transfer and allowance boundaries, including arbitrary nonzero recipients and maximum integer inputs.

`test/ForeverCultFund.invariant.t.sol` mixes transfers, approvals, delegated transfers, and overspending attempts among four holders. It compares every tracked balance and allowance with an independent model, and checks that all balances sum to the original supply after every operation.

The supplied protected checks were read to establish the factory and transfer requirements. Their executable network harness, Uniswap v4 implementation, and resolved launch manifest are not part of this repository. Local launch tests exercise the token's transfer legs; they do not execute real Uniswap swaps. The network's independent launch verification remains responsible for those integration checks.

The security review focused on the constructor-only mint, exact transfer accounting, holder authorization, failure atomicity, and absence of external calls and privileged operations. With no external calls or callbacks, token operations provide no reentrancy entry point. Foundry compilation, unit/fuzz tests, invariants, and formatting checks are the automated checks used here; Slither and Mythril were not run. These checks do not replace an independent security review before release.

## Dependency provenance

Vendored upstream files are unchanged. `dependencies.lock.json` records exact commits, archive URLs and hashes, and SHA-256 hashes for each included file:

- [OpenZeppelin Contracts v5.1.0](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/69c8def5f222ff96f2b5beff05dfba996368aa79), commit `69c8def5f222ff96f2b5beff05dfba996368aa79`. Only the ERC-20 dependency closure and MIT license are included under `lib/openzeppelin-contracts/`.
- [forge-std v1.9.7](https://github.com/foundry-rs/forge-std/tree/77041d2ce690e692d6e03cc812b57d1ddaa4d505), commit `77041d2ce690e692d6e03cc812b57d1ddaa4d505`. Test sources and MIT/Apache-2.0 licenses are included under `lib/forge-std/`. This library is used only by tests.
