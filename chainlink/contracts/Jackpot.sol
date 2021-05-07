// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract JackpotGame is VRFConsumerBase {
    event NewJackpot(uint256 index, uint256 blockstamp);
    event JackpotResult(address winner, uint256 jackpotSize);

    // chainlink vrf variables
    bytes32 internal keyHash;
    uint256 internal fee;

    //jackpot struct to organize each jackpot info
    struct Jackpot {
        uint256 index;
        uint256 size;
        uint256 blockstamp;
        address[] players;
        address winner;
    }

    //used to track game information
    uint256 index;
    address[] players;
    mapping(uint256 => Jackpot) jackpotIndex;
    Jackpot currentJackpot;

    //number of players in a jackpot at which a pot size bet max is set. To prevent buying pots
    uint256 freeBetRange;

    //used to determine whether a jackpot can be created/joined
    bool jackpotActive;

    address owner;

    mapping(address => uint256) playerBet;

    modifier onlyOwner() {
        require(msg.sender == owner, "Function only callable by owner");
        _;
    }

    constructor()
        public
        VRFConsumerBase(
            0x3d2341ADb2D31f1c5530cDC622016af293177AE0, // VRF Coordinator
            0xb0897686c545045aFc77CF20eC7A532E3120E0F1 // Link Token
        )
    {
        keyHash = 0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da;
        fee = 0.0001 * 10**18; //0.001 link oracle fee
        index = 0;
        owner = msg.sender;
        freeBetRange = 5;
    }

    function newJackpot() public payable {
        require(jackpotActive == false, "Jackpot already active");
        jackpotActive = true;
        currentJackpot = Jackpot(
            index,
            msg.value,
            block.timestamp,
            players,
            address(this)
        );
        jackpotIndex[index] = currentJackpot;
        emit NewJackpot(index, block.timestamp);
    }

    function enterJackpot() public payable {
        require(
            jackpotActive == true,
            "no active jackpot to join, create your own"
        );
        if (currentJackpot.players.length >= freeBetRange) {
            require(
                msg.value <= currentJackpot.size,
                "you cannot bet more than the current pot"
            );
        }
        currentJackpot.players.push(msg.sender);
        currentJackpot.size += msg.value;
        playerBet[msg.sender] = msg.value;

        if (now >= currentJackpot.blockstamp + 24 hours) {
            getRandomNumber(currentJackpot.players.length);
        }
    }

    function setFreeBetRange(uint256 _freeBetRange) public onlyOwner {
        freeBetRange = _freeBetRange;
    }

    //CHAINLINK VRF FUNCTIONS BELOW
    function getRandomNumber(uint256 userProvidedSeed)
        public
        returns (bytes32 requestId)
    {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK for VRF transaction"
        );
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        uint256 playersIndex = randomness % currentJackpot.players.length;
        currentJackpot.winner = payable(currentJackpot.players[playersIndex]);
        payable(currentJackpot.winner).transfer(currentJackpot.size);
        index++;
        jackpotActive = false;
        emit JackpotResult(currentJackpot.winner, currentJackpot.size);
    }
}
