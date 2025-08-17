// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PeriodicUSDTDistribution is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token; // USDT token
    address public beneficiary;    // 接收人
    uint256 public amountPerInterval; // 每期发放额度
    uint256 public intervalSeconds;   // 每期间隔时间（秒）
    uint256 public startTimestamp;    // 开始时间
    uint256 public claimedIntervals;  // 已领取的期数
    bool public paused;               // 暂停状态

    event Claimed(address indexed to, uint256 amount, uint256 timestamp);
    event AmountPerIntervalChanged(uint256 newAmount);
    event BeneficiaryChanged(address indexed newBeneficiary);
    event Paused(bool isPaused);
    event Funded(address indexed from, uint256 amount);

    constructor(
        address _token,
        address _beneficiary,
        uint256 _startTimestamp,
        uint256 _intervalSeconds,
        uint256 _amountPerInterval
    ) {
        require(_token != address(0), "token is zero");
        require(_beneficiary != address(0), "beneficiary is zero");
        require(_intervalSeconds > 0, "interval zero");
        token = IERC20(_token);
        beneficiary = _beneficiary;
        startTimestamp = _startTimestamp;
        intervalSeconds = _intervalSeconds;
        amountPerInterval = _amountPerInterval;
        paused = false;
    }

    modifier notPaused() {
        require(!paused, "paused");
        _;
    }

    // owner 可以存钱到合约
    function fund(uint256 amount) external nonReentrant {
        require(amount > 0, "amount zero");
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Funded(msg.sender, amount);
    }

    // 可领取的期数
    function availableIntervals() public view returns (uint256) {
        if (block.timestamp < startTimestamp) return 0;
        uint256 elapsed = (block.timestamp - startTimestamp) / intervalSeconds;
        if (elapsed <= claimedIntervals) return 0;
        return elapsed - claimedIntervals;
    }

    // 可领取的总金额
    function availableAmount() public view returns (uint256) {
        return availableIntervals() * amountPerInterval;
    }

    // 领取
    function claim() external nonReentrant notPaused {
        require(msg.sender == beneficiary, "not beneficiary");
        uint256 amt = availableAmount();
        require(amt > 0, "nothing to claim");
        require(token.balanceOf(address(this)) >= amt, "insufficient balance");

        claimedIntervals += availableIntervals(); // 更新已领取期数
        token.safeTransfer(beneficiary, amt);
        emit Claimed(beneficiary, amt, block.timestamp);
    }

    // owner 改每期发放额度
    function setAmountPerInterval(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "zero amount");
        amountPerInterval = newAmount;
        emit AmountPerIntervalChanged(newAmount);
    }

    // owner 改受益人
    function setBeneficiary(address newB) external onlyOwner {
        require(newB != address(0), "zero address");
        beneficiary = newB;
        emit BeneficiaryChanged(newB);
    }

    // 暂停/恢复
    function pause(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    // 紧急取回（只能 owner 执行）
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }
}
