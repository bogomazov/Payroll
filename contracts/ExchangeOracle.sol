pragma solidity ^0.4.8;

import "./ERC20Token.sol";

interface ExchangeSubscriber {
  function setExchangeRate(address token, uint256 usdExchangeRate) public;
}

contract ExchangeOracle {
  address[] subscribers;
  address[] supportedTokens;
  mapping (address => uint) tokenPrice;

  function ExchangeOracle(address[] tokens, uint[] prices) public {
    require(tokens.length > 0);
    require(tokens.length  == prices.length);
    supportedTokens = tokens;

    for (uint i = 0; i < tokens.length; i++) {
      /* verify subscriber interface */
      require(prices[i] > 0);
      tokenPrice[tokens[i]] = prices[i];
    }
  }

  /* subscribes to all supported tokens */
  function subscribe() public {
    for (uint i = 0; i < supportedTokens.length; i++) {
      /* verify subscriber interface */
      ExchangeSubscriber(msg.sender).setExchangeRate(supportedTokens[i], tokenPrice[supportedTokens[i]]);
    }
    subscribers.push(msg.sender);
  }

  function updateExchange(address token, uint256 price) public {
    /* verify that the address is indeed the token */
    require(ERC20Token(token).totalSupply() > 0);
    require(price > 0);
    if (tokenPrice[token] == 0) {
      supportedTokens.push(token);
    }

    tokenPrice[token] = price;

    for (uint i = 0; i < subscribers.length; i++) {
      ExchangeSubscriber(subscribers[i]).setExchangeRate(token, price);
    }
  }
}
