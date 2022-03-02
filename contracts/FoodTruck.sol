//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./HotDog.sol";

contract FoodTruck is ERC721Enumerable, Ownable, Pausable {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    struct FoodTruckInfo {
        uint256 tokenId;
        uint256 foodTruckType;
    }

    // CONSTANTS

    uint256 public constant FOOD_TRUCK_PRICE_WHITELIST = 1 ether;
    uint256 public constant FOOD_TRUCK_PRICE_AVAX = 1.5 ether;

    uint256 public constant WHITELIST_FOOD_TRUCKS = 1000;
    uint256 public constant FOOD_TRUCKS_PER_HOTDOG_MINT_LEVEL = 5000;

    uint256 public constant MAXIMUM_MINTS_PER_WHITELIST_ADDRESS = 4;

    uint256 public constant NUM_GEN0_FOOD_TRUCKS = 10_000;
    uint256 public constant NUM_GEN1_FOOD_TRUCKS = 10_000;

    uint256 public constant FOOD_TRUCK_TYPE = 1;
    uint256 public constant GOLD_FOOD_TRUCK_TYPE = 2;
    uint256 public constant DIAMOND_FOOD_TRUCK_TYPE = 3;
    uint256 public constant SPECIAL_FOOD_TRUCK_TYPE = 4;

    uint256 public constant FOOD_TRUCK_YIELD = 1;
    uint256 public constant GOLD_FOOD_TRUCK_YIELD = 3;
    uint256 public constant DIAMOND_FOOD_TRUCK_YIELD = 6;
    uint256 public constant SPECIAL_FOOD_TRUCK_YIELD = 9;

    uint256 public constant PROMOTIONAL_FOOD_TRUCKS = 50;

    // VAR

    // external contracts
    HotDog public hotDog;
    address public hotDoggeriaAddress;

    // metadata URI
    string public BASE_URI;

    // foodTruck type definitions (normal, gold, diamond or special?)
    mapping(uint256 => uint256) public tokenTypes; // maps tokenId to its type
    mapping(uint256 => uint256) public typeYields; // maps foodTruck type to yield

    // mint tracking
    uint256 public foodTrucksMintedWithAVAX;
    uint256 public foodTrucksMintedWithHOTDOG;
    uint256 public foodTrucksMintedWhitelist;
    uint256 public foodTrucksMintedPromotional;
    uint256 public foodTrucksMinted = 50; // First 50 ids are reserved for the promotional foodTrucks

    // mint control timestamps
    uint256 public startTimeWhitelist;
    uint256 public startTimeAVAX;
    uint256 public startTimeHOTDOG;

    // HOTDOG mint price tracking
    uint256 public currentHOTDOGMintCost = 20_000 * 1e18;

    // whitelist
    bytes32 public merkleRoot;
    mapping(address => uint256) public whitelistClaimed;

    // EVENTS

    event onFoodTruckCreated(uint256 tokenId);
    event onFoodTruckRevealed(uint256 tokenId, uint256 foodTruckType);

    /**
     * requires pizza, foodTruckType oracle address
     * pizza: for liquidity bootstrapping and spending on foodTrucks
     */
    constructor(HotDog _hotDog, string memory _BASE_URI)
        ERC721("Hot Dog Game FoodTrucks", "HOTDOG-GAME-FOODTRUCK")
    {
        require(address(_hotDog) != address(0));

        // set required contract references
        hotDog = _hotDog;

        // set base uri
        BASE_URI = _BASE_URI;

        // initialize token yield values for each foodTruck type
        typeYields[FOOD_TRUCK_TYPE] = FOOD_TRUCK_YIELD;
        typeYields[GOLD_FOOD_TRUCK_TYPE] = GOLD_FOOD_TRUCK_YIELD;
        typeYields[DIAMOND_FOOD_TRUCK_TYPE] = DIAMOND_FOOD_TRUCK_YIELD;
        typeYields[SPECIAL_FOOD_TRUCK_TYPE] = SPECIAL_FOOD_TRUCK_YIELD;
    }

    // VIEWS

    // minting status

    function mintingStartedWhitelist() public view returns (bool) {
        return startTimeWhitelist != 0 && block.timestamp >= startTimeWhitelist;
    }

    function mintingStartedAVAX() public view returns (bool) {
        return startTimeAVAX != 0 && block.timestamp >= startTimeAVAX;
    }

    function mintingStartedHOTDOG() public view returns (bool) {
        return startTimeHOTDOG != 0 && block.timestamp >= startTimeHOTDOG;
    }

    // metadata

    function _baseURI() internal view virtual override returns (string memory) {
        return BASE_URI;
    }

    function getYield(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId), "token does not exist");
        return typeYields[tokenTypes[_tokenId]];
    }

    function getType(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId), "token does not exist");
        return tokenTypes[_tokenId];
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return
            string(
                abi.encodePacked(_baseURI(), "/", tokenId.toString(), ".json")
            );
    }

    // override

    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool)
    {
        // pizzeria must be able to stake and unstake
        if (hotDoggeriaAddress != address(0) && _operator == hotDoggeriaAddress)
            return true;
        return super.isApprovedForAll(_owner, _operator);
    }

    // ADMIN

    function setHotDoggeriaAddress(address _hotDoggeriaAddress)
        external
        onlyOwner
    {
        hotDoggeriaAddress = _hotDoggeriaAddress;
    }

    function setHotDog(address _hotDog) external onlyOwner {
        hotDog = HotDog(_hotDog);
    }

    function setStartTimeWhitelist(uint256 _startTime) external onlyOwner {
        require(
            _startTime >= block.timestamp,
            "startTime cannot be in the past"
        );
        startTimeWhitelist = _startTime;
    }

    function setStartTimeAVAX(uint256 _startTime) external onlyOwner {
        require(
            _startTime >= block.timestamp,
            "startTime cannot be in the past"
        );
        startTimeAVAX = _startTime;
    }

    function setStartTimeHOTDOG(uint256 _startTime) external onlyOwner {
        require(
            _startTime >= block.timestamp,
            "startTime cannot be in the past"
        );
        startTimeHOTDOG = _startTime;
    }

    function setBaseURI(string calldata _BASE_URI) external onlyOwner {
        BASE_URI = _BASE_URI;
    }

    /**
     * @dev merkle root for WL wallets
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    /**
     * @dev allows owner to send ERC20s held by this contract to target
     */
    function forwardERC20s(
        IERC20 _token,
        uint256 _amount,
        address target
    ) external onlyOwner {
        _token.safeTransfer(target, _amount);
    }

    /**
     * @dev allows owner to withdraw AVAX
     */
    function withdrawAVAX(uint256 _amount) external payable onlyOwner {
        require(address(this).balance >= _amount, "not enough AVAX");
        address payable to = payable(_msgSender());
        (bool sent, ) = to.call{value: _amount}("");
        require(sent, "Failed to send AVAX");
    }

    // MINTING

    function _createFoodTruck(address to, uint256 tokenId) internal {
        require(
            foodTrucksMinted <= NUM_GEN0_FOOD_TRUCKS + NUM_GEN1_FOOD_TRUCKS,
            "cannot mint anymore Food Trucks"
        );
        _safeMint(to, tokenId);

        emit onFoodTruckCreated(tokenId);
    }

    function _createFoodTrucks(uint256 qty, address to) internal {
        for (uint256 i = 0; i < qty; i++) {
            foodTrucksMinted += 1;
            _createFoodTruck(to, foodTrucksMinted);
        }
    }

    /**
     * @dev as an anti cheat mechanism, an external automation will generate the NFT metadata and set the foodTruck types via rng
     * - Using an external source of randomness ensures our mint cannot be cheated
     * - The external automation is open source and can be found on pizza game's github
     * - Once the mint is finished, it is provable that this randomness was not tampered with by providing the seed
     * - Food Truck type can be set only once
     */
    function setFoodTruckType(uint256 tokenId) external {
        require(
            tokenTypes[tokenId] == 0,
            "that token's type has already been set"
        );

        uint256 points = random(101);
        if (points <= 89) {
            tokenTypes[tokenId] = FOOD_TRUCK_TYPE;
            emit onFoodTruckRevealed(tokenId, FOOD_TRUCK_TYPE);
        }
        if (points > 89 && points <= 99) {
            tokenTypes[tokenId] = GOLD_FOOD_TRUCK_TYPE;
            emit onFoodTruckRevealed(tokenId, GOLD_FOOD_TRUCK_TYPE);
        }
        if (points == 100) {
            tokenTypes[tokenId] = DIAMOND_FOOD_TRUCK_TYPE;
            emit onFoodTruckRevealed(tokenId, DIAMOND_FOOD_TRUCK_TYPE);
        }
    }

    function setSpecialFoodTruckType(uint256 tokenId, uint256 foodTruckType)
        external
        onlyOwner
    {
        require(
            tokenTypes[tokenId] == 0,
            "that token's type has already been set"
        );

        require(
            foodTruckType == FOOD_TRUCK_TYPE ||
                foodTruckType == GOLD_FOOD_TRUCK_TYPE ||
                foodTruckType == DIAMOND_FOOD_TRUCK_TYPE ||
                foodTruckType == SPECIAL_FOOD_TRUCK_TYPE,
            "invalid foodTruck type"
        );

        tokenTypes[tokenId] = foodTruckType;
        emit onFoodTruckRevealed(tokenId, foodTruckType);
    }

    /**
     * @dev Promotional GEN0 minting
     * Can mint maximum of PROMOTIONAL_FOOD_TRUCKS
     * All foodTrucks minted are from the same foodTruckType
     */
    function mintPromotional(
        uint256 qty,
        uint256 foodTruckType,
        address target
    ) external onlyOwner {
        require(qty > 0, "quantity must be greater than 0");
        require(
            (foodTrucksMintedPromotional + qty) <= PROMOTIONAL_FOOD_TRUCKS,
            "you can't mint that many right now"
        );
        require(
            foodTruckType == FOOD_TRUCK_TYPE ||
                foodTruckType == GOLD_FOOD_TRUCK_TYPE ||
                foodTruckType == DIAMOND_FOOD_TRUCK_TYPE ||
                foodTruckType == SPECIAL_FOOD_TRUCK_TYPE,
            "invalid foodTruck type"
        );

        for (uint256 i = 0; i < qty; i++) {
            foodTrucksMintedPromotional += 1;
            require(
                tokenTypes[foodTrucksMintedPromotional] == 0,
                "that token's type has already been set"
            );
            tokenTypes[foodTrucksMintedPromotional] = foodTruckType;
            emit onFoodTruckRevealed(
                foodTrucksMintedPromotional,
                foodTruckType
            );
            _createFoodTruck(target, foodTrucksMintedPromotional);
        }
    }

    /**
     * @dev Whitelist GEN0 minting
     * We implement a hard limit on the whitelist foodTrucks.
     */
    function mintWhitelist(bytes32[] calldata _merkleProof, uint256 qty)
        external
        payable
        whenNotPaused
    {
        // check most basic requirements
        require(merkleRoot != 0, "missing root");
        require(mintingStartedWhitelist(), "cannot mint right now");
        require(!mintingStartedAVAX(), "whitelist minting is closed");

        // check if address belongs in whitelist
        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "this address does not have permission"
        );

        // check more advanced requirements
        require(
            qty > 0 && qty <= MAXIMUM_MINTS_PER_WHITELIST_ADDRESS,
            "quantity must be between 1 and 4"
        );
        require(
            (foodTrucksMintedWhitelist + qty) <= WHITELIST_FOOD_TRUCKS,
            "you can't mint that many right now"
        );
        require(
            (whitelistClaimed[_msgSender()] + qty) <=
                MAXIMUM_MINTS_PER_WHITELIST_ADDRESS,
            "this address can't mint any more whitelist foodTrucks"
        );

        // check price
        require(
            msg.value >= FOOD_TRUCK_PRICE_WHITELIST * qty,
            "not enough AVAX"
        );

        foodTrucksMintedWhitelist += qty;
        whitelistClaimed[_msgSender()] += qty;

        // mint foodTrucks
        _createFoodTrucks(qty, _msgSender());
    }

    /**
     * @dev GEN0 minting
     */
    function mintFoodTruckWithAVAX(uint256 qty) external payable whenNotPaused {
        require(mintingStartedAVAX(), "cannot mint right now");
        require(qty > 0 && qty <= 10, "quantity must be between 1 and 10");
        require(
            (foodTrucksMintedWithAVAX + qty) <=
                (NUM_GEN0_FOOD_TRUCKS -
                    foodTrucksMintedWhitelist -
                    PROMOTIONAL_FOOD_TRUCKS),
            "you can't mint that many right now"
        );

        // calculate the transaction cost
        uint256 transactionCost = FOOD_TRUCK_PRICE_AVAX * qty;
        require(msg.value >= transactionCost, "not enough AVAX");

        foodTrucksMintedWithAVAX += qty;

        // mint foodTrucks
        _createFoodTrucks(qty, _msgSender());
    }

    /**
     * @dev GEN1 minting
     */
    function mintFoodTruckWithHOTDOG(uint256 qty) external whenNotPaused {
        require(mintingStartedHOTDOG(), "cannot mint right now");
        require(qty > 0 && qty <= 10, "quantity must be between 1 and 10");
        require(
            (foodTrucksMintedWithHOTDOG + qty) <= NUM_GEN1_FOOD_TRUCKS,
            "you can't mint that many right now"
        );

        // calculate transaction costs
        uint256 transactionCostHOTDOG = currentHOTDOGMintCost * qty;
        require(
            hotDog.balanceOf(_msgSender()) >= transactionCostHOTDOG,
            "not enough HOTDOG"
        );

        // raise the mint level and cost when this mint would place us in the next level
        // if you mint in the cost transition you get a discount =)
        if (
            foodTrucksMintedWithHOTDOG <= FOOD_TRUCKS_PER_HOTDOG_MINT_LEVEL &&
            foodTrucksMintedWithHOTDOG + qty > FOOD_TRUCKS_PER_HOTDOG_MINT_LEVEL
        ) {
            currentHOTDOGMintCost = currentHOTDOGMintCost * 2;
        }

        foodTrucksMintedWithHOTDOG += qty;

        // spend pizza
        hotDog.burn(_msgSender(), transactionCostHOTDOG);

        // mint foodTrucks
        _createFoodTrucks(qty, _msgSender());
    }

    // Returns information for multiples foodTrucks
    function batchedFoodTrucksOfOwner(
        address _owner,
        uint256 _offset,
        uint256 _maxSize
    ) public view returns (FoodTruckInfo[] memory) {
        if (_offset >= balanceOf(_owner)) {
            return new FoodTruckInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= balanceOf(_owner)) {
            outputSize = balanceOf(_owner) - _offset;
        }
        FoodTruckInfo[] memory foodTrucks = new FoodTruckInfo[](outputSize);

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, _offset + i); // tokenOfOwnerByIndex comes from IERC721Enumerable

            foodTrucks[i] = FoodTruckInfo({
                tokenId: tokenId,
                foodTruckType: tokenTypes[tokenId]
            });
        }

        return foodTrucks;
    }

    function random(uint256 number) public view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender
                    )
                )
            ) % number;
    }
}
