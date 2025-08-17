// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GroupUSDTDistribution is Ownable, ReentrancyGuard {
    IERC20 public immutable usdt;

    struct Beneficiary {
        address wallet;
        uint256 share; // 按万分比（10000 = 100%）
        uint256 lastClaim;
    }

    Beneficiary[] public beneficiaries;
    mapping(address => bool) public isBeneficiary;

    uint256 public distributionInterval; // 例如 30 天
    bool public isPaused;

    event BeneficiaryAdded(address indexed wallet, uint256 share);
    event BeneficiaryRemoved(address indexed wallet);
    event BeneficiaryUpdated(address indexed wallet, uint256 newShare);
    event FundsDistributed(address indexed wallet, uint256 amount);
    event Paused(bool paused);
    event IntervalChanged(uint256 newInterval);

    constructor(address _usdt, uint256 _distributionInterval) {
        require(_usdt != address(0), "Invalid USDT address");
        require(_distributionInterval > 0, "Invalid interval");
        usdt = IERC20(_usdt);
        distributionInterval = _distributionInterval;
        isPaused = false;
    }

    modifier notPaused() {
        require(!isPaused, "Distribution is paused");
        _;
    }

    // 添加受益人
    function addBeneficiary(address _wallet, uint256 _share) external onlyOwner {
        require(_wallet != address(0), "Invalid wallet");
        require(!isBeneficiary[_wallet], "Already a beneficiary");
        require(_share > 0, "Share must be > 0");

        beneficiaries.push(Beneficiary({
            wallet: _wallet,
            share: _share,
            lastClaim: block.timestamp
        }));

        isBeneficiary[_wallet] = true;
        emit BeneficiaryAdded(_wallet, _share);
    }

    // 删除受益人
    function removeBeneficiary(address _wallet) external onlyOwner {
        require(isBeneficiary[_wallet], "Not a beneficiary");

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i].wallet == _wallet) {
                beneficiaries[i] = beneficiaries[beneficiaries.length - 1];
                beneficiaries.pop();
                break;
            }
        }

        isBeneficiary[_wallet] = false;
        emit BeneficiaryRemoved(_wallet);
    }

    // 更新受益人比例
    function updateShare(address _wallet, uint256 _newShare) external onlyOwner {
        require(isBeneficiary[_wallet], "Not a beneficiary");
        require(_newShare > 0, "Share must be > 0");

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i].wallet == _wallet) {
                beneficiaries[i].share = _newShare;
                emit BeneficiaryUpdated(_wallet, _newShare);
                break;
            }
        }
    }

    // 修改发放间隔
    function setDistributionInterval(uint256 _interval) external onlyOwner {
        require(_interval > 0, "Invalid interval");
        distributionInterval = _interval;
        emit IntervalChanged(_interval);
    }

    // 暂停/恢复
    function setPaused(bool _paused) external onlyOwner {
        isPaused = _paused;
        emit Paused(_paused);
    }

    // 自动发放 USDT（可手动调用）
    function distribute() external notPaused nonReentrant {
        require(beneficiaries.length > 0, "No beneficiaries");
        uint256 contractBalance = usdt.balanceOf(address(this));
        require(contractBalance > 0, "No funds");

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            Beneficiary storage b = beneficiaries[i];

            if (block.timestamp >= b.lastClaim + distributionInterval) {
                uint256 amount = (contractBalance * b.share) / 10000;
                if (amount > 0) {
                    require(usdt.transfer(b.wallet, amount), "Transfer failed");
                    b.lastClaim = block.timestamp;
                    emit FundsDistributed(b.wallet, amount);
                }
            }
        }
    }

    // owner 存 USDT 到合约
    function fund(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(usdt.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    // 紧急取回
    function emergencyWithdraw(uint256 amount, address to) external onlyOwner {
        require(usdt.transfer(to, amount), "Withdraw failed");
    }

    // 查询受益人数量
    function getBeneficiaryCount() external view returns (uint256) {
        return beneficiaries.length;
    }
}
