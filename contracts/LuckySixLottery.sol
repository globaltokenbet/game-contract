pragma solidity ^0.4.19;

import './Owned.sol';
import './GTBToken.sol';

contract LuckySixLottery is Owned, GTBToken {
    string constant version = "1.0.0";

    address public drawer;

    mapping(address => uint[2][]) playerTickets;

    Game[] public games;

    uint public gameIndex;

    uint public gameIndexToBuy;

    uint public checkGameIndex;

    uint public numbersCount;

    uint public ticketCountMax;

    uint public redBallCount;

    uint public blueBallCount;

    uint public jackpotGuaranteedEth;

    uint public jackpotGuaranteedToken;

    uint public disableBuyingTime;

    address public incomeWallet;

    bool public buyEnable = true;

    uint public nextPrice;

    uint public sharePercent;

    uint public intervalTime;

    uint public rate;

    uint public percentDivider = 10000;

    struct Ticket {
        address user;
        bytes redNumbers;
        bytes blueNumbers;
    }

    struct Win {
        uint index;
        address wallet;
        bytes redNumbers;
        bytes blueNumbers;
        uint amountEth;
        uint amountToken;
        uint level;
    }

    struct Game {
        uint startTime;
        uint price;
        mapping(string => uint) exchangeRate;
        bytes winRedNumbers;
        bytes winBlueNumbers;
        mapping(byte => bool) winRedNumbersMap;
        mapping(byte => bool) winBlueNumbersMap;
        mapping(uint => uint) winnerCount;
        Ticket[] tickets;
        Win[] wins;
        uint blockIndex;
        string blockHash;
        mapping(string => uint) ticketSize;
    }

    modifier onlyDrawer() {
        require(msg.sender == drawer);
        _;
    }

    function setDrawer(address _drawer) public onlyOwner {
        drawer = _drawer;
    }

    function MarkSixLottery() public {

        drawer = msg.sender;
        incomeWallet = msg.sender;

        disableBuyingTime = 30 minutes;
        intervalTime = 2 hours;

        nextPrice = 2 ether;
        rate = 10000;

        games.length = 2;

        numbersCount = 6;
        redBallCount = 5;
        blueBallCount = 1;
        jackpotGuaranteedEth = 1000 ether;
        ticketCountMax = 1000000;
        sharePercent = 2000;

        games[0].price = nextPrice;
        games[0].startTime = 1520553600;
        games[0].exchangeRate['GTB'] = rate;

        games[1].price = nextPrice;
        games[1].startTime = games[0].startTime + intervalTime;
        games[1].exchangeRate['GTB'] = rate;
    }

    function() public payable {
        uint remainder = msg.data.length % numbersCount;
        require(remainder == 0);
        uint[] memory numbers = new uint[](msg.data.length);
        for (uint i = 0; i < numbers.length; i++) {
            numbers[i] = uint((msg.data[i] >> 4) & 0xF) * 10 + uint(msg.data[i] & 0xF);
        }
        buyTicket(numbers);
    }

    function buyTicket(uint[] numbers) public payable {
        require(buyEnable);
        require(numbers.length % numbersCount == 0);

        Game storage game = games[gameIndexToBuy];

        uint buyTicketCount = numbers.length / numbersCount;
        require(msg.value == game.price * buyTicketCount);
        require(game.tickets.length + buyTicketCount <= ticketCountMax);

        uint i = 0;
        while (i < numbers.length) {

            bytes memory redNumber_ = new bytes(numbersCount - 1);
            bytes memory blueNumber_ = new bytes(1);

            for (uint j = 0; j < numbersCount; j++) {
                byte temp = byte(numbers[i++]);
                if(j < (numbersCount - 1)) {
                    redNumber_[j] = temp;
                } else {
                    blueNumber_[0] = temp;
                }
            }

            require(noDuplicates(redNumber_));

            playerTickets[msg.sender].push([gameIndexToBuy, game.tickets.length]);
            game.tickets.push(Ticket(msg.sender, redNumber_, blueNumber_));
            game.ticketSize['ETH']++;
        }
    }

    function buyTicketToken(uint[] numbers, uint value) public {
        require(buyEnable);
        require(numbers.length % numbersCount == 0);

        Game storage game = games[gameIndexToBuy];

        uint buyTicketCount = numbers.length / numbersCount;
        require(value == game.price / game.exchangeRate['GTB'] * buyTicketCount);
        require(game.tickets.length + buyTicketCount <= ticketCountMax);

        bool flag = transferFrom(msg.sender, getCurrentContractAddress(), value);

        if(flag) {
            uint i = 0;
            while (i < numbers.length) {

                bytes memory redNumber_ = new bytes(numbersCount - 1);
                bytes memory blueNumber_ = new bytes(1);

                for (uint j = 0; j < numbersCount; j++) {
                    byte temp = byte(numbers[i++]);
                    if(j < (numbersCount - 1)) {
                        redNumber_[j] = temp;
                    } else {
                        blueNumber_[0] = temp;
                    }
                }

                require(noDuplicates(redNumber_));

                playerTickets[msg.sender].push([gameIndexToBuy, game.tickets.length]);
                game.tickets.push(Ticket(msg.sender, redNumber_, blueNumber_));
                game.ticketSize['GTB']++;
            }
        }
    }

    function drawGame(uint blockIndex, string blockHash) public onlyDrawer {
        Game storage game = games[gameIndex];

        require(isNeedDrawGame(blockIndex));

        game.blockIndex = blockIndex;
        game.blockHash = blockHash;

        bytes memory winRedNumbers = new bytes(5);
        bytes memory winBlueNumbers = new bytes(1);
        (winRedNumbers, winBlueNumbers) = getWinNumbers(blockHash);
        game.winRedNumbers = winRedNumbers;
        game.winBlueNumbers = winBlueNumbers;

        for (uint i = 0; i < game.winRedNumbers.length; i++) {
            game.winRedNumbersMap[game.winRedNumbers[i]] = true;
        }
        game.winBlueNumbersMap[game.winBlueNumbers[0]] = true;

        uint k = 0;
        uint winnerOne = 0;
        uint winnerTwo = 0;
        while (k < game.tickets.length) {
            Ticket storage ticket = game.tickets[k];
            uint winNumbersCount = getEqualCount(ticket.redNumbers, ticket.blueNumbers, game);
            if(winNumbersCount == 6) {
                game.wins.push(Win(gameIndex, ticket.user, winRedNumbers, winBlueNumbers, 0, 0, 1));
                winnerOne++;
            } else if (winNumbersCount == 5) {
                game.wins.push(Win(gameIndex, ticket.user, winRedNumbers, ticket.blueNumbers, 0, 0, 2));
                winnerTwo++;
            }
            k++;
        }

        uint allAmountEth = game.ticketSize['ETH'] * game.price;
        uint allAmountToken = game.ticketSize['GTB']  * game.price / game.exchangeRate['GTB'];

        game.winnerCount[0] = winnerOne;
        game.winnerCount[1] = winnerTwo;

        jackpotGuaranteedEth += (allAmountEth * (percentDivider - sharePercent) / percentDivider);
        jackpotGuaranteedToken += (allAmountToken * (percentDivider - sharePercent) / percentDivider);

        require(getCurrentContractBalance() == allAmountEth);
        transferToReceive(msg.sender, allAmountEth);

        require(balanceOf(getCurrentContractAddress()) == allAmountToken);
        transferFrom(getCurrentContractAddress(), drawer, allAmountToken);

        games.length++;
        gameIndex++;
        games[gameIndex + 1].startTime = games[gameIndex].startTime + intervalTime;
        games[gameIndex + 1].price = nextPrice;
        games[gameIndex + 1].exchangeRate['GTB'] = rate;
    }

    function calculateWinner() public onlyDrawer {
        require(checkGameIndex == (gameIndex - 1));
        Game storage game = games[checkGameIndex];
        uint firstPrizeEth = 0;
        uint secondPrizeEth = 0;
        uint firstPrizeToken = 0;
        uint secondPrizeToken = 0;
        if(game.winnerCount[1] > 0  || game.winnerCount[0] == 0) {
            secondPrizeEth = (jackpotGuaranteedEth  * 1000 / percentDivider) / game.winnerCount[1];
            secondPrizeToken = (jackpotGuaranteedToken  * 1000 / percentDivider) / game.winnerCount[1];
            for(uint x = 0; x < game.wins.length; x++) {
                game.wins[x].amountEth = secondPrizeEth;
                game.wins[x].amountToken = secondPrizeToken;
            }
        } else if(game.winnerCount[1] > 0  || game.winnerCount[0] > 0) {
            secondPrizeEth = (jackpotGuaranteedEth * 1000 / percentDivider) / game.winnerCount[1];
            firstPrizeEth = (jackpotGuaranteedEth * 7000 / percentDivider) / game.winnerCount[0];
            secondPrizeToken = (jackpotGuaranteedToken * 1000 / percentDivider) / game.winnerCount[1];
            firstPrizeToken = (jackpotGuaranteedToken * 7000 / percentDivider) / game.winnerCount[0];
            for(uint y = 0; y < game.wins.length; y++) {
                if(game.wins[y].level == 1) {
                    game.wins[y].amountEth = firstPrizeEth;
                    game.wins[y].amountToken = firstPrizeToken;
                } else if(game.wins[y].level == 2) {
                    game.wins[y].amountEth = secondPrizeEth;
                    game.wins[y].amountToken = secondPrizeToken;
                }
            }
        } else if(game.winnerCount[1] == 0  || game.winnerCount[0] > 0) {
            firstPrizeEth = (jackpotGuaranteedEth * 8000 / percentDivider) / game.winnerCount[0];
            firstPrizeToken = (jackpotGuaranteedToken * 8000 / percentDivider) / game.winnerCount[0];
            for(uint z = 0; z < game.wins.length; z++) {
                game.wins[z].amountEth = firstPrizeEth;
                game.wins[z].amountToken = firstPrizeToken;
            }
        }
        checkGameIndex++;
    }

    function getWinNumbers(string blockHash) public pure returns (bytes, bytes){
        bytes32 random = keccak256(blockHash);
        bytes memory allRedNumbers = new bytes(40);
        bytes memory allBlueNumbers = new bytes(9);
        bytes memory winRedNumbers = new bytes(5);
        bytes memory winBlueNumber = new bytes(1);

        for (uint i = 0; i < 40; i++) {
            allRedNumbers[i] = byte(i + 1);
            if(i < 9) {
                allBlueNumbers[i] = byte(i + 1);
            }
        }

        for (i = 0; i < 5; i++) {
            uint n = 40 - i;
            uint r = (uint(random[i * 4]) + (uint(random[i * 4 + 1]) << 8) + (uint(random[i * 4 + 2]) << 16) + (uint(random[i * 4 + 3]) << 24)) % (n + 1);
            winRedNumbers[i] = allRedNumbers[r];
            allRedNumbers[r] = allRedNumbers[n - 1];
        }

        uint m = 9;
        uint t = (uint(random[i * 4]) + (uint(random[i * 4 + 1]) << 8) + (uint(random[i * 4 + 2]) << 16) + (uint(random[i * 4 + 3]) << 24)) % (m + 1);
        winBlueNumber[0] = allBlueNumbers[t];

        return (winRedNumbers, winBlueNumber);
    }

    function noDuplicates(bytes array) private pure returns (bool){
        for (uint i = 0; i < array.length - 1; i++) {
            for (uint j = i + 1; j < array.length; j++) {
                if (array[i] == array[j]) return false;
            }
        }
        return true;
    }

    function isNeedCloseCurrentGame() private view returns (bool){
        return games[gameIndex].startTime < disableBuyingTime + now && gameIndexToBuy == gameIndex;
    }

    function closeCurrentGame(uint blockIndex) public onlyDrawer {
        require(isNeedCloseCurrentGame());

        games[gameIndex].blockIndex = blockIndex;
        gameIndexToBuy = gameIndex + 1;
    }

    function isNeedDrawGame(uint blockIndex) private view returns (bool){
        Game storage game = games[gameIndex];
        return blockIndex > game.blockIndex && game.blockIndex > 0 && now >= game.startTime;
    }

    function getEqualCount(bytes redNumbers_, bytes blueNumbers_, Game storage game) private view returns (uint count){
        for (uint i = 0; i < redNumbers_.length; i++) {
            if (game.winRedNumbersMap[redNumbers_[i]]) {
                count++;
            }
        }
        if(count == redNumbers_.length) {
            for (uint j = 0; j < blueNumbers_.length; i++) {
                if (game.winBlueNumbersMap[blueNumbers_[j]]) {
                    count++;
                }
            }
        }
    }

    function getCurrentContractAddress() private view returns (address) {
        return address(this);
    }

    function getCurrentContractBalance() private view returns (uint) {
        return getCurrentContractAddress().balance;
    }

    function transferToReceive(address receive, uint bonus) public payable onlyDrawer {
        receive.transfer(bonus);
    }
}