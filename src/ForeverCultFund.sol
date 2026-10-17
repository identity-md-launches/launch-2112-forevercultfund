// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ForeverCultFund
/// @notice Fixed-supply ERC-20: one billion FOREVER with 18 decimals.
/// @dev The immediate deployer receives the entire supply. During an IMD launch this is the factory.
/// There are no external mint, burn, administrative, or upgrade functions.
contract ForeverCultFund is ERC20 {
    /// @notice The lifetime supply, expressed in the token's smallest units.
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor() ERC20("ForeverCultFund", "FOREVER") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
