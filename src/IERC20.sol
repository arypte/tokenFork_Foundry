interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);

    function decimals() external pure returns (uint8);
}
