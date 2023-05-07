// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/escrow/Escrow.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Escrow
 * @dev Base escrow contract, holds funds designated for a payee until they
 * withdraw them.
 *
 * Intended usage: This contract (and derived escrow contracts) should be a
 * standalone contract, that only interacts with the contract that instantiated
 * it. That way, it is guaranteed that all Ether will be handled according to
 * the `Escrow` rules, and there is no need to check for payable functions or
 * transfers in the inheritance tree. The contract that uses the escrow as its
 * payment method should be its owner, and provide public methods redirecting
 * to the escrow's deposit and withdraw.
 */
contract TokenEscrow is Ownable {
    using Address for address payable;

    mapping(address => mapping(address => uint256)) private _deposits;

    function depositsOf(address payee, address tokenAddress)
        public
        view
        returns (uint256)
    {
        return _deposits[payee][tokenAddress];
    }

    function deposit(
        address payee,
        address tokenAddress,
        uint256 amount
    ) public onlyOwner {
        IERC20(tokenAddress).transferFrom(payee, address(this), amount);
        _deposits[payee][tokenAddress] += amount;
    }

    function withdraw(
        address payee,
        address tokenAddress        
    ) public onlyOwner {
        uint256 amount = _deposits[payee][tokenAddress];
        require(amount > 0, "Insufficient funds");
        _deposits[payee][tokenAddress] -= amount;
        IERC20(tokenAddress).transfer(payee, amount);
    }
}
