pragma solidity 0.6.4;
pragma experimental ABIEncoderV2;

import "../libraries/Babylonian.sol";
import "../interfaces/IDepositExecute.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/IUniswapV2RouterWrapper.sol";
import "../interfaces/IWrappedTokensUnwrapper.sol";
import "../interfaces/IBridge.sol";
import "./HandlerHelpers.sol";
import "../ERC20Safe.sol";
import "../utils/UpgradableOwnable.sol";

interface IBeefyVault is IERC20 {
    function deposit(uint256 amount) external;
    function withdraw(uint256 shares) external;
    function want() external pure returns (address); // Beefy Vault V6
    function token() external pure returns (address); // Beefy Vault V5
    function native() external pure returns (address); // Beefy Vault Native
}

/**
    @title Handles Beefy deposits and withdrawals.
    @notice This contract is intended to be used with the Bridge contract.
 */
contract BeefyHandler is
    IDepositExecute,
    HandlerHelpers,
    UpgradableOwnable,
    ERC20Safe
{
    using SafeMath for uint256;

    address public WETH;
    uint256 public constant minimumAmount = 1000;

    bytes8 public lachainChainID;
    address public routerWrapper;

    // token => tokenHandler
    mapping(address => address) public tokenHandlers;

    // factory => router
    mapping(address => IUniswapV2Router) public routers;

    // unwrapper for WBNB
    address public wrappedTokensUnwrapper;

    /**
        @param bridgeAddress Contract address of previously deployed Bridge.
     */
    function initialize(bytes8 _lachainChainID, address _WETH, address bridgeAddress) public {
        WETH = _WETH;
        
        _bridgeAddress = bridgeAddress;
        lachainChainID = _lachainChainID;
        routerWrapper = address(0);

        ownableInit(msg.sender);
    }

    receive() external payable {
        if (wrappedTokensUnwrapper == address(0)) {
            assert(msg.sender == WETH);
        } else {
            assert(msg.sender == wrappedTokensUnwrapper);
        }
    }

    function setBridgeAddress(address bridgeAddress) external onlyOwner isInitisalised {
        _bridgeAddress = bridgeAddress;
    }

    function setLachainID(bytes8 _lachainChainID) external onlyOwner isInitisalised {
        lachainChainID = _lachainChainID;
    }

    function setRouterWrapper(address _routerWrapper) external onlyOwner isInitisalised {
        routerWrapper = _routerWrapper;
    }

    function setTokenHandler(address _token, address _tokenHandler) external onlyOwner isInitisalised {
        tokenHandlers[_token] = _tokenHandler;
    }

    function setRouter(address _factory, address _router) external onlyOwner {
        routers[_factory] = IUniswapV2Router(_router);
    }

    function setWrappedTokensUnwrapper(address _wrappedTokensUnwrapper) external onlyOwner {
        wrappedTokensUnwrapper = _wrappedTokensUnwrapper;
    }

    /**
        @notice A deposit is initiatied by making a deposit in the Bridge contract.
        @param destinationChainID Chain ID of chain tokens are expected to be bridged to.
        @param depositNonce This value is generated as an ID by the Bridge contract.
        @param depositer Address of account making the deposit in the Bridge contract.
        @notice Data passed into the function should be constructed as follows:
        amount                      uint256     bytes   0 - 32
        recipientAddress length     uint256     bytes  32 - 64
        recipientAddress            bytes       bytes  64 - END
        @dev Depending if the corresponding {tokenAddress} for the parsed {resourceID} is
        marked true in {_burnList}, deposited tokens will be burned, if not, they will be locked.
     */
    function deposit(
        bytes32 resourceID,
        bytes8 destinationChainID,
        uint64 depositNonce,
        address depositer,
        address recipientAddress,
        uint256 amount,
        bytes calldata params
    ) external override onlyBridge isInitisalised returns (address) {
        revert();
    }

    /**
        @notice Proposal execution should be initiated when a proposal is finalized in the Bridge contract.
        by a relayer on the deposit's destination chain.
        @notice Data passed into the function should be constructed as follows:
        amount                                 uint256     bytes  0 - 32
        destinationRecipientAddress length     uint256     bytes  32 - 64
        destinationRecipientAddress            bytes       bytes  64 - END
     */
    function executeProposal(
        bytes32 resourceID,
        address recipientAddress,
        uint256 amount,
        bytes calldata params
    ) external override onlyBridge isInitisalised {
        // ends with 0 => deposit
        // ends with 1 => withdrawal
        bool isDeposit = (uint256(resourceID) % 2 == 0);

        (bytes32 wantResourceID, bytes32 vaultResourceID) = isDeposit ? 
            (resourceID, bytes32(uint256(resourceID) + 1)) :
            (bytes32(uint256(resourceID) - 1), resourceID)
        ;

        _handleBeefy(wantResourceID, vaultResourceID, recipientAddress, amount, isDeposit);
    }

    function _handleBeefy(
        bytes32 wantResourceID,
        bytes32 vaultResourceID,
        address recipientAddress,
        uint256 amount,
        bool isDeposit
    ) private {
        address wantAddress = _resourceIDToTokenContractAddress[wantResourceID];
        address vaultAddress = _resourceIDToTokenContractAddress[vaultResourceID];

        IBridge bridge = IBridge(_bridgeAddress);
        IBeefyVault vault = IBeefyVault(vaultAddress);

        // handle deposit/withdraw
        uint256 beforeWantBalance;
        uint256 beforeVaultBalance;
        if (isDeposit) {
            if (wantAddress == WETH) {
                // get wrapped native tokens from bridge
                bridge.depositNativeToken(wantResourceID, amount);
            } else {
                // get erc20 tokens from erc20handler
                lockERC20(wantAddress, tokenHandlers[wantAddress], address(this), amount);
            }

            beforeWantBalance = IERC20(wantAddress).balanceOf(address(this)).sub(amount);
            beforeVaultBalance = vault.balanceOf(address(this));
        } else {
            beforeWantBalance = IERC20(wantAddress).balanceOf(address(this));
        }

        // if vault doesn't accept want token, swapping and adding liquidity is needed
        if (wantAddress == _getVaultWant(vault)) {
            _handleDirectBeefy(wantAddress, vaultAddress, amount, isDeposit);
        } else {
            _handleZapBeefy(wantAddress, vaultAddress, amount, isDeposit);
        }

        // return leftover want token back to user
        _returnAsset(wantAddress, IERC20(wantAddress).balanceOf(address(this)).sub(beforeWantBalance), recipientAddress);

        if (isDeposit) {
            bridge.internalDeposit(
                lachainChainID,
                vaultResourceID,
                vault.balanceOf(address(this)).sub(beforeVaultBalance),
                recipientAddress
            );
        }
    }

    function _handleDirectBeefy(
        address wantAddress,
        address vaultAddress,
        uint256 amount,
        bool isDeposit
    ) private {
        IBeefyVault vault = IBeefyVault(vaultAddress);

        if (isDeposit) {
            approveERC20(wantAddress, vaultAddress, amount);
            vault.deposit(amount);
        } else {
            vault.withdraw(amount);
        }
    }

    function _handleZapBeefy(
        address wantAddress,
        address vaultAddress,
        uint256 amount,
        bool isDeposit
    ) private {
        (IBeefyVault vault, IUniswapV2Pair pair, IUniswapV2Router router) = _getVaultPair(vaultAddress);
        bool isWant0 = pair.token0() == wantAddress;
        require(isWant0 || pair.token1() == wantAddress, 'Desired token not present in liquidity pair');

        address[] memory path = new address[](2);

        if (isDeposit) {
            (path[0], path[1]) = (wantAddress, isWant0 ? pair.token1() : pair.token0());
            
            // swap the want token for the second token and add liquidity
            uint256 amountLiquidity = _swapAndAddLiquidity(pair, router, path, amount, isWant0);

            // deposit LP tokens into the vault
            approveERC20(address(pair), vaultAddress, amountLiquidity);
            vault.deposit(amountLiquidity);
        } else {
            (path[0], path[1]) = (isWant0 ? pair.token1() : pair.token0(), wantAddress);

            // withdraw LP tokens from the vault
            uint256 beforeLpBalance = IERC20(address(pair)).balanceOf(address(this));
            vault.withdraw(amount);

            // burn LP tokens
            (uint256 amount0, uint256 amount1) = _removeLiquidity(
                address(pair),
                IERC20(address(pair)).balanceOf(address(this)).sub(beforeLpBalance),
                address(this)
            );

            // swap the second pair token for the want token
            _swapExactTokensForTokens(router, isWant0 ? amount1 : amount0, 1, path, address(this), block.timestamp);
        }
    }

    function _swapAndAddLiquidity(
        IUniswapV2Pair pair,
        IUniswapV2Router router,
        address[] memory path,
        uint256 amount,
        bool isWant0
    ) private returns (uint256) {
        (uint256 reserveA, uint256 reserveB,) = pair.getReserves();
        require(reserveA > minimumAmount && reserveB > minimumAmount, 'Liquidity pair reserves too low');

        uint256 swapAmountIn;
        if (isWant0) {
            swapAmountIn = _getSwapAmount(router, amount, reserveA, reserveB);
        } else {
            swapAmountIn = _getSwapAmount(router, amount, reserveB, reserveA);
        }

        // swap the want token for the second pair token
        uint256[] memory swappedAmounts = _swapExactTokensForTokens(router, swapAmountIn, 1, path, address(this), block.timestamp);

        // get LP tokens
        approveERC20(path[0], address(router), amount.sub(swappedAmounts[0]));
        approveERC20(path[1], address(router), swappedAmounts[1]);
        (,, uint256 amountLiquidity) = router
            .addLiquidity(path[0], path[1], amount.sub(swappedAmounts[0]), swappedAmounts[1], 1, 1, address(this), block.timestamp);

        return amountLiquidity;
    }

    function _swapExactTokensForTokens(
        IUniswapV2Router router,
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to,
        uint deadline
    ) private returns (uint[] memory amounts) {
        if (routerWrapper == address(0)) {
            approveERC20(path[0], address(router), amountIn);
            return router.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);   
        }

        approveERC20(path[0], routerWrapper, amountIn);
        return IUniswapV2RouterWrapper(routerWrapper)
            .wrappedSwapExactTokensForTokens(address(router), amountIn, amountOutMin, path, to, deadline);
    }

    function _removeLiquidity(address pair, uint256 amount, address to) private returns (uint256 amount0, uint256 amount1) {
        releaseERC20(pair, pair, amount);
        (amount0, amount1) = IUniswapV2Pair(pair).burn(to);

        require(amount0 >= minimumAmount, 'INSUFFICIENT_A_AMOUNT');
        require(amount1 >= minimumAmount, 'INSUFFICIENT_B_AMOUNT');
    }

    function _returnAsset(address token, uint256 amount, address recipientAddress) private {
        IBridge bridge = IBridge(_bridgeAddress);

        if (amount > 0) {
            bytes32 tokenResourceID = _tokenContractAddressToResourceID[token];

            if (token == WETH) {
                // send native tokens to bridge
                if (wrappedTokensUnwrapper == address(0)) {
                    IWETH(WETH).withdraw(amount);
                } else {
                    IWETH(WETH).transfer(wrappedTokensUnwrapper, amount);
                    IWrappedTokensUnwrapper(wrappedTokensUnwrapper).unwrap(WETH);
                }
                bridge.depositNativeToken{value: amount}(tokenResourceID, amount);
            } else {
                // send erc20 tokens to erc20handler
                releaseERC20(token, tokenHandlers[token], amount);
            }

            // bridge tokens to Lachain
            bridge.internalDeposit(lachainChainID, tokenResourceID, amount, recipientAddress);
        }
    }

    function _getVaultPair (
        address beefyVault
    ) private view returns (
        IBeefyVault vault,
        IUniswapV2Pair pair,
        IUniswapV2Router router
    ) {
        vault = IBeefyVault(beefyVault);
        pair = IUniswapV2Pair(_getVaultWant(vault));
        router = routers[pair.factory()];

        require(address(router) != address(0), 'Unknown liquidity pair router');
    }

    function _getVaultWant(IBeefyVault vault) private view returns (address) {
        try vault.native() returns (address native) {
            require(native == WETH, "Unknown native token wrapper");
            // Vault Native
            return native;
        } catch {
            try vault.want() returns (address want) {
                // Vault V6
                return want;
            } catch {
                // Vault V5
                return vault.token();
            }
        }
    }

    function _getSwapAmount(
        IUniswapV2Router router,
        uint256 investmentA,
        uint256 reserveA,
        uint256 reserveB
    ) private view returns (uint256 swapAmount) {
        uint256 halfInvestment = investmentA / 2;

        uint256 nominator;
        try router.getAmountOut(halfInvestment, reserveA, reserveB) returns (uint256 amountOut) {
            nominator = amountOut;    
        } catch {
            nominator = router.getAmountOut(halfInvestment, reserveA, reserveB, 1);
        }
        
        uint256 denominator = router.quote(halfInvestment, reserveA.add(halfInvestment), reserveB.sub(nominator));
        swapAmount = investmentA.sub(Babylonian.sqrt(halfInvestment * halfInvestment * nominator / denominator));
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
    ) external override onlyBridge isInitisalised {
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

    /**
        @notice Used to approve spending tokens.
        @param resourceID ResourceID to be used for approval.
        @param spender Spender address.
        @param amount Amount to approve.
     */
    function approve(
        bytes32 resourceID,
        address spender,
        uint256 amount
    ) external override onlyBridge isInitisalised {
        address tokenAddress = _resourceIDToTokenContractAddress[resourceID];
        require(
            _contractWhitelist[tokenAddress],
            "provided tokenAddress is not whitelisted"
        );

        approveERC20(tokenAddress, spender, amount);
    }
}
