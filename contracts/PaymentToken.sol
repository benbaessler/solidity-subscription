// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

  constructor() ERC20("Token", "BEN") {
    _mint(msg.sender, 10000);
  }

}