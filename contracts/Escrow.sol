// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Trade.sol";
import "./Arbitration.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title Escrow contract for handling trade funds
 * @dev This contract manages the locking, releasing, refunding, splitting, and penalizing of funds for trades.
 */

contract Escrow is ReentrancyGuardUpgradeable {
    address public admin;
    Trade private tradeContract;
    Arbitration private arbitrationContract;

    uint256 public platformFeePercentage;
    uint256 public penaltyPercentage;

    struct EscrowDetails {
        uint256 tradeId;
        uint256 amount;
        bool isLocked;
        bool isReleased;
        bool isRefunded;
    }

    mapping(uint256 => EscrowDetails) public escrows;

    event CryptoLocked(uint256 indexed tradeId, uint256 amount);
    event CryptoReleased(uint256 indexed tradeId, uint256 amount);
    event CryptoRefunded(uint256 indexed tradeId, uint256 amount);
    event CryptoSplit(
        uint256 indexed tradeId,
        uint256 amount,
        uint256 splitAmount
    );
    event CryptoPenalized(
        uint256 indexed tradeId,
        uint256 amount,
        uint256 penaltyAmount
    );
    event PlatformFeePaid(uint256 indexed tradeId, uint256 feeAmount);
    event FeePercentagesUpdated(
        uint256 platformFeePercentage,
        uint256 penaltyPercentage
    );

    constructor(
        address _admin,
        address _tradeContractAddress,
        address _arbitrationContractAddress,
        uint256 _platformFeePercentage,
        uint256 _penaltyPercentage
    ) {
        require(_admin != address(0), "Invalid admin address");
        require(
            _tradeContractAddress != address(0),
            "Invalid Trade contract address"
        );
        require(
            _arbitrationContractAddress != address(0),
            "Invalid Arbitration contract address"
        );
        require(
            _platformFeePercentage <= 1,
            "Platform fee percentage must be between 0 and 1"
        );
        require(
            _penaltyPercentage <= 100,
            "Penalty percentage must be between 0 and 100"
        );

        admin = _admin;
        tradeContract = Trade(_tradeContractAddress);
        arbitrationContract = Arbitration(_arbitrationContractAddress);
        platformFeePercentage = _platformFeePercentage;
        penaltyPercentage = _penaltyPercentage;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only an admin can perform this action");
        _;
    }

    modifier onlyTradeContract() {
        require(
            msg.sender == address(tradeContract),
            "Only the Trade contract can perform this action"
        );
        _;
    }

    modifier onlyArbitrationContract() {
        require(
            msg.sender == address(arbitrationContract),
            "Only the Arbitration contract can perform this action"
        );
        _;
    }

    /**
     * @dev Locks the crypto for a trade
     * @param _tradeId The ID of the trade
     * @param _amount The amount of crypto to lock
     * @notice Only the Trade contract can call this function
     * @notice The crypto must not be already locked for the trade
     */

    function lockCrypto(
        uint256 _tradeId,
        uint256 _amount
    ) public onlyTradeContract {
        require(
            !escrows[_tradeId].isLocked,
            "The crypto is already locked for this trade"
        );

        escrows[_tradeId] = EscrowDetails(
            _tradeId,
            _amount,
            true,
            false,
            false
        );

        emit CryptoLocked(_tradeId, _amount);
    }

    /**
     * @dev Releases the crypto to the receiver after trade finalization or dispute resolution
     * @param _tradeId The ID of the trade
     * @param _receiver The address of the receiver
     * @notice Only the Trade contract can call this function
     * @notice The crypto must be locked for the trade
     * @notice The crypto must not be already released or refunded for the trade
     * @notice The trade must be finalized or the dispute must be resolved in favor of the maker
     */

    function releaseCrypto(
        uint256 _tradeId,
        address payable _receiver
    ) public nonReentrant onlyTradeContract {
        require(
            escrows[_tradeId].isLocked,
            "The crypto is not locked for this trade"
        );
        require(
            !escrows[_tradeId].isReleased,
            "The crypto is already released for this trade"
        );
        require(
            !escrows[_tradeId].isRefunded,
            "The crypto is already refunded for this trade"
        );

        (, , , , , , , , Trade.TradeStatus tradeStatus, , , ) = tradeContract
            .getTradeDetails(_tradeId);

        require(
            tradeStatus == Trade.TradeStatus.Finalized ||
                (arbitrationContract.isDisputeResolved(_tradeId) &&
                    arbitrationContract.getDisputeOutcome(_tradeId)),
            "Trade is not finalized or dispute is not resolved in favor of maker"
        );

        escrows[_tradeId].isReleased = true;

        uint256 feeAmount = calculatePlatformFee(_tradeId);
        uint256 releaseAmount = escrows[_tradeId].amount - feeAmount;

        _receiver.transfer(releaseAmount);

        emit CryptoReleased(_tradeId, releaseAmount);
        emit PlatformFeePaid(_tradeId, feeAmount);
    }

    /**
     * @dev Refunds the crypto to the taker if the trade is cancelled, timed out, or dispute resolved in favor of taker
     * @param _tradeId The ID of the trade
     * @notice Only the Trade contract can call this function
     * @notice The crypto must be locked for the trade
     * @notice The crypto must not be already refunded for the trade
     * @notice The trade must be cancelled, timed out, or the dispute must be resolved in favor of the taker
     */

    function refundCrypto(
        uint256 _tradeId
    ) public nonReentrant onlyTradeContract {
        require(
            escrows[_tradeId].isLocked,
            "Crypto is not locked for this trade"
        );
        require(
            !escrows[_tradeId].isRefunded,
            "Crypto is already refunded for this trade"
        );

        (, , , , , , , , Trade.TradeStatus tradeStatus, , , ) = tradeContract
            .getTradeDetails(_tradeId);
        require(
            tradeStatus == Trade.TradeStatus.Cancelled ||
                tradeStatus == Trade.TradeStatus.TimedOut ||
                (arbitrationContract.isDisputeResolved(_tradeId) &&
                    !arbitrationContract.getDisputeOutcome(_tradeId)),
            "Trade is not cancelled, timed out, or dispute is not resolved in favor of taker"
        );

        escrows[_tradeId].isRefunded = true;

        // Get the trade details
        (, address taker, , , , , , , , , , ) = tradeContract.getTradeDetails(
            _tradeId
        );

        payable(taker).transfer(escrows[_tradeId].amount);

        emit CryptoRefunded(_tradeId, escrows[_tradeId].amount);
    }

    /**
     * @dev Splits the crypto and sends a portion to the receiver
     * @param _tradeId The ID of the trade
     * @param _splitAmount The amount of crypto to split
     * @param _receiver The address of the receiver
     * @notice Only an admin can call this function
     * @notice The crypto must be locked for the trade
     * @notice The crypto must not be already released or refunded for the trade
     * @notice The split amount must not exceed the locked amount
     */

    function splitCrypto(
        uint256 _tradeId,
        uint256 _splitAmount,
        address payable _receiver
    ) public nonReentrant onlyAdmin {
        require(
            escrows[_tradeId].isLocked,
            "Crypto is not locked for this trade"
        );
        require(
            !escrows[_tradeId].isReleased,
            "Crypto is already released for this trade"
        );
        require(
            !escrows[_tradeId].isRefunded,
            "Crypto is already refunded for this trade"
        );
        require(
            _splitAmount <= escrows[_tradeId].amount,
            "Split amount exceeds the locked amount"
        );

        uint256 remainingAmount = escrows[_tradeId].amount - _splitAmount;

        // Transfer the split amount to the receiver
        _receiver.transfer(_splitAmount);

        // Update the escrow amount
        escrows[_tradeId].amount = remainingAmount;

        emit CryptoSplit(_tradeId, escrows[_tradeId].amount, _splitAmount);
    }

    /**
     * @dev Penalizes the crypto by transferring a portion to the admin
     * @param _tradeId The ID of the trade
     * @notice Only an admin can call this function
     * @notice The crypto must be locked for the trade
     * @notice The crypto must not be already released or refunded for the trade
     */

    function penalizeCrypto(uint256 _tradeId) public nonReentrant onlyAdmin {
        require(
            escrows[_tradeId].isLocked,
            "Crypto is not locked for this trade"
        );
        require(
            !escrows[_tradeId].isReleased,
            "Crypto is already released for this trade"
        );
        require(
            !escrows[_tradeId].isRefunded,
            "Crypto is already refunded for this trade"
        );

        uint256 penaltyAmount = (escrows[_tradeId].amount * penaltyPercentage) /
            100;
        uint256 remainingAmount = escrows[_tradeId].amount - penaltyAmount;

        // Transfer the penalty amount to the admin
        payable(admin).transfer(penaltyAmount);

        // Update the escrow amount
        escrows[_tradeId].amount = remainingAmount;

        emit CryptoPenalized(_tradeId, escrows[_tradeId].amount, penaltyAmount);
    }

    /**
     * @dev Pays the platform fee by transferring the fee amount to the admin
     * @param _tradeId The ID of the trade
     * @notice Only an admin can call this function
     * @notice The crypto must be locked for the trade
     * @notice The crypto must not be already released or refunded for the trade
     */

    function payPlatformFee(uint256 _tradeId) public nonReentrant onlyAdmin {
        require(
            escrows[_tradeId].isLocked,
            "Crypto is not locked for this trade"
        );
        require(
            !escrows[_tradeId].isReleased,
            "Crypto is already released for this trade"
        );
        require(
            !escrows[_tradeId].isRefunded,
            "Crypto is already refunded for this trade"
        );

        uint256 feeAmount = calculatePlatformFee(_tradeId);
        uint256 remainingAmount = escrows[_tradeId].amount - feeAmount;

        // Transfer the fee amount to the admin
        payable(admin).transfer(feeAmount);

        // Update the escrow amount
        escrows[_tradeId].amount = remainingAmount;

        emit PlatformFeePaid(_tradeId, feeAmount);
    }

    /**
     * @dev Updates the platform fee and penalty percentages
     * @param _platformFeePercentage The new platform fee percentage
     * @param _penaltyPercentage The new penalty percentage
     * @notice Only an admin can call this function
     * @notice The platform fee percentage must be between 0 and 1
     * @notice The penalty percentage must be between 0 and 100
     */

    function updateFeePercentages(
        uint256 _platformFeePercentage,
        uint256 _penaltyPercentage
    ) public onlyAdmin {
        require(
            _platformFeePercentage <= 1,
            "Platform fee percentage must be between 0 and 1"
        );
        require(
            _penaltyPercentage <= 100,
            "Penalty percentage must be between 0 and 100"
        );

        platformFeePercentage = _platformFeePercentage;
        penaltyPercentage = _penaltyPercentage;

        emit FeePercentagesUpdated(_platformFeePercentage, _penaltyPercentage);
    }

    /**
     * @dev Withdraws the platform fees to the admin
     * @notice Only an admin can call this function
     */

    function withdrawPlatformFees() public nonReentrant onlyAdmin {
        uint256 balance = address(this).balance;
        payable(admin).transfer(balance);
    }

    /**
     * @dev Calculates the platform fee for a trade
     * @param _tradeId The ID of the trade
     * @return The platform fee amount
     */

    function calculatePlatformFee(
        uint256 _tradeId
    ) internal view returns (uint256) {
        return (escrows[_tradeId].amount * platformFeePercentage) / 100;
    }
}
