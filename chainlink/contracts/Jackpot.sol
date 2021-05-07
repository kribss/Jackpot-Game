// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.6;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract Jackpot is VRFConsumerBase {
    event LotteryResult(address winner, uint256 ammount);

    bytes32 internal keyHash;
    uint256 internal fee;

    uint256 lotterySize;
    uint256 betSize;
    uint256 maxPlayers;

    address payable winner;

    address[] players;

    address owner;

    mapping(address => string) playerInfo;

    modifier onlyOwner() {
        require(msg.sender == owner, "Function only callable by owner");
        _;
    }

    constructor(uint256 _betSize, uint256 _maxPlayers) public {
        betSize = _betSize;
        maxPlayers = _maxPlayers;
    }

    function enterLottery(string memory _name) public payable {
        require(msg.value == betSize, "Incorrect bet ammount");
        players.push(msg.sender);
        lotterySize += msg.value;
        playerInfo[msg.sender] = _name;

        if (players.size >= maxPlayers) {
            getRandomNumber();
        }
    }

    function getRandomNumber(uint256 userProvidedSeed)
        public
        returns (bytes32 requestId)
    {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        uint256 index = randomness % players.length;
        winner = payable(players[index]);
        winner.transfer(address(this).balance);
        emit LotteryResult(winner, lotterySize);
    }

    function changeEntryBetSize(uint256 _betSize) public onlyOwner {
        betSize = _betSize;
    }

    function changeMaxPlayerSize(uint256 _maxPlayers) public onlyOwner {
        maxPlayers = _maxPlayers;
    }
}
