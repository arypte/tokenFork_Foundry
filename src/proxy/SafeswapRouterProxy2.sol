/**
 *Submitted for verification at BscScan.com on 2023-01-20
*/

// SPDX-License-Identifier: MIT

// File: contracts/IWETH.sol

pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import {ISafeswapPair} from "../interfaces/SafeMoon/ISafeswapPair.sol";
import {IERC20} from "../interfaces/IERC20.sol";

import {Initializable} from "../lib/openzeppelin/Initializable.sol";

import {SafeswapLibrary} from "../library/SafeSwapLibrary.sol";
import {TransferHelper} from "../library/TransferHelper.sol";

contract SafeswapRouterProxy2 is Initializable {
    uint256 public constant ONE = 1e18;
    address public factory;
    address public WETH;
    bool private killSwitch;
    address public admin;
    uint256 tokensCount;

    mapping(address => bool) private _lpTokenLockStatus;
    mapping(address => uint256) private _locktime;
    mapping(address => TokenInfo) nameToInfo;
    mapping(uint256 => address) public idToAddress;
    address public routerTrade;
    mapping(address => bool) public whitelistAccess;
    mapping(uint256 => address) public impls;

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

    struct TokenInfo {
        bool enabled;
        bool isDeleted;
        string tokenName;
        address tokenAddress;
        address feesAddress;
        uint256 buyFeePercent;
        uint256 sellFeePercent;
    }

    function version() view public returns (uint256) {
        return 2;
    }

    function _onlyOwner() private view {
        require(admin == msg.sender, "Ownable: caller is not the owner");
    }

    function _ensure(uint256 deadline) private view {
        require(deadline >= block.timestamp, "SafeswapRouter: EXPIRED");
    }

    function _onlyRouterTrade() private view {
        require(msg.sender == routerTrade, "SafeswapRouter: ONLY_ROUTER_TRADE");
    }

    function _onlyWhitelist() private view {
        require(whitelistAccess[msg.sender], "SafeswapRouter: ONLY_WHITELIST");
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    modifier ensure(uint256 deadline) {
        _ensure(deadline);
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

    receive() external payable {}

    function getTokenDeduction(address token, uint256 amount) external view returns (uint256, address) {
        if (nameToInfo[token].enabled == false || killSwitch == true) return (0, address(0));
        uint256 deduction = (amount * nameToInfo[token].buyFeePercent) / ONE;
        return (deduction, nameToInfo[token].feesAddress);
    }

    function registerToken(
        string memory tokenName,
        address tokenAddress,
        address feesAddress,
        uint256 buyFeePercent,
        uint256 sellFeePercent,
        bool isUpdate
    ) public onlyOwner {
        if (!isUpdate) {
            require(nameToInfo[tokenAddress].tokenAddress == address(0), "token already exists");
            idToAddress[tokensCount] = tokenAddress;
            tokensCount++;
        } else {
            require(nameToInfo[tokenAddress].tokenAddress != address(0), "token does not exist");
        }
        nameToInfo[tokenAddress].enabled = true;
        nameToInfo[tokenAddress].isDeleted = false;
        nameToInfo[tokenAddress].tokenName = tokenName;
        nameToInfo[tokenAddress].tokenAddress = tokenAddress;
        nameToInfo[tokenAddress].feesAddress = feesAddress;
        nameToInfo[tokenAddress].buyFeePercent = buyFeePercent;
        nameToInfo[tokenAddress].sellFeePercent = sellFeePercent;

        emit RegisterToken(tokenName, tokenAddress, feesAddress, buyFeePercent, sellFeePercent, isUpdate);
    }

    function unregisterToken(address tokenAddress) external onlyOwner {
        require(nameToInfo[tokenAddress].tokenAddress != address(0), "token does not exist");
        require(nameToInfo[tokenAddress].isDeleted == false, "token already deleted");

        nameToInfo[tokenAddress].isDeleted = true;
        nameToInfo[tokenAddress].enabled = false;

        emit UnregisterToken(tokenAddress);
    }

    // function to disable token stp
    function switchSTPToken(address _tokenAddress) public onlyOwner {
        require(nameToInfo[_tokenAddress].isDeleted == false, "token already deleted");
        nameToInfo[_tokenAddress].enabled = !nameToInfo[_tokenAddress].enabled;
    }

    function getKillSwitch() public view returns (bool) {
        return killSwitch;
    }

    function switchSTP() public onlyOwner returns (bool) {
        killSwitch = !killSwitch;
        emit isSwiched(killSwitch);
        return killSwitch;
    }

    function getAllStpTokens() public view returns (TokenInfo[] memory) {
        uint32 count = 0;
        for (uint256 i = 0; i < tokensCount; i++) {
            if (!nameToInfo[idToAddress[i]].isDeleted) {
                count++;
            }
        }

        TokenInfo[] memory response = new TokenInfo[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < tokensCount; i++) {
            if (!nameToInfo[idToAddress[i]].isDeleted) {
                response[index++] = nameToInfo[idToAddress[i]];
            }
        }

        return response;
    }

    function getTokenSTP(address _tokenAddress) public view returns (TokenInfo memory) {
        return nameToInfo[_tokenAddress];
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = SafeswapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2 ? SafeswapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            ISafeswapPair(SafeswapLibrary.pairFor(factory, input, output)).swap(
                amount0Out,
                amount1Out,
                to,
                new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) onlyWhitelist returns (uint256[] memory amounts) {
        amounts = SafeswapLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "SafeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        // snippet for 'sell' fees !
        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amountIn = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], msg.sender, nameToInfo[path[0]].feesAddress, deduction);
        }
        amounts = SafeswapLibrary.getAmountsOut(factory, amountIn, path);
        // same code snippet for 'buy' fees
        if (nameToInfo[path[1]].enabled == true && killSwitch == false && (nameToInfo[path[1]].buyFeePercent > 0)) {
            uint256 amountOut = amounts[amounts.length - 1];
            uint256 deduction = (amountOut * nameToInfo[path[1]].buyFeePercent) / ONE;
            amountOut = amountOut - deduction;
            amounts[amounts.length - 1] = amountOut;
        }

        TransferHelper.safeTransferFrom(path[0], msg.sender, SafeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address from,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) onlyWhitelist returns (uint256[] memory amounts) {
        amounts = SafeswapLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "SafeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        // snippet for 'sell' fees !
        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amountIn = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], from, nameToInfo[path[0]].feesAddress, deduction);
        }
        amounts = SafeswapLibrary.getAmountsOut(factory, amountIn, path);
        // same code snippet for 'buy' fees
        if (nameToInfo[path[1]].enabled == true && killSwitch == false && (nameToInfo[path[1]].buyFeePercent > 0)) {
            uint256 amountOut = amounts[amounts.length - 1];
            uint256 deduction = (amountOut * nameToInfo[path[1]].buyFeePercent) / ONE;
            amountOut = amountOut - deduction;
            amounts[amounts.length - 1] = amountOut;
        }

        TransferHelper.safeTransferFrom(path[0], from, SafeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) onlyWhitelist returns (uint256[] memory amounts) {
        amounts = SafeswapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "SafeswapRouter: EXCESSIVE_INPUT_AMOUNT");
        if (nameToInfo[path[1]].enabled == true && killSwitch == false && (nameToInfo[path[1]].buyFeePercent > 0)) {
            uint256 deduction = (amountOut * nameToInfo[path[1]].buyFeePercent) / ONE;
            amountOut = amountOut - deduction;
        }
        amounts = SafeswapLibrary.getAmountsIn(factory, amountOut, path);
        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 amountIn = amounts[0];
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amounts[0] = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], msg.sender, nameToInfo[path[0]].feesAddress, deduction);
        }
        amounts = SafeswapLibrary.getAmountsOut(factory, amounts[0], path);

        TransferHelper.safeTransferFrom(path[0], msg.sender, SafeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address from,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) onlyWhitelist returns (uint256[] memory amounts) {
        amounts = SafeswapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "SafeswapRouter: EXCESSIVE_INPUT_AMOUNT");
        if (nameToInfo[path[1]].enabled == true && killSwitch == false && (nameToInfo[path[1]].buyFeePercent > 0)) {
            uint256 deduction = (amountOut * nameToInfo[path[1]].buyFeePercent) / ONE;
            amountOut = amountOut - deduction;
        }
        amounts = SafeswapLibrary.getAmountsIn(factory, amountOut, path);
        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 amountIn = amounts[0];
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amounts[0] = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], from, nameToInfo[path[0]].feesAddress, deduction);
        }
        amounts = SafeswapLibrary.getAmountsOut(factory, amounts[0], path);

        TransferHelper.safeTransferFrom(path[0], from, SafeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }


    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to)
        internal
        virtual
        returns (uint256 amount0Out, uint256 amount1Out)
    {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = SafeswapLibrary.sortTokens(input, output);
            ISafeswapPair pair = ISafeswapPair(SafeswapLibrary.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
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

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) onlyWhitelist {
        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amountIn = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], msg.sender, nameToInfo[path[0]].feesAddress, deduction);
        }

        TransferHelper.safeTransferFrom(path[0], msg.sender, SafeswapLibrary.pairFor(factory, path[0], path[1]), amountIn);
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "SafeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address from,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) onlyWhitelist {
        if (nameToInfo[path[0]].enabled == true && killSwitch == false && (nameToInfo[path[0]].sellFeePercent > 0)) {
            uint256 deduction = (amountIn * nameToInfo[path[0]].sellFeePercent) / ONE;
            amountIn = amountIn - deduction;
            TransferHelper.safeTransferFrom(path[0], from, nameToInfo[path[0]].feesAddress, deduction);
        }

        TransferHelper.safeTransferFrom(path[0], from, SafeswapLibrary.pairFor(factory, path[0], path[1]), amountIn);
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "SafeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

}