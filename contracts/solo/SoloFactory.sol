// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import { Solo } from "./Solo.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract SoloFactory is Ownable {

    error Unacceptable(string reason);
    
    address private constant NULL_ADDRESS = address(0);
    address public immutable poolFactory;
    address[] public deployedPools;

    constructor (address poolFactory_) {
        if(poolFactory_ == NULL_ADDRESS) 
            revert Unacceptable({ reason: "1" });
        poolFactory = poolFactory_;
    }

    function createSoloPool(
        address tokenX,
        address tokenY,
        bool xIsDeposit,
        uint24 fee
    ) external returns (Solo soloPool) {

        string memory lpName = _lpName(
            (tokenX < tokenY) ? tokenX : tokenY, 
            (tokenX < tokenY) ? tokenY : tokenX);
        string memory lpSymbol = _lpSymbol(
            (tokenX < tokenY) ? tokenX : tokenY, 
            (tokenX < tokenY) ? tokenY : tokenX);

        bytes32 salt = keccak256(abi.encode(
                (tokenX < tokenY) ? tokenX : tokenY, 
                (tokenX < tokenY) ? tokenY : tokenX));

        soloPool = new Solo{ salt: salt } (
                poolFactory,
                tokenX,
                tokenY,
                xIsDeposit,
                fee,
                lpName,
                lpSymbol
            );

        deployedPools.push(address(soloPool));
        
    }

    function _lpName(address token0, address token1) internal view returns (string memory lpName_) {
        lpName_ = "test";
    }
    function _lpSymbol(address token0, address token1) internal view returns (string memory lpSymbol_) {
        lpSymbol_ = "test";
    }

}
