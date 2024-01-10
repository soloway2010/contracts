pragma solidity 0.6.4;
pragma experimental ABIEncoderV2;

import "../interfaces/IDepositExecute.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IAToken.sol";
import "../interfaces/IBridge.sol";
import "./HandlerHelpers.sol";
import "../ERC20Safe.sol";
import "../ExampleToken.sol";
import "../utils/UpgradableOwnable.sol";

/**
    @title Handles ERC20 deposits and deposit executions.
    @notice This contract is intended to be used with the Bridge contract.
 */
contract AaveHandler is
    IDepositExecute,
    HandlerHelpers,
    UpgradableOwnable,
    ERC20Safe
{
    address public constant AAVE_AVAX_LP_ADDR =
        0x4F01AeD16D97E3aB5ab2B501154DC9bb0F1A5A2C;
    address public constant AAVE_FUJI_LP_ADDR =
        0x76cc67FF2CC77821A70ED14321111Ce381C2594D;
    bytes8 public LACHAIN_ID;
    address public amTokenHandler;
    address public erc20Handler;

    struct DepositRecord {
        address _tokenAddress;
        bytes8 _destinationChainID;
        bytes32 _resourceID;
        address _destinationRecipientAddress;
        address _depositer;
        uint256 _amount;
    }

    mapping(bytes8 => mapping(uint64 => DepositRecord)) public _depositRecords;

    mapping(bytes32 => bytes32) public aaveTokenResources;

    event AAVEDepositDone(
        address indexed recipientAddress,
        uint256 amount,
        bytes32 indexed resourceID
    );

    /**
        @param bridgeAddress Contract address of previously deployed Bridge.
     */
    function initialize(address bridgeAddress) public {
        _bridgeAddress = bridgeAddress;
        LACHAIN_ID = 0x0000000000000019;
        ownableInit(msg.sender);
    }

    function setLachainId(bytes8 _LACHAIN_ID) external onlyOwner {
        LACHAIN_ID = _LACHAIN_ID;
    }

    function setErc20Handler(address _erc20Handler) external onlyOwner {
        erc20Handler = _erc20Handler;
    }

    function setAmTokenHandler(address _amTokenHandler) external onlyOwner {
        amTokenHandler = _amTokenHandler;
    }

    function setAaveTokenResources(
        bytes32 aaveTokenResourceId,
        bytes32 amTokenResourceId
    ) external onlyOwner {
        aaveTokenResources[aaveTokenResourceId] = amTokenResourceId;
    }

    function adminChangeBridgeAddress(address newBridgeAddress)
        external
        onlyOwner
    {
        _bridgeAddress = newBridgeAddress;
    }

    function getDepositRecord(uint64 depositNonce, bytes8 destId)
        external
        view
        returns (DepositRecord memory)
    {
        return _depositRecords[destId][depositNonce];
    }

    function deposit(
        bytes32 resourceID,
        bytes8 destinationChainID,
        uint64 depositNonce,
        address depositer,
        address recipientAddress,
        uint256 amount,
        bytes calldata params
    ) external override onlyBridge returns (address) {
        address tokenAddress = _resourceIDToTokenContractAddress[resourceID];
        require(
            _contractWhitelist[tokenAddress],
            "provided tokenAddress is not whitelisted"
        );

        if (_burnList[tokenAddress]) {
            burnERC20(tokenAddress, depositer, amount);
        } else {
            lockERC20(tokenAddress, depositer, address(this), amount);
        }

        _depositRecords[destinationChainID][depositNonce] = DepositRecord(
            tokenAddress,
            destinationChainID,
            resourceID,
            recipientAddress,
            depositer,
            amount
        );
        return (tokenAddress);
    }

    function executeProposal(
        bytes32 resourceID,
        address recipientAddress,
        uint256 amount,
        bytes calldata params
    ) external override onlyBridge {
        address tokenAddress = _resourceIDToTokenContractAddress[resourceID];

        fundERC20(tokenAddress, erc20Handler, amount);
        approveERC20(tokenAddress, AAVE_AVAX_LP_ADDR, amount);
        address aTokenAddress = ILendingPool(AAVE_AVAX_LP_ADDR)
            .getReserveData(tokenAddress)
            .aTokenAddress;
        uint256 oldBalance = IAToken(aTokenAddress).scaledBalanceOf(
            amTokenHandler
        );
        ILendingPool(AAVE_AVAX_LP_ADDR).deposit(
            tokenAddress,
            amount,
            amTokenHandler,
            0x0
        );
        uint256 newAmount = IAToken(aTokenAddress).scaledBalanceOf(
            amTokenHandler
        ) - oldBalance;

        IBridge(_bridgeAddress).internalDeposit(
            LACHAIN_ID,
            aaveTokenResources[resourceID],
            newAmount,
            recipientAddress
        );

        emit AAVEDepositDone(recipientAddress, amount, resourceID);
    }

    /**
        @notice Used to manually release ERC20 tokens from ERC20Safe.
        @param tokenAddress Address of token contract to release.
        @param recipient Address to release tokens to.
        @param amount The amount of ERC20 tokens to release.
     */
    function withdraw(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external override onlyBridge {
        releaseERC20(tokenAddress, recipient, amount);
    }

    function getAddressFromResourceId(bytes32 resourceID)
        external
        view
        override
        returns (address)
    {
        return _resourceIDToTokenContractAddress[resourceID];
    }
}
