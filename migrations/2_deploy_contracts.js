var ERC20Token = artifacts.require("./ERC20Token.sol");
var Utils = artifacts.require("./Utils.sol");
var Payroll = artifacts.require("./Payroll.sol");
var ExchangeOracle = artifacts.require("./ExchangeOracle.sol");

module.exports = async function(deployer) {
  deployer.deploy(ERC20Token, 100000, 'USD', 1, 'USD')
  .then(() => deployer.deploy(Utils))
  .then(() => deployer.link(Utils, Payroll))
  .then(() => deployer.link(Utils, ExchangeOracle))
  .then(() => deployer.deploy(ExchangeOracle, [ERC20Token.address], [1]))
  .then(() => deployer.deploy(Payroll, ExchangeOracle.address));
};
