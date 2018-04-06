var MicroDex = artifacts.require("./MicroDex.sol");
var LavaDex = artifacts.require("./LavaDex.sol");

module.exports = function(deployer) {
  deployer.deploy(LavaDex);
};
