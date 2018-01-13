pragma solidity ^0.4.8;

import "./Utils.sol";
import "./ERC20Token.sol";
import "./ExchangeOracle.sol";

/*BUG: payday approves employee in using payroll's funds, however calculations based on "balanceOf" if employee doesn't withdraw immediately*/
/*SOLUTION: mapping of supported tokens to their actual contract's balances + addTokenFunds implementation */
contract Payroll is ExchangeSubscriber {
  struct Employee {
      address account;
      address[] allowedTokens; 
      uint256[] distribution;
      uint256 yearlyUSDSalary;
      uint lastPayroll;
      uint lastAllocDistribution;
  }

  address public owner;
  address public oracle;

  mapping (uint256 => Employee) employees;
  mapping (address => uint256) exchangeRate;

  /* Solidity doesn't support generics to allow a portable library for iterable mapping type */
  /* thus we are going to double use storage */
  address[] supportedTokens;
  uint totalYearlyUSDSalaries;
  uint totalEmployees;

  event NewEmployee(uint256 employeeId);

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  modifier onlyOracle() {
    require(msg.sender == oracle);
    _;
  }

  modifier onlyEmployee() {
    require(employees[Utils.fromAddrToInt(msg.sender)].account == msg.sender);
    _;
  }

  modifier positive(uint number) {
    require(number > 0);
    _;
  }


  function Payroll() public {
    totalEmployees = 0;
    owner = tx.origin; // we still want to know the person responsible for our payroll :P
                       // and allow one to manage from within different contracts
  }

  function subscribeToOracle(address oracleAddr) public onlyOwner {
    oracle = oracleAddr;
    ExchangeOracle(oracleAddr).subscribe();
  }
  /* OWNER ONLY */
  /* @return unique employee id */
  function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) external onlyOwner positive(initialYearlyUSDSalary) {
    /* more expensive then a simple id counter, but doesn't loose ids space as employees get removed  */
    for (uint i = 0; i < allowedTokens.length; i++) {
      /* verify that the address is indeed a ERC20 token, otherwise reverts */
      require(ERC20Token(allowedTokens[i]).totalSupply() > 0);
    }

    uint256 employeeId = Utils.fromAddrToInt(accountAddress);
    totalYearlyUSDSalaries += initialYearlyUSDSalary;
    employees[employeeId] = Employee(accountAddress, allowedTokens, new uint[](0), initialYearlyUSDSalary, 0, 0);
    if (allowedTokens.length == 1) {
      employees[employeeId].distribution.push(initialYearlyUSDSalary);
    }
    totalEmployees += 1;
    NewEmployee(employeeId);
  }

  function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) public onlyOwner positive(yearlyUSDSalary) {
    employees[employeeId].yearlyUSDSalary = yearlyUSDSalary;
  }
  function removeEmployee(uint256 employeeId) public onlyOwner {
    require(totalEmployees > 0);

    totalYearlyUSDSalaries -= employees[employeeId].yearlyUSDSalary;
    delete employees[employeeId];
    totalEmployees -= 1;
  }

  function addFunds() public payable onlyOwner {
    /* adding funds ONLY for contract's operations (not payouts) */
  }

  function escapeHatch() public onlyOwner {
    selfdestruct(owner);
  }
  /*function addTokenFunds()? // Use approveAndCall or ERC223 tokenFallback*/

  function getEmployeeCount() public onlyOwner constant returns (uint256) {
    return totalEmployees;
  }

  function getEmployee(uint256 employeeId) public onlyOwner constant returns (address employee, uint256 yearlyUSDSalary, uint256 lastPayroll) {
    Employee memory emp = employees[employeeId];
    return (emp.account, emp.yearlyUSDSalary, emp.lastPayroll);
  }

  /* MONTHLY BURNRATE */
  function calculatePayrollBurnrate() public onlyOwner constant returns (uint256) {
    return totalYearlyUSDSalaries / 12;
  }

  /* DAYS RUNWAY */
  function calculatePayrollRunway() public onlyOwner constant returns (uint256) {
    /*For simplicity we will only take  USD balances from "supported"/oraclised tokens and divide by "daily" spending */
    uint256 totalUSDAvailable = 0;

    for (uint i = 0; i < supportedTokens.length; i++) {
      if (exchangeRate[supportedTokens[i]] > 0) {
        totalUSDAvailable += ERC20Token(supportedTokens[i]).balanceOf(this) / exchangeRate[supportedTokens[i]];
      }
    }

    return totalUSDAvailable / ( calculatePayrollBurnrate() / 30);
  }
 // Days until the contract can run out of funds

  /* EMPLOYEE ONLY */
  function determineAllocation(address[] tokens, uint256[] distribution) external onlyEmployee {
    /* Assume distribution is in USD */
    uint256 employeeId = Utils.fromAddrToInt(msg.sender);
    Employee memory employee = employees[employeeId];
    /* Allowed once 6 months */
    require(employee.lastAllocDistribution < now - 6 * 4 weeks);
    require(tokens.length == distribution.length);
    require(tokens.length == employee.allowedTokens.length);

    uint256 totalDistribution = 0;
    employee.distribution = new uint256[](distribution.length);

    for (uint i = 0; i < tokens.length; i++) {
      /* Require tokens to be listed in the same order as allowed tokens during initialization to reduce the cost */
      require(tokens[i] == employee.allowedTokens[i]);

      employee.distribution[i] = distribution[i];
      totalDistribution += distribution[i];
    }

    assert(totalDistribution == employee.yearlyUSDSalary);

    employee.lastAllocDistribution = now;
    employees[employeeId] = employee;
  }

  function payday() public onlyEmployee {
    uint employeeId = Utils.fromAddrToInt(msg.sender);
    Employee memory employee = employees[employeeId];

    require(employee.lastPayroll < now - 4 weeks);
    require(employee.allowedTokens.length == employee.distribution.length);

    for (uint i = 0; i < employee.allowedTokens.length; i++) {
      address token = employee.allowedTokens[i];
      assert(exchangeRate[token] > 0);
      uint balance = ERC20Token(token).allowance(this, employee.account) + ((employee.distribution[i] / 12) / exchangeRate[token]);
      ERC20Token(token).approve(employee.account, balance);
    }
    employees[employeeId].lastPayroll = now;
  }

  /* ORACLE ONLY */
  /* Simple solutions works as long as we don't want to blacklist some tokens */
  function setExchangeRate(address token, uint256 usdExchangeRate) public onlyOracle {
    /* verify address is a token */
    require(ERC20Token(token).totalSupply() > 0);

    if (exchangeRate[token] == 0) {
      supportedTokens.push(token);
    }

    exchangeRate[token] = usdExchangeRate;
  }
}
