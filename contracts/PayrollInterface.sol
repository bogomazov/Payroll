pragma solidity ^0.4.8;

// For the sake of simplicity lets assume USD is a ERC20 token
// Also lets assume we can 100% trust the exchange rate oracle
contract PayrollInterface {
  /* OWNER ONLY */
  function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) external;
  function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) public;
  function removeEmployee(uint256 employeeId) public;

  function addFunds() public payable;
  function escapeHatch() public;
  // function addTokenFunds()? // Use approveAndCall or ERC223 tokenFallback

  function getEmployeeCount() public constant returns (uint256);
  function getEmployee(uint256 employeeId) public constant returns (address employee, uint256 yearlyUSDSalary, uint256 lastPayroll); // Return all important info too

  function calculatePayrollBurnrate() public constant returns (uint256); // Monthly usd amount spent in salaries
  function calculatePayrollRunway() public constant returns (uint256); // Days until the contract can run out of funds

  /* EMPLOYEE ONLY */
  function determineAllocation(address[] tokens, uint256[] distribution) external; // only callable once every 6 months
  function payday() public; // only callable once a month

  /* ORACLE ONLY */
  function setExchangeRate(address token, uint256 usdExchangeRate) public; // uses decimals from token
}
