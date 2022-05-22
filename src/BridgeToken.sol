// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";

error Unauthorized();

contract BridgeToken is ERC20, Owned {

    event Mint(address indexed to, uint256 amount);

    event Burn(address indexed from, uint256 amount);

    event BridgeSet(address indexed bridge);

    address public bridge;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol, 18) Owned(msg.sender) {}

    function setBridge(address _bridge) public onlyOwner {
        bridge = _bridge;

        setOwner(_bridge);

        emit BridgeSet(_bridge);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

}
