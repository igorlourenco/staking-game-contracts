//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./FoodTruck.sol";
import "./Upgrade.sol";
import "./HotDog.sol";
import "./HotDoggeriaProgression.sol";

contract HotDoggeria is HotDoggeriaProgression, ReentrancyGuard {
    using SafeMath for uint256;

    // Constants
    uint256 public constant YIELD_PPS = 16666666666666667; // HotDog cooked per second per unit of yield
    uint256 public constant CLAIM_HOTDOG_CONTRIBUTION_PERCENTAGE = 10;
    uint256 public constant CLAIM_HOTDOG_BURN_PERCENTAGE = 10;
    uint256 public constant MAX_FATIGUE = 100000000000000;

    uint256 public startTime;

    // Staking

    struct StakedFoodTruck {
        address owner;
        uint256 tokenId;
        uint256 startTimestamp;
        bool staked;
    }

    struct StakedFoodTruckInfo {
        uint256 foodTruckId;
        uint256 upgradeId;
        uint256 foodTruckHDPM;
        uint256 upgradeHDPM;
        uint256 hotDog;
        uint256 fatigue;
        uint256 timeUntilFatigued;
    }

    mapping(uint256 => StakedFoodTruck) public stakedFoodTrucks; // tokenId => StakedFoodTruck
    mapping(address => mapping(uint256 => uint256))
        private ownedFoodTruckStakes; // (address, index) => tokenid
    mapping(uint256 => uint256) private ownedFoodTruckStakesIndex; // tokenId => index in its owner's stake list
    mapping(address => uint256) public ownedFoodTruckStakesBalance; // address => stake count

    mapping(address => uint256) public fatiguePerMinute; // address => fatigue per minute in the hot doggeria
    mapping(uint256 => uint256) private foodTruckFatigue; // tokenId => fatigue
    mapping(uint256 => uint256) private foodTruckHotDog; // tokenId => hotDog

    mapping(address => uint256[2]) private numberOfFoodTrucks; // address => [number of regular food trucks, number of master food trucks]
    mapping(address => uint256) private totalHDPM; // address => total HDPM

    struct StakedUpgrade {
        address owner;
        uint256 tokenId;
        bool staked;
    }

    mapping(uint256 => StakedUpgrade) public stakedUpgrades; // tokenId => StakedUpgrade
    mapping(address => mapping(uint256 => uint256)) private ownedUpgradeStakes; // (address, index) => tokenid
    mapping(uint256 => uint256) private ownedUpgradeStakesIndex; // tokenId => index in its owner's stake list
    mapping(address => uint256) public ownedUpgradeStakesBalance; // address => stake count

    // Fatigue cooldowns

    struct RestingFoodTruck {
        address owner;
        uint256 tokenId;
        uint256 endTimestamp;
        bool present;
    }

    struct RestingFoodTruckInfo {
        uint256 tokenId;
        uint256 endTimestamp;
    }

    mapping(uint256 => RestingFoodTruck) public restingFoodTrucks; // tokenId => RestingFoodTruck
    mapping(address => mapping(uint256 => uint256))
        private ownedRestingFoodTrucks; // (user, index) => resting food truck id
    mapping(uint256 => uint256) private restingFoodTrucksIndex; // tokenId => index in its owner's cooldown list
    mapping(address => uint256) public restingFoodTrucksBalance; // address => cooldown count

    // Var

    FoodTruck public foodTruck;
    Upgrade public upgrade;
    HotDog public hotDog;
    address public freezerAddress;

    constructor(
        FoodTruck _foodTruck,
        Upgrade _upgrade,
        HotDog _hotDog,
        Juice _juice,
        address _freezerAddress
    ) HotDoggeriaProgression(_juice) {
        foodTruck = _foodTruck;
        upgrade = _upgrade;
        hotDog = _hotDog;
        freezerAddress = _freezerAddress;
    }

    // Views

    function _getUpgradeStakedForFoodTruck(address _owner, uint256 _foodTruckId)
        internal
        view
        returns (uint256)
    {
        uint256 index = ownedFoodTruckStakesIndex[_foodTruckId];
        return ownedUpgradeStakes[_owner][index];
    }

    function getFatiguePerMinuteWithModifier(address _owner)
        public
        view
        returns (uint256)
    {
        uint256 fatigueSkillModifier = getFatigueSkillModifier(_owner);
        return fatiguePerMinute[_owner].mul(fatigueSkillModifier).div(100);
    }

    function _getMasterFoodTruckNumber(address _owner)
        internal
        view
        returns (uint256)
    {
        return numberOfFoodTrucks[_owner][1];
    }

    /**
     * Returns the current Food Truck's fatigue
     */
    function getFatigueAccruedForFoodTruck(
        uint256 _tokenId,
        bool checkOwnership
    ) public view returns (uint256) {
        StakedFoodTruck memory stakedFoodTruck = stakedFoodTrucks[_tokenId];
        require(stakedFoodTruck.staked, "This token isn't staked");
        if (checkOwnership) {
            require(
                stakedFoodTruck.owner == _msgSender(),
                "You don't own this token"
            );
        }

        uint256 fatigue = ((block.timestamp - stakedFoodTruck.startTimestamp) *
            getFatiguePerMinuteWithModifier(stakedFoodTruck.owner)) / 60;
        fatigue += foodTruckFatigue[_tokenId];
        if (fatigue > MAX_FATIGUE) {
            fatigue = MAX_FATIGUE;
        }
        return fatigue;
    }

    /**
     * Returns the timestamp of when the Food Truck will be fatigued
     */
    function timeUntilFatiguedCalculation(
        uint256 _startTime,
        uint256 _fatigue,
        uint256 _fatiguePerMinute
    ) public pure returns (uint256) {
        return _startTime + (60 * (MAX_FATIGUE - _fatigue)) / _fatiguePerMinute;
    }

    function getTimeUntilFatigued(uint256 _tokenId, bool checkOwnership)
        public
        view
        returns (uint256)
    {
        StakedFoodTruck memory stakedFoodTruck = stakedFoodTrucks[_tokenId];
        require(stakedFoodTruck.staked, "This token isn't staked");
        if (checkOwnership) {
            require(
                stakedFoodTruck.owner == _msgSender(),
                "You don't own this token"
            );
        }
        return
            timeUntilFatiguedCalculation(
                stakedFoodTruck.startTimestamp,
                foodTruckFatigue[_tokenId],
                getFatiguePerMinuteWithModifier(stakedFoodTruck.owner)
            );
    }

    /**
     * Returns the timestamp of when the Food Truck will be fully rested
     */
    function restingTimeCalculation(
        uint256 _foodTruckType,
        uint256 _masterFoodTruckType,
        uint256 _fatigue
    ) public pure returns (uint256) {
        uint256 maxTime = 43200; //12*60*60
        if (_foodTruckType == _masterFoodTruckType) {
            maxTime = maxTime / 2; // master Food Trucks rest half of the time of regular Food Trucks
        }

        if (_fatigue > MAX_FATIGUE / 2) {
            return (maxTime * _fatigue) / MAX_FATIGUE;
        }

        return maxTime / 2; // minimum rest time is half of the maximum time
    }

    function getRestingTime(uint256 _tokenId, bool checkOwnership)
        public
        view
        returns (uint256)
    {
        StakedFoodTruck memory stakedFoodTruck = stakedFoodTrucks[_tokenId];
        require(stakedFoodTruck.staked, "This token isn't staked");
        if (checkOwnership) {
            require(
                stakedFoodTruck.owner == _msgSender(),
                "You don't own this token"
            );
        }

        return
            restingTimeCalculation(
                foodTruck.getType(_tokenId),
                foodTruck.GOLD_FOOD_TRUCK_TYPE(),
                getFatigueAccruedForFoodTruck(_tokenId, false)
            );
    }

    function getHotDogAccruedForManyFoodTrucks(uint256[] calldata _tokenIds)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory output = new uint256[](_tokenIds.length);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            output[i] = _getHotDogAccruedForFoodTruck(_tokenIds[i], false);
        }
        return output;
    }

    /**
     * Returns food trucks's hot dog from foodTruckHotDog mapping
     */
    function hotDogAccruedCalculation(
        uint256 _initialHotDog,
        uint256 _deltaTime,
        uint256 _hdpm,
        uint256 _modifier,
        uint256 _fatigue,
        uint256 _fatiguePerMinute
    ) public pure returns (uint256) {
        if (_fatigue >= MAX_FATIGUE) {
            return _initialHotDog;
        }

        uint256 a = (_deltaTime *
            _hdpm *
            YIELD_PPS *
            _modifier *
            (MAX_FATIGUE - _fatigue)) / (100 * MAX_FATIGUE);
        uint256 b = (_deltaTime *
            _deltaTime *
            _hdpm *
            YIELD_PPS *
            _modifier *
            _fatiguePerMinute) / (100 * 2 * 60 * MAX_FATIGUE);
        if (a > b) {
            return _initialHotDog + a - b;
        }

        return _initialHotDog;
    }

    function _getHotDogAccruedForFoodTruck(
        uint256 _tokenId,
        bool checkOwnership
    ) internal view returns (uint256) {
        StakedFoodTruck memory stakedFoodTruck = stakedFoodTrucks[_tokenId];
        address owner = stakedFoodTruck.owner;
        require(stakedFoodTruck.staked, "This token isn't staked");
        if (checkOwnership) {
            require(owner == _msgSender(), "You don't own this token");
        }

        // if Food TruckFatigue = MAX_FATIGUE it means that Food TruckHotDog already has the correct value for the HotDog, since it didn't produce HotDog since last update
        uint256 foodTruckFatigueLastUpdate = foodTruckFatigue[_tokenId];
        if (foodTruckFatigueLastUpdate == MAX_FATIGUE) {
            return foodTruckHotDog[_tokenId];
        }

        uint256 timeUntilFatigued = getTimeUntilFatigued(_tokenId, false);

        uint256 endTimestamp;
        if (block.timestamp >= timeUntilFatigued) {
            endTimestamp = timeUntilFatigued;
        } else {
            endTimestamp = block.timestamp;
        }

        uint256 hdpm = foodTruck.getYield(_tokenId);
        uint256 upgradeId = _getUpgradeStakedForFoodTruck(owner, _tokenId);

        if (upgradeId > 0) {
            hdpm += upgrade.getYield(upgradeId);
        }

        uint256 masterFoodTruckSkillModifier = getMasterFoodTruckSkillModifier(
            owner,
            _getMasterFoodTruckNumber(owner)
        );

        uint256 delta = endTimestamp - stakedFoodTruck.startTimestamp;

        return
            hotDogAccruedCalculation(
                foodTruckHotDog[_tokenId],
                delta,
                hdpm,
                masterFoodTruckSkillModifier,
                foodTruckFatigueLastUpdate,
                getFatiguePerMinuteWithModifier(owner)
            );
    }

    /**
     * Calculates the total HDPM staked for a pizzeria.
     * This will also be used in the fatiguePerMinute calculation
     */
    function getTotalHDPM(address _owner) public view returns (uint256) {
        return totalHDPM[_owner];
    }

    function gameStarted() public view returns (bool) {
        return startTime != 0 && block.timestamp >= startTime;
    }

    function setStartTime(uint256 _startTime) external onlyOwner {
        require(
            _startTime >= block.timestamp,
            "startTime cannot be in the past"
        );
        require(!gameStarted(), "game already started");
        startTime = _startTime;
    }

    /**
     * Updates the Fatigue per Minute
     * This function is called in _updateState
     */

    function fatiguePerMinuteCalculation(uint256 _hdpm)
        public
        pure
        returns (uint256)
    {
        // NOTE: fatiguePerMinute[_owner] = 8610000000 + 166000000  * totalHDPM[_owner] + -220833 * totalHDPM[_owner]* totalHDPM[_owner]  + 463 * totalHDPM[_owner]*totalHDPM[_owner]*totalHDPM[_owner];
        uint256 a = 463;
        uint256 b = 220833;
        uint256 c = 166000000;
        uint256 d = 8610000000;
        if (_hdpm == 0) {
            return d;
        }
        return d + c * _hdpm + a * _hdpm * _hdpm * _hdpm - b * _hdpm * _hdpm;
    }

    function _updatefatiguePerMinute(address _owner) internal {
        fatiguePerMinute[_owner] = fatiguePerMinuteCalculation(
            totalHDPM[_owner]
        );
    }

    /**
     * This function updates Food TruckHotDog and Food TruckFatigue mappings
     * Calls _updatefatiguePerMinute
     * Also updates startTimestamp for Food Trucks
     * It should be used whenever the HDPM changes
     */
    function _updateState(address _owner) internal {
        uint256 foodTruckBalance = ownedFoodTruckStakesBalance[_owner];
        for (uint256 i = 0; i < foodTruckBalance; i++) {
            uint256 tokenId = ownedFoodTruckStakes[_owner][i];
            StakedFoodTruck storage stakedFoodTruck = stakedFoodTrucks[tokenId];
            if (
                stakedFoodTruck.staked &&
                block.timestamp > stakedFoodTruck.startTimestamp
            ) {
                foodTruckHotDog[tokenId] = _getHotDogAccruedForFoodTruck(
                    tokenId,
                    false
                );

                foodTruckFatigue[tokenId] = getFatigueAccruedForFoodTruck(
                    tokenId,
                    false
                );

                stakedFoodTruck.startTimestamp = block.timestamp;
            }
        }
        _updatefatiguePerMinute(_owner);
    }

    //Claim
    function _claimHotDog(address _owner) internal {
        uint256 totalClaimed = 0;

        uint256 freezerSkillModifier = getFreezerSkillModifier(_owner);
        uint256 burnSkillModifier = getBurnSkillModifier(_owner);

        uint256 foodTruckBalance = ownedFoodTruckStakesBalance[_owner];

        for (uint256 i = 0; i < foodTruckBalance; i++) {
            uint256 foodTruckId = ownedFoodTruckStakes[_owner][i];

            totalClaimed += _getHotDogAccruedForFoodTruck(foodTruckId, true); // also checks that msg.sender owns this token

            delete foodTruckHotDog[foodTruckId];

            foodTruckFatigue[foodTruckId] = getFatigueAccruedForFoodTruck(
                foodTruckId,
                false
            ); // bug fix for fatigue

            stakedFoodTrucks[foodTruckId].startTimestamp = block.timestamp;
        }

        uint256 taxAmountFreezer = (totalClaimed *
            (CLAIM_HOTDOG_CONTRIBUTION_PERCENTAGE - freezerSkillModifier)) /
            100;
        uint256 taxAmountBurn = (totalClaimed *
            (CLAIM_HOTDOG_BURN_PERCENTAGE - burnSkillModifier)) / 100;

        totalClaimed = totalClaimed - taxAmountFreezer - taxAmountBurn;

        hotDog.mint(_msgSender(), totalClaimed);
        hotDog.mint(freezerAddress, taxAmountFreezer);
    }

    function claimHotDog() public nonReentrant whenNotPaused {
        address owner = _msgSender();
        _claimHotDog(owner);
    }

    function unstakeFoodTrucksAndUpgrades(
        uint256[] calldata _foodTruckIds,
        uint256[] calldata _upgradeIds
    ) public nonReentrant whenNotPaused {
        address owner = _msgSender();
        // Check 1:1 correspondency between Food Truck and upgrade
        require(
            ownedFoodTruckStakesBalance[owner] - _foodTruckIds.length >=
                ownedUpgradeStakesBalance[owner] - _upgradeIds.length,
            "Needs at least food truck for each tool"
        );

        _claimHotDog(owner);

        for (uint256 i = 0; i < _upgradeIds.length; i++) {
            //unstake upgrades
            uint256 upgradeId = _upgradeIds[i];

            require(
                stakedUpgrades[upgradeId].owner == owner,
                "You don't own this tool"
            );
            require(
                stakedUpgrades[upgradeId].staked,
                "Tool needs to be staked"
            );

            totalHDPM[owner] -= upgrade.getYield(upgradeId);
            upgrade.transferFrom(address(this), owner, upgradeId);

            _removeUpgrade(upgradeId);
        }

        for (uint256 i = 0; i < _foodTruckIds.length; i++) {
            //unstake Food Trucks
            uint256 foodTruckId = _foodTruckIds[i];

            require(
                stakedFoodTrucks[foodTruckId].owner == owner,
                "You don't own this token"
            );
            require(
                stakedFoodTrucks[foodTruckId].staked,
                "Chef needs to be staked"
            );

            if (
                foodTruck.getType(foodTruckId) ==
                foodTruck.GOLD_FOOD_TRUCK_TYPE()
            ) {
                numberOfFoodTrucks[owner][1]--;
            } else {
                numberOfFoodTrucks[owner][0]--;
            }

            totalHDPM[owner] -= foodTruck.getYield(foodTruckId);

            _moveFoodTruckToCooldown(foodTruckId);
        }

        _updateState(owner);
    }

    // Stake

    /**
     * This function updates stake Food Trucks and upgrades
     * The upgrades are paired with the Food Truck the upgrade will be applied
     */
    function stakeMany(
        uint256[] calldata _foodTruckIds,
        uint256[] calldata _upgradeIds
    ) public nonReentrant whenNotPaused {
        require(gameStarted(), "The game has not started");

        address owner = _msgSender();

        uint256 maxNumberFoodTrucks = getMaxNumberFoodTrucks(owner);
        uint256 foodTrucksAfterStaking = _foodTruckIds.length +
            numberOfFoodTrucks[owner][0] +
            numberOfFoodTrucks[owner][1];
        require(
            maxNumberFoodTrucks >= foodTrucksAfterStaking,
            "You can't stake that many Food Trucks"
        );

        // Check 1:1 correspondency between Food Truck and upgrade
        require(
            ownedFoodTruckStakesBalance[owner] + _foodTruckIds.length >=
                ownedUpgradeStakesBalance[owner] + _upgradeIds.length,
            "Needs at least Food Truck for each tool"
        );

        for (uint256 i = 0; i < _foodTruckIds.length; i++) {
            //stakes Food Truck
            uint256 foodTruckId = _foodTruckIds[i];

            require(
                foodTruck.ownerOf(foodTruckId) == owner,
                "You don't own this token"
            );
            require(
                foodTruck.getType(foodTruckId) > 0,
                "Chef not yet revealed"
            );
            require(
                !stakedFoodTrucks[foodTruckId].staked,
                "Chef is already staked"
            );

            _addFoodTruckToHotDoggeria(foodTruckId, owner);

            if (
                foodTruck.getType(foodTruckId) ==
                foodTruck.GOLD_FOOD_TRUCK_TYPE()
            ) {
                numberOfFoodTrucks[owner][1]++;
            } else {
                numberOfFoodTrucks[owner][0]++;
            }

            totalHDPM[owner] += foodTruck.getYield(foodTruckId);

            foodTruck.transferFrom(owner, address(this), foodTruckId);
        }
        uint256 maxLevelUpgrade = getMaxLevelUpgrade(owner);
        for (uint256 i = 0; i < _upgradeIds.length; i++) {
            //stakes upgrades
            uint256 upgradeId = _upgradeIds[i];

            require(
                upgrade.ownerOf(upgradeId) == owner,
                "You don't own this tool"
            );
            require(
                !stakedUpgrades[upgradeId].staked,
                "Tool is already staked"
            );
            require(
                upgrade.getLevel(upgradeId) <= maxLevelUpgrade,
                "You can't equip that tool"
            );

            upgrade.transferFrom(owner, address(this), upgradeId);
            totalHDPM[owner] += upgrade.getYield(upgradeId);

            _addUpgradeToHotDoggeria(upgradeId, owner);
        }
        _updateState(owner);
    }

    function _addFoodTruckToHotDoggeria(uint256 _tokenId, address _owner)
        internal
    {
        stakedFoodTrucks[_tokenId] = StakedFoodTruck({
            owner: _owner,
            tokenId: _tokenId,
            startTimestamp: block.timestamp,
            staked: true
        });
        _addStakeToOwnerEnumeration(_owner, _tokenId);
    }

    function _addUpgradeToHotDoggeria(uint256 _tokenId, address _owner)
        internal
    {
        stakedUpgrades[_tokenId] = StakedUpgrade({
            owner: _owner,
            tokenId: _tokenId,
            staked: true
        });
        _addUpgradeToOwnerEnumeration(_owner, _tokenId);
    }

    function _addStakeToOwnerEnumeration(address _owner, uint256 _tokenId)
        internal
    {
        uint256 length = ownedFoodTruckStakesBalance[_owner];
        ownedFoodTruckStakes[_owner][length] = _tokenId;
        ownedFoodTruckStakesIndex[_tokenId] = length;
        ownedFoodTruckStakesBalance[_owner]++;
    }

    function _addUpgradeToOwnerEnumeration(address _owner, uint256 _tokenId)
        internal
    {
        uint256 length = ownedUpgradeStakesBalance[_owner];
        ownedUpgradeStakes[_owner][length] = _tokenId;
        ownedUpgradeStakesIndex[_tokenId] = length;
        ownedUpgradeStakesBalance[_owner]++;
    }

    function _moveFoodTruckToCooldown(uint256 _foodTruckId) internal {
        address owner = stakedFoodTrucks[_foodTruckId].owner;

        uint256 endTimestamp = block.timestamp +
            getRestingTime(_foodTruckId, false);
        restingFoodTrucks[_foodTruckId] = RestingFoodTruck({
            owner: owner,
            tokenId: _foodTruckId,
            endTimestamp: endTimestamp,
            present: true
        });

        delete foodTruckFatigue[_foodTruckId];
        delete stakedFoodTrucks[_foodTruckId];
        _removeStakeFromOwnerEnumeration(owner, _foodTruckId);
        _addCooldownToOwnerEnumeration(owner, _foodTruckId);
    }

    // Cooldown
    function _removeUpgrade(uint256 _upgradeId) internal {
        address owner = stakedUpgrades[_upgradeId].owner;

        delete stakedUpgrades[_upgradeId];

        _removeUpgradeFromOwnerEnumeration(owner, _upgradeId);
    }

    function withdrawFoodTrucks(uint256[] calldata _foodTruckIds)
        public
        nonReentrant
        whenNotPaused
    {
        for (uint256 i = 0; i < _foodTruckIds.length; i++) {
            uint256 _foodTruckId = _foodTruckIds[i];
            RestingFoodTruck memory resting = restingFoodTrucks[_foodTruckId];

            require(resting.present, "Food Truck is not resting");
            require(
                resting.owner == _msgSender(),
                "You don't own this Food Truck"
            );
            require(
                block.timestamp >= resting.endTimestamp,
                "Food Truck is still resting"
            );

            _removeFoodTruckFromCooldown(_foodTruckId);
            foodTruck.transferFrom(address(this), _msgSender(), _foodTruckId);
        }
    }

    function reStakeRestedFoodTrucks(uint256[] calldata _foodTruckIds)
        public
        nonReentrant
        whenNotPaused
    {
        address owner = _msgSender();

        uint256 maxNumberFoodTrucks = getMaxNumberFoodTrucks(owner);
        uint256 foodTrucksAfterStaking = _foodTruckIds.length +
            numberOfFoodTrucks[owner][0] +
            numberOfFoodTrucks[owner][1];
        require(
            maxNumberFoodTrucks >= foodTrucksAfterStaking,
            "You can't stake that many Food Trucks"
        );

        for (uint256 i = 0; i < _foodTruckIds.length; i++) {
            //stakes Food Truck
            uint256 _foodTruckId = _foodTruckIds[i];

            RestingFoodTruck memory resting = restingFoodTrucks[_foodTruckId];

            require(resting.present, "Food Truck is not resting");
            require(resting.owner == owner, "You don't own this Food Truck");
            require(
                block.timestamp >= resting.endTimestamp,
                "Food Truck is still resting"
            );

            _removeFoodTruckFromCooldown(_foodTruckId);

            _addFoodTruckToHotDoggeria(_foodTruckId, owner);

            if (
                foodTruck.getType(_foodTruckId) ==
                foodTruck.GOLD_FOOD_TRUCK_TYPE()
            ) {
                numberOfFoodTrucks[owner][1]++;
            } else {
                numberOfFoodTrucks[owner][0]++;
            }

            totalHDPM[owner] += foodTruck.getYield(_foodTruckId);
        }
        _updateState(owner);
    }

    function _addCooldownToOwnerEnumeration(address _owner, uint256 _tokenId)
        internal
    {
        uint256 length = restingFoodTrucksBalance[_owner];
        ownedRestingFoodTrucks[_owner][length] = _tokenId;
        restingFoodTrucksIndex[_tokenId] = length;
        restingFoodTrucksBalance[_owner]++;
    }

    function _removeStakeFromOwnerEnumeration(address _owner, uint256 _tokenId)
        internal
    {
        uint256 lastTokenIndex = ownedFoodTruckStakesBalance[_owner] - 1;
        uint256 tokenIndex = ownedFoodTruckStakesIndex[_tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedFoodTruckStakes[_owner][lastTokenIndex];

            ownedFoodTruckStakes[_owner][tokenIndex] = lastTokenId;
            ownedFoodTruckStakesIndex[lastTokenId] = tokenIndex;
        }

        delete ownedFoodTruckStakesIndex[_tokenId];
        delete ownedFoodTruckStakes[_owner][lastTokenIndex];
        ownedFoodTruckStakesBalance[_owner]--;
    }

    function _removeUpgradeFromOwnerEnumeration(
        address _owner,
        uint256 _tokenId
    ) internal {
        uint256 lastTokenIndex = ownedUpgradeStakesBalance[_owner] - 1;
        uint256 tokenIndex = ownedUpgradeStakesIndex[_tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedUpgradeStakes[_owner][lastTokenIndex];

            ownedUpgradeStakes[_owner][tokenIndex] = lastTokenId;
            ownedUpgradeStakesIndex[lastTokenId] = tokenIndex;
        }

        delete ownedUpgradeStakesIndex[_tokenId];
        delete ownedUpgradeStakes[_owner][lastTokenIndex];
        ownedUpgradeStakesBalance[_owner]--;
    }

    function _removeFoodTruckFromCooldown(uint256 _foodTruckId) internal {
        address owner = restingFoodTrucks[_foodTruckId].owner;
        delete restingFoodTrucks[_foodTruckId];
        _removeCooldownFromOwnerEnumeration(owner, _foodTruckId);
    }

    function _removeCooldownFromOwnerEnumeration(
        address _owner,
        uint256 _tokenId
    ) internal {
        uint256 lastTokenIndex = restingFoodTrucksBalance[_owner] - 1;
        uint256 tokenIndex = restingFoodTrucksIndex[_tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedRestingFoodTrucks[_owner][
                lastTokenIndex
            ];
            ownedRestingFoodTrucks[_owner][tokenIndex] = lastTokenId;
            restingFoodTrucksIndex[lastTokenId] = tokenIndex;
        }

        delete restingFoodTrucksIndex[_tokenId];
        delete ownedRestingFoodTrucks[_owner][lastTokenIndex];
        restingFoodTrucksBalance[_owner]--;
    }

    function stakeOfOwnerByIndex(address _owner, uint256 _index)
        public
        view
        returns (uint256)
    {
        require(
            _index < ownedFoodTruckStakesBalance[_owner],
            "owner index out of bounds"
        );
        return ownedFoodTruckStakes[_owner][_index];
    }

    function batchedStakesOfOwner(
        address _owner,
        uint256 _offset,
        uint256 _maxSize
    ) public view returns (StakedFoodTruckInfo[] memory) {
        if (_offset >= ownedFoodTruckStakesBalance[_owner]) {
            return new StakedFoodTruckInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= ownedFoodTruckStakesBalance[_owner]) {
            outputSize = ownedFoodTruckStakesBalance[_owner] - _offset;
        }
        StakedFoodTruckInfo[] memory outputs = new StakedFoodTruckInfo[](
            outputSize
        );

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 foodTruckId = stakeOfOwnerByIndex(_owner, _offset + i);
            uint256 upgradeId = _getUpgradeStakedForFoodTruck(
                _owner,
                foodTruckId
            );
            uint256 foodTruckHDPM = foodTruck.getYield(foodTruckId);
            uint256 upgradeHDPM;
            if (upgradeId > 0) {
                upgradeHDPM = upgrade.getYield(upgradeId);
            }

            outputs[i] = StakedFoodTruckInfo({
                foodTruckId: foodTruckId,
                upgradeId: upgradeId,
                foodTruckHDPM: foodTruckHDPM,
                upgradeHDPM: upgradeHDPM,
                hotDog: _getHotDogAccruedForFoodTruck(foodTruckId, false),
                fatigue: getFatigueAccruedForFoodTruck(foodTruckId, false),
                timeUntilFatigued: getTimeUntilFatigued(foodTruckId, false)
            });
        }

        return outputs;
    }

    function cooldownOfOwnerByIndex(address _owner, uint256 _index)
        public
        view
        returns (uint256)
    {
        require(
            _index < restingFoodTrucksBalance[_owner],
            "owner index out of bounds"
        );
        return ownedRestingFoodTrucks[_owner][_index];
    }

    function batchedCooldownsOfOwner(
        address _owner,
        uint256 _offset,
        uint256 _maxSize
    ) public view returns (RestingFoodTruckInfo[] memory) {
        if (_offset >= restingFoodTrucksBalance[_owner]) {
            return new RestingFoodTruckInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= restingFoodTrucksBalance[_owner]) {
            outputSize = restingFoodTrucksBalance[_owner] - _offset;
        }
        RestingFoodTruckInfo[] memory outputs = new RestingFoodTruckInfo[](
            outputSize
        );

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 tokenId = cooldownOfOwnerByIndex(_owner, _offset + i);

            outputs[i] = RestingFoodTruckInfo({
                tokenId: tokenId,
                endTimestamp: restingFoodTrucks[tokenId].endTimestamp
            });
        }

        return outputs;
    }

    /**
     * enables owner to pause / unpause minting
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }
}
