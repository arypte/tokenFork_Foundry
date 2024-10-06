/**
 *Submitted for verification at BscScan.com on 2022-12-23
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {AccessControlUpgradeable} from "./lib/openzeppelin/AcccessControlUpgradeable.sol";
import {ISafeswapFactory} from "./interfaces/SafeMoon/ISafeswapFactory.sol";

/**
 * @title FeeJar
 * @dev Allows split SFM SwapRouter Fee
 */
contract FeeJar is AccessControlUpgradeable {

    /*========================================================================================================================*/
    /*======================================================= constants ======================================================*/
    /*========================================================================================================================*/

    /// @notice FeeJar Admin role
    bytes32 public constant FEE_JAR_ADMIN_ROLE = keccak256("FEE_JAR_ADMIN_ROLE");

    /// @notice Fee setter role
    bytes32 public constant FEE_SETTER_ROLE = keccak256("FEE_SETTER_ROLE");

    /*========================================================================================================================*/
    /*======================================================== states ========================================================*/
    /*========================================================================================================================*/

    /// @notice Network fee (measured in bips: 100 bips = 1% of contract balance)
    uint32 public buyBackAndBurnFee;
    uint32 public lpFee;
    uint32 public supportFee;
    uint256 public maxPercentage;

    address public factory;

    /// @notice Network fee output address
    address public buyBackAndBurnFeeCollector;
    address public lpFeeCollector;

    /*========================================================================================================================*/
    /*======================================================== events ========================================================*/
    /*========================================================================================================================*/

    /// @notice Network Fee set event
    event BuyBackAndBurnFeeSet(uint32 indexed newFee, uint32 indexed oldFee);
    /// @notice LP Fee set event
    event LPFeeSet(uint32 indexed newFee, uint32 indexed oldFee);
    /// @notice Support Fee set event
    event SupportFeeSet(uint32 indexed newFee, uint32 indexed oldFee);

    /// @notice Network Fee collector set event
    event NetworFeeCollectorSet(address newCollector, address oldBuyBackAndBurnFeeCollector);

    /// @notice LP Fee collector set event
    event LPFeeCollectorSet(address newCollector, address oldLPFeeCollector);

    event WithdrawBNB(address to, uint256 amount);

    /// @notice Fee event
    event Fee(
        address indexed feePayer, // tx.origin
        uint256 feeAmount, // msg.value
        uint256 buyBackAndBurnFeeAmount, // buyBackAndBurnFeeAmount
        uint256 lpFeeAmount, // lpFeeAmount
        uint256 supportFeeAmount, // supportFeeAmount
        address buyBackAndBurnFeeCollector, // buyBackAndBurnFeeCollector
        address supportFeeCollector, // supportFeeCollector
        address lpFeeCollector // lpFeeCollector
    );

    /*========================================================================================================================*/
    /*====================================================== modifiers =======================================================*/
    /*========================================================================================================================*/

    /// @notice modifier to restrict functions to admins
    modifier onlyAdmin() {
        require(hasRole(FEE_JAR_ADMIN_ROLE, msg.sender), "Caller must have FEE_JAR_ADMIN_ROLE role");
        _;
    }

    /// @notice modifier to restrict functions to fee setters
    modifier onlyFeeSetter() {
        require(hasRole(FEE_SETTER_ROLE, msg.sender), "Caller must have FEE_SETTER_ROLE role");
        _;
    }

    /*========================================================================================================================*/
    /*====================================================== initialize ======================================================*/
    /*========================================================================================================================*/

    /// @notice Initializes contract, setting admin roles + network fee
    /// @param _feeJarAdmin admin of fee pool
    /// @param _feeSetter fee setter address
    /// @param _buyBackAndBurnFeeCollector address that collects network fees
    /// @param _buyBackAndBurnFee % of fee collected by the network\
    function initialize(
        address _feeJarAdmin,
        address _feeSetter,
        address _buyBackAndBurnFeeCollector,
        address _lpFeeCollector,
        address _factory,
        uint256 _maxPercentage,
        uint32 _buyBackAndBurnFee,
        uint32 _lpFee,
        uint32 _supportFee
    ) external initializer {
        // addresses validation!
        require(
            _buyBackAndBurnFeeCollector != address(0) &&
                _lpFeeCollector != address(0) &&
                _feeJarAdmin != address(0) &&
                _feeSetter != address(0) &&
                _factory != address(0),
            "FEEJAR: PLEASE ENTER VALID ADDRESSES"
        );

        // fees validation
        require(
            _buyBackAndBurnFee <= _maxPercentage && _lpFee <= _maxPercentage && _supportFee <= _maxPercentage,
            "FEEJAR: INCORRECT FEES VALUES"
        );

        __AccessControl_init();

        _setRoleAdmin(FEE_JAR_ADMIN_ROLE, FEE_JAR_ADMIN_ROLE);
        _setRoleAdmin(FEE_SETTER_ROLE, FEE_JAR_ADMIN_ROLE);
        _setupRole(FEE_JAR_ADMIN_ROLE, _feeJarAdmin);
        _setupRole(FEE_SETTER_ROLE, _feeSetter);
        buyBackAndBurnFeeCollector = _buyBackAndBurnFeeCollector;
        lpFeeCollector = _lpFeeCollector;
        buyBackAndBurnFee = _buyBackAndBurnFee;
        emit BuyBackAndBurnFeeSet(_buyBackAndBurnFee, 0);
        lpFee = _lpFee;
        emit LPFeeSet(_lpFee, 0);
        supportFee = _supportFee;
        emit SupportFeeSet(_supportFee, 0);
        factory = _factory;
        maxPercentage = _maxPercentage;
    }

    /*========================================================================================================================*/
    /*=================================================== public functions ===================================================*/
    /*========================================================================================================================*/

    function withdrawBNB(address payable to) public onlyAdmin {
        uint256 amount = address(this).balance;
        to.transfer(amount);
        emit WithdrawBNB(to, amount);
    }

    /**
     * @notice Distributes any ETH in contract to relevant parties
     */
    function fee()
        public
        payable
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 feeBalance = msg.value;
        if (feeBalance == 0) {
            return (0,0,0);
        }
        (uint256 buyBackAndBurnFeeAmount, uint256 supportFeeAmount, uint256 lpFeeAmount) = getFeeAmount(feeBalance);
        address supportFeeCollector;

        if (buyBackAndBurnFee > 0) {
            (bool buyBackAndBurnFeeSuccess, ) = buyBackAndBurnFeeCollector.call{ value: buyBackAndBurnFeeAmount }("");
            require(buyBackAndBurnFeeSuccess, "Swap Fee: Could not collect network fee");
        }

        if (supportFee > 0) {
            supportFeeCollector = ISafeswapFactory(factory).feeTo();
            bool feeOn = supportFeeCollector != address(0);
            if (feeOn) {
                (bool supportFeeSuccess, ) = supportFeeCollector.call{ value: supportFeeAmount }("");
                require(supportFeeSuccess, "Swap Fee: Could not collect support fee");
            }
        }

        if (address(this).balance > 0) {
            uint256 lpAmount = address(this).balance;
            (bool success, ) = lpFeeCollector.call{ value: lpAmount }("");
            require(success, "Swap Fee: Could not collect LP ETH");
        }

        /// @notice Fee event
        emit Fee(
            tx.origin, // tx.origin
            msg.value, // msg.value
            buyBackAndBurnFeeAmount, // buyBackAndBurnFeeAmount
            lpFeeAmount, // lpFeeAmount
            supportFeeAmount, // supportFeeAmount
            buyBackAndBurnFeeCollector, // buyBackAndBurnFeeCollector
            supportFeeCollector, // supportFeeCollector
            buyBackAndBurnFeeCollector // lpFeeCollector
        );

        return (buyBackAndBurnFeeAmount, supportFeeAmount, lpFeeAmount);
    }

    /*========================================================================================================================*/
    /*================================================== external functions ==================================================*/
    /*========================================================================================================================*/

    /**
     * @notice Admin function to set network fee
     * @param newFee new fee
     */
    function setBuyBackAndBurnFee(uint32 newFee) external onlyFeeSetter {
        require(newFee <= maxPercentage, ">100%");
        emit BuyBackAndBurnFeeSet(newFee, buyBackAndBurnFee);
        buyBackAndBurnFee = newFee;
    }

    /**
     * @notice Admin function to set LP fee
     * @param newFee new fee
     */
    function setLPFee(uint32 newFee) external onlyFeeSetter {
        require(newFee <= maxPercentage, ">100%");
        emit LPFeeSet(newFee, lpFee);
        lpFee = newFee;
    }

    /**
     * @notice Admin function to set support fee
     * @param newFee new fee
     */
    function setSupportFee(uint32 newFee) external onlyFeeSetter {
        require(newFee <= maxPercentage, ">100%");
        emit SupportFeeSet(newFee, supportFee);
        supportFee = newFee;
    }



    /*========================================================================================================================*/
    /*================================================= public view functions ================================================*/
    /*========================================================================================================================*/

    /**
     * @notice Return fees amount based on the total fee
     * @param totalFee total fee
     */
    function getFeeAmount(uint256 totalFee)
        public
        view
        returns (
            uint256 buyBackAndBurnFeeAmount,
            uint256 supportFeeAmount,
            uint256 lpFeeAmount
        )
    {
        if (buyBackAndBurnFee > 0) {
            buyBackAndBurnFeeAmount = (totalFee * buyBackAndBurnFee) / maxPercentage;
        }
        if (lpFee > 0) {
            lpFeeAmount = (totalFee * lpFee) / maxPercentage;
        }
        if (supportFee > 0) {
            supportFeeAmount = (totalFee * supportFee) / maxPercentage;
        }
    }

    /*========================================================================================================================*/
    /*======================================================= fallbacks ======================================================*/
    /*========================================================================================================================*/

    /// @notice Receive function to allow contract to accept ETH
    receive() external payable {}

    /// @notice Fallback function to allow contract to accept ETH
    fallback() external payable {}

    /*========================================================================================================================*/
    /*====================================================== Only Admin ======================================================*/
    /*========================================================================================================================*/

    /**
     * @notice Admin function to set network fee collector address
     * @param newCollector new fee collector address
     */
    function setBuyBackAndBurnFeeCollector(address newCollector) external onlyAdmin {
        emit NetworFeeCollectorSet(newCollector, buyBackAndBurnFeeCollector);
        buyBackAndBurnFeeCollector = newCollector;
    }

    /**
     * @notice Admin function to set Lp fee collector address
     * @param newCollector new fee collector address
     */
    function setLPFeeCollector(address newCollector) external onlyAdmin {
        emit LPFeeCollectorSet(newCollector, lpFeeCollector);
        lpFeeCollector = newCollector;
    }
}