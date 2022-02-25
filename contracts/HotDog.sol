//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HotDog is ERC20("HotDog", "HOTDOG"), Ownable {
    uint256 public constant ONE_HOTDOG = 1e18;
    uint256 public constant NUM_PROMOTIONAL_HOTDOG = 500_000;
    uint256 public constant NUM_HOTDOG_SODA_LP = 20_000_000;

    uint256 public NUM_HOTDOG_AVAX_LP = 30_000_000;

    address public freezerAddress;
    address public hotDoggeriaAddress;
    address public chefAddress;
    address public upgradeAddress;

    bool public promotionalHotDogMinted = false;
    bool public avaxLPHotDogMinted = false;
    bool public sodaLPHotDogMinted = false;

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

    function setFreezerAddress(address _freezerAddress) external onlyOwner {
        freezerAddress = _freezerAddress;
    }

    function setUpgradeAddress(address _upgradeAddress) external onlyOwner {
        upgradeAddress = _upgradeAddress;
    }

    /**
     * chef consumes hot dog
     * chef address can only be set once
     */
    function setChefAddress(address _chefAddress) external onlyOwner {
        require(address(chefAddress) == address(0), "chef address already set");
        chefAddress = _chefAddress;
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

    function mintSodaLPHotDog() external onlyOwner {
        require(!sodaLPHotDogMinted, "soda hot dog LP has already been minted");
        sodaLPHotDogMinted = true;
        _mint(owner(), NUM_HOTDOG_SODA_LP * ONE_HOTDOG);
    }

    function setNumHotDogAvaxLp(uint256 _numHotDogAvaxLp) external onlyOwner {
        NUM_HOTDOG_AVAX_LP = _numHotDogAvaxLp;
    }

    // external

    function mint(address _to, uint256 _amount) external {
        require(
            hotDoggeriaAddress != address(0) &&
                chefAddress != address(0) &&
                freezerAddress != address(0) &&
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
            chefAddress != address(0) &&
                freezerAddress != address(0) &&
                upgradeAddress != address(0),
            "missing initial requirements"
        );
        require(
            _msgSender() == chefAddress ||
                _msgSender() == freezerAddress ||
                _msgSender() == upgradeAddress,
            "msgsender does not have permission"
        );
        _burn(_from, _amount);
    }

    function transferToFreezer(address _from, uint256 _amount) external {
        require(freezerAddress != address(0), "missing initial requirements");
        require(
            _msgSender() == freezerAddress,
            "only the freezer contract can call transferToFreezer"
        );
        _transfer(_from, freezerAddress, _amount);
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
