// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Account {
    address public owner;

    struct UserBasicInfo {
        uint256 userId;
        bytes32 userEmail;
        bytes32 userChatHandle;
        bytes32 userWebsite;
        string userAvatar;
        string userRole;
    }

    struct UserStats {
        uint256 userReputationScore;
        uint256 userEndorsementsGiven;
        uint256 userEndorsementsReceived;
        uint256 userRatingsGiven;
        uint256 userRatingsReceived;
        uint256 userDisputesInitiated;
        uint256 userDisputesLost;
        uint256 userTotalTradesInitiated;
        uint256 userTotalTradesAccepted;
        uint256 userTotalTradesCompleted;
        uint256 userTotalTradeVolume;
        uint256 userAverageTradeVolume;
        uint256 userLastCompletedTradeDate;
    }

    mapping(address => UserBasicInfo) public userBasicInfo;
    mapping(address => UserStats) public userStats;
    mapping(uint256 => address) public userIdToAddress;
    uint256 public userCount;

    event UserRegistered(address indexed user, uint256 indexed userId);
    event UserProfileUpdated(address indexed user, uint256 indexed userId);
    event EndorsementGiven(address indexed endorser, address indexed endorsed);
    event EndorsementReceived(
        address indexed endorser,
        address indexed endorsed
    );
    event ReputationUpdated(address indexed user, uint256 newReputationScore);
    event DisputeInitiated(address indexed user);
    event DisputeLost(address indexed user);
    event TradeStatsUpdated(address indexed user);

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

    function userReg(
        bytes32 _userEmail,
        bytes32 _userChatHandle,
        bytes32 _userWebsite,
        string memory _userAvatar
    ) public {
        require(
            userBasicInfo[msg.sender].userId == 0,
            "User already registered"
        );

        userCount++;
        userBasicInfo[msg.sender] = UserBasicInfo(
            userCount,
            _userEmail,
            _userChatHandle,
            _userWebsite,
            _userAvatar,
            "user"
        );
        userIdToAddress[userCount] = msg.sender;

        emit UserRegistered(msg.sender, userCount);
    }

    event UserRoleUpdated(
        address indexed user,
        uint256 indexed userId,
        string newRole
    );

    function userUpdateProfile(
        bytes32 _userEmail,
        bytes32 _userChatHandle,
        bytes32 _userWebsite,
        string memory _userAvatar,
        string memory _userRole
    ) public {
        require(userBasicInfo[msg.sender].userId != 0, "User not registered");

        UserBasicInfo storage user = userBasicInfo[msg.sender];
        user.userEmail = _userEmail;
        user.userChatHandle = _userChatHandle;
        user.userWebsite = _userWebsite;
        user.userAvatar = _userAvatar;

        if (msg.sender == owner) {
            user.userRole = _userRole; // Only the contract owner (admin) can update the user's role
        }

        emit UserProfileUpdated(msg.sender, user.userId);
    }

    // TODO:
    // This function should be called whenever a user's reputation needs to be updated
    // based on trade volume, active offers, number of trades, trade completion rate,
    // trade partner ratings, endorsements, and a decay function for older trades.
    function userReputationCalc(address _user) public {
        UserStats storage stats = userStats[_user];

        // Calculate reputation score based on user stats
        uint256 reputationScore = 0;

        // Increase reputation based on completed trades
        reputationScore += stats.userTotalTradesCompleted * 10;

        // Increase reputation based on trade volume
        reputationScore += stats.userTotalTradeVolume / 1 ether;

        // Decrease reputation based on disputes lost
        reputationScore -= stats.userDisputesLost * 50;

        // Increase reputation based on endorsements received
        reputationScore += stats.userEndorsementsReceived * 5;

        // Update user's reputation score
        stats.userReputationScore = reputationScore;

        emit ReputationUpdated(_user, reputationScore);
    }

    function updateEndorsementsGiven(
        address _endorser,
        address _endorsed
    ) public {
        userStats[_endorser].userEndorsementsGiven++;
        emit EndorsementGiven(_endorser, _endorsed);
    }

    function updateEndorsementsReceived(
        address _endorser,
        address _endorsed
    ) public {
        userStats[_endorsed].userEndorsementsReceived++;
        emit EndorsementReceived(_endorser, _endorsed);
    }

    function updateDisputesInitiated(address _user) public {
        userStats[_user].userDisputesInitiated++;
        emit DisputeInitiated(_user);
    }

    function updateDisputesLost(address _user) public {
        userStats[_user].userDisputesLost++;
        emit DisputeLost(_user);
    }

    function updateTradeStats(
        address _user,
        uint256 _tradeVolume,
        bool _initiated,
        bool _accepted,
        bool _completed
    ) public {
        UserStats storage stats = userStats[_user];
        if (_initiated) {
            stats.userTotalTradesInitiated++;
        }
        if (_accepted) {
            stats.userTotalTradesAccepted++;
        }
        if (_completed) {
            stats.userTotalTradesCompleted++;
            stats.userTotalTradeVolume += _tradeVolume;
            stats.userAverageTradeVolume =
                stats.userTotalTradeVolume /
                stats.userTotalTradesCompleted;
            stats.userLastCompletedTradeDate = block.timestamp;
        }
        emit TradeStatsUpdated(_user);
    }
}
