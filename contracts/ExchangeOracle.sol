pragma solidity ^0.4.8;

import "./ERC20Token.sol";
import "./Utils.sol";

interface ExchangeSubscriber {
  function setExchangeRate(address token, uint256 usdExchangeRate) public;
  /* called once right after subscription */
  function supportedExchangeTokens(address[] tokens) public;
}

contract ExchangeOracle {
  using Utils for address[];

  address owner;
  address[] subscribers;
  address[] supportedTokens;
  mapping (address => uint) tokenPrice;

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function ExchangeOracle(address[] tokens, uint[] prices) public {
    require(tokens.length > 0);
    require(tokens.length  == prices.length);

    owner = msg.sender;
    supportedTokens = tokens;

    for (uint i = 0; i < tokens.length; i++) {
      /* verify subscriber interface */
      require(prices[i] > 0);
      tokenPrice[tokens[i]] = prices[i];
    }
  }

  /* subscribes to all supported tokens */
  function subscribe() public {
    ExchangeSubscriber(msg.sender).supportedExchangeTokens(supportedTokens);
    for (uint i = 0; i < supportedTokens.length; i++) {
      /* verify subscriber interface */
      ExchangeSubscriber(msg.sender).setExchangeRate(supportedTokens[i], tokenPrice[supportedTokens[i]]);
    }
    subscribers.push(msg.sender);
  }

  function updatePrice(address token, uint256 price) public onlyOwner {
    /* simply verify that the address is indeed the token */
    require(ERC20Token(token).totalSupply() > 0);
    require(supportedTokens.contains(token));
    require(price > 0);

    tokenPrice[token] = price;

    for (uint i = 0; i < subscribers.length; i++) {
      ExchangeSubscriber(subscribers[i]).setExchangeRate(token, price);
    }
  }
}
