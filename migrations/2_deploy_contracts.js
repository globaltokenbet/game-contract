var LuckySixLottery = artifacts.require("LuckySixLottery");
// var RealTimeLottery = artifacts.require("RealTimeLottery");
// var GTBToken = artifacts.require("GTBToken");

module.exports = function(deployer) {
      deployer.deploy(LuckySixLottery);
};