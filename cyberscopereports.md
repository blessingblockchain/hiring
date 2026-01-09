# Cyberscope.io 

My name is Adeola, I am an independent secutrity researcher, i have been in security for more than 2 years now. I am wanting to get in for the role at cyberscope.io as a full time security researcher. 

I am of high skill and value to the cyberscope teamm if i get choosen as you can see in my reports, i spent roughly 2 days as i am fast and skilled. 

This is my twitter: (Playboi)[https://x.com/adeolRxxxx]
Email: adeolasola01@gmail.com
 

My Finding Summay
|ID|Title|Severity|
|:-:|:---|:------:|
|[C-01](#c-01-withdraw-function-uses-memory-copy-instead-of-storage-which-leads-to-reapeated-withdrawals-and-complete-contract-drainage)|Withdraw function uses memory copy instead of storage which leads to repeated withdrawals & complete contract drainage.|CRITICAL|
|[C-02](#c-02-Incorrect-Use-of-Public-transfer()-Instead-of-Internal-_transfer()-in-withdraw-Causes-User-Funds-to-be-Permanently-Trapped)|Incorrect Use of Public `transfer()` Instead of Internal `_transfer()` in `withdraw()` Causes User Funds to be Permanently Trapped.|CRITICAL|
|[C-03](#c-03-transferFrom-Missing-Allowance-Check-Enables-Token-Theft)|`transferFrom` Missing Allowance Check Enables Token Theft.|CRITICAL|
|[C-04](#c-04-Reversed-Swap-Path-in-swapTokensForEth()-Causes-Swap-Failures-and-Transfer-DoS)|Reversed Swap Path in `swapTokensForEth()` Causes Swap Failures and Transfer DoS.|CRITICAL|
|[C-05](#c-05-claimReward()-Never-Resets-lastUpdate-Timestamp-Enabling-Attackers-to-Drain-Entire-Reward-Pool.)|`claimReward()` Never Resets `lastUpdate` Timestamp, Enabling Attackers to Drain Entire Reward Pool.|CRITICAL|
|[C-06](#c-06-stake()-Overwrites-Existing-Stake-Amount-Instead-of-Adding-Causing-Permanent-Token-Loss.)|`stake()` Overwrites Existing Stake Amount Instead of Adding, Causing Permanent Token Loss.|CRITICAL|
|[C-07](#c-07-rewardRate-Is-Always-Zero-due-to-Integer-Division-Causing-Users-to-Receive-Zero-Rewards-Indefinitely)|`rewardRate` Is Always Zero Due to Integer Division, Causing Users to Receive Zero Rewards Indefinitely.|CRITICAL|
|[C-08](#c-08-stake()-Accepts-Arbitrary-Token-Address-Enabling-Complete-Reward-Pool-Theft-With-Worthless-Tokens.)|`stake()` Accepts Arbitrary Token Address, Enabling Complete Reward Pool Theft With Worthless Tokens.|CRITICAL|
||||
|[H-01](#h-01-Double-Deduction-In-_transfer()-Function-Overcharges-Senders-By-Fees-Plus-Full-Amount-Leading-To-Unintended-Fund-Losses)|Double Deduction in `_transfer()` Function Overcharges Senders By Fees Plus Full Amount Leading To Unintended Fund Losses.|HIGH|
|[H-02](#h-02-Zero-Slippage-Protection-in-swapTokensForEth()-causes-attackers-to-drain-protocol-fee-revenue-by-sandwich-attacks)|Zero Slippage Protection in `swapTokensForEth()` causes attackers to drain protocol fee revenue by sandwich attacks.|HIGH|
|[H-03](#h-03-_transfer()-Auto-Swap-Consumes-Staking-Rewards-Due-to-Lack-of-Fee-and-Reward-Balance-Separation-Causing-Reward-Pool-drainage)|`_transfer()` Auto-Swap Consumes Staking Rewards Due to Lack of Fee and Reward Balance Separation, Causing Reward Pool drainage.|HIGH|
|[H-04](#h-04-Zero-claimReward()-Reverts-When-Contract-Balance-Falls-Below-totalRewardsDistributed-Causing-Permanent-DoS)|`claimReward()` Reverts When `Contract Balance Falls Below totalRewardsDistributed`, Causing Permanent DoS.|HIGH|
||||
|[M-01](#m-01-renounceOwnership()-Sets-Owner-to-Caller-Instead-of-Zer0-Address-Preventing-True-Renouncement)|`renounceOwnership()` Sets Owner to `Caller` Instead of Zero Address, Preventing True Renouncement.|MEDIUM|
|[M-02](#m-02-withdraw()-Allows-Early-Withdrawal-Before-Staking-Period-Ends-Enabling-Reward-Gaming-Without-Token-Lock-Commitment)|`withdraw()` allows Early Withdrawal Before Staking Period Ends, Enabling Reward Gaming Without Token Lock Commitment
.|MEDIUM|
||||
|[L-01](#l-01-_transfer()-with-amount=0-Does-Not-Return-Early-Causing-Duplicate-Events-and-Wasted-Gas)|`_transfer()` with `amount=0` Does Not Return Early, Causing Duplicate Events and Wasted Gas.|LOW|



## [C-01] `Withdraw function` uses `memory copy` instead of storage which leads to repeated withdrawals & complete contract drainage. 

## Description

The `withdraw()` function in `Token.sol` uses `memory` instead of `storage` when referencing the user's stake, causing the stake to never be cleared after withdrawal. This allows users to withdraw their staked tokens infinite times, draining the entire contract balance. 

```solidity
function withdraw() external {
    Stake memory userStake = stakes[msg.sender];  // ← audit- BUG: Creates a COPY
    require(userStake.amount > 0, "No stake to withdraw");
    uint256 reward = claimReward(msg.sender);
    uint256 stakedAmount = userStake.amount;
    userStake.amount = 0;       // ← Only modifies the COPY
    userStake.lastUpdate = 0;   // ← Only modifies the COPY
    transfer(msg.sender, stakedAmount);
    emit Withdrawn(msg.sender, stakedAmount, reward);
}
```

## Root cause 

This particular function declares `Stake memory userStake` which creates a temporary copy of the stake data in memory. When the function sets `userStake.amount = 0` and `userStake.lastUpdate = 0`, it only modifies this temporary copy. The actual storage `mapping stakes[msg.sender]` is never updated.

## Impact 
-  Complete Protocol Drain:

1. User stakes 1000 tokens
2. User calls `withdraw()` → receives 1000 tokens
3. Storage still shows: `stakes[user].amount = 1000 (unchanged!)`
4. User calls `withdraw()` again → receives 1000 tokens again
5. User repeats until contract is completely drained

This affects:
- All staked tokens in the contract
- All reward tokens held by the contract
- Every user who has tokens in the protocol

## Poc

I created an entire testsuite with the ridgt set-up for the test. 

Create a file and add this to it. 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Test} from "forge-std/Test.sol";
import {Token, IERC20} from "../src/Token.sol";

// Mock Uniswap V2 Router
contract MockUniswapV2Router {
    address public immutable WETH_ADDRESS;
    address public immutable FACTORY_ADDRESS;

    constructor() {
        WETH_ADDRESS = address(new MockWETH());
        FACTORY_ADDRESS = address(new MockUniswapV2Factory());
    }

    function factory() external view returns (address) {
        return FACTORY_ADDRESS;
    }

    function WETH() external view returns (address) {
        return WETH_ADDRESS;
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        // Mock: just pretend the swap happened
    }
}

// Mock WETH
contract MockWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
}

// Mock Uniswap V2 Factory
contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public pairs;
    
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        pair = address(new MockUniswapV2Pair());
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;
        return pair;
    }

    function getPair(address tokenA, address tokenB) external view returns (address) {
        return pairs[tokenA][tokenB];
    }
}

// Mock Uniswap V2 Pair
contract MockUniswapV2Pair {
    // Empty mock pair
}

contract TokenTest is Test {
    // ============ Contracts ============
    Token public token;
    MockUniswapV2Router public router;

    // ============ Actors ============
    address public owner;
    address public feeReceiver;
    address public alice;
    address public bob;
    address public attacker;

    // ============ Token Parameters ============
    string constant NAME = "Test Token";
    string constant SYMBOL = "TEST";
    uint8 constant DECIMALS = 18;
    uint256 constant TOTAL_SUPPLY = 1_000_000 * 10**18;

    // ============ Setup ============
    function setUp() public {
        // Create actors
        owner = makeAddr("owner");
        feeReceiver = makeAddr("feeReceiver");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        attacker = makeAddr("attacker");

        // Fund actors with ETH for gas
        vm.deal(owner, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(attacker, 100 ether);

        // Deploy mock router
        router = new MockUniswapV2Router();

        // Deploy token as owner
        vm.startPrank(owner);
        token = new Token(
            NAME,
            SYMBOL,
            DECIMALS,
            TOTAL_SUPPLY,
            feeReceiver,
            address(router)
        );
        vm.stopPrank();
    }

    // ============ Helper Functions ============
    
    /// @notice Transfer tokens from owner to a user
    function _fundUser(address user, uint256 amount) internal {
        vm.prank(owner);
        token.transfer(user, amount);
    }

    /// @notice Approve and stake tokens for a user
    function _stakeAs(address user, uint256 amount) internal {
        vm.startPrank(user);
        token.approve(address(token), amount);
        token.stake(address(token), amount);
        vm.stopPrank();
    }

    /// @notice Warp time forward
    function _warpForward(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    /// @notice Get user's stake info
    function _getStake(address user) internal view returns (uint256 amount, uint256 lastUpdate, uint256 rewardDebt) {
        (amount, lastUpdate, rewardDebt) = token.stakes(user);
    }

    // ============ Test Functions Go Below ============

    /// @notice PoC: Critical - Storage Never Updated in withdraw() due to memory vs storage bug
    /// @dev The withdraw() function uses `memory` instead of `storage`, so stake is never cleared
    function test_POC_MemoryVsStorage_StakeNeverCleared() public {
        uint256 stakeAmount = 100 * 10**18;
        
        // Fund alice with tokens
        _fundUser(alice, stakeAmount);
        
        // Alice stakes tokens
        _stakeAs(alice, stakeAmount);
        
        // Verify stake is recorded
        (uint256 stakedBefore, uint256 lastUpdateBefore,) = _getStake(alice);
        assertEq(stakedBefore, stakeAmount, "Stake should be recorded");
        assertGt(lastUpdateBefore, 0, "lastUpdate should be set");
        
        // Give alice extra tokens (needed due to another bug in withdraw)
        _fundUser(alice, stakeAmount * 2);
        
        // Call withdraw - this SHOULD clear the stake
        vm.prank(alice);
        token.withdraw();
        
        // === THE BUG: Storage is NEVER updated ===
        (uint256 stakedAfter, uint256 lastUpdateAfter,) = _getStake(alice);
        
        // BUG PROVEN: After withdraw(), stake should be 0 but it's still the original amount!
        assertEq(stakedAfter, stakeAmount, "BUG: Stake should be 0 but is still original amount!");
        assertEq(lastUpdateAfter, lastUpdateBefore, "BUG: lastUpdate should be 0 but unchanged!");
    }
}
```
- the stake amount remains unchanged in storage.

## Recommendation

- Change `memory` to `storage` to create a reference instead of a copy:

```solidity
function withdraw() external {
    Stake storage userStake = stakes[msg.sender];  // ← FIX: Use storage reference
    require(userStake.amount > 0, "No stake to withdraw");
    uint256 reward = claimReward(msg.sender);
    uint256 stakedAmount = userStake.amount;
    userStake.amount = 0;       // ← Now modifies actual storage
    userStake.lastUpdate = 0;   // ← Now modifies actual storage
    transfer(msg.sender, stakedAmount);
    emit Withdrawn(msg.sender, stakedAmount, reward);
}
```

## IMPACT 2

- This is where it gets compounded. This bug enables `infinite withdrawals of both staked tokens` AND `maximum rewards per call`, resulting in complete protocol drain.

check this function and see why it happens;

```solidity
function calculateReward(address _user) public view returns (uint256) {
    uint256 stakingDuration = block.timestamp - userStake.lastUpdate;
    //                                          ^^^^^^^^^^^^^^^^
    //                        Still the ORIGINAL timestamp from first stake!
    
    if (stakingDuration > stakingPeriod) {
        stakingDuration = stakingPeriod;  // Capped at 30 days
    }
    uint256 reward = userStake.amount * stakingDuration * rewardRate;
}
```

so basically for each withdrawal, the maximum rewards are extracted per - call. 


## [C-02] Incorrect Use of Public `transfer()` Instead of Internal `_transfer()` in `withdraw()` Causes User Funds to be Permanently Trapped. 

## Description

The `withdraw()` and `claimReward()` functions use the public `transfer()` function which transfers `FROM` the caller instead of `FROM the contract`. This causes all withdrawal and reward claims to fail, permanently trapping user funds in the contract.

## Vulnerable Code

```solidity
function withdraw() external {
    Stake memory userStake = stakes[msg.sender];
    require(userStake.amount > 0, "No stake to withdraw");
    uint256 reward = claimReward(msg.sender);
    uint256 stakedAmount = userStake.amount;
    userStake.amount = 0;
    userStake.lastUpdate = 0;
    transfer(msg.sender, stakedAmount);  // ← BUG: Wrong sender
    emit Withdrawn(msg.sender, stakedAmount, reward);
}

function claimReward(address _user) public returns (uint256) {
    // ...
    if (reward > 0) {
        totalRewardsDistributed += reward;
        userStake.rewardDebt = 0;
        transfer(_user, reward);  // ← BUG: Wrong sender
        emit RewardClaimed(_user, reward);
    }
    return reward;
}
```

## Root Cause
- The public `transfer()` function uses `msgSender()` as the sender:

```solidity
function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(_msgSender(), recipient, amount);  // _msgSender() = caller, not contract
    return true;
}
```

When `withdraw()` calls `transfer(msg.sender, stakedAmount)`:

-  `transfer()` is called
-  `transfer(_msgSender(), msg.sender, amount)` executes
-  `msgSender()` returns the user (original caller of withdraw)
-  Result:` transfer(USER, USER, amount)` - transferring from user to user!
 - The contract holds the staked tokens, but the code tries to transfer FROM the user who has zero balance.


## Impact
Complete Loss of User Funds:
1. User stakes tokens - tokens move to contract
2. User calls `withdraw()` - REVERTS because user balance is 0
3. Tokens remain trapped in contract forever
4. No way to recover funds. 


## Poc

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Test} from "forge-std/Test.sol";
import {Token, IERC20} from "../src/Token.sol";

// Mock Uniswap V2 Router
contract MockUniswapV2Router {
    address public immutable WETH_ADDRESS;
    address public immutable FACTORY_ADDRESS;

    constructor() {
        WETH_ADDRESS = address(new MockWETH());
        FACTORY_ADDRESS = address(new MockUniswapV2Factory());
    }

    function factory() external view returns (address) {
        return FACTORY_ADDRESS;
    }

    function WETH() external view returns (address) {
        return WETH_ADDRESS;
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        // Mock: just pretend the swap happened
    }
}

// Mock WETH
contract MockWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
}

// Mock Uniswap V2 Factory
contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public pairs;
    
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        pair = address(new MockUniswapV2Pair());
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;
        return pair;
    }

    function getPair(address tokenA, address tokenB) external view returns (address) {
        return pairs[tokenA][tokenB];
    }
}

// Mock Uniswap V2 Pair
contract MockUniswapV2Pair {
    // Empty mock pair
}

contract TokenTest is Test {
    // ============ Contracts ============
    Token public token;
    MockUniswapV2Router public router;

    // ============ Actors ============
    address public owner;
    address public feeReceiver;
    address public alice;
    address public bob;
    address public attacker;

    // ============ Token Parameters ============
    string constant NAME = "Test Token";
    string constant SYMBOL = "TEST";
    uint8 constant DECIMALS = 18;
    uint256 constant TOTAL_SUPPLY = 1_000_000 * 10**18;

    // ============ Setup ============
    function setUp() public {
        // Create actors
        owner = makeAddr("owner");
        feeReceiver = makeAddr("feeReceiver");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        attacker = makeAddr("attacker");

        // Fund actors with ETH for gas
        vm.deal(owner, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(attacker, 100 ether);

        // Deploy mock router
        router = new MockUniswapV2Router();

        // Deploy token as owner
        vm.startPrank(owner);
        token = new Token(
            NAME,
            SYMBOL,
            DECIMALS,
            TOTAL_SUPPLY,
            feeReceiver,
            address(router)
        );
        vm.stopPrank();
    }

    // ============ Helper Functions ============
    
    /// @notice Transfer tokens from owner to a user
    function _fundUser(address user, uint256 amount) internal {
        vm.prank(owner);
        token.transfer(user, amount);
    }

    /// @notice Approve and stake tokens for a user
    function _stakeAs(address user, uint256 amount) internal {
        vm.startPrank(user);
        token.approve(address(token), amount);
        token.stake(address(token), amount);
        vm.stopPrank();
    }

    /// @notice Warp time forward
    function _warpForward(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    /// @notice Get user's stake info
    function _getStake(address user) internal view returns (uint256 amount, uint256 lastUpdate, uint256 rewardDebt) {
        (amount, lastUpdate, rewardDebt) = token.stakes(user);
    }

 

    /// @notice PoC: Wrong Transfer Direction - withdraw() transfers from user, not contract
    /// @dev withdraw() uses public transfer() which uses _msgSender() as sender
    function test_POC_WrongTransferDirection_Withdraw() public {
        uint256 stakeAmount = 100 * 10**18;
        
        // Fund alice and stake
        _fundUser(alice, stakeAmount);
        _stakeAs(alice, stakeAmount);
        
        // Alice's balance is now 0 (all staked)
        uint256 aliceBalanceAfterStake = token.balanceOf(alice);
        assertEq(aliceBalanceAfterStake, 0, "Alice has 0 after staking");
        
        // Contract holds the staked tokens
        uint256 contractBalance = token.balanceOf(address(token));
        assertGt(contractBalance, stakeAmount, "Contract holds staked tokens");
        
        // Now alice tries to withdraw
        // withdraw() calls transfer(msg.sender, stakedAmount)
        // which calls _transfer(_msgSender(), msg.sender, amount)
        // = _transfer(alice, alice, amount) ← WRONG! Should be from contract
        
        vm.prank(alice);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.withdraw();
        
        // The withdraw FAILS because it tries to transfer FROM alice (who has 0)
        // instead of FROM the contract (which holds the tokens)
        
        // Tokens remain trapped in contract forever
        assertEq(token.balanceOf(address(token)), contractBalance, "Tokens trapped in contract");
    }
}
```

## Recommendation
Use `transfer()` directly with `address(this)` as the sender. 

```solidity
function withdraw() external {
    Stake storage userStake = stakes[msg.sender];
    require(userStake.amount > 0, "No stake to withdraw");
    uint256 reward = claimReward(msg.sender);
    uint256 stakedAmount = userStake.amount;
    userStake.amount = 0;
    userStake.lastUpdate = 0;
    _transfer(address(this), msg.sender, stakedAmount);  // FIX: Contract → User
    emit Withdrawn(msg.sender, stakedAmount, reward);
}

function claimReward(address _user) public returns (uint256) {
    // ...
    if (reward > 0) {
        totalRewardsDistributed += reward;
        userStake.rewardDebt = 0;
        _transfer(address(this), _user, reward);  // FIX: Contract → User
        emit RewardClaimed(_user, reward);
    }
    return reward;
}
```

## [C-03] `transferFrom` Missing Allowance Check Enables Token Theft. 

## Description

The `transferFrom()` function does not check or decrement token allowances before transferring. This allows anyone to transfer tokens `FROM` any address without approval, enabling complete theft of all user tokens.

## Vulnerable Code

```solidity
function transferFrom(
    address sender,
    address recipient,
    uint256 amount
) public virtual override returns (bool) {
    _transfer(sender, recipient, amount);
    return true;
}
```

## Root Cause

Standard `ERC20 transferFrom()` requires:
- Check that `msg.sender` has sufficient allowance from sender.
- Decrement the allowance after transfer.
- Then execute the transfer. 

This implementation skips both checks entirely. Anyone can call `transferFrom(victim, attacker, amount)` and steal tokens directly from any address that has a balance.


Missing standard logic:

```solidity
// This is what SHOULD exist but DOESN'T:
uint256 currentAllowance = _allowances[sender][_msgSender()];
require(currentAllowance >= amount, "ERC20: insufficient allowance");
unchecked {
    _allowances[sender][_msgSender()] = currentAllowance - amount;
}
```


## Impact 

Complete Token Theft:
- Attacker identifies victim with token balance
- Attacker calls `transferFrom(victim, attacker, victimBalance)`
- No approval check - transfer executes immediately
- Victim loses all tokens
- Attacker gains all tokens


## Recommendation
Add the missing allowance check and decrement:

```solidity
function transferFrom(
    address sender,
    address recipient,
    uint256 amount
) public virtual override returns (bool) {
    uint256 currentAllowance = _allowances[sender][_msgSender()];
    require(currentAllowance >= amount, "ERC20: insufficient allowance");
    unchecked {
        _allowances[sender][_msgSender()] = currentAllowance - amount;
    }
    _transfer(sender, recipient, amount);
    return true;
}
```



## [C-04] Reversed Swap Path in `swapTokensForEth()` Causes Swap Failures and Transfer DoS.

## Description 

The `swapTokensForEth()` function has the Uniswap path reversed because it tries to swap `WETH` for tokens instead of `tokens for ETH`. Since this function is called automatically during transfers, once fees accumulate past the threshold, ALL non-excluded transfers permanently revert, causing complete protocol DoS.


## Vulnerable Code

```solidity
function swapTokensForEth(uint256 tokenAmount) private {
    address[] memory path = new address[](2);
    path[0] = uniswapV2Router.WETH();   // ← WRONG: Should be address(this)
    path[1] = address(this);             // ← WRONG: Should be WETH
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokenAmount,
        0, 
        path,
        feeReceiver,
        block.timestamp
    );   
}
```

## Root Cause

For `swapExactTokensForETHSupportingFeeOnTransferTokens`:
- path[0] must be the INPUT token (what you're selling)
- path[1] must be WETH (what you're receiving as ETH).


Current path: [WETH, Token] - tries to sell WETH for Token
Correct path: [Token, WETH] - sells Token for ETH

The contract approves its own tokens but the path says "start with WETH", causing Uniswap to revert.

## Impact
1. Complete Protocol DoS:


```solidity
1. Fees accumulate in contract from transfers (3% fee)
2. Contract balance reaches swapTokensAtAmount (0.1% of supply)
3. Next non-excluded transfer triggers swapTokensForEth()
4. Uniswap swap REVERTS due to invalid path
5. Entire _transfer() reverts
6. ALL future non-excluded transfers fail permanently
```
- The DoS is triggered automatically from `transfer()`:

```solidity
if(canSwap && !swapping && ...) {
    swapping = true;
    swapTokensForEth(swapTokensAtAmount);  // ← Reverts here
    swapping = false;
}
// If swap reverts, entire transfer reverts
```
- Timeline to DoS:
1. swapTokensAtAmount = totalSupply * 1 / 1000 = 0.1% of supply
2. After ~34 transfers of average size, enough fees accumulate. 
3. Protocol becomes completely unusable

This affects:
- All non-excluded transfers (normal users)
- Any token movement between regular addresses

## Recommendation
Reverse the path order:

```solidity
function swapTokensForEth(uint256 tokenAmount) private {
    address[] memory path = new address[](2);
    path[0] = address(this);              // FIX: Token first (selling)
    path[1] = uniswapV2Router.WETH();     // FIX: WETH second (receiving)
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokenAmount,
        0, 
        path,
        feeReceiver,
        block.timestamp
    );   
}
```

## [C-05] `claimReward()` Never Resets `lastUpdate` Timestamp, Enabling Attackers to Drain Entire Reward Pool. 

## Description

The `claimReward()` function calculates rewards based on `block.timestamp - userStake.lastUpdate` but never resets `lastUpdate` after paying out rewards. This allows attackers to repeatedly claim overlapping reward periods, receiving far more than their fair share and draining the reward pool.

```solidity
function claimReward(address _user) public returns (uint256) {
    Stake storage userStake = stakes[_user];
    if (userStake.amount == 0) return 0;
    
    uint256 reward = calculateReward(_user) + userStake.rewardDebt;
    // ↑ calculateReward uses: (block.timestamp - userStake.lastUpdate)
    
    if (reward + totalRewardsDistributed > balanceOf(address(this))) {
        reward = balanceOf(address(this)) - totalRewardsDistributed;
    }
    
    if (reward > 0) {
        totalRewardsDistributed += reward;
        userStake.rewardDebt = 0;    // ← Resets debt
        // userStake.lastUpdate = ?   ← MISSING! Never reset
        transfer(_user, reward);
        emit RewardClaimed(_user, reward);
    }
    return reward;
}
```

## Root Cause

After paying rewards, the function resets `rewardDebt` to 0 but fails to update `lastUpdate` to `block.timestamp`. Every subsequent call to `claimReward()` recalculates rewards from the original stake timestamp, not from the last claim.

## Impact

**Complete Reward Pool Drain:**

Attack sequence for an attacker who stakes on Day 0:

| Day | Action | Reward Calculated | Cumulative Paid |
|:---:|--------|-------------------|-----------------|
| 0 | Stake 100 tokens | - | - |
| 15 | `claimReward()` | 15 days worth | 15 days |
| 30 | `claimReward()` | 30 days worth (from Day 0!) | 45 days |
| 45 | `claimReward()` | 30 days worth (capped) | 75 days |
| 60 | `claimReward()` | 30 days worth (capped) | 105 days |

**For 60 days of staking, attacker receives 105 days worth of rewards (1.75x overpayment)**

The attacker can repeat until `totalRewardsDistributed` hits the contract balance cap, draining the entire reward pool and leaving nothing for legitimate stakers.

**Additional Attack Vector - Public Access Control:**
The function is `public` with an `_user` parameter, meaning anyone can call `claimReward(victim)` to:
- Force early claims on victims, manipulating their reward timing
- Reset victims' `rewardDebt` without their consent

## Proof of Concept

```solidity
function test_POC_AttackerDrainsRewardPool() public {
    uint256 stakeAmount = 100 * 10**18;
    
    // Attacker stakes tokens
    _fundUser(attacker, stakeAmount);
    _stakeAs(attacker, stakeAmount);
    
    // Get initial lastUpdate
    (, uint256 lastUpdateInitial,) = _getStake(attacker);
    
    // Warp forward 15 days (halfway through 30-day staking period)
    _warpForward(15 days);
    
    // EXPLOIT: Attacker claims partial reward
    vm.prank(attacker);
    token.claimReward(attacker);
    // Attacker gets 15-day reward, but lastUpdate is NEVER reset
    
    // Verify: lastUpdate was NOT updated in claimReward
    (, uint256 lastUpdateAfterClaim1,) = _getStake(attacker);
    assertEq(lastUpdateAfterClaim1, lastUpdateInitial, "BUG: lastUpdate never updated");
    
    // Warp forward another 15 days (30 days total from stake)
    _warpForward(15 days);
    
    // EXPLOIT: Attacker claims again
    vm.prank(attacker);
    token.claimReward(attacker);
    // Reward calculated from ORIGINAL lastUpdate (Day 0), not Day 15
    // So attacker gets 30-day reward, but already got 15-day reward earlier
    // Total received: 15 + 30 = 45 days of rewards for 30 days of staking!
    
    // lastUpdate STILL unchanged - can repeat infinitely
    (, uint256 lastUpdateFinal,) = _getStake(attacker);
    assertEq(lastUpdateFinal, lastUpdateInitial, "lastUpdate STILL never updated - can repeat");
    
    // Attacker can keep calling claimReward every few days
    // Each call pays out full period reward (not delta since last claim)
    // This drains the reward pool at accelerated rate
}
```

## Recommendation

1. **Reset `lastUpdate` after claiming rewards:**

```solidity
function claimReward(address _user) public returns (uint256) {
    Stake storage userStake = stakes[_user];
    if (userStake.amount == 0) return 0;
    
    uint256 reward = calculateReward(_user) + userStake.rewardDebt;
    
    if (reward + totalRewardsDistributed > balanceOf(address(this))) {
        reward = balanceOf(address(this)) - totalRewardsDistributed;
    }
    
    if (reward > 0) {
        totalRewardsDistributed += reward;
        userStake.rewardDebt = 0;
        userStake.lastUpdate = block.timestamp;  // ← ADD THIS
        transfer(_user, reward);
        emit RewardClaimed(_user, reward);
    }
    return reward;
}
```

2. **Restrict access to prevent third-party manipulation:**

```solidity
function claimReward() external returns (uint256) {  // Remove _user parameter
    Stake storage userStake = stakes[msg.sender];    // Use msg.sender only
    // ...
}
``` 


## [C-06] `stake()` Overwrites Existing Stake Amount Instead of Adding, Causing Permanent Token Loss. 

## Description

The `stake()` function overwrites `userStake.amount` with the new deposit instead of adding to it. When users attempt to increase their stake, their previous tokens become permanently trapped in the contract.

```solidity
function stake(address stakingToken, uint256 _amount) external {
    require(_amount > 0, "Amount must be greater than 0");
    Stake storage userStake = stakes[msg.sender];
    if (userStake.amount > 0) {
        userStake.rewardDebt += calculateReward(msg.sender);
    }
    IERC20(stakingToken).transferFrom(msg.sender, address(this), _amount);
    userStake.amount = _amount;           // ← BUG: Overwrites, should be +=
    userStake.lastUpdate = block.timestamp;
    emit Staked(msg.sender, _amount);
}
```

## Root Cause

Line `userStake.amount = _amount` replaces the existing stake with the new amount instead of using `userStake.amount += _amount` to accumulate deposits.

## Impact 

- Permanent token loss. 
-  No mechanism exists to recover trapped funds. 

```solidity
Alice stakes 10,000 tokens (Day 0)
Alice waits 29 days (almost full staking period)
Alice stakes 100 more tokens (Day 29)
  → userStake.amount = 100 (overwrites 10,000!)
  → userStake.lastUpdate = Day 29 (clock reset)
Alice withdraws
  → Receives 100 tokens
  → 10,000 tokens permanently locked
```

## Recommendation
Accumulate stake amounts instead of overwriting:

```solidity
function stake(address stakingToken, uint256 _amount) external {
    require(_amount > 0, "Amount must be greater than 0");
    Stake storage userStake = stakes[msg.sender];
    if (userStake.amount > 0) {
        userStake.rewardDebt += calculateReward(msg.sender);
    }
    IERC20(stakingToken).transferFrom(msg.sender, address(this), _amount);
    userStake.amount += _amount;          // ← FIX: Add to existing stake
    userStake.lastUpdate = block.timestamp;
    emit Staked(msg.sender, _amount);
}
```


## [C-07] `rewardRate` Is Always Zero Due to Integer Division, Causing Users to Receive Zero Rewards Indefinitely.


## Description

The `rewardRate` calculation in the constructor performs division before multiplication, causing integer truncation to zero. This permanently breaks all staking rewards and locks `30%` of the total supply in the contract forever.


```solidity
constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 totalSupply_,
    address feeReceiver_,
    address router
) {
    // ...
    uint256 ownerAmount = totalSupply_ * 70 / 100;      // 70% to owner
    uint256 rewardAmount = totalSupply_ - ownerAmount;  // 30% for rewards
    _mint(owner(), ownerAmount);
    _mint(address(this), rewardAmount);
    stakingPeriod = 30 days;
    rewardRate = ((rewardAmount) / ownerAmount) / stakingPeriod;  // ← BUG: Always 0
    // ...
}
```
## Root Cause

Solidity uses integer division with no decimals. The calculation order causes truncation:


```solidity
Given totalSupply = 1,000,000 tokens:

ownerAmount  = 1,000,000 * 70 / 100 = 700,000
rewardAmount = 1,000,000 - 700,000  = 300,000

Step 1: rewardAmount / ownerAmount
        = 300,000 / 700,000
        = 0.428...
        = 0  ← Integer division truncates to 0!

Step 2: 0 / stakingPeriod
        = 0 / 2,592,000
        = 0

rewardRate = 0 (always, for any totalSupply)
```
- Since `rewardAmount < ownerAmount (30% < 70%)`, the first division always yields 0.


## Impact 

1. zero Rewards Forever, No matter how long users stake or how much they stake, `reward = amount * duration * 0 = 0`

2. The `rewardAmount` minted to the contract can never be distributed or recovered - dead tokens.

3. user loss, Users lock tokens expecting rewards, receive nothing. 

## Recommendation

Use scaled math to preserve precision - multiply before dividing:

```solidity
// In constructor:
uint256 PRECISION = 1e18;
rewardRate = (rewardAmount * PRECISION / ownerAmount) / stakingPeriod;

// In calculateReward:
function calculateReward(address _user) public view returns (uint256) {
    Stake storage userStake = stakes[_user];
    if (userStake.amount == 0) return 0;
    uint256 stakingDuration = block.timestamp - userStake.lastUpdate;
    if (stakingDuration > stakingPeriod) {
        stakingDuration = stakingPeriod;
    }
    uint256 reward = (userStake.amount * stakingDuration * rewardRate) / PRECISION;  // Scale back
    return reward;
}
```


## [C-08] `stake()` Accepts Arbitrary Token Address, Enabling Complete Reward Pool Theft With Worthless Tokens.


## Description 

The `stake()` function accepts a `stakingToken` parameter that is never validated against the actual Token contract address. An attacker can pass any ERC20 token address (including a worthless token they deploy), get credited for staking, and then withdraw real Token tokens from the contract's reward pool.


## Vulnerable Code 

```solidity
function stake(address stakingToken, uint256 _amount) external {
    require(_amount > 0, "Amount must be greater than 0");
    Stake storage userStake = stakes[msg.sender];
    if (userStake.amount > 0) {
        userStake.rewardDebt += calculateReward(msg.sender);
    }
    IERC20(stakingToken).transferFrom(msg.sender, address(this), _amount);  // ← Accepts ANY token
    userStake.amount = _amount;           // ← Credits as if it were the real Token
    userStake.lastUpdate = block.timestamp;
    emit Staked(msg.sender, _amount);
}
```

## Root Cause

The function has no validation that `stakingToken == address(this)`. It blindly:
- Pulls tokens from any ERC20 contract the caller specifies
- Credits `userStake.amount` with that value
- Later, `withdraw()` and `claimReward()` pay out using the real Token via `transfer()`

## Impact
Complete Reward Pool Theft, Look at this scenario

```solidity
1. Attacker deploys FakeToken (costs ~0.01 ETH gas)
2. Attacker mints 1,000,000 FakeTokens to self (free)
3. Attacker approves Token contract to spend FakeTokens
4. Attacker calls stake(FakeToken, 1_000_000e18)
   → FakeTokens transferred to Token contract
   → stakes[attacker].amount = 1,000,000e18 (credited as real!)
5. Attacker calls withdraw()
   → withdraw() calls transfer(attacker, 1_000_000e18)
   → Attacker receives 1,000,000 real Token tokens
6. Contract drained. All stakers' rewards stolen.
```

- The entire contract balance (30% of total supply allocated as rewards = 300,000 tokens for a 1M supply).



## Recommendation
Validate that only the native Token can be staked. 







## [H-01] Double Deduction in `_transfer()` Function Overcharges Senders By Fees Plus Full Amount Leading To Unintended Fund Losses. 

## Description

The `_transfer() function` deducts fees from the `sender's balance`, then deducts the full transfer amount again. This causes senders to lose `amount + fees` tokens instead of just `amount`, resulting in systematic overcharging on every transfer.

## Vulnerable Code

```solidity
function _transfer(address sender, address recipient, uint256 amount) internal virtual {
    // ... swap logic ...
    
    uint256 fees = 0;
    if(takeFee){
        fees = amount * fee / 100;
        
        if(fees > 0){
            _balances[sender] = _balances[sender].sub(fees, "...");      // FIRST deduction
            _balances[address(this)] = _balances[address(this)] + fees;   
            emit Transfer(sender, address(this), fees); 
        }
    }
    _balances[sender] = _balances[sender].sub(amount, "...");            // SECOND deduction
    _balances[recipient] = _balances[recipient] + amount;   
    emit Transfer(sender, recipient, amount);
}
```
- This is what should happen: 

```solidity
User wants to send 100 tokens
├── Fees (3%) taken FROM the 100 = 3 tokens
├── Recipient gets: 100 - 3 = 97 tokens
├── Contract gets: 3 tokens
└── User loses: 100 tokens total
```

- What the code is actually doing: 

```solidity 
User wants to send 100 tokens
├── Fees (3%) taken FROM USER'S BALANCE = 3 tokens
├── Then FULL 100 taken FROM USER'S BALANCE = 100 tokens
├── Recipient gets: 100 tokens (full amount!)
├── Contract gets: 3 tokens
└── User loses: 103 tokens total (OVERCHARGED!)
```

## Root cause

The function performs two separate deductions from the sender: 
- `_balances[sender].sub(fees)` deducts `3 tokens`. 
- `_balances[sender].sub(amount)` deducts 100 tokens. 

- Total deducted: 103 tokens.

The intended behavior is for the sender to lose only amount (100 tokens), with fees taken from that amount. Instead, fees are deducted separately, causing the sender to pay `amount + fees`. 

## Impact

1. Systematic Fund Loss on Every Transfer, For a `transfer of 100 tokens with 3% fee`: 

Sender expected to lose: 100 tokens Sender actually loses: 103 tokens Recipient expected to receive: 97 tokens Recipient actually receives: 100 tokens Contract receives: 3 tokens.


## Proof of code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Test} from "forge-std/Test.sol";
import {Token, IERC20} from "../src/Token.sol";

// Mock Uniswap V2 Router
contract MockUniswapV2Router {
    address public immutable WETH_ADDRESS;
    address public immutable FACTORY_ADDRESS;

    constructor() {
        WETH_ADDRESS = address(new MockWETH());
        FACTORY_ADDRESS = address(new MockUniswapV2Factory());
    }

    function factory() external view returns (address) {
        return FACTORY_ADDRESS;
    }

    function WETH() external view returns (address) {
        return WETH_ADDRESS;
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        // Mock: just pretend the swap happened
    }
}

// Mock WETH
contract MockWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
}

// Mock Uniswap V2 Factory
contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public pairs;
    
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        pair = address(new MockUniswapV2Pair());
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;
        return pair;
    }

    function getPair(address tokenA, address tokenB) external view returns (address) {
        return pairs[tokenA][tokenB];
    }
}

// Mock Uniswap V2 Pair
contract MockUniswapV2Pair {
    // Empty mock pair
}

contract TokenTest is Test {
    // ============ Contracts ============
    Token public token;
    MockUniswapV2Router public router;

    // ============ Actors ============
    address public owner;
    address public feeReceiver;
    address public alice;
    address public bob;
    address public attacker;

    // ============ Token Parameters ============
    string constant NAME = "Test Token";
    string constant SYMBOL = "TEST";
    uint8 constant DECIMALS = 18;
    uint256 constant TOTAL_SUPPLY = 1_000_000 * 10**18;

    // ============ Setup ============
    function setUp() public {
        // Create actors
        owner = makeAddr("owner");
        feeReceiver = makeAddr("feeReceiver");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        attacker = makeAddr("attacker");

        // Fund actors with ETH for gas
        vm.deal(owner, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(attacker, 100 ether);

        // Deploy mock router
        router = new MockUniswapV2Router();

        // Deploy token as owner
        vm.startPrank(owner);
        token = new Token(
            NAME,
            SYMBOL,
            DECIMALS,
            TOTAL_SUPPLY,
            feeReceiver,
            address(router)
        );
        vm.stopPrank();
    }

    // ============ Helper Functions ============
    
    /// @notice Transfer tokens from owner to a user
    function _fundUser(address user, uint256 amount) internal {
        vm.prank(owner);
        token.transfer(user, amount);
    }

    /// @notice Approve and stake tokens for a user
    function _stakeAs(address user, uint256 amount) internal {
        vm.startPrank(user);
        token.approve(address(token), amount);
        token.stake(address(token), amount);
        vm.stopPrank();
    }

    /// @notice Warp time forward
    function _warpForward(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    /// @notice Get user's stake info
    function _getStake(address user) internal view returns (uint256 amount, uint256 lastUpdate, uint256 rewardDebt) {
        (amount, lastUpdate, rewardDebt) = token.stakes(user);
    }

    
    /// @notice PoC: Double Deduction Bug in _transfer()
    /// @dev Sender is charged fees + full amount instead of just amount
    function test_POC_DoubleDeduction_Transfer() public {
        uint256 transferAmount = 100 * 10**18;
        uint256 feePercent = 3; // 3% fee
        uint256 expectedFee = (transferAmount * feePercent) / 100; // 3 tokens
        
        // Fund alice (non-excluded address)
        _fundUser(alice, transferAmount * 2); // Give 200 tokens
        
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 contractBalanceBefore = token.balanceOf(address(token));
        
        // Alice transfers 100 tokens to Bob
        vm.prank(alice);
        token.transfer(bob, transferAmount);
        
        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalanceAfter = token.balanceOf(bob);
        uint256 contractBalanceAfter = token.balanceOf(address(token));
        
        // Calculate actual changes
        uint256 aliceLost = aliceBalanceBefore - aliceBalanceAfter;
        uint256 bobGained = bobBalanceAfter - bobBalanceBefore;
        uint256 contractGained = contractBalanceAfter - contractBalanceBefore;
        
        // === BUG PROOF ===
        // EXPECTED: Alice loses 100, Bob gets 97, Contract gets 3
        // ACTUAL:   Alice loses 103, Bob gets 100, Contract gets 3
        
        // Alice lost MORE than she transferred (double deduction!)
        assertEq(aliceLost, transferAmount + expectedFee, "BUG: Alice charged amount + fees!");
        
        // Bob received FULL amount (should receive amount - fees)
        assertEq(bobGained, transferAmount, "BUG: Bob got full amount, not amount - fees!");
        
        // Contract got the fees
        assertEq(contractGained, expectedFee, "Contract received fees");
    }
}
```

## Recommendation
- Deduct fees from the transfer amount, not separately.


## [H-02] Zero Slippage Protection in `swapTokensForEth()` causes attackers to drain protocol fee revenue by sandwich attacks.

## Description

The `swapTokensForEth()` function swaps accumulated fee tokens for ETH with `amountOutMin = 0`, accepting any output amount. This allows MEV bots to sandwich the swap transaction, extracting nearly all value from protocol fees.

```solidity
function swapTokensForEth(uint256 tokenAmount) private {
    address[] memory path = new address[](2);
    path[0] = uniswapV2Router.WETH();
    path[1] = address(this);
    
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokenAmount,
        0,                      // ← BUG: amountOutMin = 0, accepts ANY output
        path,
        feeReceiver,
        block.timestamp         // ← Also this is weak: deadline offers no protection
    );
}
```

## Root Cause. 

Two issues compound to enable the attack:
1. `amountOutMin = 0`: The swap will succeed even if it receives 0.0001 ETH for 1000 tokens
2. `deadline = block.timestamp`: No protection against delayed execution; always passes. 

## Impact

- Protocol revenue loss


## Recommendation
- Add proper slippage protection using price oracle. 




## [H-03] `_transfer()` Auto-Swap Consumes Staking Rewards Due to Lack of Fee and Reward Balance Separation, Causing Reward Pool drainage. 

## Description

`Token.sol` does not separate fee tokens from staking reward tokens in its balance. Both are stored in balanceOf(address(this)). When the auto-swap mechanism triggers during transfers, it indiscriminately swaps tokens from this combined pool, draining the staking rewards meant for users.


## Root Cause
In the constructor, `30% of total supply` is minted to the contract as staking rewards:

```solidity
uint256 rewardAmount = totalSupply_ - ownerAmount;
_mint(address(this), rewardAmount);
```

- Fees from transfers are also added to the same balance:

```solidity
_balances[address(this)] = _balances[address(this)] + fees;
```

- When `_transfer` triggers a swap, it pulls from this combined pool:

```solidity
bool canSwap = contractTokenBalance >= swapTokensAtAmount;
if (canSwap && ...) {
    swapTokensForEth(swapTokensAtAmount);  // Swaps 1,000 tokens regardless of source
}
```
There is no accounting to track which tokens are fees versus rewards.


## Impact
1. Each qualifying transfer drains the reward pool. 

2. With 300,000 tokens allocated for rewards, the pool is exhausted after approximately 309 qualifying transfers. Stakers who deposit later receive reduced or zero rewards, despite the protocol promising staking yields.



## poc

I have to add a poc here so you can understand the bug well: 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Test} from "forge-std/Test.sol";
import {Token, IERC20} from "../src/Token.sol";

// Mock Uniswap V2 Router - REALISTIC: Actually removes tokens during swap
contract MockUniswapV2Router {
    address public immutable WETH_ADDRESS;
    address public immutable FACTORY_ADDRESS;

    constructor() {
        WETH_ADDRESS = address(new MockWETH());
        FACTORY_ADDRESS = address(new MockUniswapV2Factory());
    }

    function factory() external view returns (address) {
        return FACTORY_ADDRESS;
    }

    function WETH() external view returns (address) {
        return WETH_ADDRESS;
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        // REALISTIC: Router pulls tokens from caller (the Token contract)
        // This simulates real Uniswap behavior where tokens leave the contract
        IERC20 token = IERC20(msg.sender);
        token.transferFrom(msg.sender, address(this), amountIn);
    }
}

// Mock WETH
contract MockWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
}

// Mock Uniswap V2 Factory
contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public pairs;
    
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        pair = address(new MockUniswapV2Pair());
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;
        return pair;
    }

    function getPair(address tokenA, address tokenB) external view returns (address) {
        return pairs[tokenA][tokenB];
    }
}

// Mock Uniswap V2 Pair
contract MockUniswapV2Pair {
    // Empty mock pair
}

contract TokenTest is Test {
    // ============ Contracts ============
    Token public token;
    MockUniswapV2Router public router;

    // ============ Actors ============
    address public owner;
    address public feeReceiver;
    address public alice;
    address public bob;
    address public attacker;

    // ============ Token Parameters ============
    string constant NAME = "Test Token";
    string constant SYMBOL = "TEST";
    uint8 constant DECIMALS = 18;
    uint256 constant TOTAL_SUPPLY = 1_000_000 * 10**18;

    // ============ Setup ============
    function setUp() public {
        // Create actors
        owner = makeAddr("owner");
        feeReceiver = makeAddr("feeReceiver");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        attacker = makeAddr("attacker");

        // Fund actors with ETH for gas
        vm.deal(owner, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(attacker, 100 ether);

        // Deploy mock router
        router = new MockUniswapV2Router();

        // Deploy token as owner
        vm.startPrank(owner);
        token = new Token(
            NAME,
            SYMBOL,
            DECIMALS,
            TOTAL_SUPPLY,
            feeReceiver,
            address(router)
        );
        vm.stopPrank();
    }

    // ============ Helper Functions ============
    
    /// @notice Transfer tokens from owner to a user
    function _fundUser(address user, uint256 amount) internal {
        vm.prank(owner);
        token.transfer(user, amount);
    }

    /// @notice Approve and stake tokens for a user
    function _stakeAs(address user, uint256 amount) internal {
        vm.startPrank(user);
        token.approve(address(token), amount);
        token.stake(address(token), amount);
        vm.stopPrank();
    }

    /// @notice Warp time forward
    function _warpForward(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    /// @notice Get user's stake info
    function _getStake(address user) internal view returns (uint256 amount, uint256 lastUpdate, uint256 rewardDebt) {
        (amount, lastUpdate, rewardDebt) = token.stakes(user);
    }



    /// @notice PoC: Fee swaps drain the staking reward pool
    /// @dev Contract doesn't separate fees from rewards - swaps eat into reward tokens
    function test_POC_FeeSwapsDrainRewardPool() public {
        // ============ INITIAL STATE ============
        // Contract holds 30% of total supply as staking rewards = 300,000 tokens
        uint256 initialContractBalance = token.balanceOf(address(token));
        uint256 expectedRewards = TOTAL_SUPPLY * 30 / 100;
        uint256 swapThreshold = token.swapTokensAtAmount(); // 0.1% = 1,000 tokens
        
        assertEq(initialContractBalance, expectedRewards, "Initial: 30% in contract for rewards");
        
        // ============ SETUP ============
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        
        _fundUser(user1, 10_000 * 10**18);
        
        // ============ SINGLE TRANSFER PROOF ============
        // Transfer 1,000 tokens between non-excluded users
        // Fee: 1,000 * 3% = 30 tokens (added to contract)
        // Swap: 1,000 tokens (removed from contract)
        // Net: -970 tokens = REWARD POOL DRAINED
        
        uint256 transferAmount = 1_000 * 10**18;
        uint256 expectedFee = transferAmount * 3 / 100; // 30 tokens
        
        uint256 balanceBefore = token.balanceOf(address(token));
        
        vm.prank(user1);
        token.transfer(user2, transferAmount);
        
        uint256 balanceAfter = token.balanceOf(address(token));
        
        // ============ MATHEMATICAL PROOF ============
        // Before: 300,000 tokens
        // Fee added: +30 tokens  
        // Swap removed: -1,000 tokens
        // After: 299,030 tokens
        //
        // Net change: 299,030 - 300,000 = -970 tokens (REWARD POOL DRAINED!)
        
        uint256 netDrain = balanceBefore - balanceAfter; // How much balance decreased
        uint256 expectedDrain = swapThreshold - expectedFee; // 1000 - 30 = 970
        
        // ============ ASSERT: Bug drains 970 tokens from rewards ============
        assertEq(
            netDrain,
            expectedDrain,
            "BUG PROVEN: Each transfer drains (swapAmount - fee) from reward pool"
        );
        
        // Verify balance actually decreased (rewards consumed)
        assertTrue(
            balanceAfter < balanceBefore,
            "BUG PROVEN: Contract balance decreased - rewards drained by swap"
        );
        
        // Verify the swap took from rewards, not just fees
        // The swap removed 1000, but only 30 were fees = 970 from rewards
        assertEq(
            balanceAfter,
            balanceBefore - netDrain, // 300,000 - 970 = 299,030
            "Balance correctly reflects reward drain"
        );
        
        // ============ IMPACT CALCULATION ============
        // With 300,000 reward tokens and 970 drained per qualifying transfer:
        // Pool exhausted after: 300,000 / 970 = ~309 transfers
        // That's just ~309 user-to-user transfers to drain ALL staking rewards!
    }
}
```
## Recommendation
Track fees and rewards separately.

```solidity
uint256 public feeBalance;
uint256 public rewardBalance;
```

- Only swap from feeBalance when it exceeds the threshold. Pay staking rewards only from rewardBalance.


## [H-04] `claimReward()` Reverts When `Contract Balance Falls Below totalRewardsDistributed`, Causing Permanent DoS.

## Description 

The `claimReward()` function attempts to cap reward payouts by calculating the "remaining" distributable balance as `balanceOf(address(this)) - totalRewardsDistributed`. 

In Solidity 0.8.16, when `balanceOf(address(this)) < totalRewardsDistributed` (due to over-distribution from repeated claims or external balance reductions), this subtraction underflows and reverts with a panic error. Once triggered, all future calls to `claimReward()` and `withdraw()` permanently fail, trapping user stakes and halting the reward system.


## Vulnerable Code

```solidity
function claimReward(address _user) public returns (uint256) {
    Stake storage userStake = stakes[_user];
    if (userStake.amount == 0) return 0;
    
    uint256 reward = calculateReward(_user) + userStake.rewardDebt;
    
    if (reward + totalRewardsDistributed > balanceOf(address(this))) {
        reward = balanceOf(address(this)) - totalRewardsDistributed;  // ← UNDERFLOW REVERT
    }
    
    if (reward > 0) {
        totalRewardsDistributed += reward;
        userStake.rewardDebt = 0;
        transfer(_user, reward);
        emit RewardClaimed(_user, reward);
    }
    return reward;
}
```



## Root Cause

The subtraction `balanceOf(address(this)) - totalRewardsDistributed` assumes the contract's token balance is always greater than or equal to the cumulative rewards paid out. This assumption fails when:


1. Over-Distribution via Missing `lastUpdate Reset (C-05)`: Each`claimReward()` recalculates rewards from the original stake timestamp, paying out overlapping periods. A user staking 30 days but claiming at day 15 and day 30 receives 15 + 30 = 45 days of rewards for 30 days of staking. This inflates `totalRewardsDistributed` beyond what the initial reward pool can cover.


2. External Balance Reduction: Owner calling `burn(address(this), amount)` or manual transfers reduce contract balance independent of reward accounting.

3. Anyone can call `claimReward(victim)` to force-trigger claims, accelerating the over-distribution race.


Once `totalRewardsDistributed > balanceOf(address(this))`, Solidity 0.8.16's built-in underflow protection reverts the subtraction. No `unchecked {}` block bypasses this—it's a VM-enforced panic (error code 0x11).


## Impact 

1. Permanent Denial of Service
-`claimReward()` reverts for all users, not just the triggering user. 
- `withdraw()` internally calls `claimReward()`, so withdrawals also DoS'd. 
- No admin recovery function exists
- No way to reset `totalRewardsDistributed`
- Staked tokens permanently locked in contract


## Recommendation
Replace the unsafe subtraction with an explicit zero-floor check.

```solidity
function claimReward(address _user) public returns (uint256) {
    Stake storage userStake = stakes[_user];
    if (userStake.amount == 0) return 0;
    
    uint256 reward = calculateReward(_user) + userStake.rewardDebt;
    
    if (reward + totalRewardsDistributed > balanceOf(address(this))) {
        // FIX: Prevent underflow by checking before subtraction
        if (balanceOf(address(this)) > totalRewardsDistributed) {
            reward = balanceOf(address(this)) - totalRewardsDistributed;
        } else {
            reward = 0;  // No rewards left - graceful handling instead of revert
        }
    }
    
    if (reward > 0) {
        totalRewardsDistributed += reward;
        userStake.rewardDebt = 0;
        userStake.lastUpdate = block.timestamp; 
        _transfer(address(this), _user, reward); 
        emit RewardClaimed(_user, reward);
    }
    return reward;
}
```







## [M-01] `renounceOwnership()` Sets Owner to Caller Instead of Zero Address, Preventing True Renouncement. 

## Description

The `renounceOwnership()` function is intended to permanently give up ownership, making the contract ownerless. However, it incorrectly sets the owner back to the caller (the current owner) instead of address(0).

```solidity
function renounceOwnership() public virtual onlyOwner {
    _setOwner(_msgSender());  // ← BUG: Sets owner to caller, not address(0)
}
```
- Compare to OpenZeppelin's correct implementation:

```solidity
function renounceOwnership() public virtual onlyOwner {
    _setOwner(address(0));    // ← Correct: Sets owner to zero address
}
```

## Root Cause
The function calls `_setOwner(_msgSender())` which sets `_owner = msg.sender`. Since msg.sender is already the owner (due to onlyOwner modifier), this is a no-op that leaves ownership unchanged. 

## Recommendation
Set owner to zero address to truly renounce:

```solidity
function renounceOwnership() public virtual onlyOwner {
    _setOwner(address(0));  // ← FIX: Renounce to zero address
}
```

## [M-02] `withdraw()` Allows Early Withdrawal Before Staking Period Ends, Enabling Reward Gaming Without Token Lock Commitment. 

## Description

The `withdraw()` function in the `Token.sol` allows users to withdraw their staked tokens at any time without verifying that the staking period (30 days) has completed. This breaks the purpose of having a stakingPeriod variable and allows users to game the reward system without any lock-up commitment.

```solidity
function withdraw() external {
    Stake memory userStake = stakes[msg.sender];
    require(userStake.amount > 0, "No stake to withdraw");
    uint256 reward = claimReward(msg.sender);
    uint256 stakedAmount = userStake.amount;
    userStake.amount = 0;
    userStake.lastUpdate = 0;
    transfer(msg.sender, stakedAmount);
    emit Withdrawn(msg.sender, stakedAmount, reward);
    // ← No check: block.timestamp >= lastUpdate + stakingPeriod
}
```

## Root Cause
The function is missing a time-lock validation before allowing withdrawal:

```solidity
require(block.timestamp >= userStake.lastUpdate + stakingPeriod, "Staking period not ended");
```

Despite the contract defining stakingPeriod = 30 days, this value is never enforced during withdrawal.


## Impact 

1. Reward Gaming: Users can:
- Stake large amounts
- Claim pro-rata rewards immediately
- Withdraw and move funds elsewhere
- Repeat when convenient. 

## Recommendation
Add staking period validation in `withdraw()`:

```solidity
function withdraw() external {
    Stake storage userStake = stakes[msg.sender];
    require(userStake.amount > 0, "No stake to withdraw");
    require(
        block.timestamp >= userStake.lastUpdate + stakingPeriod,
        "Staking period not ended"
    );
    
    uint256 reward = claimReward(msg.sender);
    uint256 stakedAmount = userStake.amount;
    
    userStake.amount = 0;
    userStake.lastUpdate = 0;
    
    _transfer(address(this), msg.sender, stakedAmount);
    emit Withdrawn(msg.sender, stakedAmount, reward);
}
```


## [L-01] `_transfer()` with `amount=0` Does Not Return Early, Causing Duplicate Events and Wasted Gas.


## Description
The `_transfer()` function checks for zero-amount transfers and emits a Transfer event, but fails to return after doing so. Execution continues through the rest of the function, resulting in duplicate Transfer events, unnecessary balance operations, and wasted gas.

## Vulnerable Code

```solidity
function _transfer(
    address sender,
    address recipient,
    uint256 amount
) internal virtual {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");
    
    if(amount == 0) {
        emit Transfer(sender, recipient, amount);  // ← First event emitted
    }                                               // ← NO RETURN! Execution continues...
 
    // ... swap logic executes ...
    
    // ... fee logic executes ...
    
    _balances[sender] = _balances[sender].sub(amount, "...");  // sub(0) - passes but wasteful
    _balances[recipient] = _balances[recipient] + amount;       // +0 - passes but wasteful
    emit Transfer(sender, recipient, amount);                   // ← DUPLICATE event emitted!
}
```

## Root Cause
The conditional block for `amount == 0` lacks a return statement. 

## Impact
- Every zero-amount transfer emits two identical Transfer(sender, recipient, 0) events

## Recommendation
Add early return after handling zero-amount transfers. 