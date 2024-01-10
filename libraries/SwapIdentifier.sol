// SPDX-License-Identifier: Unliscensed

pragma solidity 0.6.4;

library SwapIdentifier {
    function getSwapIdentifier() internal pure returns (bytes4) {
        return bytes4(0x73776170);
    }

    function getDestinationChainID(bytes32 resourceID)
        internal
        pure
        returns (bytes8)
    {
        return bytes8(resourceID << 32);
    }

    function getDestinationResourceID(bytes32 resourceID)
        internal
        pure
        returns (bytes32)
    {
        bytes22 padding22 = bytes22(
            0x00000000000000000000000000000000000000000000
        );
        return
            bytes32(
                (uint256(uint176(padding22)) << 168) |
                    uint80(bytes10(resourceID << 96))
            );
    }

    function getSourceResourceID(bytes32 resourceID)
        internal
        pure
        returns (bytes32)
    {
        bytes22 padding22 = bytes22(
            0x00000000000000000000000000000000000000000000
        );
        return
            bytes32(
                (uint256(uint176(padding22)) << 168) |
                    uint80(bytes10(resourceID << 176))
            );
    }
}
