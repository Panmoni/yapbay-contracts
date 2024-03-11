// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Offer {
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
        string offerStatus; // active, paused, withdrawn
        uint256 offerCreatedTime;
    }

    uint256 public offerCount;
    mapping(uint256 => OfferDetails) public offers;

    event OfferCreated(uint256 indexed offerId, address indexed owner);
    event OfferStatusChanged(uint256 indexed offerId, string status);
    event OfferMinMaxTradeAmountsChanged(
        uint256 indexed offerId,
        uint256 minAmount,
        uint256 maxAmount
    );

    function offerCreate(
        uint256 _minTradeAmount,
        uint256 _maxTradeAmount,
        string memory _fiatCurrency
    ) public {
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
            "active",
            block.timestamp
        );

        emit OfferCreated(offerCount, msg.sender);
    }

    function offerUpdateOffer(
        uint256 _offerId,
        uint256 _minTradeAmount,
        uint256 _maxTradeAmount,
        string memory _status
    ) public {
        require(
            offers[_offerId].offerOwner == msg.sender,
            "Only offer owner can update the offer"
        );

        OfferDetails storage offer = offers[_offerId];
        offer.offerMinTradeAmount = _minTradeAmount;
        offer.offerMaxTradeAmount = _maxTradeAmount;
        offer.offerStatus = _status;

        emit OfferStatusChanged(_offerId, _status);
        emit OfferMinMaxTradeAmountsChanged(
            _offerId,
            _minTradeAmount,
            _maxTradeAmount
        );
    }

    function getOfferDetails(
        uint256 _offerId
    )
        public
        view
        returns (
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            string memory,
            string memory,
            uint256
        )
    {
        OfferDetails memory offer = offers[_offerId];
        return (
            offer.offerOwner,
            offer.offerTotalTradesAccepted,
            offer.offerTotalTradesCompleted,
            offer.offerDisputesInvolved,
            offer.offerDisputesLost,
            offer.offerAverageTradeVolume,
            offer.offerMinTradeAmount,
            offer.offerMaxTradeAmount,
            offer.offerFiatCurrency,
            offer.offerStatus,
            offer.offerCreatedTime
        );
    }
}
