// SPDX-License-Identifier: MIT
pragma solidity 0.6.4;

import "./ECDSA.sol";

contract VerifySignature {
    using ECDSA for bytes32;

    function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
    {
        return _messageHash.toEthSignedMessageHash();
    }

    function verify(
        bytes32 _ethSignedMessageHash,
        address _signer,
        bytes memory _signature
    ) public pure returns (bool) {
        return getSigner(_ethSignedMessageHash, _signature) == _signer;
    }

    function getSigner(bytes32 messageHash, bytes memory signature)
        public
        pure
        returns (address)
    {
        return messageHash.recover(signature);
    }

    function createMesssageHash(
        uint256 amount,
        address recipient,
        bytes8 chainId
    ) public pure returns (bytes32) {
        bytes memory _message = message(amount, recipient, chainId);
        bytes32 msgHash = keccak256(_message);
        return msgHash;
    }

    function message(
        uint256 amount,
        address recipient,
        bytes8 chainId
    ) internal pure returns (bytes memory) {
        bytes memory _message = abi.encode(amount, recipient, chainId);
        return _message;
    }
}
