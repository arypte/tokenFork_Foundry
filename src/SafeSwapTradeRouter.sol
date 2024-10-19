/**
 * Submitted for verification at BscScan.com on 2023-09-29
 */

//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import {ISafeswapRouter01} from "./interfaces/SafeMoon/ISafeswapRouter01.sol";
import {ISafeSwapRouter} from "./ISafeswapRouter.sol";

import {IFeeJar} from "./interfaces/SafeMoon/IFeeJar.sol";

import {Initializable} from "./lib/openzeppelin/Initializable.sol";

import {IERC20} from "./IERC20.sol";

import {ISafeswapFactory} from "./interfaces/SafeMoon/ISafeswapFactory.sol";

import {ISafeswapPair} from "./interfaces/SafeMoon/ISafeswapPair.sol";

import {TransferHelper} from "./library/TransferHelper.sol";

/**
 * @title SafeSwapTradeRouter
 * @dev Allows SFM Router-compliant trades to be paid via bsc
 */
contract SafeSwapTradeRouter is Initializable {
    /*========================================================================================================================*/
    /*======================================================= constants ======================================================*/
    /*========================================================================================================================*/

    uint256 private constant LP_PRICE_BASE_AMOUNT = 6;

    /*========================================================================================================================*/
    /*======================================================== states ========================================================*/
    /*========================================================================================================================*/

    /// @notice FeepJar proxy
    IFeeJar public feeJar;
    address public swapRouter;
    address public admin;
    uint256 public percent;
    uint256 public feePercent;

    address[] private tokenFeeAddresses;

    bool public isARCBEnabled;

    /*========================================================================================================================*/
    /*======================================================= mappings =======================================================*/
    /*========================================================================================================================*/

    mapping(address => bool) public whitelistFfsFee;

    mapping(address => mapping(TransactionType => TokenFee)) private tokensFeeList;

    mapping(address => AdaptiveLpPriceRange) private adaptiveLpPriceRange;

    /*========================================================================================================================*/
    /*======================================================= structs ========================================================*/
    /*========================================================================================================================*/

    /// @notice Trade details
    struct Trade {
        uint256 amountIn;
        uint256 amountOut;
        address[] path;
        address payable to;
        uint256 deadline;
    }

    /// @notice TMI details
    struct TokenFee {
        TokenInfo tokenInfo;
        SingleSwapFee[] singleSwapFees;
    }

    struct TokenInfo {
        TransactionType transactionType;
        address tokenAddress;
        uint256 feePercentage;
        bool isEnabled;
        bool isDeleted;
    }

    /// @notice adaptive Lp Price Range details
    struct AdaptiveLpPriceRange {
        address tokenAddress;
        uint256 lastPrice;
        uint256 upl;
        uint256 lpl;
        bool isEnabled;
    }

    /// @notice FM details
    struct SingleSwapFee {
        SwapKind swapKind;
        address assetOut;
        address beneficiary;
        uint256 percentage;
        bool isEnabled;
    }

    /*========================================================================================================================*/
    /*========================================================= enum =========================================================*/
    /*========================================================================================================================*/

    enum SwapKind {
        SEND_ONLY,
        SWAP_AND_SEND,
        SWAP_AND_BURN
    }

    enum FeeKind {
        TOKEN_FEE,
        PORTAL_FEE
    }

    enum TransactionType {
        SELL,
        BUY
    }

    /*========================================================================================================================*/
    /*======================================================== events ========================================================*/
    /*========================================================================================================================*/

    event NewFeeJar(address indexed _feeJar);
    event SetTokenFeeStatus(address indexed _tokenAddress, TransactionType _transactionType, bool _isEnabled);
    event SetTokenDeletionStatus(address indexed _tokenAddress, TransactionType _transactionType, bool _status);
    event SubmitLpPriceRange(address indexed _pair, uint256 indexed _upl, uint256 indexed _lpl, uint256 _lastPrice);
    event SetLpPriceRangeStatus(address indexed _pair, bool _isEnabled);
    event SetARCBStatus(bool _isARCBEnabled);
    event SetTokenSwapFeeStatus(
        address indexed _tokenAddress, TransactionType _transactionType, bool _isEnabled, uint256 indexed _index
    );
    event SubmitTokenSwapFee(
        address indexed _tokenAddress,
        TransactionType _transactionType,
        uint256 _tokenFeePercentage,
        SwapKind _swapKind,
        address indexed _assetOut,
        address indexed _beneficiary,
        uint256 swapFeePercentage,
        bool isEnabled
    );
    event TokenFeeSwapped(
        address indexed _beneficiary, address indexed _assetIn, address indexed _assetOut, uint256 _feeAmount
    );

    /*========================================================================================================================*/
    /*====================================================== modifiers =======================================================*/
    /*========================================================================================================================*/

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    modifier isSwapRangeValid(address[] memory _path) {
        _isSwapRangeValid(_path);
        _;
    }

    modifier isTokenInfoDelted(bool _isTokenDeleted) {
        _isTokenInfoDeleted(_isTokenDeleted);
        _;
    }

    modifier isValidAdd(address _address) {
        _isValidAdd(_address);
        _;
    }

    /*========================================================================================================================*/
    /*====================================================== initialize ======================================================*/
    /*========================================================================================================================*/

    function initialize(address _feeJar, address _router, uint256 _feePercent, uint256 _percent) external initializer {
        feeJar = IFeeJar(_feeJar);
        swapRouter = _router;
        admin = msg.sender;
        feePercent = _feePercent;
        percent = _percent;
        isARCBEnabled = true;
    }

    /*========================================================================================================================*/
    /*=================================================== public functions ===================================================*/
    /*========================================================================================================================*/

    /*========================================================================================================================*/
    /*================================================== external functions ==================================================*/
    /*========================================================================================================================*/

    /**
     * @notice Swap tokens for BNB and pay amount of BNB as fee
     * @param trade Trade details
     */
    // input = tokenAFee + swapInput
    function swapExactTokensForETHAndFeeAmount(Trade memory trade) external payable isSwapRangeValid(trade.path) {
        // TODO: 뭔지 모르겠음 아직
        uint256[] memory lastLpsPrices = _calcLpsLastPrice(trade.path);

        //! dex fee 계산

        /* 
            Dex Fee - User 입장에서 낼 금액
            Fee Jar - 운영자 입장에서 분배되는 금액 (BuybackAndBurn, Supporter, LP)
         */
        (, uint256 dexFee, uint256 tokenAFee,) = getFees(trade.path, trade.amountIn, msg.sender);

        require(msg.value >= dexFee, "SafeswapRouter: You must send enough BNB to cover fee");

        //! Dex Fee는 Fee Jar로 분배
        _feeAmountBNB(address(this).balance);

        if (tokenAFee > 0) {
            //! 여기가 fee 떼는 곳
            // tokenA -> WETH로 스왑
            _claimTokenFee(trade.path[0], msg.sender, TransactionType.SELL, trade.amountIn, tokenAFee, false);

            //! 나머지를 swap
            _swapExactTokensForETH(
                _getContractBalance(trade.path[0]), trade.amountOut, trade.path, address(this), trade.to, trade.deadline
            );

            // 화리인 경우
        } else {
            //! 화리인 경우 전체를 그대로 swap
            _swapExactTokensForETH(trade.amountIn, trade.amountOut, trade.path, msg.sender, trade.to, trade.deadline);
        }

        _updateLastPairsPrice(trade.path, lastLpsPrices);
    }

    /**
     * @notice Swap tokens for BNB and pay amount of BNB as fee
     * @param trade Trade details
     */
    function swapTokensForExactETHAndFeeAmount(Trade memory trade) external payable isSwapRangeValid(trade.path) {
        uint256[] memory lastLpsPrices = _calcLpsLastPrice(trade.path);

        (, uint256 dexFee, uint256 tokenAFee,) = getFees(trade.path, trade.amountIn, msg.sender);
        require(msg.value >= dexFee, "SafeswapRouter: You must send enough BNB to cover fee");
        _feeAmountBNB(address(this).balance);

        if (tokenAFee > 0) {
            _claimTokenFee(trade.path[0], msg.sender, TransactionType.SELL, trade.amountIn, tokenAFee, false);
            _swapTokensForExactETH(
                _getAmountsOut(_getContractBalance(trade.path[0]), trade.path),
                _getContractBalance(trade.path[0]),
                trade.path,
                address(this),
                trade.to,
                trade.deadline
            );
        } else {
            _swapTokensForExactETH(trade.amountOut, trade.amountIn, trade.path, msg.sender, trade.to, trade.deadline);
        }

        _updateLastPairsPrice(trade.path, lastLpsPrices);
    }

    /**
     * @notice Swap BNB for tokens and pay % of BNB input as fee
     * @param trade Trade details
     * @param _feeAmount Fee value
     */
    function swapExactETHForTokensWithFeeAmount(Trade memory trade, uint256 _feeAmount)
        external
        payable
        isSwapRangeValid(trade.path)
    {
        uint256[] memory lastLpsPrices = _calcLpsLastPrice(trade.path);

        (, uint256 dexFee,, uint256 tokenBFee) = getFees(trade.path, trade.amountIn, msg.sender);
        require(
            _feeAmount >= dexFee && (msg.value >= trade.amountIn + dexFee),
            "SafeswapRouter: You must send enough BNB to cover fee "
        );
        _distributeTokenFee(trade.path[trade.path.length - 1], TransactionType.BUY, tokenBFee);
        _feeAmountBNB(dexFee);

        _swapExactETHForTokens((trade.amountIn - tokenBFee), trade.amountOut, trade.path, trade.to, trade.deadline);
        _updateLastPairsPrice(trade.path, lastLpsPrices);
    }

    /**
     * @notice Swap BNB for tokens and pay amount of BNB input as fee
     * @param trade Trade details
     * @param _feeAmount Fee value
     */
    function swapETHForExactTokensWithFeeAmount(Trade memory trade, uint256 _feeAmount)
        external
        payable
        isSwapRangeValid(trade.path)
    {
        uint256[] memory lastLpsPrices = _calcLpsLastPrice(trade.path);

        (, uint256 dexFee,, uint256 tokenBFee) = getFees(trade.path, trade.amountIn, msg.sender);
        require(
            _feeAmount >= dexFee && (msg.value >= trade.amountIn + dexFee),
            "SafeswapRouter: You must send enough BNB to cover fee "
        );
        _distributeTokenFee(trade.path[trade.path.length - 1], TransactionType.BUY, tokenBFee);
        _feeAmountBNB(dexFee);

        _swapETHForExactTokens(trade.amountOut, (trade.amountIn - tokenBFee), trade.path, trade.to, trade.deadline);

        _updateLastPairsPrice(trade.path, lastLpsPrices);
    }

    /**
     * @notice Swap tokens for tokens and pay BNB amount as fee
     * @param trade Trade details
     */
    function swapExactTokensForTokensWithFeeAmount(Trade memory trade) external payable isSwapRangeValid(trade.path) {
        uint256[] memory lastLpsPrices = _calcLpsLastPrice(trade.path);

        (, uint256 dexFee, uint256 tokenAFee, uint256 tokenBFee) = getFees(trade.path, trade.amountIn, msg.sender);
        require(msg.value >= dexFee, "SafeswapRouter: You must send enough BNB to cover fee");
        _feeAmountBNB(address(this).balance);

        if (tokenAFee > 0) {
            _claimTokenFee(trade.path[0], msg.sender, TransactionType.SELL, trade.amountIn, tokenAFee, false);
        }

        if (tokenBFee > 0) {
            if (tokenAFee == 0) {
                TransferHelper.safeTransferFrom(trade.path[0], msg.sender, address(this), trade.amountIn);
                TransferHelper.safeApprove(trade.path[0], address(swapRouter), _getContractBalance(trade.path[0]));
            }

            _swapExactTokensForTokens(
                _getContractBalance(trade.path[0]),
                trade.amountOut,
                trade.path,
                address(this),
                address(this),
                trade.deadline
            );
            _claimTokenFee(
                trade.path[trade.path.length - 1], trade.to, TransactionType.BUY, trade.amountOut, tokenBFee, true
            );
        } else {
            if (tokenAFee > 0) {
                _swapExactTokensForTokens(
                    _getContractBalance(trade.path[0]),
                    trade.amountOut,
                    trade.path,
                    address(this),
                    trade.to,
                    trade.deadline
                );
            } else {
                _swapExactTokensForTokens(
                    trade.amountIn, trade.amountOut, trade.path, msg.sender, trade.to, trade.deadline
                );
            }
        }

        _updateLastPairsPrice(trade.path, lastLpsPrices);
    }

    /**
     * @notice Swap tokens for tokens and pay BNB amount as fee
     * @param trade Trade details
     */
    function swapTokensForExactTokensWithFeeAmount(Trade memory trade) external payable isSwapRangeValid(trade.path) {
        uint256[] memory lastLpsPrices = _calcLpsLastPrice(trade.path);

        (, uint256 dexFee, uint256 tokenAFee, uint256 tokenBFee) = getFees(trade.path, trade.amountIn, msg.sender);
        require(msg.value >= dexFee, "SafeswapRouter: You must send enough BNB to cover fee");
        _feeAmountBNB(address(this).balance);

        if (tokenAFee > 0) {
            _claimTokenFee(trade.path[0], msg.sender, TransactionType.SELL, trade.amountIn, tokenAFee, false);
        }

        if (tokenBFee > 0) {
            if (tokenAFee == 0) {
                TransferHelper.safeTransferFrom(trade.path[0], msg.sender, address(this), trade.amountIn);
                TransferHelper.safeApprove(trade.path[0], address(swapRouter), _getContractBalance(trade.path[0]));
            }
            _swapTokensForExactTokens(
                trade.amountOut,
                _getContractBalance(trade.path[0]),
                trade.path,
                address(this),
                address(this),
                trade.deadline
            );
            _claimTokenFee(
                trade.path[trade.path.length - 1], trade.to, TransactionType.BUY, trade.amountOut, tokenBFee, true
            );
        } else {
            if (tokenAFee > 0) {
                _swapTokensForExactTokens(
                    trade.amountOut, trade.amountIn, trade.path, msg.sender, trade.to, trade.deadline
                );
            } else {
                _swapTokensForExactTokens(
                    // _getAmountsOut(_getContractBalance(trade.path[0]), trade.path),
                    trade.amountOut,
                    _getContractBalance(trade.path[0]),
                    trade.path,
                    address(this),
                    trade.to,
                    trade.deadline
                );
            }
        }

        _updateLastPairsPrice(trade.path, lastLpsPrices);
    }

    /*========================================================================================================================*/
    /*================================================== internal functions ==================================================*/
    /*========================================================================================================================*/

    /**
     * @notice Internal implementation of swap BNB for tokens
     * @param amountIn Amount to swap
     * @param amountOutMin Minimum amount out
     * @param path Path for swap
     * @param to Address to receive tokens
     * @param deadline Block timestamp deadline for trade
     */
    function _swapExactETHForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal {
        ISafeSwapRouter(swapRouter).swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountIn}(
            amountOutMin, path, to, deadline
        );
    }

    /**
     * @notice Internal implementation of swap BNB for tokens
     * @param amountOut Amount of BNB out
     * @param amountInMax Max amount in
     * @param path Path for swap
     * @param to Address to receive BNB
     * @param deadline Block timestamp deadline for trade
     */
    function _swapETHForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal {
        ISafeSwapRouter(swapRouter).swapETHForExactTokens{value: amountInMax}(amountOut, path, to, deadline);
    }

    /**
     * @notice Internal implementation of swap tokens for BNB
     * @param amountOut Amount of BNB out
     * @param amountInMax Max amount in
     * @param path Path for swap
     * @param from address to swap token from
     * @param to Address to receive BNB
     * @param deadline Block timestamp deadline for trade
     */
    function _swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address from,
        address to,
        uint256 deadline
    ) internal {
        ISafeSwapRouter(swapRouter).swapTokensForExactETH(amountOut, amountInMax, path, from, to, deadline);
    }

    /**
     * @notice Internal implementation of swap tokens for BNB
     * @param amountIn Amount to swap
     * @param amountOutMin Minimum amount out
     * @param path Path for swap
     * @param from address to swap token from
     * @param to Address to receive tokens
     * @param deadline Block timestamp deadline for trade
     */
    function _swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address from,
        address to,
        uint256 deadline
    ) internal {
        ISafeSwapRouter(swapRouter).swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn, amountOutMin, path, from, to, deadline
        );
    }

    /**
     * @notice Internal implementation of swap tokens for tokens
     * @param amountIn Amount to swap
     * @param amountOutMin Minimum amount out
     * @param path Path for swap
     * @param from address to swap token from
     * @param to Address to receive tokens
     * @param deadline Block timestamp deadline for trade
     */
    function _swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address from,
        address to,
        uint256 deadline
    ) internal {
        ISafeSwapRouter(swapRouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, amountOutMin, path, from, to, deadline
        );
    }

    /**
     * @notice Internal implementation of swap tokens for tokens
     * @param amountOut Amount of tokens out
     * @param amountInMax Max amount in
     * @param path Path for swap
     * @param from address to swap token from
     * @param to Address to receive tokens
     * @param deadline Block timestamp deadline for trade
     */
    function _swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address from,
        address to,
        uint256 deadline
    ) internal {
        ISafeSwapRouter(swapRouter).swapTokensForExactTokens(amountOut, amountInMax, path, from, to, deadline);
    }

    function getAdaptiveLpPriceRange(address _pair) internal returns (uint256 upl, uint256 lpl, uint256 lastPrice) {
        if (adaptiveLpPriceRange[_pair].tokenAddress == address(0)) {
            _submitLpPriceRange(_pair, 150, 50);
        }

        upl = adaptiveLpPriceRange[_pair].upl;
        lpl = adaptiveLpPriceRange[_pair].lpl;
        lastPrice = adaptiveLpPriceRange[_pair].lastPrice;
    }

    function _syncPair(address _tokenA, address _tokenB) internal {
        address pair = pairFor(_tokenA, _tokenB);
        (uint256 reserveInput, uint256 reserveOutput) = getReserves(pair, false);

        (address token0,) = sortTokens(_tokenA, _tokenB);
        (reserveInput, reserveOutput) =
            _tokenA == token0 ? (reserveInput, reserveOutput) : (reserveOutput, reserveInput);

        if (
            _getAddressBalance(_tokenA, pair) - reserveInput > 0
                || _getAddressBalance(_tokenB, pair) - reserveOutput > 0
        ) {
            ISafeswapPair(pair).sync();
        }
    }

    function _transferContractBalance(address _token, address _to) internal {
        TransferHelper.safeTransfer(_token, payable(_to), _getContractBalance(_token));
    }

    /**
     * @notice Fee specific amount of BNB
     * @param feeAmount Amount to fee
     */
    function _feeAmountBNB(uint256 feeAmount) internal {
        if (feeAmount > 0) {
            feeJar.fee{value: feeAmount}();
        }
    }

    /**
     * @notice Convert a token balance into BNB and then fee
     * @param _fee Amount to swap
     * @param _payInToken token address would be used to pay with
     * @param _claimFee indicate to transfer fee or not
     */
    function _feeWithTokens(uint256 _fee, address _payInToken, bool _claimFee) internal {
        TransferHelper.safeApprove(_payInToken, address(swapRouter), _fee);

        // WETH로 변환
        _swapExactTokensForETH(_fee, 0, _mapPath(_payInToken, WETH()), address(this), address(this), block.timestamp);

        //! fee
        if (_claimFee) {
            _feeAmountBNB(address(this).balance);
        }
    }

    /*========================================================================================================================*/
    /*=================================================== private functions ==================================================*/
    /*========================================================================================================================*/

    function _isSwapRangeValid(address[] memory _path) private {
        require(_isLpsPriceInRange(_path), "SafeswapRouter: Transaction rejected by ARC-B");
    }

    function _isLpPriceInRange(address _tokenA, address _tokenB) private returns (bool) {
        address pair = pairFor(_tokenA, _tokenB);
        (uint256 upl, uint256 lpl, uint256 lastPrice) = getAdaptiveLpPriceRange(pair);

        if (isARCBEnabled) {
            if (adaptiveLpPriceRange[pair].isEnabled) {
                (address token0, address token1) = sortTokens(_tokenA, _tokenB);
                uint256 decimals = _getTokenDecimals(token0);
                decimals = decimals + _getTokenDecimals(token1);
                lastPrice = _tokenA == token0 ? lastPrice : 10 ** decimals / lastPrice;

                uint256 amountIn = 10 ** (_getTokenDecimals(_tokenA) - LP_PRICE_BASE_AMOUNT);
                uint256 numerator = amountIn * _getAddressBalance(_tokenB, pair);
                uint256 denominator = _getAddressBalance(_tokenA, pair) + amountIn;
                uint256 currentPrice = (numerator / denominator) * 10 ** LP_PRICE_BASE_AMOUNT;

                if (currentPrice > ((upl * lastPrice) / 100) || currentPrice < ((lpl * lastPrice) / 100)) return false;
            }
            _syncPair(_tokenA, _tokenB);
        }

        return true;
    }

    function _isLpsPriceInRange(address[] memory _path) private returns (bool isInRange) {
        // if (isARCBEnabled) {
        for (uint256 i; i < _path.length - 1; i++) {
            // bool isLpPriceInRange = _isLpPriceInRange(_path[i], _path[i + 1]);
            if (!_isLpPriceInRange(_path[i], _path[i + 1])) {
                return false;
            }
        }
        // }
        return true;
    }

    function _submitLpPriceRange(address _pair, uint256 _upl, uint256 _lpl) private isValidAdd(_pair) {
        uint256 lastPrice = _getLPPrice(ISafeswapPair(_pair).token0(), ISafeswapPair(_pair).token1());

        AdaptiveLpPriceRange storage _adaptiveLpPriceRange = adaptiveLpPriceRange[_pair];
        _adaptiveLpPriceRange.lastPrice = lastPrice;
        _adaptiveLpPriceRange.tokenAddress = _pair;
        _adaptiveLpPriceRange.upl = _upl;
        _adaptiveLpPriceRange.lpl = _lpl;
        _adaptiveLpPriceRange.isEnabled = true;

        emit SubmitLpPriceRange(_pair, _upl, _lpl, lastPrice);
    }

    function _updateLastPairPrice(address _tokenA, address _tokenB, uint256 _updatedPrice) private {
        address pair = pairFor(_tokenA, _tokenB);
        (address token0, address token1) = sortTokens(_tokenA, _tokenB);
        // uint256 decimals = _getTokenDecimals(token0);
        // decimals = decimals + _getTokenDecimals(token1);
        _updatedPrice = _tokenA == token0
            ? _updatedPrice
            : 10 ** (_getTokenDecimals(token0) + _getTokenDecimals(token1)) / _updatedPrice;
        adaptiveLpPriceRange[pair].lastPrice = _updatedPrice;
    }

    function _updateLastPairsPrice(address[] memory _path, uint256[] memory _lastPrices) private {
        for (uint256 i; i < _path.length - 1; i++) {
            _updateLastPairPrice(_path[i], _path[i + 1], _lastPrices[i]);
        }
    }

    function _distributeTokenFee(address _token, TransactionType _transactionType, uint256 _totalFeeAmount) private {
        uint256 feeAmount;
        uint256 claimedAmount;

        if (tokensFeeList[_token][_transactionType].tokenInfo.isEnabled && _totalFeeAmount > 0) {
            uint256 length = tokensFeeList[_token][_transactionType].singleSwapFees.length;

            for (uint256 i; i < length; i++) {
                if (
                    tokensFeeList[_token][_transactionType].singleSwapFees[i].isEnabled
                        && tokensFeeList[_token][_transactionType].singleSwapFees[i].percentage > 0
                ) {
                    address beneficiary = tokensFeeList[_token][_transactionType].singleSwapFees[i].beneficiary;
                    address assetOut = tokensFeeList[_token][_transactionType].singleSwapFees[i].assetOut;
                    if (i == (length - 1)) {
                        feeAmount = _totalFeeAmount - claimedAmount;
                    } else {
                        uint256 swapKindPercentage = (
                            tokensFeeList[_token][_transactionType].singleSwapFees[i].percentage * percent
                        ) / tokensFeeList[_token][_transactionType].tokenInfo.feePercentage;

                        feeAmount = ((_totalFeeAmount * swapKindPercentage) / percent);
                        claimedAmount = claimedAmount + feeAmount;
                    }

                    if (tokensFeeList[_token][_transactionType].singleSwapFees[i].swapKind == SwapKind.SEND_ONLY) {
                        TransferHelper.safeTransferETH(beneficiary, feeAmount);
                    } else {
                        _swapExactETHForTokens(
                            feeAmount, 0, _mapPath(WETH(), assetOut), beneficiary, block.timestamp + 20
                        );
                    }

                    emit TokenFeeSwapped(beneficiary, _token, assetOut, feeAmount);
                }
            }
        }
    }

    function _claimTokenFee(
        address _token,
        address _address,
        TransactionType _transactionType,
        uint256 _amountIn,
        uint256 _totalFeeAmount,
        bool _transferBalance
    ) private {
        if (tokensFeeList[_token][_transactionType].tokenInfo.isEnabled && _totalFeeAmount > 0) {

            // _transferBalance가 false인 경우에는 들고옴 (뭔차이인지 모르겠다)
            if (!_transferBalance) {
                TransferHelper.safeTransferFrom(_token, _address, address(this), _amountIn);
            }

            // fee를 WETH로 변환
            _feeWithTokens(_totalFeeAmount, _token, false);

            // TODO: 아직 못봄
            _distributeTokenFee(_token, _transactionType, address(this).balance);

            if (_transferBalance) {
                _transferContractBalance(_token, _address);
            } else {
                TransferHelper.safeApprove(_token, address(swapRouter), _getContractBalance(_token));
            }
        }
    }

    /*========================================================================================================================*/
    /*================================================= public view functions ================================================*/
    /*========================================================================================================================*/

    function getReserves(address pair) public view returns (uint256 reserve0, uint256 reserve1) {
        if (pair == address(0)) {
            return (0, 0);
        }
        (reserve0, reserve1) = getReserves(pair, true);
    }

    function getFees(address[] memory _path, uint256 _amountIn, address _address)
        public
        view
        returns (uint256 totalBNBFee, uint256 dexFee, uint256 tokenAFee, uint256 tokenBFee)
    {
        // 화리는 fee 안뗌
        if (whitelistFfsFee[_address]) {
            return (0, 0, 0, 0);
        }

        uint256 length = _path.length - 1;
        (address _tokenInput, address _tokenOutput) = (_path[0], _path[length]);

        uint256 amountInput = _amountIn;

        for (uint256 i; i < length; i++) {
            (address input, address output) = (_path[i], _path[i + 1]);

            dexFee += getDexSwapFee(amountInput, input, output);

            uint256 feeA = getTokenSwapFee(
                amountInput, TransactionType.SELL, input, _getTokenDecimals(_tokenInput), _getTokenDecimals(input)
            );

            uint256 amountOutput = _getAmountOut(amountInput, input, output, true);

            amountInput = amountOutput;

            uint256 feeB = getTokenSwapFee(
                amountOutput, TransactionType.BUY, output, _getTokenDecimals(_tokenOutput), _getTokenDecimals(output)
            );

            if (_isNativeToken(_tokenInput)) {
                tokenAFee += feeA;
                tokenBFee += _getAmountOut(feeB, output, WETH(), true);
            } else {
                tokenAFee += feeA;
                tokenBFee += feeB;
            }
        }

        if (_isNativeToken(_tokenInput)) {
            totalBNBFee = tokenAFee + tokenBFee + dexFee;
        } else {
            if (_isNativeToken(_tokenOutput)) {
                totalBNBFee = _getAmountOut(tokenAFee, _tokenInput, WETH(), true) + tokenBFee + dexFee;
            } else {
                totalBNBFee = _getAmountOut(tokenAFee, _tokenInput, WETH(), true)
                    + _getAmountOut(tokenBFee, _tokenOutput, WETH(), true) + dexFee;
            }
        }
    }

    function getSwapFees(uint256 amountIn, address[] memory path) public view returns (uint256 _fees) {
        (, _fees,,) = getFees(path, amountIn, msg.sender);
    }

    /*========================================================================================================================*/
    /*================================================ external view functions ===============================================*/
    /*========================================================================================================================*/

    /**
     * @notice Returns the tokens fee information list.
     * @return the tokens fee information list
     */
    function getTokenFeeAddresses() external view returns (address[] memory) {
        return tokenFeeAddresses;
    }

    /**
     * @notice Returns the token swap fee information for a given identifier.
     * @return the token fee information
     */
    function getTokenInfoDetails(address _tokenAddress, TransactionType _transactionType)
        external
        view
        returns (TokenFee memory)
    {
        return tokensFeeList[_tokenAddress][_transactionType];
    }

    /*========================================================================================================================*/
    /*================================================ internal view functions ===============================================*/
    /*========================================================================================================================*/

    function WETH() internal view returns (address) {
        return ISafeSwapRouter(swapRouter).WETH();
    }

    function _getAmountOut(uint256 _amountIn, address _tokenA, address _tokenB, bool _getByBalance)
        internal
        view
        returns (uint256 _amountOut)
    {
        (uint256 reserveInput, uint256 reserveOutput) = getReserves(pairFor(_tokenA, _tokenB), _getByBalance);
        (address token0,) = sortTokens(_tokenA, _tokenB);
        (reserveInput, reserveOutput) =
            _tokenA == token0 ? (reserveInput, reserveOutput) : (reserveOutput, reserveInput);

        try ISafeSwapRouter(swapRouter).getAmountOut(_amountIn, reserveInput, reserveOutput) returns (uint256 amountOut)
        {
            _amountOut = amountOut;
        } catch {
            _amountOut = 0;
        }
    }

    function _isNativeToken(address _token) internal view returns (bool isNative) {
        isNative = _token == WETH();
    }

    function _getContractBalance(address _token) internal view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function _getAddressBalance(address _token, address _owner) internal view returns (uint256) {
        return IERC20(_token).balanceOf(address(_owner));
    }

    function _getAmountsOut(uint256 _amountIn, address[] memory _path) internal view returns (uint256 amountOut) {
        try ISafeSwapRouter(swapRouter).getAmountsOut(_amountIn, _path) returns (uint256[] memory amounts) {
            amountOut = amounts[amounts.length - 1];
        } catch {
            amountOut = 0;
        }
    }

    function _getLPPrice(address token0, address token1) internal view returns (uint256) {
        return _getAmountsOut(10 ** (_getTokenDecimals(token0) - LP_PRICE_BASE_AMOUNT), _mapPath(token0, token1))
            * 10 ** LP_PRICE_BASE_AMOUNT;
    }

    function pairFor(address _token0, address _token1) internal view returns (address pair) {
        pair = ISafeswapFactory(ISafeSwapRouter(swapRouter).factory()).getPair(_token0, _token1);
        require(pair != address(0), "SafeswapRouter: Cannot find pair");
    }

    function _calcLpsLastPrice(address[] memory _path) internal view returns (uint256[] memory amounts) {
        amounts = new uint256[](_path.length - 1);
        for (uint256 i; i < _path.length - 1; i++) {
            amounts[i] = _getLPPrice(_path[i], _path[i + 1]);
        }
    }

    // /**
    //  * @notice Get swap fee based on the amounts
    //  * @param amountIn Amount in to calculate fee
    //  * @param tokenA token1 for swap
    //  * @param tokenB token2 for swap
    //  * @return _fee the tokens fee amount value
    //  */
    function getDexSwapFee(uint256 amountIn, address tokenA, address tokenB) internal view returns (uint256 _fee) {
        uint256 amountOut;

        // tokenA가 WETH 아닌 경우
        if (!_isNativeToken(tokenA)) {
            amountOut = _getAmountOut(amountIn, tokenA, WETH(), true);
            if (amountOut == 0) {
                amountOut = _getAmountOut(amountIn, tokenA, tokenB, true);
                amountOut = _getAmountOut(amountOut, tokenB, WETH(), true);
            }

            _fee = (amountOut * feePercent) / percent;
        }

        // tokenA가 WETH인 경우
        if (_isNativeToken(tokenA) || amountOut == 0) {
            int256 decimals = 18 - int8(IERC20(tokenA).decimals());
            if (decimals < 0) {
                decimals = decimals * -1;
                _fee = ((amountIn * feePercent) / percent) / 10 ** uint256(decimals);
            } else {
                _fee = ((amountIn * feePercent) / percent) * 10 ** uint256(decimals);
            }
        }
    }

    /**
     * @notice Get token swap fee for single token
     * @param _amount Amount to calculate fee
     * @param _transactionType BUY or SELL
     * @param _token token addresses
     * @param _tokenADecimals decimals for tokenA
     * @param _tokenBDecimals decimals for tokenB
     * @return _fee token swap fees amount
     */
    function getTokenSwapFee(
        uint256 _amount,
        TransactionType _transactionType,
        address _token,
        uint256 _tokenADecimals,
        uint256 _tokenBDecimals
    ) internal view returns (uint256 _fee) {
        if (
            !_isNativeToken(_token) && tokensFeeList[_token][_transactionType].tokenInfo.isEnabled
                && tokensFeeList[_token][_transactionType].tokenInfo.feePercentage > 0 && !whitelistFfsFee[msg.sender]
        ) {
            int256 decimals = int256(_tokenADecimals) - int256(_tokenBDecimals);

            if (decimals < 0) {
                decimals = decimals * -1;
                _fee = (
                    ((_amount * tokensFeeList[_token][_transactionType].tokenInfo.feePercentage) / percent)
                        / 10 ** uint256(decimals)
                );
            } else {
                _fee = ((_amount * tokensFeeList[_token][_transactionType].tokenInfo.feePercentage) / percent)
                    * 10 ** uint256(decimals);
            }
        }
    }

    /*========================================================================================================================*/
    /*================================================= private view functions ===============================================*/
    /*========================================================================================================================*/

    function _onlyOwner() private view {
        require(admin == msg.sender, "Ownable: caller is not the owner");
    }

    function getReserves(address pair, bool getByBalance) private view returns (uint256 reserve0, uint256 reserve1) {
        (reserve0, reserve1,) = ISafeswapPair(pair).getReserves();

        if (getByBalance) {
            (reserve0, reserve1) = (
                _getAddressBalance(ISafeswapPair(pair).token0(), pair),
                _getAddressBalance(ISafeswapPair(pair).token1(), pair)
            );
        }
    }

    /*========================================================================================================================*/
    /*================================================== public pure functions ===============================================*/
    /*========================================================================================================================*/

    /*========================================================================================================================*/
    /*================================================= internal pure functions ==============================================*/
    /*========================================================================================================================*/

    function _mapPath(address _token0, address _token1) internal pure returns (address[] memory _path) {
        _path = new address[](2);
        _path[0] = _token0;
        _path[1] = _token1;
    }

    function _getTokenDecimals(address _token) internal pure returns (uint256) {
        return IERC20(_token).decimals();
    }

    /**
     * @notice returns sorted token addresses, used to handle return values from pairs sorted in this order
     * @param tokenA Address
     * @param tokenB Address
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "SafeswapRouter: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "SafeswapRouter: ZERO_ADDRESS");
    }

    /*========================================================================================================================*/
    /*================================================== private pure functions ==============================================*/
    /*========================================================================================================================*/

    function _isTokenInfoDeleted(bool _isTokenDeleted) private pure {
        require(_isTokenDeleted == false, "SafeSwapTradeRouter: Token already deleted");
    }

    function _isValidAdd(address _address) private pure {
        require(_address != address(0), "SafeSwapTradeRouter: Token does not exist");
    }

    /*========================================================================================================================*/
    /*======================================================= fallbacks ======================================================*/
    /*========================================================================================================================*/

    /// @notice Receive function to allow contract to accept BNB
    receive() external payable {}

    /// @notice Fallback function in case receive function is not matched
    fallback() external payable {}

    /*========================================================================================================================*/
    /*====================================================== Only Owner ======================================================*/
    /*========================================================================================================================*/

    /**
     * @notice set SFM router address
     * @param _router Address of SFM Router contract
     */
    function setRouter(address _router) external onlyOwner {
        swapRouter = _router;
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    function setFeePercent(uint256 _feePercent) external onlyOwner {
        feePercent = _feePercent;
    }

    function sePercent(uint256 _percent) external onlyOwner {
        percent = _percent;
    }

    function addFfsWhitelist(address _wl) external onlyOwner {
        whitelistFfsFee[_wl] = true;
    }

    function removeFfsWhitelist(address _wl) external onlyOwner {
        whitelistFfsFee[_wl] = false;
    }

    /**
     * @notice set feeJar address
     * @param _feeJar Address of FeeJar contract
     */
    function setFeeJar(address _feeJar) external onlyOwner {
        feeJar = IFeeJar(_feeJar);
        emit NewFeeJar(_feeJar);
    }

    function submitLpPriceRange(address _pair, uint256 _upl, uint256 _lpl) external onlyOwner {
        _submitLpPriceRange(_pair, _upl, _lpl);
    }

    function resetLpLastPrice(address _pair) external onlyOwner isValidAdd(adaptiveLpPriceRange[_pair].tokenAddress) {
        ISafeswapPair(_pair).sync();
        adaptiveLpPriceRange[_pair].lastPrice =
            _getLPPrice(ISafeswapPair(_pair).token0(), ISafeswapPair(_pair).token1());
        emit SubmitLpPriceRange(
            _pair,
            adaptiveLpPriceRange[_pair].upl,
            adaptiveLpPriceRange[_pair].lpl,
            adaptiveLpPriceRange[_pair].lastPrice
        );
    }

    function switchARCBActivation() external onlyOwner {
        isARCBEnabled = !isARCBEnabled;
        emit SetARCBStatus(isARCBEnabled);
    }

    function switchLpPriceRangeActivation(address _pair)
        external
        onlyOwner
        isValidAdd(adaptiveLpPriceRange[_pair].tokenAddress)
    {
        adaptiveLpPriceRange[_pair].isEnabled = !adaptiveLpPriceRange[_pair].isEnabled;

        emit SetLpPriceRangeStatus(_pair, adaptiveLpPriceRange[_pair].isEnabled);
    }

    function updateLpPriceRange(address _pair, uint256 _upl, uint256 _lpl)
        external
        onlyOwner
        isValidAdd(adaptiveLpPriceRange[_pair].tokenAddress)
    {
        adaptiveLpPriceRange[_pair].lpl = _lpl;
        adaptiveLpPriceRange[_pair].upl = _upl;
        emit SubmitLpPriceRange(_pair, _upl, _lpl, adaptiveLpPriceRange[_pair].lastPrice);
    }

    function getLpPriceRangeInfo(address _pair) external view returns (AdaptiveLpPriceRange memory) {
        return adaptiveLpPriceRange[_pair];
    }

    function submitTokenSwapFee(
        address _tokenAddress,
        TransactionType _transactionType,
        SingleSwapFee memory _singleSwapFee
    ) external onlyOwner {
        uint256 feePercentage = tokensFeeList[_tokenAddress][_transactionType].tokenInfo.feePercentage;
        require(
            (feePercentage + _singleSwapFee.percentage) <= (percent - feePercent),
            "SafeSwapTradeRouter: FeePercentage >100%"
        );

        if (tokensFeeList[_tokenAddress][_transactionType].tokenInfo.tokenAddress == address(0)) {
            if (
                !tokensFeeList[_tokenAddress][TransactionType.BUY].tokenInfo.isEnabled
                    && !tokensFeeList[_tokenAddress][TransactionType.SELL].tokenInfo.isEnabled
            ) {
                tokenFeeAddresses.push(_tokenAddress);
            }
            TokenFee storage _tokenFee = tokensFeeList[_tokenAddress][_transactionType];
            _tokenFee.singleSwapFees.push(
                SingleSwapFee(
                    _singleSwapFee.swapKind,
                    _singleSwapFee.assetOut,
                    _singleSwapFee.beneficiary,
                    _singleSwapFee.percentage,
                    _singleSwapFee.isEnabled
                )
            );
            _tokenFee.tokenInfo =
                TokenInfo(_transactionType, _tokenAddress, (feePercentage + _singleSwapFee.percentage), true, false);
        } else {
            tokensFeeList[_tokenAddress][_transactionType].singleSwapFees.push(
                SingleSwapFee(
                    _singleSwapFee.swapKind,
                    _singleSwapFee.assetOut,
                    _singleSwapFee.beneficiary,
                    _singleSwapFee.percentage,
                    _singleSwapFee.isEnabled
                )
            );
            tokensFeeList[_tokenAddress][_transactionType].tokenInfo.feePercentage += _singleSwapFee.percentage;
        }
        emit SubmitTokenSwapFee(
            _tokenAddress,
            _transactionType,
            feePercentage,
            _singleSwapFee.swapKind,
            _singleSwapFee.assetOut,
            _singleSwapFee.beneficiary,
            _singleSwapFee.percentage,
            _singleSwapFee.isEnabled
        );
    }

    function updateTokenSwapFee(
        address _tokenAddress,
        TransactionType _transactionType,
        SingleSwapFee memory _singleSwapFee,
        uint256 _index
    ) external onlyOwner isValidAdd(tokensFeeList[_tokenAddress][_transactionType].tokenInfo.tokenAddress) {
        require(
            tokensFeeList[_tokenAddress][_transactionType].singleSwapFees[_index].isEnabled,
            "SafeSwapTradeRouter: Token's swap fee not active"
        );
        require(
            _index < tokensFeeList[_tokenAddress][_transactionType].singleSwapFees.length,
            "SafeSwapTradeRouter: Invalid index"
        );
        require(
            (
                tokensFeeList[_tokenAddress][_transactionType].tokenInfo.feePercentage + _singleSwapFee.percentage
                    - tokensFeeList[_tokenAddress][_transactionType].singleSwapFees[_index].percentage
            ) <= (percent - feePercent),
            "SafeSwapTradeRouter: FeePercentage >100%"
        );

        tokensFeeList[_tokenAddress][_transactionType].tokenInfo.feePercentage -=
            tokensFeeList[_tokenAddress][_transactionType].singleSwapFees[_index].percentage;
        tokensFeeList[_tokenAddress][_transactionType].singleSwapFees[_index] = SingleSwapFee(
            _singleSwapFee.swapKind,
            _singleSwapFee.assetOut,
            _singleSwapFee.beneficiary,
            _singleSwapFee.percentage,
            _singleSwapFee.isEnabled
        );
        tokensFeeList[_tokenAddress][_transactionType].tokenInfo.feePercentage += _singleSwapFee.percentage;

        emit SubmitTokenSwapFee(
            _tokenAddress,
            _transactionType,
            tokensFeeList[_tokenAddress][_transactionType].tokenInfo.feePercentage,
            _singleSwapFee.swapKind,
            _singleSwapFee.assetOut,
            _singleSwapFee.beneficiary,
            _singleSwapFee.percentage,
            _singleSwapFee.isEnabled
        );
    }

    function switchTokenDeletion(address _tokenAddress, TransactionType _transactionType)
        external
        onlyOwner
        isValidAdd(tokensFeeList[_tokenAddress][_transactionType].tokenInfo.tokenAddress)
    {
        tokensFeeList[_tokenAddress][_transactionType].tokenInfo.isDeleted =
            !tokensFeeList[_tokenAddress][_transactionType].tokenInfo.isDeleted;

        tokensFeeList[_tokenAddress][_transactionType].tokenInfo.isEnabled =
            !tokensFeeList[_tokenAddress][_transactionType].tokenInfo.isEnabled;

        emit SetTokenDeletionStatus(
            _tokenAddress, _transactionType, tokensFeeList[_tokenAddress][_transactionType].tokenInfo.isDeleted
        );
    }

    function switchTokenActivation(address _tokenAddress, TransactionType _transactionType)
        external
        onlyOwner
        isTokenInfoDelted(tokensFeeList[_tokenAddress][_transactionType].tokenInfo.isDeleted)
    {
        tokensFeeList[_tokenAddress][_transactionType].tokenInfo.isEnabled =
            !tokensFeeList[_tokenAddress][_transactionType].tokenInfo.isEnabled;

        emit SetTokenFeeStatus(
            _tokenAddress, _transactionType, tokensFeeList[_tokenAddress][_transactionType].tokenInfo.isEnabled
        );
    }

    function switchSingleSwapActivation(address _tokenAddress, TransactionType _transactionType, uint256 _index)
        external
        onlyOwner
        isTokenInfoDelted(tokensFeeList[_tokenAddress][_transactionType].tokenInfo.isDeleted)
    {
        require(
            _index < tokensFeeList[_tokenAddress][_transactionType].singleSwapFees.length,
            "SafeSwapTradeRouter: Invalid index"
        );

        if (tokensFeeList[_tokenAddress][_transactionType].singleSwapFees[_index].isEnabled) {
            tokensFeeList[_tokenAddress][_transactionType].tokenInfo.feePercentage -=
                tokensFeeList[_tokenAddress][_transactionType].singleSwapFees[_index].percentage;
        } else {
            tokensFeeList[_tokenAddress][_transactionType].tokenInfo.feePercentage +=
                tokensFeeList[_tokenAddress][_transactionType].singleSwapFees[_index].percentage;
        }

        tokensFeeList[_tokenAddress][_transactionType].singleSwapFees[_index].isEnabled =
            !tokensFeeList[_tokenAddress][_transactionType].singleSwapFees[_index].isEnabled;

        emit SetTokenSwapFeeStatus(
            _tokenAddress, _transactionType, tokensFeeList[_tokenAddress][_transactionType].tokenInfo.isEnabled, _index
        );
    }

    /* ============================================================================================================ */
}
