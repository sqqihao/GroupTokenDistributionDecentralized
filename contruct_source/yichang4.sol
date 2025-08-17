// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*

（1）部署智能合约
在 以太坊主网 或 私有链 上部署合约。

初始化参数：

_wallets：受益人钱包地址列表。

_shares：每个受益人的份额（如 [5000, 3000, 2000] 表示 50%、30%、20%）。

_interval：发放间隔（秒，如 2592000 = 30天）。

_guardian：监管人地址（可设为律师或可信第三方）。

（2）存入 USDT
使用 depositUSDT() 将 USDT 转入合约托管。

（3）自动/手动发放
自动模式：可搭配 Chainlink Automation 或 Gelato 定时触发 distribute()。

手动模式：任何人均可调用 distribute()（但仅符合条件时才会发放）。

（4）监管与终止
监管人可 pauseDistribution(true) 暂停发放。

紧急情况下可 withdrawRemainingUSDT() 提取剩余资金。

*/

/*
  GroupTokenDistributionDecentralized
  - 支持 USDT 和 WETH 分发（按万分比）
  - 多受益人，动态增删改（在未锁定前）
  - distributionInterval 控制发放频率（每个币用独立 lastClaim）
  - lockContract(): 要求 totalShares == 10000，设置 isLocked=true 并 renounceOwnership()
    => 一旦锁定，任何可修改配置的函数都不可再调用（完全去中心化）
  - 使用 SafeERC20 兼容不返回 bool 的 token（例如历史版 USDT）
*/

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GroupTokenDistributionDecentralized is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdt;
    IERC20 public immutable weth;

    struct Beneficiary {
        address wallet;
        uint256 share; // 万分比 (10000 == 100%)
        uint256 lastClaimUSDT;
        uint256 lastClaimWETH;
    }

    Beneficiary[] private beneficiaries;
    mapping(address => uint256) private beneficiaryIndex; // 1-based index; 0 means not exists
    uint256 public totalShares; // sum of all shares, should be 10000 before lock

    uint256 public distributionInterval; // seconds
    bool public isPaused;
    bool public isLocked; // 一旦 true，所有可修改配置的函数都不可再调用

    // Events
    event BeneficiaryAdded(address indexed wallet, uint256 share);
    event BeneficiaryRemoved(address indexed wallet);
    event BeneficiaryUpdated(address indexed wallet, uint256 newShare);
    event FundsDistributed(address indexed wallet, address indexed token, uint256 amount);
    event Paused(bool paused);
    event IntervalChanged(uint256 newInterval);
    event ContractLocked(uint256 timestamp);

    // Modifiers
    modifier notPaused() {
        require(!isPaused, "Distribution is paused");
        _;
    }

    modifier notLocked() {
        require(!isLocked, "Contract is locked");
        _;
    }

    constructor(
        address _usdt,
        address _weth,
        uint256 _distributionInterval
    ) {
        require(_usdt != address(0), "Invalid USDT");
        require(_weth != address(0), "Invalid WETH");
        require(_distributionInterval > 0, "Invalid interval");

        usdt = IERC20(_usdt);
        weth = IERC20(_weth);
        distributionInterval = _distributionInterval;
        isPaused = false;
        isLocked = false;
        totalShares = 0;
        // beneficiaries[] initially empty
    }

    // -------------------------
    // Owner-only configuration (only while notLocked)
    // -------------------------

    // add beneficiary; share is in 万分比 (10000 = 100%)
    function addBeneficiary(address _wallet, uint256 _share) external onlyOwner notLocked {
        require(_wallet != address(0), "Invalid wallet");
        require(_share > 0, "Share must > 0");
        require(beneficiaryIndex[_wallet] == 0, "Already beneficiary");
        require(totalShares + _share <= 10000, "Total shares exceed 10000");

        beneficiaries.push(Beneficiary({
            wallet: _wallet,
            share: _share,
            lastClaimUSDT: block.timestamp,
            lastClaimWETH: block.timestamp
        }));

        beneficiaryIndex[_wallet] = beneficiaries.length; // 1-based
        totalShares += _share;

        emit BeneficiaryAdded(_wallet, _share);
    }

    // remove beneficiary
    function removeBeneficiary(address _wallet) external onlyOwner notLocked {
        uint256 idx = beneficiaryIndex[_wallet];
        require(idx != 0, "Not beneficiary");

        uint256 arrayIndex = idx - 1;
        uint256 last = beneficiaries.length - 1;

        // subtract share
        uint256 removedShare = beneficiaries[arrayIndex].share;
        totalShares -= removedShare;

        if (arrayIndex != last) {
            // move last into removed slot
            Beneficiary memory moved = beneficiaries[last];
            beneficiaries[arrayIndex] = moved;
            beneficiaryIndex[moved.wallet] = arrayIndex + 1;
        }

        beneficiaries.pop();
        beneficiaryIndex[_wallet] = 0;

        emit BeneficiaryRemoved(_wallet);
    }

    // update share for an existing beneficiary
    function updateShare(address _wallet, uint256 _newShare) external onlyOwner notLocked {
        require(_newShare > 0, "Share must > 0");
        uint256 idx = beneficiaryIndex[_wallet];
        require(idx != 0, "Not beneficiary");
        uint256 arrayIndex = idx - 1;

        uint256 oldShare = beneficiaries[arrayIndex].share;
        // adjust totalShares safely
        if (_newShare > oldShare) {
            require(totalShares + (_newShare - oldShare) <= 10000, "Total shares exceed 10000");
        }
        totalShares = totalShares + _newShare - oldShare;
        beneficiaries[arrayIndex].share = _newShare;

        emit BeneficiaryUpdated(_wallet, _newShare);
    }

    // set distribution interval (seconds)
    function setDistributionInterval(uint256 _interval) external onlyOwner notLocked {
        require(_interval > 0, "Invalid interval");
        distributionInterval = _interval;
        emit IntervalChanged(_interval);
    }

    // pause/resume distribution (controls distribute* functions)
    function setPaused(bool _paused) external onlyOwner notLocked {
        isPaused = _paused;
        emit Paused(_paused);
    }

    // -------------------------
    // Locking -> 完全去中心化
    // -------------------------
    // 锁定合约：要求 totalShares == 10000（100% 已分配），然后 renounceOwnership() 并设置 isLocked = true。
    // 一旦锁定，任何修改函数、紧急取回都不可再调用（完全不可更改）
    function lockContract() external onlyOwner notLocked {
        require(totalShares == 10000, "Total shares must equal 10000");
        isLocked = true;
        // 放弃 owner 权限 (Ownable)
        renounceOwnership();
        emit ContractLocked(block.timestamp);
    }

    // -------------------------
    // Funding functions (任何人可充值)
    // -------------------------
    function fundUSDT(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must > 0");
        usdt.safeTransferFrom(msg.sender, address(this), amount);
    }

    function fundWETH(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must > 0");
        weth.safeTransferFrom(msg.sender, address(this), amount);
    }

    // -------------------------
    // Distribution (anyone可触发)，分发按当前合约余额按 share 比例分配
    // - 每个受益人通过 lastClaimXXX 控制频率，避免重复发放同一期
    // - 为避免循环内 balance 每次递减影响后续计算，使用 snapshotBalance 作为基数
    // -------------------------
    function distributeUSDT() external notPaused nonReentrant {
        _distributeToken(usdt, true);
    }

    function distributeWETH() external notPaused nonReentrant {
        _distributeToken(weth, false);
    }

    // 一次发两种币（可选）
    function distributeAll() external notPaused nonReentrant {
        _distributeToken(usdt, true);
        _distributeToken(weth, false);
    }

    function _distributeToken(IERC20 token, bool isUSDT) internal {
        uint256 len = beneficiaries.length;
        require(len > 0, "No beneficiaries");

        uint256 snapshot = token.balanceOf(address(this));
        require(snapshot > 0, "No funds for token");

        for (uint256 i = 0; i < len; i++) {
            Beneficiary storage b = beneficiaries[i];
            uint256 lastClaim = isUSDT ? b.lastClaimUSDT : b.lastClaimWETH;

            if (block.timestamp >= lastClaim + distributionInterval) {
                // amount based on snapshot and share
                uint256 amount = (snapshot * b.share) / 10000;
                if (amount > 0) {
                    token.safeTransfer(b.wallet, amount);
                    if (isUSDT) b.lastClaimUSDT = block.timestamp;
                    else b.lastClaimWETH = block.timestamp;
                    emit FundsDistributed(b.wallet, address(token), amount);
                }
            }
        }
    }

    // -------------------------
    // Emergency withdraw (ONLY allowed while NOT LOCKED)
    // -------------------------
    // 为了去中心化和资金不可挪用，一旦锁定，任何紧急取回都会被禁止。
    function emergencyWithdraw(IERC20 token, uint256 amount, address to) external onlyOwner notLocked nonReentrant {
        require(to != address(0), "Invalid to");
        token.safeTransfer(to, amount);
    }

    // -------------------------
    // View helpers
    // -------------------------
    function getBeneficiaryCount() external view returns (uint256) {
        return beneficiaries.length;
    }

    function getBeneficiary(uint256 idx) external view returns (address wallet, uint256 share, uint256 lastClaimUSDT, uint256 lastClaimWETH) {
        require(idx < beneficiaries.length, "Index OOB");
        Beneficiary storage b = beneficiaries[idx];
        return (b.wallet, b.share, b.lastClaimUSDT, b.lastClaimWETH);
    }

    function isBeneficiaryAddress(address who) external view returns (bool) {
        return beneficiaryIndex[who] != 0;
    }

    // returns totalShares (should be 10000 to lock)
    function getTotalShares() external view returns (uint256) {
        return totalShares;
    }
}

