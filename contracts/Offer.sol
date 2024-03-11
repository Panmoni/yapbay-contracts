// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Offer {
    address public owner;
    bool public paused;

    enum OfferStatus {
        Active,
        Paused,
        Withdrawn
    }

    struct OfferDetails {
        address offerOwner;
        uint256 offerTotalTradesAccepted;
        uint256 offerTotalTradesCompleted;
        uint256 offerDisputesInvolved;
        uint256 offerDisputesLost;
        uint256 offerAverageTradeVolume;
        uint256 offerMinTradeAmount;
        uint256 offerMaxTradeAmount;
        string offerFiatCurrency;
        OfferStatus offerStatus;
        uint256 offerCreatedTime;
    }

    uint256 public offerCount;
    mapping(uint256 => OfferDetails) public offers;
    mapping(address => uint256[]) public userOffers;
    mapping(uint256 => mapping(uint256 => bool)) public offerDisputeCounted;
    mapping(address => mapping(bytes32 => bool)) public offerParametersUsed;

    event OfferCreated(
        uint256 indexed offerId,
        address indexed offerOwner,
        uint256 minTradeAmount,
        uint256 maxTradeAmount,
        string fiatCurrency,
        OfferStatus status
    );
    event OfferUpdated(
        uint256 indexed offerId,
        uint256 minTradeAmount,
        uint256 maxTradeAmount,
        OfferStatus status
    );
    event OfferStatusChanged(uint256 indexed offerId, OfferStatus offerStatus);
    event OfferMinMaxTradeAmountsChanged(
        uint256 indexed offerId,
        uint256 minAmount,
        uint256 maxAmount
    );
    event OfferStatsUpdated(uint256 indexed offerId);
    event OfferTradeAccepted(uint256 indexed offerId);
    event OfferTradeCompleted(uint256 indexed offerId, uint256 tradeVolume);
    event OfferDisputeInvolved(uint256 indexed offerId, uint256 disputeId);
    event OfferDisputeLost(uint256 indexed offerId, uint256 disputeId);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event ContractPaused();
    event ContractUnpaused();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can perform this action"
        );
        _;
    }

    modifier offerExists(uint256 _offerId) {
        require(_offerId > 0 && _offerId <= offerCount, "Offer does not exist");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    function getUserOffers(
        address _user
    ) public view returns (uint256[] memory) {
        return userOffers[_user];
    }

    function offerCreate(
        uint256 _minTradeAmount,
        uint256 _maxTradeAmount,
        string memory _fiatCurrency
    ) public whenNotPaused {
        require(
            _minTradeAmount <= _maxTradeAmount,
            "Invalid trade amount range"
        );
        require(
            bytes(_fiatCurrency).length > 0,
            "Fiat currency cannot be empty"
        );

        bytes32 offerHash = keccak256(
            abi.encodePacked(
                msg.sender,
                _minTradeAmount,
                _maxTradeAmount,
                _fiatCurrency
            )
        );
        require(
            !offerParametersUsed[msg.sender][offerHash],
            "Duplicate offer parameters"
        );
        offerParametersUsed[msg.sender][offerHash] = true;

        offerCount++;
        offers[offerCount] = OfferDetails(
            msg.sender,
            0,
            0,
            0,
            0,
            0,
            _minTradeAmount,
            _maxTradeAmount,
            _fiatCurrency,
            OfferStatus.Active,
            block.timestamp
        );

        userOffers[msg.sender].push(offerCount);
        emit OfferCreated(
            offerCount,
            msg.sender,
            _minTradeAmount,
            _maxTradeAmount,
            _fiatCurrency,
            OfferStatus.Active
        );
    }

    function offerUpdateOffer(
        uint256 _offerId,
        uint256 _minTradeAmount,
        uint256 _maxTradeAmount,
        OfferStatus _status
    ) public offerExists(_offerId) {
        require(
            offers[_offerId].offerOwner == msg.sender,
            "Only offer owner can update the offer"
        );
        require(
            _minTradeAmount <= _maxTradeAmount,
            "Invalid trade amount range"
        );

        OfferDetails storage offer = offers[_offerId];
        offer.offerMinTradeAmount = _minTradeAmount;
        offer.offerMaxTradeAmount = _maxTradeAmount;
        offer.offerStatus = _status;

        emit OfferUpdated(_offerId, _minTradeAmount, _maxTradeAmount, _status);
    }

    function getOfferDetails(
        uint256 _offerId
    ) public view offerExists(_offerId) returns (OfferDetails memory) {
        return offers[_offerId];
    }

    function getOfferCounts()
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 acceptedCount = 0;
        uint256 completedCount = 0;
        uint256 disputedCount = 0;
        uint256 lostCount = 0;

        for (uint256 i = 1; i <= offerCount; i++) {
            acceptedCount += offers[i].offerTotalTradesAccepted;
            completedCount += offers[i].offerTotalTradesCompleted;
            disputedCount += offers[i].offerDisputesInvolved;
            lostCount += offers[i].offerDisputesLost;
        }

        return (acceptedCount, completedCount, disputedCount, lostCount);
    }

    function updateOfferStats(
        uint256 _offerId,
        uint256 _tradeVolume,
        bool _accepted,
        bool _completed,
        bool _disputed,
        bool _lost,
        uint256 _disputeId
    ) public offerExists(_offerId) whenNotPaused {
        require(
            msg.sender == address(tradeContract),
            "Only Trade contract can update offer stats"
        );

        OfferDetails storage offer = offers[_offerId];

        if (_accepted) {
            offer.offerTotalTradesAccepted++;
            emit OfferTradeAccepted(_offerId);
        }
        if (_completed) {
            offer.offerTotalTradesCompleted++;
            emit OfferTradeCompleted(_offerId, _tradeVolume);
            if (offer.offerTotalTradesCompleted > 1) {
                offer.offerAverageTradeVolume =
                    (offer.offerAverageTradeVolume *
                        (offer.offerTotalTradesCompleted - 1) +
                        _tradeVolume) /
                    offer.offerTotalTradesCompleted;
            } else {
                offer.offerAverageTradeVolume = _tradeVolume;
            }
        }
        if (_disputed && !offerDisputeCounted[_offerId][_disputeId]) {
            offer.offerDisputesInvolved++;
            offerDisputeCounted[_offerId][_disputeId] = true;
            emit OfferDisputeInvolved(_offerId, _disputeId);
        }
        if (_lost && !offerDisputeCounted[_offerId][_disputeId]) {
            offer.offerDisputesLost++;
            offerDisputeCounted[_offerId][_disputeId] = true;
            emit OfferDisputeLost(_offerId, _disputeId);
        }

        emit OfferStatsUpdated(_offerId);
    }

    function pauseContract() public onlyOwner {
        require(!paused, "Contract is already paused");
        paused = true;
        emit ContractPaused();
    }

    function unpauseContract() public onlyOwner {
        require(paused, "Contract is not paused");
        paused = false;
        emit ContractUnpaused();
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invalid new owner address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}
