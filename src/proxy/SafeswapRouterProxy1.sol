/**
 * Submitted for verification at BscScan.com on 2023-01-20
 */

// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
// contract Initializable {
//     /**
//      * @dev Indicates that the contract has been initialized.
//      */
//     bool private _initialized;

//     /**
//      * @dev Indicates that the contract is in the process of being initialized.
//      */
//     bool private _initializing;

//     /**
//      * @dev Modifier to protect an initializer function from being invoked twice.
//      */
//     modifier initializer() {
//         require(
//             _initializing || !_initialized,
//             "Initializable: contract is already initialized"
//         );

//         bool isTopLevelCall = !_initializing;
//         if (isTopLevelCall) {
//             _initializing = true;
//             _initialized = true;
//         }

//         _;

//         if (isTopLevelCall) {
//             _initializing = false;
//         }
//     }

//     /// @dev Returns true if and only if the function is running in the constructor
//     function _isConstructor() private view returns (bool) {
//         // extcodesize checks the size of the code stored in an address, and
//         // address returns the current address. Since the code is still not
//         // deployed when running a constructor, any checks on its code size will
//         // yield zero, making it an effective way to detect if a contract is
//         // under construction or not.
//         address self = address(this);
//         uint256 cs;
//         // solhint-disable-next-line no-inline-assembly
//         assembly {
//             cs := extcodesize(self)
//         }
//         return cs == 0;
//     }
// }

import {ISafeswapRouter01} from "../interfaces/SafeMoon/ISafeswapRouter01.sol";
import {ISafeswapFactory} from "../interfaces/SafeMoon/ISafeswapFactory.sol";
import {ISafeswapPair} from "../interfaces/SafeMoon/ISafeswapPair.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {IERC20} from "../interfaces/IERC20.sol";

import {Initializable} from "../lib/Initializable.sol";

import {SafeswapLibrary} from "../library/SafeSwapLibrary.sol";
import {TransferHelper} from "../library/TransferHelper.sol";

