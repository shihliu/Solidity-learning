// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidityMining {
    IERC20 private _token;
    IERC20 private _lpToken;
    uint256 private _startTime;
    uint256 private _endTime;
    uint256 private _rewardRate;
    uint256 private _lastUpdateTime;
    uint256 private _rewardPerTokenStored;
    mapping(address => uint256) private _userRewardPerTokenPaid;
    mapping(address => uint256) private _rewards;
    mapping(address => uint256) private _balances;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(IERC20 token_, IERC20 lpToken_, uint256 startTime_, uint256 endTime_, uint256 reward) {
        require(startTime_ >= block.timestamp, "LiquidityMining: start time is before current time");
        require(endTime_ > startTime_, "LiquidityMining: end time is before start time");
        require(reward > 0, "LiquidityMining: reward is zero");

        _token = token_;
        _lpToken = lpToken_;
        _startTime = startTime_;
        _endTime = endTime_;
        _rewardRate = reward / (endTime_ - startTime_);
        _lastUpdateTime = startTime_;

        emit RewardAdded(reward);
    }

    function token() public view returns (IERC20) {
        return _token;
    }

    function lpToken() public view returns (IERC20) {
        return _lpToken;
    }

    function startTime() public view returns (uint256) {
        return _startTime;
    }

    function endTime() public view returns (uint256) {
        return _endTime;
    }

    function rewardRate() public view returns (uint256) {
        return _rewardRate;
    }

    function lastUpdateTime() public view returns (uint256) {
        return _lastUpdateTime;
    }

    function rewardPerTokenStored() public view returns (uint256) {
        if (block.timestamp < _startTime) {
            return 0;
        }
        if (block.timestamp >= _endTime) {
            return _rewardPerTokenStored;
        }
        return _rewardPerTokenStored + (block.timestamp - _lastUpdateTime) * _rewardRate * 1e18 / _lpToken.totalSupply();
    }

    function earned(address account) public view returns (uint256) {
        return _balances[account] * (rewardPerTokenStored() - _userRewardPerTokenPaid[account]) / 1e18 + _rewards[account];
    }

    function stake(uint256 amount) public {
        require(block.timestamp >= _startTime, "LiquidityMining: not started");
        require(block.timestamp < _endTime, "LiquidityMining: ended");
        require(amount > 0, "LiquidityMining: cannot stake zero amount");

        _updateReward(msg.sender);
        _lpToken.transferFrom(msg.sender, address(this), amount);
        _balances[msg.sender] += amount;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "LiquidityMining: cannot withdraw zero amount");

        _updateReward(msg.sender);
        _balances[msg.sender] -= amount;
        _lpToken.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public {
        _updateReward(msg.sender);
        uint256 reward = _rewards[msg.sender];
        if (reward > 0) {
            _rewards[msg.sender] = 0;
            _token.transfer(msg.sender, reward);

            emit RewardPaid(msg.sender, reward);
        }
    }

    function _updateReward(address account) private {
        _rewardPerTokenStored = rewardPerTokenStored();
        _lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            _rewards[account] = earned(account);
            _userRewardPerTokenPaid[account] = _rewardPerTokenStored;
        }
    }
}