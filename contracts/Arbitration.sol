// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Trade.sol";
import "./Escrow.sol";

contract Arbitration {
    address public admin;
    Trade private tradeContract;
    Escrow private escrowContract;

    enum DisputeStatus {
        Pending,
        Resolved
    }

    struct DisputeDetails {
        uint256 tradeId;
        DisputeStatus status;
        uint256 disputeTimestamp;
        uint256 resolveTimestamp;
        bool resolvedInFavorOfMaker;
    }

    uint256 public disputeCount;
    mapping(uint256 => DisputeDetails) public disputes;

    event DisputeCreated(uint256 indexed tradeId, uint256 disputeId);
    event DisputeResolved(
        uint256 indexed tradeId,
        uint256 disputeId,
        bool resolvedInFavorOfMaker
    );

    constructor(
        address _admin,
        address _tradeContractAddress,
        address _escrowContractAddress
    ) {
        admin = _admin;
        tradeContract = Trade(_tradeContractAddress);
        escrowContract = Escrow(_escrowContractAddress);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    function handleDispute(uint256 _tradeId) public {
        require(
            tradeContract.trades(_tradeId).tradeStatus ==
                Trade.TradeStatus.Disputed,
            "Trade is not in disputed status"
        );

        disputeCount++;
        disputes[disputeCount] = DisputeDetails(
            _tradeId,
            DisputeStatus.Pending,
            block.timestamp,
            0,
            false
        );

        emit DisputeCreated(_tradeId, disputeCount);
    }

    function resolveDispute(
        uint256 _disputeId,
        bool _resolveInFavorOfMaker
    ) public onlyAdmin {
        require(
            disputes[_disputeId].status == DisputeStatus.Pending,
            "Dispute is not in pending status"
        );

        uint256 tradeId = disputes[_disputeId].tradeId;
        disputes[_disputeId].status = DisputeStatus.Resolved;
        disputes[_disputeId].resolveTimestamp = block.timestamp;
        disputes[_disputeId].resolvedInFavorOfMaker = _resolveInFavorOfMaker;

        if (_resolveInFavorOfMaker) {
            escrowContract.releaseCrypto(tradeId);
        } else {
            escrowContract.refundCrypto(tradeId);
        }

        emit DisputeResolved(tradeId, _disputeId, _resolveInFavorOfMaker);
    }
}
