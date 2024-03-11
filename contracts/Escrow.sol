// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Trade.sol";
import "./Arbitration.sol";

contract Escrow {
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

    constructor(
        address _admin,
        address _tradeContractAddress,
        address _arbitrationContractAddress,
        uint256 _platformFeePercentage,
        uint256 _penaltyPercentage
    ) {
        admin = _admin;
        tradeContract = Trade(_tradeContractAddress);
        arbitrationContract = Arbitration(_arbitrationContractAddress);
        platformFeePercentage = _platformFeePercentage;
        penaltyPercentage = _penaltyPercentage;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    function lockCrypto(uint256 _tradeId, uint256 _amount) public {
        require(
            tradeContract.trades(_tradeId).tradeStatus ==
                Trade.TradeStatus.Accepted,
            "Trade is not in accepted status"
        );
        require(
            !escrows[_tradeId].isLocked,
            "Crypto is already locked for this trade"
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

    function releaseCrypto(uint256 _tradeId) public {
        require(
            escrows[_tradeId].isLocked,
            "Crypto is not locked for this trade"
        );
        require(
            !escrows[_tradeId].isReleased,
            "Crypto is already released for this trade"
        );
        require(
            tradeContract.trades(_tradeId).tradeStatus ==
                Trade.TradeStatus.Finalized ||
                arbitrationContract
                    .disputes(arbitrationContract.disputeCount())
                    .resolvedInFavorOfMaker,
            "Trade is not finalized or dispute is not resolved in favor of maker"
        );

        escrows[_tradeId].isReleased = true;

        uint256 feeAmount = (escrows[_tradeId].amount * platformFeePercentage) /
            100;
        uint256 releaseAmount = escrows[_tradeId].amount - feeAmount;

        // Transfer the release amount to the maker
        payable(tradeContract.trades(_tradeId).taker).transfer(releaseAmount);

        emit CryptoReleased(_tradeId, releaseAmount);
        emit PlatformFeePaid(_tradeId, feeAmount);
    }

    function refundCrypto(uint256 _tradeId) public {
        require(
            escrows[_tradeId].isLocked,
            "Crypto is not locked for this trade"
        );
        require(
            !escrows[_tradeId].isRefunded,
            "Crypto is already refunded for this trade"
        );
        require(
            tradeContract.trades(_tradeId).tradeStatus ==
                Trade.TradeStatus.Cancelled ||
                tradeContract.trades(_tradeId).tradeStatus ==
                Trade.TradeStatus.TimedOut ||
                arbitrationContract
                    .disputes(arbitrationContract.disputeCount())
                    .resolvedInFavorOfMaker ==
                false,
            "Trade is not cancelled, timed out, or dispute is not resolved in favor of taker"
        );

        escrows[_tradeId].isRefunded = true;

        // Transfer the refund amount to the taker
        payable(tradeContract.trades(_tradeId).taker).transfer(
            escrows[_tradeId].amount
        );

        emit CryptoRefunded(_tradeId, escrows[_tradeId].amount);
    }

    function splitCrypto(
        uint256 _tradeId,
        uint256 _splitAmount
    ) public onlyAdmin {
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

        // Transfer the split amount to the maker
        payable(tradeContract.trades(_tradeId).taker).transfer(_splitAmount);

        // Update the escrow amount
        escrows[_tradeId].amount = remainingAmount;

        emit CryptoSplit(_tradeId, escrows[_tradeId].amount, _splitAmount);
    }

    function penalizeCrypto(uint256 _tradeId) public onlyAdmin {
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

    function payPlatformFee(uint256 _tradeId) public onlyAdmin {
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

        uint256 feeAmount = (escrows[_tradeId].amount * platformFeePercentage) /
            100;
        uint256 remainingAmount = escrows[_tradeId].amount - feeAmount;

        // Transfer the fee amount to the admin
        payable(admin).transfer(feeAmount);

        // Update the escrow amount
        escrows[_tradeId].amount = remainingAmount;

        emit PlatformFeePaid(_tradeId, feeAmount);
    }

    function arbitrate(uint256 _tradeId) public {
        require(
            msg.sender == address(arbitrationContract),
            "Only Arbitration contract can call this function"
        );
        // Arbitration logic will be handled by the Arbitration contract
    }
}
