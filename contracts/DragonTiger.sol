pragma solidity ^0.4.19;

import './GTBToken.sol';
import './Owned.sol';

contract DragonTiger is Owned, GTBToken {
    string constant version = "1.0.0";

    address public drawer;

    mapping(address => uint[2][]) playerTickets;

    Game[] public games;

    uint public gameIndex;

    uint public gameIndexToBuy;

    uint public checkGameIndex;

    uint public disableBuyingTime;

    bool public buyEnable = true;

    uint public intervalTime;

    uint public ticketCountMax;

    uint public nextPrice;

    uint public percent = 9500;

    uint public percentDivider = 10000;

    string[] public playType = new string[](7);

    struct Ticket {
        address user;
        uint number;
        uint amount;
    }

    struct WinTicket {
        address user;
        string bet;
        uint winAmount;
    }

    struct Game {
        uint startTime;
        uint jackpot;
        uint reserve;
        uint price;
        bytes winNumbers;
        mapping(uint => string) winNumbersMap;
        Ticket[] tickets;
        WinTicket[] winTickets;
        uint blockIndex;
        string blockHash;
    }

    modifier onlyDrawer() {
        require(msg.sender == drawer);
        _;
    }
    function setDrawer(address _drawer) public onlyOwner {
        drawer = _drawer;
    }


    function RealTimeLottery() public {
        drawer = msg.sender;

        disableBuyingTime = 5 minutes;
        intervalTime = 1 hours;

        games.length = 2;
        nextPrice = 10000;

        ticketCountMax = 1000000;

        games[0].startTime = now;
        games[1].startTime = games[0].startTime + intervalTime;
        games[0].price = nextPrice;
        games[1].price = nextPrice;

        playType[0] = "big";
        playType[1] = "small";
        playType[2] = "single";
        playType[3] = "double";
        playType[4] = "dragon";
        playType[5] = "tiger";
        playType[6] = "equal";
    }

    function buyTicket(string _playType, uint value) public {
        require(buyEnable);
        require(value > 0);
        uint playTypeIndex = getPlayTypeIndex(_playType);
        require(playTypeIndex < playType.length);

        Game storage game = games[gameIndexToBuy];
        require(game.tickets.length + 1 <= ticketCountMax);

        bool flag = transferFrom(msg.sender, getCurrentContractAddress(), value);

        if(flag) {
            playerTickets[msg.sender].push([gameIndexToBuy, game.tickets.length]);
            game.tickets.push(Ticket(msg.sender, playTypeIndex, value));
        }
    }

    function drawGame(uint blockIndex, string blockHash) public onlyDrawer {
        Game storage game = games[gameIndex];

        require(isNeedDrawGame(blockIndex));

        game.blockIndex = blockIndex;
        game.blockHash = blockHash;

        uint allAmount = game.tickets.length * game.price;

        uint[] memory winNumbers_ = getWinNumbers(blockHash);

        uint sum = 0;
        for(uint i = 0; i < winNumbers_.length; i++) {
            game.winNumbers[i] = byte(winNumbers_[i]);
            sum += winNumbers_[i];
        }

        if(sum > 22) {
            game.winNumbersMap[1] = playType[0];
        } else {
            game.winNumbersMap[1] = playType[1];
        }

        if(sum % 2 == 0) {
            game.winNumbersMap[2] = playType[2];
        } else {
            game.winNumbersMap[2] = playType[3];
        }


        if(winNumbers_[0] > winNumbers_[winNumbers_.length - 1]) {
            game.winNumbersMap[3] = playType[4];
        } else if(winNumbers_[0] < winNumbers_[winNumbers_.length - 1]) {
            game.winNumbersMap[3] = playType[5];
        } else {
            game.winNumbersMap[3] = playType[6];
        }

        require(balanceOf(getCurrentContractAddress()) == allAmount);
        transferFrom(getCurrentContractAddress(), drawer, allAmount);

        games.length++;
        gameIndex++;
        games[gameIndex + 1].startTime = games[gameIndex].startTime + intervalTime;
        games[gameIndex + 1].price = nextPrice;
    }

    function calculateWinner() public onlyDrawer {
        require(checkGameIndex == (gameIndex - 1));
        Game storage game = games[checkGameIndex];

        uint k = 0;
        while (k  < game.tickets.length) {
            Ticket storage _ticket = game.tickets[k++];
            uint _number = _ticket.number;
            address _user = _ticket.user;
            uint _amount = _ticket.amount;
            if((_number == 0 || _number == 1) && (getPlayTypeIndex(game.winNumbersMap[1]) == _number)) {
                uint winAmount_1 = (percent + percentDivider) / percentDivider * _amount;
                game.winTickets.push(WinTicket(_user, game.winNumbersMap[1], winAmount_1));
            } else if((_number == 2 || _number == 3) && (getPlayTypeIndex(game.winNumbersMap[2]) == _number)) {
                uint winAmount_2 = (percent + percentDivider) / percentDivider * _amount;
                game.winTickets.push(WinTicket(_user, game.winNumbersMap[2], winAmount_2));
            } else if((_number == 4 || _number == 5) && (getPlayTypeIndex(game.winNumbersMap[3]) == _number)) {
                uint winAmount_3 = 2 * _amount;
                game.winTickets.push(WinTicket(_user, game.winNumbersMap[3], winAmount_3));
            } else if(_number == 6 && getPlayTypeIndex(game.winNumbersMap[3]) == _number) {
                uint winAmount_4 = 4 * _amount;
                game.winTickets.push(WinTicket(_user, game.winNumbersMap[3], winAmount_4));
            }
        }
        checkGameIndex++;
    }

    function getWinTickets(uint gameIndex_, uint offset, uint count) public view returns(uint[] wins) {
        Game storage game = games[gameIndex_];
        uint k = 0;
        uint n = offset + count;

        WinTicket[] storage winTickets = game.winTickets;
        if(winTickets.length <= offset) {
            return wins;
        }
        if(n <= winTickets.length) {
            wins = new uint[](count * 3);
            for(uint i = offset; i < n; i++) {
                WinTicket storage winTicket = winTickets[i];
                wins[k++] = uint(winTicket.user);
                wins[k++] = getPlayTypeIndex(winTicket.bet);
                wins[k++] = winTicket.winAmount;
            }
        } else {
            uint currentIndex = winTickets.length - offset;
            wins = new uint[](currentIndex * 3);
            for(uint j = offset; j < offset + currentIndex; j++) {
                WinTicket storage winTicket_ = winTickets[j];
                wins[k++] = uint(winTicket_.user);
                wins[k++] = getPlayTypeIndex(winTicket_.bet);
                wins[k++] = winTicket_.winAmount;
            }
        }
        return wins;
    }

    function getWinNumbers(string blockHash) public pure returns (uint[]){
        bytes32 random = keccak256(blockHash);
        uint[] memory allNumbers = new uint[](10);
        uint[] memory winNumbers = new uint[](5);

        for (uint i = 0; i < 10; i++) {
            allNumbers[i] = i;
        }

        for (i = 0; i < 5; i++) {
            uint r = (uint(random[i * 4]) + (uint(random[i * 4 + 1]) << 8) + (uint(random[i * 4 + 2]) << 16) + (uint(random[i * 4 + 3]) << 24)) % 10;
            winNumbers[i] = allNumbers[r];
        }
        return winNumbers;
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

    function getCurrentContractAddress() public view returns (address) {
        return address(this);
    }

    function getCurrentContractBalance() private view returns (uint) {
        return getCurrentContractAddress().balance;
    }

    function transferToReceive(address receive, uint bonus) public payable onlyDrawer {
        receive.transfer(bonus);
    }

    function getPlayTypeIndex(string _playType) public view returns (uint) {
        for(uint i = 0; i < playType.length; i++) {
            if(keccak256(playType[i]) == keccak256(_playType)) {
                return i;
            }
        }
        return playType.length;
    }
}
