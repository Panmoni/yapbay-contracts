// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Offer.sol";
import "./Escrow.sol";
import "./Arbitration.sol";
import "./Rating.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract Trade is ReentrancyGuardUpgradeable {
    Offer private offerContract;
    Escrow private escrowContract;
    Arbitration private arbitrationContract;
    Rating private ratingContract;

    address public owner;

    enum TradeStatus {
        Initiated,
        Accepted,
        FiatPaid,
        Finalized,
        Cancelled,
        Disputed,
        TimedOut,
        Refunded
    }

    struct TradeDetails {
        uint256 offerId;
        address taker;
        uint256 tradeAmountFiat;
        uint256 tradeAmountCrypto;
        string tradeFiatCurrency;
        string tradeCryptoCurrency;
        uint256 blocksTillTimeout;
        string tradeCancelationReason;
        TradeStatus tradeStatus;
        uint256 tradeInitiatedTime;
        uint256 tradeFinalizedTime;
        uint256 tradeFee;
    }

    uint256 public tradeCount;
    mapping(uint256 => TradeDetails) public trades;
    mapping(TradeStatus => mapping(TradeStatus => bool))
        public validTransitions;
    mapping(address => bool) public admins;
    mapping(uint256 => mapping(address => bool)) public tradeRatings;

    constructor(
        address _offerContractAddress,
        address _escrowContractAddress,
        address _arbitrationContractAddress,
        address _ratingContractAddress
    ) {
        offerContract = Offer(_offerContractAddress);
        escrowContract = Escrow(_escrowContractAddress);
        arbitrationContract = Arbitration(_arbitrationContractAddress);
        ratingContract = Rating(_ratingContractAddress);

        owner = msg.sender;

        // Initialize valid trade status transitions
        validTransitions[TradeStatus.Initiated][TradeStatus.Accepted] = true;

        // allow trade to be cancelled when in initiated status
        validTransitions[TradeStatus.Initiated][TradeStatus.Cancelled] = true;

        validTransitions[TradeStatus.Accepted][TradeStatus.FiatPaid] = true;
        validTransitions[TradeStatus.Accepted][TradeStatus.Disputed] = true;

        // allow trade to be finalized from disputed status
        validTransitions[TradeStatus.Disputed][TradeStatus.Finalized] = true;
        // allow trade to be cancelled from disputed status
        validTransitions[TradeStatus.Disputed][TradeStatus.Cancelled] = true;

        // allow trade to be timedout from various statuses
        validTransitions[TradeStatus.Initiated][TradeStatus.TimedOut] = true;
        validTransitions[TradeStatus.Accepted][TradeStatus.TimedOut] = true;
        // validTransitions[TradeStatus.FiatPaid][TradeStatus.TimedOut] = true;

        validTransitions[TradeStatus.Accepted][TradeStatus.Cancelled] = true;
        validTransitions[TradeStatus.FiatPaid][TradeStatus.Finalized] = true;
        validTransitions[TradeStatus.FiatPaid][TradeStatus.Disputed] = true;
    }

    event TradeInitiated(
        uint256 indexed tradeId,
        uint256 indexed offerId,
        address indexed taker
    );
    event TradeAccepted(uint256 indexed tradeId);
    event CryptoLockedInEscrow(uint256 indexed tradeId, uint256 amount);
    event FiatMarkedAsPaid(uint256 indexed tradeId);
    event TradeFinalized(uint256 indexed tradeId, uint256 timestamp);
    event TradeCancelled(uint256 indexed tradeId, string reason);
    event TradeDisputed(uint256 indexed tradeId);
    event TradeTimedOut(uint256 indexed tradeId);
    event TradeRated(uint256 indexed tradeId, uint256 rating, string feedback);
    event AdminSet(address indexed admin, bool isAdmin);

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can perform this action"
        );
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "Only admin can perform this action");
        _;
    }

    modifier onlyTradeParty(uint256 _tradeId) {
        require(
            trades[_tradeId].taker == msg.sender ||
                offerContract
                    .getOfferDetails(trades[_tradeId].offerId)
                    .offerOwner ==
                msg.sender,
            "Only trade parties can perform this action"
        );
        _;
    }

    modifier tradeExists(uint256 _tradeId) {
        require(_tradeId > 0 && _tradeId <= tradeCount, "Trade does not exist");
        _;
    }

    function setInitialAdmins(address[] memory _admins) public onlyOwner {
        require(admins[owner] == false, "Initial admins can only be set once");

        for (uint256 i = 0; i < _admins.length; i++) {
            admins[_admins[i]] = true;
        }

        admins[owner] = true;
        emit AdminSet(owner, true);
    }

    function setAdmin(address _admin, bool _isAdmin) public onlyAdmin {
        admins[_admin] = _isAdmin;
        emit AdminSet(_admin, _isAdmin);
    }

    function initiateTrade(
        uint256 _offerId,
        uint256 _tradeAmountFiat,
        uint256 _tradeAmountCrypto,
        string memory _tradeFiatCurrency,
        string memory _tradeCryptoCurrency,
        uint256 _blocksTillTimeout,
        string memory _tradeCancelationReason
    ) public {
        require(
            offerContract.getOfferDetails(_offerId).offerStatus,
            "Offer is not active"
        );
        require(
            _tradeAmountFiat >=
                offerContract.getOfferDetails(_offerId).offerMinTradeAmount &&
                _tradeAmountFiat <=
                offerContract.getOfferDetails(_offerId).offerMaxTradeAmount,
            "Trade amount is outside the offer range"
        );

        tradeCount++;
        trades[tradeCount] = TradeDetails(
            _offerId,
            msg.sender,
            _tradeAmountFiat,
            _tradeAmountCrypto,
            _tradeFiatCurrency,
            _tradeCryptoCurrency,
            _blocksTillTimeout,
            _tradeCancelationReason,
            TradeStatus.Initiated,
            block.timestamp,
            0,
            0
        );

        emit TradeInitiated(tradeCount, _offerId, msg.sender);
    }

    function _updateTradeStatus(
        uint256 _tradeId,
        TradeStatus _newStatus
    ) private {
        require(
            validTransitions[trades[_tradeId].tradeStatus][_newStatus],
            "Invalid trade status transition"
        );
        trades[_tradeId].tradeStatus = _newStatus;
    }

    function acceptTrade(uint256 _tradeId) public tradeExists(_tradeId) {
        require(
            trades[_tradeId].tradeStatus == TradeStatus.Initiated,
            "Trade is not in initiated status"
        );
        require(
            offerContract
                .getOfferDetails(trades[_tradeId].offerId)
                .offerOwner == msg.sender,
            "Only offer owner can accept the trade"
        );

        _updateTradeStatus(_tradeId, TradeStatus.Accepted);
        emit TradeAccepted(_tradeId);
    }

    function lockCryptoInEscrow(
        uint256 _tradeId
    ) public nonReentrant tradeExists(_tradeId) {
        require(
            trades[_tradeId].tradeStatus == TradeStatus.Accepted,
            "Trade is not in accepted status"
        );
        require(
            trades[_tradeId].tradeStatus != TradeStatus.Finalized,
            "Trade has already been finalized"
        );
        require(
            offerContract
                .getOfferDetails(trades[_tradeId].offerId)
                .offerOwner == msg.sender,
            "Only offer owner can lock crypto in escrow"
        );

        // Call the Escrow contract to lock the crypto
        escrowContract.lockCrypto(_tradeId, trades[_tradeId].tradeAmountCrypto);
        emit CryptoLockedInEscrow(_tradeId, trades[_tradeId].tradeAmountCrypto);
    }

    function tradeMarkFiatPaid(uint256 _tradeId) public tradeExists(_tradeId) {
        require(
            trades[_tradeId].tradeStatus == TradeStatus.Accepted,
            "Trade is not in accepted status"
        );
        require(
            trades[_tradeId].taker == msg.sender,
            "Only trade taker can mark fiat as paid"
        );

        _updateTradeStatus(_tradeId, TradeStatus.FiatPaid);
        emit FiatMarkedAsPaid(_tradeId);
    }

    function finalizeTrade(
        uint256 _tradeId
    ) public nonReentrant tradeExists(_tradeId) {
        require(
            trades[_tradeId].tradeStatus == TradeStatus.FiatPaid ||
                (trades[_tradeId].tradeStatus == TradeStatus.Disputed &&
                    admins[msg.sender]),
            "Trade is not in a finalizable state or caller is not an admin"
        );
        require(
            trades[_tradeId].tradeStatus != TradeStatus.Finalized,
            "Trade has already been finalized"
        );
        require(
            offerContract
                .getOfferDetails(trades[_tradeId].offerId)
                .offerOwner ==
                msg.sender ||
                admins[msg.sender],
            "Only offer owner or admin can finalize the trade"
        );

        _updateTradeStatus(_tradeId, TradeStatus.Finalized);
        trades[_tradeId].tradeFinalizedTime = block.timestamp;

        // Call the Escrow contract to release the crypto to the taker
        escrowContract.releaseCrypto(_tradeId);
        emit TradeFinalized(_tradeId, block.timestamp);
    }

    function cancelTrade(
        uint256 _tradeId
    ) public nonReentrant tradeExists(_tradeId) {
        require(
            trades[_tradeId].tradeStatus == TradeStatus.Initiated ||
                trades[_tradeId].tradeStatus == TradeStatus.Accepted,
            "Trade cannot be cancelled at this stage"
        );
        require(
            trades[_tradeId].tradeStatus != TradeStatus.Finalized,
            "Trade has already been finalized"
        );
        require(
            trades[_tradeId].taker == msg.sender ||
                offerContract
                    .getOfferDetails(trades[_tradeId].offerId)
                    .offerOwner ==
                msg.sender,
            "Only trade parties can cancel the trade"
        );

        _updateTradeStatus(_tradeId, TradeStatus.Cancelled);

        // Call the Escrow contract to refund the crypto if it was locked
        if (trades[_tradeId].tradeStatus == TradeStatus.Accepted) {
            escrowContract.refundCrypto(_tradeId);
        }

        emit TradeCancelled(_tradeId, trades[_tradeId].tradeCancelationReason);
    }

    function disputeTrade(
        uint256 _tradeId
    ) public nonReentrant tradeExists(_tradeId) {
        require(
            trades[_tradeId].tradeStatus == TradeStatus.Accepted ||
                trades[_tradeId].tradeStatus == TradeStatus.FiatPaid,
            "Trade cannot be disputed at this stage"
        );
        require(
            trades[_tradeId].tradeStatus != TradeStatus.Disputed,
            "Trade is already disputed"
        );
        require(
            trades[_tradeId].tradeStatus != TradeStatus.Finalized,
            "Trade has already been finalized"
        );
        require(
            trades[_tradeId].taker == msg.sender ||
                offerContract
                    .getOfferDetails(trades[_tradeId].offerId)
                    .offerOwner ==
                msg.sender,
            "Only trade parties can dispute the trade"
        );

        _updateTradeStatus(_tradeId, TradeStatus.Disputed);

        // Call the Arbitration contract to handle the dispute
        arbitrationContract.handleDispute(_tradeId);
        emit TradeDisputed(_tradeId);
    }

    function timeoutTrade(uint256 _tradeId) public tradeExists(_tradeId) {
        require(
            trades[_tradeId].tradeStatus == TradeStatus.Initiated ||
                trades[_tradeId].tradeStatus == TradeStatus.Accepted ||
                trades[_tradeId].tradeStatus == TradeStatus.FiatPaid,
            "Trade cannot be timed out at this stage"
        );
        require(
            trades[_tradeId].tradeStatus != TradeStatus.TimedOut,
            "Trade has already been timed out"
        );
        require(
            block.timestamp >=
                trades[_tradeId].tradeInitiatedTime +
                    trades[_tradeId].blocksTillTimeout,
            "Trade timeout period has not passed"
        );

        _updateTradeStatus(_tradeId, TradeStatus.TimedOut);
        emit TradeTimedOut(_tradeId);

        // Call the Escrow contract to refund the crypto if it was locked
        if (trades[_tradeId].tradeStatus == TradeStatus.Accepted) {
            escrowContract.refundCrypto(_tradeId);
        }
    }

    function refundTrade(uint256 _tradeId) public tradeExists(_tradeId) {
        require(
            trades[_tradeId].tradeStatus == TradeStatus.Cancelled ||
                trades[_tradeId].tradeStatus == TradeStatus.TimedOut ||
                trades[_tradeId].tradeStatus == TradeStatus.Disputed,
            "Trade cannot be refunded at this stage"
        );
        require(
            msg.sender == address(escrowContract),
            "Only Escrow contract can call refund function"
        );

        // Refund logic handled by the Escrow contract
        // _updateTradeStatus(_tradeId, TradeStatus.Refunded);
        // emit TradeRefunded(_tradeId);
    }

    function rateTrade(
        uint256 _tradeId,
        uint256 _rating,
        string memory _feedback
    ) public onlyTradeParty(_tradeId) tradeExists(_tradeId) {
        require(
            trades[_tradeId].tradeStatus == TradeStatus.Finalized,
            "Trade is not finalized"
        );
        require(_rating >= 1 && _rating <= 5, "Invalid rating value");
        require(
            !tradeRatings[_tradeId][msg.sender],
            "Trade has already been rated by the user"
        );

        tradeRatings[_tradeId][msg.sender] = true;

        // Call the Rating contract to record the trade rating
        ratingContract.rateTrade(_tradeId, msg.sender, _rating, _feedback);
        emit TradeRated(_tradeId, _rating, _feedback);
    }

    function getTradeDetails(
        uint256 _tradeId
    )
        public
        view
        tradeExists(_tradeId)
        returns (
            uint256,
            address,
            uint256,
            uint256,
            string memory,
            string memory,
            uint256,
            string memory,
            TradeStatus,
            uint256,
            uint256,
            uint256
        )
    {
        TradeDetails memory trade = trades[_tradeId];

        return (
            trade.offerId,
            trade.taker,
            trade.tradeAmountFiat,
            trade.tradeAmountCrypto,
            trade.tradeFiatCurrency,
            trade.tradeCryptoCurrency,
            trade.blocksTillTimeout,
            trade.tradeCancelationReason,
            trade.tradeStatus,
            trade.tradeInitiatedTime,
            trade.tradeFinalizedTime,
            trade.tradeFee
        );
    }
}
