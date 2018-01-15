pragma solidity ^0.4.8;

library Utils {

  /*Convert bytes of address to integer representaion concatenating hex values of each byte*/
  /* @return unique uint256 */
  function fromAddrToInt(address addr) public pure returns (uint) {
    require(addr != 0);
    bytes memory byteAddr = new bytes(20);

    /* convert address to bytes (600 gas) */
    assembly {
      let m := mload(0x40)
      mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, addr))
      mstore(0x40, add(m, 52))
      byteAddr := m
    }

    /*return byteAddr.length;*/
    /* convert bytes to integers with respective power */
    uint mint = 0;
    for (uint i = 0; i < byteAddr.length; i++) {
        mint *= 1000;
        mint += uint(byteAddr[i]);
        /*if ((uint(byteAddr[i]) >= 48) && (uint(byteAddr[i]) <= 57)) {
          mint += uint(byteAddr[i]) - 48;
        } else if ((uint(byteAddr[i]) >= 97) && (uint(byteAddr[i]) <= 122)) {
          mint += uint(byteAddr[i]) - 87;
        }*/
    }
    return mint;
  }

  function contains(address[] storage self, address addr) public view returns (bool isSupported) {
    for (uint i = 0; i < self.length && !isSupported; i++) {
      isSupported = self[i] == addr;
    }

    return isSupported;
  }
}
