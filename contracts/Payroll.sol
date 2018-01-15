pragma solidity ^0.4.8;

import "./Utils.sol";
import "./ERC20Token.sol";
import "./ExchangeOracle.sol";

/* POSSIBLE ENHANCEMENT: allow multiple exchanges */
contract Payroll is ExchangeSubscriber, tokenRecipient {
  using Utils for address[];

  struct Employee {
      address account;
      address[] allowedTokens;
      uint256[] distribution;
      uint256 yearlyUSDSalary;
      uint lastPayroll;
      uint lastAllocDistribution;
  }

  struct Token {
    uint256 exchangeRate;
    uint256 balanceAvailable;
  }

  address public owner;
  address public oracle;

  mapping (uint256 => Employee) employees;
  /* Solidity doesn't support generics to allow a portable library for iterable mapping type */
  /* thus we are going to double use storage */
  address[] supportedTokens;
  mapping (address => Token) tokensMap;

  uint totalYearlyUSDSalaries;
  uint totalEmployees;

  event NewEmployee(uint256 employeeId);
  event NewExchangeRate(address tokenName, uint256 price);
  event AddedTokenFunds(address tokenName, uint256 amount);

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

  modifier onlySupportedToken() {
    require(isSupportedToken(msg.sender));
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

  function isSupportedToken(address addr) public constant returns(bool) {
    return supportedTokens.contains(addr);
  }

  function isEmployeeId(uint employeeId) internal constant returns(bool) {
    return employees[employeeId].account != address(0x0);
  }

  function subscribeToOracle(address oracleAddr) public onlyOwner {
    oracle = oracleAddr;
    ExchangeOracle(oracleAddr).subscribe();
  }
  /* OWNER ONLY */
  /* @return unique employee id */
  function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) external onlyOwner positive(initialYearlyUSDSalary) {
    for (uint i = 0; i < allowedTokens.length; i++) {
      /* verify that the address is indeed an ERC20 token */
      require(isSupportedToken(allowedTokens[i]));
    }
    /* more expensive and  then a simple id counter, but doesn't loose ids space as employees get removed  */
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
    require(isEmployeeId(employeeId));
    employees[employeeId].yearlyUSDSalary = yearlyUSDSalary;
  }
  function removeEmployee(uint256 employeeId) public onlyOwner {
    require(totalEmployees > 0);
    require(isEmployeeId(employeeId));

    totalYearlyUSDSalaries -= employees[employeeId].yearlyUSDSalary;
    delete employees[employeeId];
    totalEmployees -= 1;
  }

  function addFunds() public payable onlyOwner {}

  function escapeHatch() public onlyOwner {
    selfdestruct(owner);
  }

  function getEmployeeCount() public onlyOwner constant returns (uint256) {
    return totalEmployees;
  }

  function getEmployee(uint256 employeeId) public onlyOwner constant returns (address employee, uint256 yearlyUSDSalary, uint256 lastPayroll) {
    require(isEmployeeId(employeeId));

    Employee memory emp = employees[employeeId];
    return (emp.account, emp.yearlyUSDSalary, emp.lastPayroll);
  }

  /* Adding token funds with "approveAndCall" */
  function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) onlySupportedToken public {
    ERC20Token(msg.sender).transferFrom(_from, this, _value);
    tokensMap[msg.sender].balanceAvailable += _value;
    AddedTokenFunds(msg.sender, _value);
  }

  /* MONTHLY BURNRATE */
  function calculatePayrollBurnrate() public onlyOwner constant returns (uint256) {
    return totalYearlyUSDSalaries / 12;
  }

  /* DAYS RUNWAY */
  function calculatePayrollRunway() public onlyOwner constant returns (uint256) {
    /*For simplicity we will only take token balances from "supported"/oraclised tokens and divide by "daily" spending */
    uint256 totalUSDAvailable = 0;

    for (uint i = 0; i < supportedTokens.length; i++) {
      Token memory token = tokensMap[supportedTokens[i]];
      if (token.exchangeRate > 0) {
        totalUSDAvailable += token.balanceAvailable * token.exchangeRate;
      }
    }

    return totalUSDAvailable / ( calculatePayrollBurnrate() / 30);
  }

  /* EMPLOYEE ONLY */

 // Days until the contract can run out of funds
  /* @param tokens listed in the same order as during addEmployee */
  /* @param distribution totals to yearlyUSDSalary */
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
      /* Require tokens to be listed in the same order as allowed tokens during initialization to avoid sorting cost */
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

      assert(tokensMap[token].exchangeRate > 0);
      uint salary = ((employee.distribution[i] / 12) / tokensMap[token].exchangeRate);

      assert(tokensMap[token].balanceAvailable - salary >= 0);
      uint approvedBalance = ERC20Token(token).allowance(this, employee.account) + salary;
      ERC20Token(token).approve(employee.account, approvedBalance);
      tokensMap[token].balanceAvailable -= salary;
    }
    employees[employeeId].lastPayroll = now;
  }

  /* ORACLE ONLY */
  /* TRUSTED INPUT */
  function setExchangeRate(address token, uint256 usdExchangeRate) public onlyOracle {
    tokensMap[token].exchangeRate = usdExchangeRate;
    NewExchangeRate(token, usdExchangeRate);
  }

  /*called once right after subscription*/
  function supportedExchangeTokens(address[] tokens) public {
    supportedTokens = tokens;
  }
}
