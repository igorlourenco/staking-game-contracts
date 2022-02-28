//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Juice.sol";

contract HotDoggeriaProgression is Context, Ownable, Pausable {
    // Constants
    uint256[20] public JUICE_LEVELS = [
        0,
        100 * 1e18,
        250 * 1e18,
        450 * 1e18,
        700 * 1e18,
        1000 * 1e18,
        1350 * 1e18,
        1750 * 1e18,
        2200 * 1e18,
        2700 * 1e18,
        3250 * 1e18,
        3850 * 1e18,
        4500 * 1e18,
        5200 * 1e18,
        5950 * 1e18,
        6750 * 1e18,
        7600 * 1e18,
        8500 * 1e18,
        9450 * 1e18,
        10450 * 1e18
    ];
    uint256 public MAX_JUICE_AMOUNT = JUICE_LEVELS[JUICE_LEVELS.length - 1];
    uint256 public constant BURN_ID = 0;
    uint256 public constant FATIGUE_ID = 1;
    uint256 public constant FREEZER_ID = 2;
    uint256 public constant MASTER_FOOD_TRUCK_ID = 3;
    uint256 public constant UPGRADES_ID = 4;
    uint256 public constant FOOD_TRUCKS_ID = 5;
    uint256 public constant BASE_COST_RESPEC = 50 * 1e18;
    uint256[6] public MAX_SKILL_LEVEL = [3, 3, 2, 2, 5, 5];

    Juice public juice;

    uint256 public levelTime;

    mapping(address => uint256) public juiceDeposited; // address => total amount of juice deposited
    mapping(address => uint256) public skillPoints; // address => skill points available
    mapping(address => uint256[6]) public skillsLearned; // address => skill learned.

    constructor(Juice _juice) {
        juice = _juice;
    }

    // EVENTS

    event receivedSkillPoints(address owner, uint256 skillPoints);
    event skillLearned(address owner, uint256 skillGroup, uint256 skillLevel);
    event respec(address owner, uint256 level);

    // Views

    /**
     * Returns the level based on the total juice deposited
     */
    function _getLevel(address _owner) internal view returns (uint256) {
        uint256 totalJuice = juiceDeposited[_owner];

        for (uint256 i = 0; i < JUICE_LEVELS.length - 1; i++) {
            if (totalJuice < JUICE_LEVELS[i + 1]) {
                return i + 1;
            }
        }
        return JUICE_LEVELS.length;
    }

    /**
     * Returns a value representing the % of fatigue after reducing
     */
    function getFatigueSkillModifier(address _owner)
        public
        view
        returns (uint256)
    {
        uint256 fatigueSkill = skillsLearned[_owner][FATIGUE_ID];

        if (fatigueSkill == 3) {
            return 80;
        } else if (fatigueSkill == 2) {
            return 85;
        } else if (fatigueSkill == 1) {
            return 92;
        } else {
            return 100;
        }
    }

    /**
     * Returns a value representing the % that will be reduced from the claim burn
     */
    function getBurnSkillModifier(address _owner)
        public
        view
        returns (uint256)
    {
        uint256 burnSkill = skillsLearned[_owner][BURN_ID];

        if (burnSkill == 3) {
            return 8;
        } else if (burnSkill == 2) {
            return 6;
        } else if (burnSkill == 1) {
            return 3;
        } else {
            return 0;
        }
    }

    /**
     * Returns a value representing the % that will be reduced from the freezer share of the claim
     */
    function getFreezerSkillModifier(address _owner)
        public
        view
        returns (uint256)
    {
        uint256 freezerSkill = skillsLearned[_owner][FREEZER_ID];

        if (freezerSkill == 2) {
            return 9;
        } else if (freezerSkill == 1) {
            return 4;
        } else {
            return 0;
        }
    }

    /**
     * Returns the multiplier for $PIZZA production based on the number of masterchefs and the skill points spent
     */
    function getMasterFoodTruckSkillModifier(
        address _owner,
        uint256 _masterFoodTruckNumber
    ) public view returns (uint256) {
        uint256 masterFoodTruckSkill = skillsLearned[_owner][
            MASTER_FOOD_TRUCK_ID
        ];

        if (masterFoodTruckSkill == 2 && _masterFoodTruckNumber >= 5) {
            return 110;
        } else if (masterFoodTruckSkill >= 1 && _masterFoodTruckNumber >= 2) {
            return 103;
        } else {
            return 100;
        }
    }

    /**
     * Returns the max level upgrade that can be staked based on the skill points spent
     */
    function getMaxLevelUpgrade(address _owner) public view returns (uint256) {
        uint256 upgradesSkill = skillsLearned[_owner][UPGRADES_ID];

        if (upgradesSkill == 0) {
            return 1; //level id starts at 0, so here are first and second tiers
        } else if (upgradesSkill == 1) {
            return 4;
        } else if (upgradesSkill == 2) {
            return 6;
        } else if (upgradesSkill == 3) {
            return 8;
        } else if (upgradesSkill == 4) {
            return 11;
        } else {
            return 100;
        }
    }

    /**
     * Returns the max number of chefs that can be staked based on the skill points spent
     */
    function getMaxNumberFoodTrucks(address _owner)
        public
        view
        returns (uint256)
    {
        uint256 foodTrucksSkill = skillsLearned[_owner][FOOD_TRUCKS_ID];

        if (foodTrucksSkill == 0) {
            return 10;
        } else if (foodTrucksSkill == 1) {
            return 15;
        } else if (foodTrucksSkill == 2) {
            return 20;
        } else if (foodTrucksSkill == 3) {
            return 30;
        } else if (foodTrucksSkill == 4) {
            return 50;
        } else {
            return 20000;
        }
    }

    // Public views

    /**
     * Returns the Pizzeria level
     */
    function getLevel(address _owner) public view returns (uint256) {
        return _getLevel(_owner);
    }

    /**
     * Returns the $JUICE deposited in the current level
     */
    function getJuiceDeposited(address _owner) public view returns (uint256) {
        uint256 level = _getLevel(_owner);
        uint256 totalJuice = juiceDeposited[_owner];

        return totalJuice - JUICE_LEVELS[level - 1];
    }

    /**
     * Returns the amount of juice required to level up
     */
    function getJuiceToNextLevel(address _owner) public view returns (uint256) {
        uint256 level = _getLevel(_owner);
        if (level == JUICE_LEVELS.length) {
            return 0;
        }
        return JUICE_LEVELS[level] - JUICE_LEVELS[level - 1];
    }

    /**
     * Returns the amount of skills points available to be spent
     */
    function getSkillPoints(address _owner) public view returns (uint256) {
        return skillPoints[_owner];
    }

    /**
     * Returns the current skills levels for each skill group
     */
    function getSkillsLearned(address _owner)
        public
        view
        returns (
            uint256 burn,
            uint256 fatigue,
            uint256 freezer,
            uint256 masterFoodTruck,
            uint256 upgrades,
            uint256 foodTrucks
        )
    {
        uint256[6] memory skills = skillsLearned[_owner];

        burn = skills[BURN_ID];
        fatigue = skills[FATIGUE_ID];
        freezer = skills[FREEZER_ID];
        masterFoodTruck = skills[MASTER_FOOD_TRUCK_ID];
        upgrades = skills[UPGRADES_ID];
        foodTrucks = skills[FOOD_TRUCKS_ID];
    }

    // External

    /**
     * Burns deposited $JUICE and add skill point if level up.
     */
    function depositJuice(uint256 _amount) external whenNotPaused {
        require(levelStarted(), "You can't level yet");
        require(
            _getLevel(_msgSender()) < JUICE_LEVELS.length,
            "already at max level"
        );
        require(juice.balanceOf(_msgSender()) >= _amount, "not enough JUICE");

        if (_amount + juiceDeposited[_msgSender()] > MAX_JUICE_AMOUNT) {
            _amount = MAX_JUICE_AMOUNT - juiceDeposited[_msgSender()];
        }

        uint256 levelBefore = _getLevel(_msgSender());
        juiceDeposited[_msgSender()] += _amount;
        uint256 levelAfter = _getLevel(_msgSender());
        skillPoints[_msgSender()] += levelAfter - levelBefore;

        if (levelAfter == JUICE_LEVELS.length) {
            skillPoints[_msgSender()] += 1;
        }

        emit receivedSkillPoints(_msgSender(), levelAfter - levelBefore);

        juice.burn(_msgSender(), _amount);
    }

    /**
     *  Spend skill point based on the skill group and skill level. Can only spend 1 point at a time.
     */
    function spendSkillPoints(uint256 _skillGroup, uint256 _skillLevel)
        external
        whenNotPaused
    {
        require(skillPoints[_msgSender()] > 0, "Not enough skill points");
        require(_skillGroup <= 5, "Invalid Skill Group");
        require(
            _skillLevel >= 1 && _skillLevel <= MAX_SKILL_LEVEL[_skillGroup],
            "Invalid Skill Level"
        );

        uint256 currentSkillLevel = skillsLearned[_msgSender()][_skillGroup];
        require(
            _skillLevel == currentSkillLevel + 1,
            "Invalid Skill Level jump"
        ); //can only level up 1 point at a time

        skillsLearned[_msgSender()][_skillGroup] = _skillLevel;
        skillPoints[_msgSender()]--;

        emit skillLearned(_msgSender(), _skillGroup, _skillLevel);
    }

    /**
     *  Resets skills learned for a fee
     */
    function resetSkills() external whenNotPaused {
        uint256 level = _getLevel(_msgSender());
        uint256 costToRespec = level * BASE_COST_RESPEC;
        require(level > 1, "you are still at level 1");
        require(
            juice.balanceOf(_msgSender()) >= costToRespec,
            "not enough JUICE"
        );

        skillsLearned[_msgSender()][BURN_ID] = 0;
        skillsLearned[_msgSender()][FATIGUE_ID] = 0;
        skillsLearned[_msgSender()][FREEZER_ID] = 0;
        skillsLearned[_msgSender()][MASTER_FOOD_TRUCK_ID] = 0;
        skillsLearned[_msgSender()][UPGRADES_ID] = 0;
        skillsLearned[_msgSender()][FOOD_TRUCKS_ID] = 0;

        skillPoints[_msgSender()] = level - 1;

        if (level == 20) {
            skillPoints[_msgSender()]++;
        }

        juice.burn(_msgSender(), costToRespec);

        emit respec(_msgSender(), level);
    }

    // Admin

    function levelStarted() public view returns (bool) {
        return levelTime != 0 && block.timestamp >= levelTime;
    }

    function setLevelStartTime(uint256 _startTime) external onlyOwner {
        require(
            _startTime >= block.timestamp,
            "startTime cannot be in the past"
        );
        require(!levelStarted(), "leveling already started");
        levelTime = _startTime;
    }
}
