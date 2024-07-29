// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IGetGlobalStateFromPool {
    struct GlobalState {
        uint160 price; // The square root of the current price in Q64.96 format
        int24 tick; // The current tick
        uint16 feeZto; // The current fee for ZtO swap in hundredths of a bip, i.e. 1e-6
        uint16 feeOtz; // The current fee for OtZ swap in hundredths of a bip, i.e. 1e-6
        uint16 timepointIndex; // The index of the last written timepoint
        uint8 communityFeeToken0; // The community fee represented as a percent of all collected fee in thousandths (1e-3)
        uint8 communityFeeToken1;
        bool unlocked; // True if the contract is unlocked, otherwise - false
    }

    /**
     * @notice The globalState structure in the pool stores many values but requires only one slot
     * and is exposed as a single method to save gas when accessed externally.
     * @return price The current price of the pool as a sqrt(token1/token0) Q64.96 value;
     * Returns tick The current tick of the pool, i.e. according to the last tick transition that was run;
     * Returns This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(price) if the price is on a tick
     * boundary;
     * Returns fee The last pool fee value in hundredths of a bip, i.e. 1e-6;
     * Returns timepointIndex The index of the last written timepoint;
     * Returns communityFeeToken0 The community fee percentage of the swap fee in thousandths (1e-3) for token0;
     * Returns communityFeeToken1 The community fee percentage of the swap fee in thousandths (1e-3) for token1;
     * Returns unlocked Whether the pool is currently locked to reentrancy;
     */
    function globalState() external view returns (GlobalState memory);

    function token0() external view returns (address);

    function token1() external view returns (address);
}
