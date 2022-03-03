//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HotDog is ERC20("HotDog", "HOTDOG"), Ownable {
    uint256 public constant ONE_HOTDOG = 1e18;
    uint256 public constant NUM_PROMOTIONAL_HOTDOG = 500_000;
    uint256 public constant NUM_HOTDOG_JUICE_LP = 20_000_000;

    uint256 public NUM_HOTDOG_AVAX_LP = 30_000_000;

    address public employeeAddress;
    address public hotDoggeriaAddress;
    address public foodTruckAddress;
    address public upgradeAddress;

    bool public promotionalHotDogMinted = false;
    bool public avaxLPHotDogMinted = false;
    bool public juiceLPHotDogMinted = false;

    // ADMIN

    /**
     * hot doggeria  yields hot dog
     */
    function setHotDoggeriaddress(address _hotDoggeriaAddress)
        external
        onlyOwner
    {
        hotDoggeriaAddress = _hotDoggeriaAddress;
    }

    function setEmployeeAddress(address _employeeAddress) external onlyOwner {
        employeeAddress = _employeeAddress;
    }

    function setUpgradeAddress(address _upgradeAddress) external onlyOwner {
        upgradeAddress = _upgradeAddress;
    }

    /**
     * chef consumes hot dog
     * chef address can only be set once
     */
    function setFoodTruckAddress(address _foodTruckAddress) external onlyOwner {
        require(
            address(foodTruckAddress) == address(0),
            "food truck address already set"
        );
        foodTruckAddress = _foodTruckAddress;
    }

    function mintPromotionalHotDog(address _to) external onlyOwner {
        require(
            !promotionalHotDogMinted,
            "promotional hot dog has already been minted"
        );
        promotionalHotDogMinted = true;
        _mint(_to, NUM_PROMOTIONAL_HOTDOG * ONE_HOTDOG);
    }

    function mintAvaxLPHotDog() external onlyOwner {
        require(!avaxLPHotDogMinted, "avax hot dog LP has already been minted");
        avaxLPHotDogMinted = true;
        _mint(owner(), NUM_HOTDOG_AVAX_LP * ONE_HOTDOG);
    }

    function mintJuiceLPHotDog() external onlyOwner {
        require(
            !juiceLPHotDogMinted,
            "juice hot dog LP has already been minted"
        );
        juiceLPHotDogMinted = true;
        _mint(owner(), NUM_HOTDOG_JUICE_LP * ONE_HOTDOG);
    }

    function setNumHotDogAvaxLp(uint256 _numHotDogAvaxLp) external onlyOwner {
        NUM_HOTDOG_AVAX_LP = _numHotDogAvaxLp;
    }

    // external

    function mint(address _to, uint256 _amount) external {
        require(
            hotDoggeriaAddress != address(0) &&
                foodTruckAddress != address(0) &&
                employeeAddress != address(0) &&
                upgradeAddress != address(0),
            "missing initial requirements"
        );
        require(
            _msgSender() == hotDoggeriaAddress,
            "msgsender does not have permission"
        );
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        require(
            foodTruckAddress != address(0) &&
                employeeAddress != address(0) &&
                upgradeAddress != address(0),
            "missing initial requirements"
        );
        require(
            _msgSender() == foodTruckAddress ||
                _msgSender() == employeeAddress ||
                _msgSender() == upgradeAddress,
            "msgsender does not have permission"
        );
        _burn(_from, _amount);
    }

    function transferToEmployee(address _from, uint256 _amount) external {
        require(employeeAddress != address(0), "missing initial requirements");
        require(
            _msgSender() == employeeAddress,
            "only the employee contract can call transferToEmployee"
        );
        _transfer(_from, employeeAddress, _amount);
    }

    function transferForUpgradesFees(address _from, uint256 _amount) external {
        require(upgradeAddress != address(0), "missing initial requirements");
        require(
            _msgSender() == upgradeAddress,
            "only the upgrade contract can call transferForUpgradesFees"
        );
        _transfer(_from, upgradeAddress, _amount);
    }
}
