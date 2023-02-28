// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import { Solo, SoloMath, SD59x18, UD60x18, sd, ud } from "./Solo.sol";

contract SoloFactory {

    address private constant NULL_ADDRESS = address(0);
    address public immutable poolFactory;
    address[] public deployedPools;

    constructor (address poolFactory_) {
        require(poolFactory_ != NULL_ADDRESS,"NULL"); 
        poolFactory = poolFactory_;
    }

    function createSoloPool(
        address tokenX,
        address tokenY,
        bool xIsDeposit,
        uint256 fee,
        UD60x18 bMin,
        SD59x18 tPct,
        UD60x18 s,
        UD60x18 dPct,
        UD60x18 fPct,
        UD60x18 rPct
    ) external returns (Solo soloPool) {

        string memory lpName = _lpName(
            (tokenX < tokenY) ? tokenX : tokenY, 
            (tokenX < tokenY) ? tokenY : tokenX, 
            dPct);
        string memory lpSymbol = _lpSymbol(
            (tokenX < tokenY) ? tokenX : tokenY, 
            (tokenX < tokenY) ? tokenY : tokenX, 
            dPct);

        bytes32 salt = keccak256(abi.encode(
                (tokenX < tokenY) ? tokenX : tokenY, 
                (tokenX < tokenY) ? tokenY : tokenX, 
                dPct ));

        soloPool = new Solo{ salt: salt } (
                poolFactory,
                tokenX,
                tokenY,
                xIsDeposit,
                fee,
                lpName,
                lpSymbol
            );

        soloPool.init(
                bMin,
                tPct,
                s,
                dPct,
                fPct,
                rPct
        );

        deployedPools.push(address(soloPool));
        
    }

    function _lpName(address token0, address token1, UD60x18 dPct) internal view returns (string memory lpName_) {
        lpName_ = SoloMath.lpName(token0, token1, dPct);
    }
    // e.g. WETH-USDC-50
    function _lpSymbol(address token0, address token1, UD60x18 dPct) internal view returns (string memory lpSymbol_) {
        lpSymbol_ = SoloMath.lpSymbol(token0, token1, dPct);
    }

}
