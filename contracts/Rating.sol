// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Trade.sol";
import "./Offer.sol";
import "./Account.sol";

contract Rating {
    Trade private tradeContract;
    Offer private offerContract;
    Account private accountContract;

    struct RatingDetails {
        uint256 tradeId;
        uint256 offerId;
        address raterId;
        address rateeId;
        uint256 rateStars;
        string rateString;
        uint256 rateTimestamp;
    }

    uint256 public ratingCount;
    mapping(uint256 => RatingDetails) public ratings;

    event TradeRated(
        uint256 indexed tradeId,
        uint256 indexed offerId,
        address indexed raterId,
        address rateeId,
        uint256 rateStars,
        string rateString
    );

    constructor(
        address _tradeContractAddress,
        address _offerContractAddress,
        address _accountContractAddress
    ) {
        tradeContract = Trade(_tradeContractAddress);
        offerContract = Offer(_offerContractAddress);
        accountContract = Account(_accountContractAddress);
    }

    function rateTrade(
        uint256 _tradeId,
        address _raterId,
        uint256 _rateStars,
        string memory _rateString
    ) public {
        require(
            tradeContract.trades(_tradeId).tradeStatus ==
                Trade.TradeStatus.Finalized,
            "Trade is not in finalized status"
        );
        require(
            _raterId == tradeContract.trades(_tradeId).taker ||
                _raterId ==
                offerContract
                    .getOfferDetails(tradeContract.trades(_tradeId).offerId)
                    .offerOwner,
            "Only trade parties can rate the trade"
        );
        require(
            _rateStars >= 1 && _rateStars <= 5,
            "Rating stars must be between 1 and 5"
        );
        require(
            bytes(_rateString).length <= 280,
            "Rating string must not exceed 280 bytes"
        );

        uint256 offerId = tradeContract.trades(_tradeId).offerId;
        address rateeId;

        if (_raterId == tradeContract.trades(_tradeId).taker) {
            rateeId = offerContract.getOfferDetails(offerId).offerOwner;
        } else {
            rateeId = tradeContract.trades(_tradeId).taker;
        }

        ratingCount++;
        ratings[ratingCount] = RatingDetails(
            _tradeId,
            offerId,
            _raterId,
            rateeId,
            _rateStars,
            _rateString,
            block.timestamp
        );

        emit TradeRated(
            _tradeId,
            offerId,
            _raterId,
            rateeId,
            _rateStars,
            _rateString
        );

        // Update user reputation in the Account contract
        accountContract.updateUserReputation(rateeId, _rateStars);
    }
}
