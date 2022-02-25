//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./HotDog.sol";

contract Freezer is ERC20("Staked HotDog", "sHOTDOG"), Ownable, Pausable {
    using SafeERC20 for HotDog;
    using SafeMath for uint256;

    uint256 public constant DELAYED_UNSTAKE_LOCKUP_PERIOD = 2 days;
    uint256 public constant DELAYED_UNSTAKE_BURN_PERCENT = 10;
    uint256 public constant QUICK_UNSTAKE_CONTRIBUTION_PERCENT = 50;
    uint256 public constant QUICK_UNSTAKE_BURN_PERCENT = 25;

    HotDog public hotDog;
    uint256 public frozenHotDog; // HOTDOG pending withdrawal

    mapping(address => uint256) public unlockAmounts;
    mapping(address => uint256) public unlockTimestamps;

    uint256 public stakeTime;

    constructor(HotDog _hotDog) {
        hotDog = _hotDog;
    }

    // Views

    function hotDogBalance() public view returns (uint256 balance) {
        return hotDog.balanceOf(address(this)) - frozenHotDog;
    }

    function _unstakeOutput(uint256 _share)
        internal
        view
        returns (uint256 output)
    {
        uint256 totalShares = totalSupply();
        return _share.mul(hotDogBalance()).div(totalShares);
    }

    // External

    function stake(uint256 _amount) external whenNotPaused {
        require(stakeStarted(), "You can't stake yet");
        uint256 totalShares = totalSupply();
        // If no sHOTDOG exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || hotDogBalance() == 0) {
            _mint(_msgSender(), _amount);
        } else {
            uint256 share = _amount.mul(totalShares).div(hotDogBalance());
            _mint(_msgSender(), share);
        }

        hotDog.transferToFreezer(_msgSender(), _amount);
    }

    function quickUnstake(uint256 _share) external whenNotPaused {
        // QUICK_UNSTAKE_CONTRIBUTION_PERCENT of the claimable HOTDOG will remain in the freezer
        // the rest is transfered to the staker
        uint256 unstakeOutput = _unstakeOutput(_share);
        uint256 output = unstakeOutput
            .mul(100 - QUICK_UNSTAKE_CONTRIBUTION_PERCENT)
            .div(100);
        // QUICK_UNSTAKE_BURN_PERCENT of the claimable HOTDOG is burned
        uint256 amountSpoiled = unstakeOutput
            .mul(QUICK_UNSTAKE_BURN_PERCENT)
            .div(100);

        // burn staker's share
        _burn(_msgSender(), _share);

        hotDog.burn(address(this), amountSpoiled);
        hotDog.safeTransfer(_msgSender(), output);
    }

    /**
     * @dev _share argument specified in sHOTDOG
     */
    function prepareDelayedUnstake(uint256 _share) external whenNotPaused {
        // calculate output and burn staker's share
        uint256 output = _unstakeOutput(_share); //converts sHOTDOG values to hotDog
        _burn(_msgSender(), _share);

        // calculate and burn amount of output spoiled
        uint256 amountSpoiled = output.mul(DELAYED_UNSTAKE_BURN_PERCENT).div(
            100
        );

        // remove amountSpoiled from output
        output -= amountSpoiled;

        unlockAmounts[_msgSender()] += output;
        unlockTimestamps[_msgSender()] =
            block.timestamp +
            DELAYED_UNSTAKE_LOCKUP_PERIOD;
        frozenHotDog += output;

        hotDog.burn(address(this), amountSpoiled);
    }

    /**
     * @dev argument specified in HOTDOG, not sHOTDOG
     */
    function claimDelayedUnstake(uint256 _amount) external whenNotPaused {
        require(
            block.timestamp >= unlockTimestamps[_msgSender()],
            "HOTDOG not yet unlocked"
        );
        require(
            _amount <= unlockAmounts[_msgSender()],
            "insufficient locked balance"
        );

        // deduct from unlocked
        unlockAmounts[_msgSender()] -= _amount;

        frozenHotDog -= _amount;

        // transfer claim
        hotDog.safeTransfer(_msgSender(), _amount);
    }

    // Admin

    function stakeStarted() public view returns (bool) {
        return stakeTime != 0 && block.timestamp >= stakeTime;
    }

    function setStakeStartTime(uint256 _startTime) external onlyOwner {
        require(
            _startTime >= block.timestamp,
            "startTime cannot be in the past"
        );
        require(!stakeStarted(), "staking already started");
        stakeTime = _startTime;
    }
}
