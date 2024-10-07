/**
 * Submitted for verification at BscScan.com on 2022-12-23
 */

// Sources flattened with hardhat v2.10.1 https://hardhat.org

// File contracts/interfaces/ISafeswapFactory.sol

// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import {ISafeswapFactory} from "./interfaces/SafeMoon/ISafeswapFactory.sol";
import {ISafeswapPair} from "./interfaces/SafeMoon/ISafeswapPair.sol";
import {ISafeswapERC20} from "./interfaces/SafeMoon/ISafeswapERC20.sol";
import {SafeswapERC20} from "./SafeswapERC20.sol";
import {Initializable} from "./lib/openzeppelin/Initializable.sol";
import {Math} from "./library/Math.sol";
import {UQ112x112} from "./library/UQ112x112.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {ISafeswapCallee} from "./interfaces/SafeMoon/ISafeswapCallee.sol";
import {ISafeswapRouter} from "./interfaces/SafeMoon/ISafeswapRouter.sol";
import {Proxy} from "./lib/openzeppelin/Proxy.sol";

import {Address} from "./lib/openzeppelin/Address.sol";
import {UpgradeableProxy} from "./lib/openzeppelin/UpgradeableProxy.sol";
import {OptimizedTransparentUpgradeableProxy} from "./OptimizedTransparentUpgradeableProxy.sol";
import {SafeswapPair} from "./SafeswapPair.sol";

contract SafeswapFactory is ISafeswapFactory, Initializable {
    /*========================================================================================================================*/
    /*======================================================= constants ======================================================*/
    /*========================================================================================================================*/

    bytes32 public constant INIT_CODE_PAIR_HASH =
        keccak256(abi.encodePacked(type(OptimizedTransparentUpgradeableProxy).creationCode));

    /*========================================================================================================================*/
    /*======================================================== states ========================================================*/
    /*========================================================================================================================*/

    address public feeTo;
    address public feeToSetter;
    address public router;
    address public admin;

    address[] public allPairs;

    address public implementation;

    /*========================================================================================================================*/
    /*======================================================= mappings =======================================================*/
    /*========================================================================================================================*/

    mapping(address => bool) public isBlacklistedStatus;
    mapping(address => bool) public approvePartnerStatus;
    mapping(address => bool) public isBlacklistedToken;
    mapping(address => mapping(address => address)) public getPair;

    /*========================================================================================================================*/
    /*====================================================== modifiers =======================================================*/
    /*========================================================================================================================*/

    modifier onlyOwner() {
        require(admin == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /*========================================================================================================================*/
    /*====================================================== initialize ======================================================*/
    /*========================================================================================================================*/

    function initialize(address _feeToSetter, address _feeTo) external initializer {
        feeToSetter = _feeToSetter;
        feeTo = _feeTo;
        admin = msg.sender;
    }

    /*========================================================================================================================*/
    /*=================================================== public functions ===================================================*/
    /*========================================================================================================================*/

    function setRouter(address _router) public {
        require(msg.sender == admin, "NOT AUTHORIZED");
        router = _router;
    }

    /*========================================================================================================================*/
    /*================================================== external functions ==================================================*/
    /*========================================================================================================================*/

    function createPair(address tokenA, address tokenB, address to) external returns (address pair) {
        require(implementation != address(0), "Please set implementation");
        require((isBlacklistedToken[tokenA] == false), "Cannot create with tokenA");
        require((isBlacklistedToken[tokenB] == false), "Cannot create with tokenB");
        require((approvePartnerStatus[to] == true), "Not approved the partner");
        require((approvePartnerStatus[msg.sender] == true), "Not approved the partner");

        require(tokenA != tokenB, "Safeswap: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Safeswap: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "Safeswap: PAIR_EXISTS"); // single check is sufficient
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        OptimizedTransparentUpgradeableProxy pairProxy = new OptimizedTransparentUpgradeableProxy{salt: salt}();
        pairProxy._OptimizedTransparentUpgradeableProxy_init_(
            address(this), address(0x000000000000000000000000000000000000dEaD), hex""
        );
        pair = address(pairProxy);
        ISafeswapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "Safeswap: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "Safeswap: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }

    /*========================================================================================================================*/
    /*================================================ external view functions ===============================================*/
    /*========================================================================================================================*/

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /*========================================================================================================================*/
    /*====================================================== Only Owner ======================================================*/
    /*========================================================================================================================*/

    function setImplementation(address _impl) external onlyOwner {
        require(_impl != address(0), "Not allow zero address");
        implementation = _impl;
    }

    function deployImplementation() external onlyOwner {
        implementation = address(new SafeswapPair());
    }

    function blacklistAddress(address account) external onlyOwner {
        require((isBlacklistedStatus[account] == false), "Already Blacklisted");
        isBlacklistedStatus[account] = true;
    }

    function unBlacklistAddress(address account) external onlyOwner {
        require((isBlacklistedStatus[account] == true), "Already Not Blacklisted");
        isBlacklistedStatus[account] = false;
    }

    function blacklistTokenAddress(address token) external onlyOwner {
        require((isBlacklistedToken[token] == false), "Already Blacklisted");
        isBlacklistedToken[token] = true;
    }

    function whitelistTokenAddress(address token) external onlyOwner {
        require((isBlacklistedToken[token] == true), "Already Whitelisted");
        isBlacklistedToken[token] = false;
    }

    function approveLiquidityPartner(address account) external onlyOwner {
        require((approvePartnerStatus[account] == false), "Already approved");
        approvePartnerStatus[account] = true;
    }

    function unApproveLiquidityPartner(address account) external onlyOwner {
        require((approvePartnerStatus[account] == true), "Not approved yet");
        approvePartnerStatus[account] = false;
    }
}
