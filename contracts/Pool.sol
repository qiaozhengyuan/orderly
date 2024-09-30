// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing required OpenZeppelin upgradeable contracts
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Importing OpenZeppelin utility contracts
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Importing ABDK math library for 64.64 fixed-point arithmetic
import "abdk-libraries-solidity/ABDKMath64x64.sol";

/**
 * @title Pool Contract
 * @dev A decentralized liquidity pool that supports multiple tokens, allows liquidity
 * provision, withdrawal, and token swaps.
 * The contract uses upgradeable OpenZeppelin patterns and is pausable, non-reentrant,
 * and supports access control.
 */
contract Pool is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    // Constant for the admin role
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // List of supported token addresses
    address[] public tokens;

    // Mapping to store reserves for each token
    mapping(address => uint256) public reserves;

    // Total liquidity in the pool
    uint256 public totalLiquidity;

    // Mapping to store liquidity provided by each user
    mapping(address => uint256) public liquidityBalance;

    // Events
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event LiquidityAdded(
        address indexed provider,
        uint256[] amounts,
        uint256 liquidityMinted
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256[] amounts,
        uint256 liquidityBurned
    );

    /**
     * @dev Initializes the contract, sets supported tokens, and assigns roles.
     * @param _tokens Array of token addresses supported by the pool.
     */
    function initialize(address[] memory _tokens) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        // Ensure at least two tokens are provided
        require(_tokens.length >= 2, "At least two tokens required");

        // Ensure only one Ether token (address 0) can be added
        bool etherTokenExists = false;
        for (uint256 i; i < _tokens.length; i++) {
            if (_tokens[i] == address(0)) {
                require(!etherTokenExists, "Ether token already added");
                etherTokenExists = true;
            }
        }

        // Set the supported tokens
        tokens = _tokens;

        // Assign the admin role to the contract deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Pauses the contract, only callable by an admin.
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the contract, only callable by an admin.
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Allows the admin to withdraw accumulated fees by calculating the difference between the token balance and the reserve.
     * @param token The address of the token whose fees should be withdrawn.
     * @param to The address to send the withdrawn fees.
     */
    function withdrawFees(
        address token,
        address to
    ) external onlyRole(ADMIN_ROLE) {
        uint256 contractBalance = IERC20(token).balanceOf(address(this)); // Get the current balance of the contract for the token
        uint256 reserve = reserves[token]; // Get the reserve amount for the token
        require(contractBalance > reserve, "No fees available to withdraw");

        uint256 feeAmount = contractBalance - reserve; // The difference is the fee that can be withdrawn

        // Transfer the fees to the specified address
        _withdrawToken(token, to, feeAmount);
    }

    /**
     * @dev Adds liquidity to the pool. Requires the sender to provide tokens proportional
     * to their current reserves.
     * @param amounts Array of token amounts to deposit, must match the number of supported tokens.
     * @return liquidity The amount of liquidity tokens minted.
     */
    function addLiquidity(
        uint256[] memory amounts
    ) external payable nonReentrant whenNotPaused returns (uint256 liquidity) {
        require(amounts.length == tokens.length, "Amounts length mismatch");

        if (totalLiquidity == 0) {
            // Handle initial liquidity provision
            liquidity = _calculateInitialLiquidity(amounts);
            require(liquidity > 0, "Invalid initial liquidity");

            // Deposit tokens and update reserves
            for (uint256 i; i < tokens.length; i++) {
                _depositToken(tokens[i], amounts[i]);
                reserves[tokens[i]] = amounts[i];
            }
        } else {
            // Handle subsequent liquidity provisions

            // Reference token is usually the first token in the array
            uint256 referenceAmount = amounts[0];
            address referenceToken = tokens[0];
            uint256 referenceReserve = reserves[referenceToken];

            // Calculate liquidity based on the reference token
            liquidity = (totalLiquidity * referenceAmount) / referenceReserve;
            require(liquidity > 0, "Insufficient liquidity minted");

            // Deposit tokens and update reserves proportionally
            for (uint256 i; i < tokens.length; i++) {
                address token = tokens[i];
                uint256 reserve = reserves[token];
                uint256 requiredAmount = (reserve * liquidity) / totalLiquidity;

                require(
                    amounts[i] >= requiredAmount,
                    "Token amounts must be proportional to reserves"
                );

                _depositToken(token, requiredAmount);
                reserves[token] = reserve + requiredAmount;
            }
        }

        // Update liquidity balances and total liquidity
        liquidityBalance[msg.sender] += liquidity;
        totalLiquidity += liquidity;

        // Emit LiquidityAdded event
        emit LiquidityAdded(msg.sender, amounts, liquidity);
    }

    /**
     * @dev Removes liquidity from the pool. The user receives tokens proportionally to their liquidity share.
     * @param liquidity The amount of liquidity to remove.
     * @return amountsOut Array of token amounts withdrawn from the pool.
     */
    function removeLiquidity(
        uint256 liquidity
    )
        external
        nonReentrant
        whenNotPaused
        returns (uint256[] memory amountsOut)
    {
        require(liquidity > 0, "Liquidity must be greater than zero");
        require(
            liquidityBalance[msg.sender] >= liquidity,
            "Insufficient liquidity balance"
        );

        // Initialize array to store withdrawn amounts
        amountsOut = new uint256[](tokens.length);

        // Withdraw tokens proportionally to the liquidity removed
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 reserve = reserves[token];

            uint256 amountOut = (reserve * liquidity) / totalLiquidity;

            reserves[token] = reserve - amountOut;
            _withdrawToken(token, msg.sender, amountOut);
            amountsOut[i] = amountOut;
        }

        // Update liquidity balances and total liquidity
        liquidityBalance[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;

        // Emit LiquidityRemoved event
        emit LiquidityRemoved(msg.sender, amountsOut, liquidity);
    }

    /**
     * @dev Swaps tokens within the pool using the constant product formula (x * y = k).
     * @param tokenInId Index of the token to swap from.
     * @param tokenOutId Index of the token to swap to.
     * @param amountIn Amount of the input token to swap.
     * @param minAmountOut Minimum amount of the output token expected.
     * @return amountOut Amount of the output token received.
     */
    function swap(
        uint256 tokenInId,
        uint256 tokenOutId,
        uint256 amountIn,
        uint256 minAmountOut
    ) external payable nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(amountIn > 0, "AmountIn must be greater than zero");
        require(tokenInId != tokenOutId, "Tokens must be different");
        require(
            tokenInId < tokens.length && tokenOutId < tokens.length,
            "Unsupported tokens"
        );

        // Get input and output token addresses and reserves
        address tokenIn = tokens[tokenInId];
        address tokenOut = tokens[tokenOutId];
        uint256 reserveIn = reserves[tokenIn];
        uint256 reserveOut = reserves[tokenOut];

        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        // Deposit input tokens and update reserves
        _depositToken(tokenIn, amountIn);
        reserves[tokenIn] = reserveIn + amountIn;

        // Apply a fee (e.g., 0.3%) on the input amount
        uint256 amountInWithFee = (amountIn * 997) / 1000;

        // Calculate output amount using the constant product formula
        amountOut =
            (amountInWithFee * reserveOut) /
            (reserveIn + amountInWithFee);
        require(amountOut >= minAmountOut, "Insufficient output amount");
        require(amountOut <= reserveOut, "Not enough liquidity");

        // Update reserves and transfer output tokens to the user
        reserves[tokenOut] = reserveOut - amountOut;
        _withdrawToken(tokenOut, msg.sender, amountOut);

        // Emit Swap event
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    /**
     * @dev Calculates the required amounts of each token for a given liquidity contribution.
     * @param referenceAmount The amount of the reference token (first token) to calculate.
     * @return requiredAmounts Array of required amounts for each token.
     */
    function getRequiredAmounts(
        uint256 referenceAmount
    ) external view returns (uint256[] memory requiredAmounts) {
        require(totalLiquidity > 0, "Pool has no liquidity");
        requiredAmounts = new uint256[](tokens.length);

        // Calculate the liquidity corresponding to the reference token amount
        uint256 liquidity = (totalLiquidity * referenceAmount) /
            reserves[tokens[0]];

        // Calculate required amounts for each token
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 reserve = reserves[tokens[i]];
            requiredAmounts[i] = (reserve * liquidity) / totalLiquidity;
        }
    }

    /**
     * @dev Internal function to deposit tokens to the pool.
     * @param token The address of the token to deposit (address(0) for ETH).
     * @param amount The amount of tokens to deposit.
     */
    function _depositToken(address token, uint256 amount) internal {
        if (token == address(0)) {
            // Handle Ether (ETH) deposits
            require(msg.value == amount, "Incorrect ETH amount sent");
        } else {
            // Handle ERC20 token deposits
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    /**
     * @dev Internal function to withdraw tokens from the pool.
     * @param token The address of the token to withdraw (address(0) for ETH).
     * @param to The address to send the tokens to.
     * @param amount The amount of tokens to withdraw.
     */
    function _withdrawToken(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (token == address(0)) {
            // Handle Ether (ETH) withdrawals
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            // Handle ERC20 token withdrawals
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /**
     * @dev Internal function to calculate initial liquidity using the geometric mean.
     * @param amounts Array of token amounts provided.
     * @return liquidity The calculated initial liquidity.
     */
    function _calculateInitialLiquidity(
        uint256[] memory amounts
    ) internal pure returns (uint256 liquidity) {
        // Variables for fixed-point calculations
        int128 logSum = 0;
        uint256 n = amounts.length;

        // Sum the logarithms of the amounts
        for (uint256 i = 0; i < n; i++) {
            require(amounts[i] > 0, "Token amount must be greater than zero");
            int128 logAmount = ABDKMath64x64.log_2(
                ABDKMath64x64.fromUInt(amounts[i])
            );
            logSum = ABDKMath64x64.add(logSum, logAmount);
        }

        // Compute the geometric mean
        int128 avgLog = ABDKMath64x64.div(logSum, ABDKMath64x64.fromUInt(n));
        int128 geoMean = ABDKMath64x64.exp_2(avgLog);

        // Convert back to uint256
        liquidity = ABDKMath64x64.toUInt(geoMean);
        require(liquidity > 0, "Calculated liquidity is zero");
    }

    // Fallback function to receive ETH
    receive() external payable {}
}