contract SafeswapRouterProxy1 is ISafeswapRouter01, Initializable {
    /*========================================================================================================================*/
    /*======================================================== states ========================================================*/
    /*========================================================================================================================*/

    uint256 public constant ONE = 1e18;
    address public override factory;
    address public override WETH;
    bool private killSwitch;
    address public admin;
    uint256 tokensCount;

    /*========================================================================================================================*/
    /*======================================================= mappings =======================================================*/
    /*========================================================================================================================*/

    mapping(address => bool) private _lpTokenLockStatus;
    mapping(address => uint256) private _locktime;
    mapping(address => TokenInfo) nameToInfo;
    mapping(uint256 => address) public idToAddress;
    address public routerTrade;
    mapping(address => bool) public whitelistAccess;
    mapping(uint256 => address) public impls;

    /*========================================================================================================================*/
    /*======================================================== events ========================================================*/
    /*========================================================================================================================*/

    event isSwiched(bool newSwitch);

    event RegisterToken(
        string tokenName,
        address tokenAddress,
        address feesAddress,
        uint256 buyFeePercent,
        uint256 sellFeePercent,
        bool isUpdate
    );

    event UnregisterToken(address tokenAddress);

    /*========================================================================================================================*/
    /*======================================================= structs ========================================================*/
    /*========================================================================================================================*/

    struct TokenInfo {
        bool enabled;
        bool isDeleted;
        string tokenName;
        address tokenAddress;
        address feesAddress;
        uint256 buyFeePercent;
        uint256 sellFeePercent;
    }

    /*========================================================================================================================*/
    /*====================================================== modifiers =======================================================*/
    /*========================================================================================================================*/

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    modifier ensure(uint256 deadline) {
        _;
    }

    modifier onlyRouterTrade() {
        _onlyRouterTrade();
        _;
    }

    modifier onlyWhitelist() {
        _onlyWhitelist();
        _;
    }

    /*========================================================================================================================*/
    /*====================================================== initialize ======================================================*/
    /*========================================================================================================================*/

    function initialize(address _factory, address _WETH) external initializer {
        factory = _factory;
        WETH = _WETH;
        admin = msg.sender;
        tokensCount = 0;
        killSwitch = false;
    }

    /*========================================================================================================================*/
    /*=================================================== public functions ===================================================*/
    /*========================================================================================================================*/

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to);
        address pair = SafeswapLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = ISafeswapPair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable virtual ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        (amountToken, amountETH) =
            _addLiquidity(token, WETH, amountTokenDesired, msg.value, amountTokenMin, amountETHMin, to);
        address pair = SafeswapLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = ISafeswapPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = SafeswapLibrary.pairFor(factory, tokenA, tokenB);
        ISafeswapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = ISafeswapPair(pair).burn(to);
        (address token0,) = SafeswapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "SafeswapRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "SafeswapRouter: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) =
            removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
        TransferHelper.safeTransfer(token, to, amountToken);
    }

    function lockLP(address LPtoken, uint256 time) public onlyOwner {
        _lpTokenLockStatus[LPtoken] = true;
        _locktime[LPtoken] = block.timestamp + time;
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountETH) {
        (, amountETH) = removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
    }
    /*========================================================================================================================*/
    /*================================================== external functions ==================================================*/
    /*========================================================================================================================*/

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair

    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        onlyWhitelist
        returns (uint256[] memory amounts)
    {
        require(path[0] == WETH, "SafeswapRouter: INVALID_PATH");
        amounts = SafeswapLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "SafeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        if (nameToInfo[path[1]].enabled == true && killSwitch == false && (nameToInfo[path[1]].buyFeePercent > 0)) {
            uint256 amountOut = amounts[amounts.length - 1];
            uint256 deduction = (amountOut * nameToInfo[path[1]].buyFeePercent) / ONE;
            amounts[amounts.length - 1] = amountOut - deduction;
        }
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(SafeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address from,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) onlyWhitelist returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "SafeswapRouter: INVALID_PATH");
        amounts = SafeswapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "SafeswapRouter: EXCESSIVE_INPUT_AMOUNT");
        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 amountIn = amounts[0];
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amounts[0] = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], from, nameToInfo[path[0]].feesAddress, deduction);
        }
        amounts = SafeswapLibrary.getAmountsOut(factory, amounts[0], path);
        TransferHelper.safeTransferFrom(path[0], from, SafeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address from,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) onlyWhitelist returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "SafeswapRouter: INVALID_PATH");
        uint256[] memory oldamounts = SafeswapLibrary.getAmountsOut(factory, amountIn, path); // ,amountIn,
        require(oldamounts[oldamounts.length - 1] >= amountOutMin, "SafeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT");

        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amountIn = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], from, nameToInfo[path[0]].feesAddress, deduction);
        }

        amounts = SafeswapLibrary.getAmountsOut(factory, amountIn, path); // ,amountIn,

        TransferHelper.safeTransferFrom(
            path[0],
            from,
            SafeswapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0] // amouts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        onlyWhitelist
        returns (uint256[] memory amounts)
    {
        require(path[0] == WETH, "SafeswapRouter: INVALID_PATH");
        amounts = SafeswapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, "SafeswapRouter: EXCESSIVE_INPUT_AMOUNT");
        if (nameToInfo[path[1]].enabled == true && killSwitch == false && (nameToInfo[path[1]].buyFeePercent > 0)) {
            uint256 deduction = (amountOut * nameToInfo[path[1]].buyFeePercent) / ONE;
            amountOut = amountOut - deduction;
        }
        amounts = SafeswapLibrary.getAmountsIn(factory, amountOut, path);

        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(SafeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(to, msg.value - amounts[0]);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = SafeswapLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        ISafeswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountETH) {
        address pair = SafeswapLibrary.pairFor(factory, token, WETH);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        ISafeswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) onlyWhitelist {
        require(path[0] == WETH, "SafeswapRouter: INVALID_PATH");
        uint256 amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(SafeswapLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "SafeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address from,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) onlyWhitelist {
        require(path[path.length - 1] == WETH, "SafeswapRouter: INVALID_PATH");

        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amountIn = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], from, nameToInfo[path[0]].feesAddress, deduction);
        }

        TransferHelper.safeTransferFrom(path[0], from, SafeswapLibrary.pairFor(factory, path[0], path[1]), amountIn);
        (uint256 amount0Out, uint256 amount1Out) = _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = amount0Out > 0 ? amount0Out : amount1Out;

        require(amountOut >= amountOutMin, "SafeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) onlyWhitelist {
        require(path[path.length - 1] == WETH, "SafeswapRouter: INVALID_PATH");

        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amountIn = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], msg.sender, nameToInfo[path[0]].feesAddress, deduction);
        }

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SafeswapLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        (uint256 amount0Out, uint256 amount1Out) = _swapSupportingFeeOnTransferTokensForV1(path, address(this));
        uint256 amountOut = amount0Out > 0 ? amount0Out : amount1Out;

        require(amountOut >= amountOutMin, "SafeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) onlyWhitelist returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "SafeswapRouter: INVALID_PATH");
        amounts = SafeswapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "SafeswapRouter: EXCESSIVE_INPUT_AMOUNT");
        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 amountIn = amounts[0];
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amounts[0] = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], msg.sender, nameToInfo[path[0]].feesAddress, deduction);
        }
        amounts = SafeswapLibrary.getAmountsOut(factory, amounts[0], path);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SafeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) onlyWhitelist returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "SafeswapRouter: INVALID_PATH");
        uint256[] memory oldamounts = SafeswapLibrary.getAmountsOut(factory, amountIn, path); // ,amountIn,
        require(oldamounts[oldamounts.length - 1] >= amountOutMin, "SafeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT");

        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amountIn = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], msg.sender, nameToInfo[path[0]].feesAddress, deduction);
        }

        amounts = SafeswapLibrary.getAmountsOut(factory, amountIn, path); // ,amountIn,

        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            SafeswapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0] // amouts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountToken, uint256 amountETH) {
        address pair = SafeswapLibrary.pairFor(factory, token, WETH);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        ISafeswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    /*========================================================================================================================*/
    /*================================================== internal functions ==================================================*/
    /*========================================================================================================================*/

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (ISafeswapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            ISafeswapFactory(factory).createPair(tokenA, tokenB, to);
        }
        (uint256 reserveA, uint256 reserveB) = SafeswapLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = SafeswapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "SafeswapRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = SafeswapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "SafeswapRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SafeswapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? SafeswapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            ISafeswapPair(SafeswapLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to)
        internal
        virtual
        returns (uint256 amount0Out, uint256 amount1Out)
    {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SafeswapLibrary.sortTokens(input, output);
            ISafeswapPair pair = ISafeswapPair(SafeswapLibrary.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = SafeswapLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            if (nameToInfo[output].enabled == true && killSwitch == false && (nameToInfo[output].buyFeePercent > 0)) {
                uint256 deduction = (amountOutput * nameToInfo[output].buyFeePercent) / ONE;
                amountOutput = amountOutput - deduction;
            }
            (amount0Out, amount1Out) = input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? SafeswapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function _delegate(address _impl) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _swapSupportingFeeOnTransferTokensForV1(address[] memory path, address _to)
        internal
        virtual
        returns (uint256 amount0Out, uint256 amount1Out)
    {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SafeswapLibrary.sortTokens(input, output);
            ISafeswapPair pair = ISafeswapPair(SafeswapLibrary.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = SafeswapLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            if (nameToInfo[output].enabled == true && killSwitch == false && (nameToInfo[output].buyFeePercent > 0)) {
                uint256 deduction = (amountOutput * nameToInfo[output].buyFeePercent) / ONE;
                amountOutput = amountOutput - deduction;
            }
            (amount0Out, amount1Out) = input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? SafeswapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    /*========================================================================================================================*/
    /*================================================= public view functions ================================================*/
    /*========================================================================================================================*/

    function version() public view returns (uint256) {
        return 1;
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return SafeswapLibrary.getAmountsIn(factory, amountOut, path);
    }

    /*========================================================================================================================*/
    /*================================================= private view functions ===============================================*/
    /*========================================================================================================================*/

    function _onlyWhitelist() private view {
        require(whitelistAccess[msg.sender], "SafeswapRouter: ONLY_WHITELIST");
    }

    function _ensure(uint256 deadline) private view {
        require(deadline >= block.timestamp, "SafeswapRouter: EXPIRED");
    }

    function _onlyRouterTrade() private view {
        require(msg.sender == routerTrade, "SafeswapRouter: ONLY_ROUTER_TRADE");
    }

    function _onlyOwner() private view {
        require(admin == msg.sender, "Ownable: caller is not the owner");
    }

    /*========================================================================================================================*/
    /*================================================== public pure functions ===============================================*/
    /*========================================================================================================================*/

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        public
        pure
        virtual
        override
        returns (uint256 amountB)
    {
        return SafeswapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountIn)
    {
        return SafeswapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountOut)
    {
        return SafeswapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return SafeswapLibrary.getAmountsOut(factory, amountIn, path);
    }

    /*========================================================================================================================*/
    /*======================================================= fallbacks ======================================================*/
    /*========================================================================================================================*/

    receive() external payable {}

    fallback() external {
        _delegate(impls[version()]);
    }

    /*========================================================================================================================*/
    /*====================================================== Only Owner ======================================================*/
    /*========================================================================================================================*/

    function setRouterTrade(address _routerTrade) public override onlyOwner {
        routerTrade = _routerTrade;
    }

    function setWhitelist(address _user, bool _status) external override onlyOwner {
        whitelistAccess[_user] = _status;
    }

    function setImpls(uint256 _implIndex, address _impl) public override onlyOwner {
        impls[_implIndex] = _impl;
    }
}
