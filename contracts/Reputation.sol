// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Account.sol";

contract Reputation {
    Account private accountContract;

    uint256 private constant REPUTATION_SCALE = 100;
    uint256 private constant TRADE_VOLUME_WEIGHT = 30;
    uint256 private constant ACTIVE_OFFERS_WEIGHT = 20;
    uint256 private constant TRADE_COUNT_WEIGHT = 20;
    uint256 private constant COMPLETION_RATE_WEIGHT = 15;
    uint256 private constant RATING_WEIGHT = 10;
    uint256 private constant ENDORSEMENT_WEIGHT = 5;

    constructor(address _accountContractAddress) {
        accountContract = Account(_accountContractAddress);
    }

    function calculateReputation(address _user) public view returns (uint256) {
        Account.User memory user = accountContract.users(_user);

        uint256 tradeVolumeScore = (user.userTotalTradeVolume *
            TRADE_VOLUME_WEIGHT) / REPUTATION_SCALE;
        uint256 activeOffersScore = (user.userTotalTradesInitiated *
            ACTIVE_OFFERS_WEIGHT) / REPUTATION_SCALE;
        uint256 tradeCountScore = (user.userTotalTradesCompleted *
            TRADE_COUNT_WEIGHT) / REPUTATION_SCALE;

        uint256 completionRate = (user.userTotalTradesCompleted * 100) /
            (user.userTotalTradesAccepted + 1);
        uint256 completionRateScore = (completionRate *
            COMPLETION_RATE_WEIGHT) / 100;

        uint256 ratingScore = (user.userReputationScore * RATING_WEIGHT) /
            REPUTATION_SCALE;
        uint256 endorsementScore = (user.userEndorsementsReceived *
            ENDORSEMENT_WEIGHT) / REPUTATION_SCALE;

        uint256 reputationScore = tradeVolumeScore +
            activeOffersScore +
            tradeCountScore +
            completionRateScore +
            ratingScore +
            endorsementScore;

        // Apply decay function to reduce the importance of older trades
        uint256 decayFactor = calculateDecayFactor(
            user.userLastCompletedTradeDate
        );
        reputationScore = (reputationScore * decayFactor) / 100;

        return reputationScore;
    }

    function calculateDecayFactor(
        uint256 _lastTradeTimestamp
    ) private view returns (uint256) {
        uint256 timeSinceLastTrade = block.timestamp - _lastTradeTimestamp;
        uint256 decayFactor = 100;

        if (timeSinceLastTrade > 365 days) {
            decayFactor = 50;
        } else if (timeSinceLastTrade > 180 days) {
            decayFactor = 75;
        }

        return decayFactor;
    }
}
