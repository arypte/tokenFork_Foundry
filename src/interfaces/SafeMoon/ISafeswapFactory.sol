interface ISafeswapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function feeTo() external view returns (address);

    function router() external view returns (address);

    function feeToSetter() external view returns (address);

    function isBlacklistedStatus(address account) external view returns (bool);

    function approvePartnerStatus(address account) external view returns (bool);

    function isBlacklistedToken(address account) external view returns (bool);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(
        address tokenA,
        address tokenB,
        address to
    ) external returns (address pair);
}
