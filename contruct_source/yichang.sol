// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InheritanceTrust {
    // USDT 合约地址（以太坊主网）
    address public constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    IERC20 public usdt = IERC20(USDT_ADDRESS);

    // 受益人结构
    struct Beneficiary {
        address wallet;     // 受益人钱包地址
        uint256 share;      // 份额（如 100 = 1%）
        uint256 lastClaim;  // 上次领取时间
    }

    address public owner;          // 合约所有者（设立人）
    address public guardian;        // 监管人（可紧急暂停）
    uint256 public distributionInterval; // 发放间隔（秒，如 30天 = 2592000）
    bool public isPaused;           // 是否暂停发放

    Beneficiary[] public beneficiaries; // 受益人列表

    event FundsDistributed(address beneficiary, uint256 amount);
    event ContractPaused(bool isPaused);

    constructor(address[] memory _wallets, uint256[] memory _shares, uint256 _interval, address _guardian) {
        require(_wallets.length == _shares.length, "Invalid input");
        owner = msg.sender;
        guardian = _guardian;
        distributionInterval = _interval;

        // 初始化受益人
        for (uint256 i = 0; i < _wallets.length; i++) {
            beneficiaries.push(Beneficiary({
                wallet: _wallets[i],
                share: _shares[i],
                lastClaim: block.timestamp
            }));
        }
    }

    // 仅所有者可存入 USDT
    function depositUSDT(uint256 amount) external {
        require(msg.sender == owner, "Only owner can deposit");
        require(usdt.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    // 自动发放 USDT
    function distribute() external {
        require(!isPaused, "Distribution is paused");
        
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            Beneficiary storage b = beneficiaries[i];
            
            // 检查是否到发放时间
            if (block.timestamp >= b.lastClaim + distributionInterval) {
                uint256 contractBalance = usdt.balanceOf(address(this));
                uint256 amount = (contractBalance * b.share) / 10000; // 按比例计算
                
                if (amount > 0) {
                    require(usdt.transfer(b.wallet, amount), "Transfer failed");
                    b.lastClaim = block.timestamp;
                    emit FundsDistributed(b.wallet, amount);
                }
            }
        }
    }

    // 监管人可暂停合约（如发现漏洞）
    function pauseDistribution(bool _pause) external {
        require(msg.sender == guardian, "Only guardian can pause");
        isPaused = _pause;
        emit ContractPaused(_pause);
    }

    // 所有者或监管人可提取剩余资金（紧急情况）
    function withdrawRemainingUSDT(address to) external {
        require(msg.sender == owner || msg.sender == guardian, "Not authorized");
        uint256 balance = usdt.balanceOf(address(this));
        require(usdt.transfer(to, balance), "Transfer failed");
    }
}