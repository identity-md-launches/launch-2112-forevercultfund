// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ForeverCultFund} from "src/ForeverCultFund.sol";

/// @dev Additional boundary and lifecycle properties complement the existing launch/unit tests.
/// forge-config: default.fuzz.runs = 1000
contract ForeverCultFundPropertiesTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000 * 10 ** 18;
    ForeverCultFund internal token;
    address internal alice;
    address internal bob;
    address internal spender;

    function setUp() public {
        token = new ForeverCultFund();
        alice = makeAddr("property holder");
        bob = makeAddr("property recipient");
        spender = makeAddr("property spender");
    }

    function testMaximumTransferCannotOverflowBalances() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, type(uint256).max
            )
        );
        token.transfer(alice, type(uint256).max);
        _assertBalances(SUPPLY, 0, 0);
    }

    function testMaximumDelegatedTransferCannotBypassBalanceCheck() public {
        assertTrue(token.approve(spender, type(uint256).max));
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, type(uint256).max
            )
        );
        vm.prank(spender);
        token.transferFrom(address(this), alice, type(uint256).max);
        assertEq(token.allowance(address(this), spender), type(uint256).max);
        _assertBalances(SUPPLY, 0, 0);
    }

    function testLargestFiniteAllowanceIsConsumed() public {
        assertTrue(token.approve(spender, type(uint256).max - 1));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), spender), type(uint256).max - 2);
        _assertBalances(SUPPLY - 1, 1, 0);
    }

    function testInfiniteAllowanceCanBeReducedThenRevoked() public {
        assertTrue(token.approve(spender, type(uint256).max));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), spender), type(uint256).max);

        assertTrue(token.approve(spender, 2));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 2));
        assertEq(token.allowance(address(this), spender), 0);

        assertTrue(token.approve(spender, type(uint256).max));
        assertTrue(token.approve(spender, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), alice, 1);
        _assertBalances(SUPPLY - 3, 3, 0);
    }

    function testSelfTransferStillRequiresSufficientBalance() public {
        assertTrue(token.transfer(alice, 1));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1, 2));
        vm.prank(alice);
        token.transfer(alice, 2);
        _assertBalances(SUPPLY - 1, 1, 0);
    }

    function testDelegatedSelfTransferStillRequiresSufficientBalance() public {
        assertTrue(token.transfer(alice, 1));
        vm.prank(alice);
        assertTrue(token.approve(spender, 2));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1, 2));
        vm.prank(spender);
        token.transferFrom(alice, alice, 2);
        assertEq(token.allowance(alice, spender), 2);
        _assertBalances(SUPPLY - 1, 1, 0);
    }

    function testOwnerUsingTransferFromNeedsSelfApproval() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 1));
        token.transferFrom(address(this), alice, 1);
        _assertBalances(SUPPLY, 0, 0);

        assertTrue(token.approve(address(this), 1));
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), address(this)), 0);
        _assertBalances(SUPPLY - 1, 1, 0);
    }

    function testZeroDelegatedTransferEmitsEventWithoutApproval() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(alice, bob, 0);
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 0));
        assertEq(token.allowance(alice, spender), 0);
        _assertBalances(SUPPLY, 0, 0);
    }

    function testZeroSpenderRejectedForZeroAndMaximumApprovals() public {
        assertTrue(token.approve(spender, 7));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), type(uint256).max);
        assertEq(token.allowance(address(this), address(0)), 0);
        assertEq(token.allowance(address(this), spender), 7);
        _assertBalances(SUPPLY, 0, 0);
    }

    function testReceivingTokensDoesNotInheritSendersApprovals() public {
        assertTrue(token.transfer(alice, 11));
        vm.startPrank(alice);
        assertTrue(token.approve(spender, 11));
        assertTrue(token.transfer(bob, 11));
        vm.stopPrank();

        assertEq(token.allowance(alice, spender), 11);
        assertEq(token.allowance(bob, spender), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(bob, spender, 1);
        _assertBalances(SUPPLY - 11, 0, 11);
    }

    function testApprovalCannotBeUsedForAnotherOwner() public {
        assertTrue(token.transfer(alice, 10));
        assertTrue(token.transfer(bob, 10));
        vm.prank(alice);
        assertTrue(token.approve(spender, 10));

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(bob, alice, 1);
        assertEq(token.allowance(alice, spender), 10);
        assertEq(token.allowance(bob, spender), 0);
        _assertBalances(SUPPLY - 20, 10, 10);
    }

    function testFuzzFailedDelegatedTransferCanBeRetried(uint256 balanceSeed, uint256 amountSeed, bool infiniteApproval)
        public
    {
        uint256 balance = bound(balanceSeed, 1, SUPPLY);
        uint256 amount = bound(amountSeed, balance + 1, type(uint256).max);
        uint256 approved = infiniteApproval ? type(uint256).max : amount;
        assertTrue(token.transfer(alice, balance));
        vm.prank(alice);
        assertTrue(token.approve(spender, approved));

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, balance, amount));
        vm.prank(spender);
        token.transferFrom(alice, bob, amount);
        assertEq(token.allowance(alice, spender), approved);
        _assertBalances(SUPPLY - balance, balance, 0);

        // The failed call must neither consume the approval nor freeze the holder's balance.
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, balance));
        assertEq(token.allowance(alice, spender), approved == type(uint256).max ? approved : approved - balance);
        _assertBalances(SUPPLY - balance, 0, balance);
    }

    function testFuzzApprovalAppliesToFutureReceipts(uint256 amountSeed) public {
        uint256 amount = bound(amountSeed, 1, SUPPLY);
        vm.prank(alice);
        assertTrue(token.approve(spender, amount));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, amount));
        vm.prank(spender);
        token.transferFrom(alice, bob, amount);
        assertEq(token.allowance(alice, spender), amount);
        _assertBalances(SUPPLY, 0, 0);

        assertTrue(token.transfer(alice, amount));
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, amount));
        assertEq(token.allowance(alice, spender), 0);
        _assertBalances(SUPPLY - amount, 0, amount);
    }

    function testFuzzReplacementAfterPartialSpendIsExact(uint256 approvalSeed, uint256 spentSeed, uint256 replacement)
        public
    {
        uint256 approved = bound(approvalSeed, 1, SUPPLY - 1);
        uint256 spent = bound(spentSeed, 1, approved);
        assertTrue(token.approve(spender, approved));
        assertTrue(token.approve(bob, 17));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, spent));

        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Approval(address(this), spender, replacement);
        assertTrue(token.approve(spender, replacement));
        assertEq(token.allowance(address(this), spender), replacement);
        assertEq(token.allowance(address(this), bob), 17);
        _assertBalances(SUPPLY - spent, spent, 0);

        uint256 spendable = replacement < SUPPLY - spent ? replacement : SUPPLY - spent;
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, spendable));
        assertEq(
            token.allowance(address(this), spender),
            replacement == type(uint256).max ? replacement : replacement - spendable
        );
        assertEq(token.allowance(address(this), bob), 17);
        _assertBalances(SUPPLY - spent - spendable, spent + spendable, 0);
    }

    function testFuzzRevocationBlocksPreviouslyApprovedSpender(uint256 approvedSeed, uint256 spentSeed) public {
        uint256 approved = bound(approvedSeed, 1, type(uint256).max);
        uint256 limit = approved < SUPPLY - 1 ? approved : SUPPLY - 1;
        uint256 spent = bound(spentSeed, 0, limit);
        assertTrue(token.approve(spender, approved));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, spent));

        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Approval(address(this), spender, 0);
        assertTrue(token.approve(spender, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), alice, 1);
        assertEq(token.allowance(address(this), spender), 0);
        _assertBalances(SUPPLY - spent, spent, 0);
    }

    function testFuzzRoundTripRestoresBalancesAndLeavesAllowancesAlone(uint256 amountSeed, uint256 approved) public {
        uint256 amount = bound(amountSeed, 0, SUPPLY);
        assertTrue(token.approve(spender, approved));
        vm.prank(alice);
        assertTrue(token.approve(spender, approved));

        assertTrue(token.transfer(alice, amount));
        _assertBalances(SUPPLY - amount, amount, 0);
        vm.prank(alice);
        assertTrue(token.transfer(address(this), amount));
        _assertBalances(SUPPLY, 0, 0);
        assertEq(token.allowance(address(this), spender), approved);
        assertEq(token.allowance(alice, spender), approved);
    }

    function testFuzzDelegatedSelfTransferOnlyConsumesAllowance(
        uint256 balanceSeed,
        uint256 approved,
        uint256 amountSeed
    ) public {
        uint256 balance = bound(balanceSeed, 0, SUPPLY);
        uint256 amount = bound(amountSeed, 0, approved < balance ? approved : balance);
        assertTrue(token.transfer(alice, balance));
        vm.prank(alice);
        assertTrue(token.approve(spender, approved));

        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(alice, alice, amount);
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, alice, amount));
        assertEq(token.allowance(alice, spender), approved == type(uint256).max ? approved : approved - amount);
        _assertBalances(SUPPLY - balance, balance, 0);
    }

    function _assertBalances(uint256 deployerBalance, uint256 aliceBalance, uint256 bobBalance) private view {
        assertEq(token.balanceOf(address(this)), deployerBalance, "deployer balance");
        assertEq(token.balanceOf(alice), aliceBalance, "holder balance");
        assertEq(token.balanceOf(bob), bobBalance, "recipient balance");
        assertEq(token.balanceOf(spender), 0, "spender received unrequested tokens");
        assertEq(token.balanceOf(address(0)), 0, "tokens burned");
        assertEq(token.balanceOf(address(token)), 0, "token retained a fee");
        assertEq(token.totalSupply(), SUPPLY, "fixed supply changed");
    }
}
