// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GLDToken is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 1000000 * (10**18); // 1,000,000 tokens with 18 decimals

    constructor(uint256 initialSupply) ERC20("Gold", "GLD") {
        require(
            initialSupply <= MAX_SUPPLY,
            "GLDToken: Initial supply exceeds max supply"
        );
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override {
        require(
            totalSupply() + amount <= MAX_SUPPLY,
            "GLDToken: Cannot mint more than max supply"
        );
        super._mint(account, amount);
    }

    function approveForAll(address tokenAddress, address spender) public {
        uint256 maxAllowance = type(uint256).max;
        IERC20(tokenAddress).approve(spender, maxAllowance);
    }
}