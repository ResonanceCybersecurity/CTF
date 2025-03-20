// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/// @title Resonance Solidity CTF
/// @author Luis Arroyo
contract ResonanceStaking is ERC721Enumerable {
    // User staking data
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 tokenId;
        bool isNative;
    }

    // DAO proposal and voting system
    struct Proposal {
        uint256 newDuration;
        uint256 newAmount;
        uint256 votes;
        bool executed;
    }

    IERC20 public resToken;

    uint256 public stakingDuration; // Time in seconds
    uint256 public stakingAmount; // Amount of RES required to stake
    mapping(address => Stake) public stakes;

    Proposal public currentProposal;
    mapping(address => bool) public hasVoted;
    uint256 public totalVotes; // Total weighted votes needed to execute a proposal

    uint256 private nextTokenId = 1;
    uint256 public rewardsBalance; // Rewards pool balance

    // Events
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 startTime,
        uint256 tokenId,
        bool isNative
    );
    event Unstaked(
        address indexed user,
        uint256 amount,
        uint256 reward,
        uint256 tokenId,
        bool isNative
    );
    event ProposalCreated(uint256 newDuration, uint256 newAmount);
    event Voted(address indexed voter, uint256 weight);
    event ProposalExecuted(uint256 newDuration, uint256 newAmount);
    event RewardPoolUpdated(uint256 amount);

    /**
     * @dev Constructor to initialize the StakingProtocol contract.
     * @param _resToken Address of the RES token contract.
     * @param _totalVotes Minimum weighted votes required to execute a proposal.
     * @param initialPool Initial amount of RES tokens to be transferred to the rewards pool.
     */
    constructor(
        IERC20 _resToken,
        uint256 _totalVotes,
        uint256 initialPool
    ) ERC721("StakingPositionNFT", "SPNFT") {
        resToken = _resToken;
        totalVotes = _totalVotes;
        rewardsBalance = initialPool;
    }

    /**
     * @dev Creates a new proposal to update staking parameters.
     * @param _newDuration New staking duration in seconds.
     * @param _newAmount New staking amount in RES tokens.
     */
    function createProposal(uint256 _newDuration, uint256 _newAmount) external {
        require(_newDuration > 0, "Staking duration must be greater than 0");
        require(_newAmount > 0, "Staking amount must be greater than 0");
        require(
            currentProposal.votes == 0 || currentProposal.executed,
            "Another proposal is still active"
        );
        require(
            resToken.balanceOf(msg.sender) > 0,
            "You must hold RES tokens to create a proposal"
        );

        currentProposal = Proposal({
            newDuration: _newDuration,
            newAmount: _newAmount,
            votes: 0,
            executed: false
        });

        // Reset votes
        for (uint256 i = 0; i < totalVotes; i++) {
            hasVoted[address(uint160(i))] = false;
        }

        emit ProposalCreated(_newDuration, _newAmount);
    }

    /**
     * @dev Votes on the current proposal.
     */
    function vote() external {
        require(!hasVoted[msg.sender], "You have already voted");
        require(
            currentProposal.votes < totalVotes,
            "Proposal already has enough votes"
        );
        require(!currentProposal.executed, "Proposal already executed");

        uint256 weight = resToken.balanceOf(msg.sender);
        require(weight > 0, "You must hold RES tokens to vote");

        hasVoted[msg.sender] = true;
        currentProposal.votes += weight;

        emit Voted(msg.sender, weight);

        // Check if the proposal has enough weighted votes to execute
        if (currentProposal.votes >= totalVotes) {
            executeProposal();
        }
    }

    /**
     * @dev Executes the current proposal to update staking parameters.
     */
    function executeProposal() internal {
        require(!currentProposal.executed, "Proposal already executed");

        stakingDuration = currentProposal.newDuration;
        stakingAmount = currentProposal.newAmount;
        currentProposal.executed = true;

        emit ProposalExecuted(
            currentProposal.newDuration,
            currentProposal.newAmount
        );
    }

    /**
     * @dev Allows users to stake RES tokens.
     * @param _stakingAmount Amount of RES tokens to stake.
     */
    function stake(uint256 _stakingAmount) external {
        require(stakes[msg.sender].amount == 0, "Already staking");
        require(
            resToken.balanceOf(msg.sender) >= stakingAmount,
            "Insufficient RES balance"
        );

        resToken.transferFrom(msg.sender, address(this), _stakingAmount);

        uint256 tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);

        stakes[msg.sender] = Stake({
            amount: stakingAmount,
            startTime: block.timestamp,
            tokenId: tokenId,
            isNative: false
        });

        emit Staked(msg.sender, stakingAmount, block.timestamp, tokenId, false);
    }

    /**
     * @dev Allows users to stake native ETH.
     */
    function stakeWithETH() external payable {
        require(stakes[msg.sender].amount == 0, "Already staking");
        require(msg.value > 0, "Staking amount must be greater than 0");

        uint256 tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);

        stakes[msg.sender] = Stake({
            amount: msg.value,
            startTime: block.timestamp,
            tokenId: tokenId,
            isNative: true
        });

        emit Staked(msg.sender, msg.value, block.timestamp, tokenId, true);
    }

    /**
     * @dev Allows users to unstake tokens and claim rewards.
     */
    function unstake() external {
        Stake memory userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No active stake");
        require(
            block.timestamp > userStake.startTime + stakingDuration,
            "Staking period not yet complete"
        );

        uint256 reward = _generateReward(userStake.amount);

        if (userStake.isNative) {
            (bool success, ) = payable(msg.sender).call{
                value: userStake.amount + reward
            }("");
            require(success, "Transfer failed");
        } else {
            resToken.transferFrom(
                address(this),
                msg.sender,
                userStake.amount + reward
            );
        }

        // Remove staking position
        _burn(userStake.tokenId);
        delete stakes[msg.sender];

        emit Unstaked(
            msg.sender,
            userStake.amount,
            reward,
            userStake.tokenId,
            userStake.isNative
        );
    }

    /**
     * @dev Calculates the reward for staking.
     * @param amount Amount of tokens staked.
     * @return The reward amount.
     */
    function _generateReward(uint256 amount) public returns (uint256) {
        uint256 reward = (amount * 5) / 100; // 5% reward for staking
        require(reward <= rewardsBalance, "Insufficient rewards balance");
        rewardsBalance -= reward;
        return reward;
    }

    /**
     * @dev Updates the rewards pool by transferring RES tokens from the sender.
     * @param amount Amount of RES tokens to add to the rewards pool.
     */
    function updateRewardsPool(uint256 amount) external {
        resToken.transferFrom(msg.sender, address(this), amount);
        emit RewardPoolUpdated(amount);
    }

    /**
     * @dev Updates the rewards pool by transferring RES tokens from a specified address.
     * used by ResPool periodically to send obtained fees to the rewards pool.
     * @param amount Amount of RES tokens to add to the rewards pool.
     * @param from Address from which the RES tokens will be transferred.
     */
    function updateRewardsPool(uint256 amount, address from) external {
        resToken.transferFrom(from, address(this), amount);
        emit RewardPoolUpdated(amount);
    }
}
