// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GroupTokenDistributionDecentralized is Ownable {
    struct Beneficiary {
        address wallet;
        uint256 share; // 万分比
        uint256 lastClaim;
    }

    IERC20 public usdt;
    IERC20 public weth;
    Beneficiary[] public beneficiaries;
    uint256 public distributionInterval;
    bool public isPaused;
    bool public isLocked;

    event FundsDistributed(address indexed beneficiary, address token, uint256 amount);
    event ContractLocked();

    modifier notLocked() {
        require(!isLocked, "Contract is locked");
        _;
    }

    constructor(address _usdt, address _weth, uint256 _interval) Ownable(msg.sender) {
        usdt = IERC20(_usdt);
        weth = IERC20(_weth);
        distributionInterval = _interval;
    }

    function addBeneficiary(address _wallet, uint256 _share) external onlyOwner notLocked {
        beneficiaries.push(Beneficiary(_wallet, _share, 0));
    }

    function removeBeneficiary(uint256 index) external onlyOwner notLocked {
        require(index < beneficiaries.length, "Invalid index");
        beneficiaries[index] = beneficiaries[beneficiaries.length - 1];
        beneficiaries.pop();
    }

    function updateShare(uint256 index, uint256 _share) external onlyOwner notLocked {
        require(index < beneficiaries.length, "Invalid index");
        beneficiaries[index].share = _share;
    }

    function setDistributionInterval(uint256 _interval) external onlyOwner notLocked {
        distributionInterval = _interval;
    }

    function setPaused(bool _paused) external onlyOwner notLocked {
        isPaused = _paused;
    }

    function lockContract() external onlyOwner notLocked {
        isLocked = true;
        emit ContractLocked();
    }

    function distributeUSDT() external {
        _distribute(usdt);
    }

    function distributeWETH() external {
        _distribute(weth);
    }

    function _distribute(IERC20 token) internal {
        require(!isPaused, "Distribution paused");

        uint256 contractBalance = token.balanceOf(address(this));
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            Beneficiary storage b = beneficiaries[i];
            
            // 第一次直接发放，之后才按间隔
            if (b.lastClaim == 0 || block.timestamp >= b.lastClaim + distributionInterval) {
                uint256 amount = (contractBalance * b.share) / 10000;
                if (amount > 0) {
                    require(token.transfer(b.wallet, amount), "Transfer failed");
                    b.lastClaim = block.timestamp;
                    emit FundsDistributed(b.wallet, address(token), amount);
                }
            }
        }
    }

    function beneficiariesCount() external view returns (uint256) {
        return beneficiaries.length;
    }
}
