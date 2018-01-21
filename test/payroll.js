var Payroll = artifacts.require("./Payroll.sol");
var ExchangeOracle = artifacts.require("./ExchangeOracle.sol");
var ERC20Token = artifacts.require("./ERC20Token.sol");
var Utils = artifacts.require("./Utils.sol");
var utils = require("../utils/utils");

// logging line execution
function test() {
    console.log('Test Trace')
    console.trace();
}

contract('Payroll', ([owner, employee1, employee2]) => {

  const employee1Salary = 100;

  let payrollInstance;
  let exchangeInstance;
  let tokenInstance;
  let utilsInstance;

  beforeEach(async () => {
    payrollInstance = await Payroll.deployed(100000, 'USD');
    exchangeInstance = await ExchangeOracle.deployed();
    tokenInstance = await ERC20Token.deployed();
    utilsInstance = await Utils.deployed();

    test();
    await payrollInstance.subscribeToOracle(exchangeInstance.address);
    test();
    await tokenInstance.approveAndCall(payrollInstance.address, employee1Salary + 400, "", {from: owner});
  })

  it("tests interactions", async () => {
    test();
    await exchangeInstance.updatePrice(tokenInstance.address, 1);
    test();
    const transaction = await payrollInstance.addEmployee(employee1, [tokenInstance.address], employee1Salary)
    const transaction2 = await payrollInstance.addEmployee(employee2, [tokenInstance.address], 1000)
    const employee1Id = transaction.logs[0].args.employeeId.valueOf();

    assert.equal((await payrollInstance.calculatePayrollBurnrate.call()).valueOf(), 91, "calculatePayrollBurnrate");
    assert.equal((await payrollInstance.calculatePayrollRunway.call()).valueOf(), 166, "calculatePayrollRunway");
    assert.equal((await payrollInstance.getEmployeeCount.call()).valueOf(), 2, "# of employees");

    test();
    await payrollInstance.payday({from: employee1});

    test();
    await tokenInstance.transferFrom(payrollInstance.address, employee1, Math.floor(employee1Salary / 12), {from: employee1});
    test();
    assert.equal((await tokenInstance.balanceOf.call(employee1)).valueOf(), Math.floor(employee1Salary / 12), "balance of employee1");
    test();
    const employeeData = (await payrollInstance.getEmployee(employee1Id)).valueOf();
    assert.equal(employeeData[0], employee1);
    assert.equal(employeeData[1], employee1Salary);
  });
});
