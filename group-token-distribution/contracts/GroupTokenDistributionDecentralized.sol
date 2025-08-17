// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GroupTokenDistributionDecentralized is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Beneficiary {
        uint256 share;            // 万分比（总份额为 10000）
        uint256 lastClaimUSDT;    // 最近一次领取 USDT 时间戳
        uint256 lastClaimWETH;    // 最近一次领取 WETH 时间戳
        bool exists;              // 是否为有效用户
    }

    IERC20 public immutable usdt;
    IERC20 public immutable weth;

    address[] private beneficiaryList;                     // 受益人地址列表（用于遍历）
    mapping(address => Beneficiary) private beneficiaries;  // 受益人数据映射
    uint256 public totalShares;                             // 当前总份额
    uint256 public distributionInterval;                    // 发放时间间隔（秒）
    bool public isPaused;                                   // 是否暂停发放
    bool public isLocked;                                   // 是否锁定配置

    event BeneficiaryAdded(address indexed wallet, uint256 share);
    event BeneficiaryRemoved(address indexed wallet, uint256 oldShare);
    event BeneficiaryUpdated(address indexed wallet, uint256 oldShare, uint256 newShare);
    event FundsDistributed(address indexed wallet, address indexed token, uint256 amount);
    event Paused(bool paused);
    event IntervalChanged(uint256 newInterval);
    event ContractLocked();

    modifier notLocked() {
        require(!isLocked, "Contract is locked");
        _;
    }

    modifier notPaused() {
        require(!isPaused, "Distribution paused");
        _;
    }

    constructor(address _usdt, address _weth, uint256 _interval) Ownable(msg.sender) {
        require(_usdt != address(0) && _weth != address(0), "Invalid token");
        require(_interval > 0, "Invalid interval");
        usdt = IERC20(_usdt);
        weth = IERC20(_weth);
        distributionInterval = _interval;
    }

    // -----------------------
    // 配置相关
    // -----------------------

    /// @notice 添加新的受益人
    /// @param _wallet 受益人地址
    /// @param _share 分配份额（万分比）
    function addBeneficiary(address _wallet, uint256 _share) external onlyOwner notLocked {
        require(_wallet != address(0), "Invalid wallet");
        require(_share > 0, "Share must > 0");
        require(totalShares + _share <= 10000, "Total shares exceed 10000");
        require(!beneficiaries[_wallet].exists, "Beneficiary exists");

        beneficiaries[_wallet] = Beneficiary({
            share: _share,
            lastClaimUSDT: 0,
            lastClaimWETH: 0,
            exists: true
        });

        beneficiaryList.push(_wallet);
        totalShares += _share;

        emit BeneficiaryAdded(_wallet, _share);
    }

    /// @notice 移除受益人
    /// @param _wallet 受益人地址
    function removeBeneficiary(address _wallet) external onlyOwner notLocked {
        require(beneficiaries[_wallet].exists, "Not found");

        uint256 removedShare = beneficiaries[_wallet].share;
        totalShares -= removedShare;

        delete beneficiaries[_wallet];

        // 从数组中移除该地址（顺序不保留）
        for (uint256 i = 0; i < beneficiaryList.length; i++) {
            if (beneficiaryList[i] == _wallet) {
                beneficiaryList[i] = beneficiaryList[beneficiaryList.length - 1];
                beneficiaryList.pop();
                break;
            }
        }

        emit BeneficiaryRemoved(_wallet, removedShare);
    }

    /// @notice 更新受益人的分配份额
    /// @param _wallet 受益人地址
    /// @param _share 新份额（万分比）
    function updateShare(address _wallet, uint256 _share) external onlyOwner notLocked {
        require(beneficiaries[_wallet].exists, "Not found");
        require(_share > 0, "Share must > 0");

        uint256 old = beneficiaries[_wallet].share;
        if (_share > old) {
            require(totalShares + (_share - old) <= 10000, "Total shares exceed 10000");
            totalShares += (_share - old);
        } else {
            totalShares -= (old - _share);
        }

        beneficiaries[_wallet].share = _share;
        emit BeneficiaryUpdated(_wallet, old, _share);
    }

    /// @notice 设置发放间隔时间
    /// @param _interval 间隔秒数
    function setDistributionInterval(uint256 _interval) external onlyOwner notLocked {
        require(_interval > 0, "Invalid interval");
        distributionInterval = _interval;
        emit IntervalChanged(_interval);
    }

    /// @notice 暂停或恢复发放
    /// @param _paused true=暂停，false=恢复
    function setPaused(bool _paused) external onlyOwner notLocked {
        isPaused = _paused;
        emit Paused(_paused);
    }

    /// @notice 锁定合约配置，无法再修改
    /// @param requireFull10000 是否要求总份额必须为10000
    function lockContract(bool requireFull10000) external onlyOwner notLocked {
        if (requireFull10000) {
            require(totalShares == 10000, "totalShares must be 10000");
        }
        isLocked = true;
        emit ContractLocked();
    }

    /// @notice 批量发放 USDT（全员）
    function distributeUSDT() external notPaused nonReentrant {
        _distributeToken(usdt, true, 0, beneficiaryList.length,false, address(0));
    }

    /// @notice 批量发放 WETH（全员）
    function distributeWETH() external notPaused nonReentrant {
        _distributeToken(weth, false, 0, beneficiaryList.length,false, address(0));
    }

    /*
    /// @notice 批量发放 USDT（指定范围）
    /// @param start 起始索引
    /// @param endExclusive 结束索引（不包含）
    function distributeRangeUSDT(uint256 start, uint256 endExclusive) external notPaused nonReentrant {
        _distributeToken(usdt, true, start, endExclusive,false, address(0));
    }

    /// @notice 批量发放 WETH（指定范围）
    /// @param start 起始索引
    /// @param endExclusive 结束索引（不包含）
    function distributeRangeWETH(uint256 start, uint256 endExclusive) external notPaused nonReentrant {
        _distributeToken(weth, false, start, endExclusive,false, address(0));
    }
    */


    /// @dev 内部函数，执行代币分发逻辑
    function _distributeToken(
        IERC20 token,
        bool isUSDTToken,
        uint256 start,
        uint256 endExclusive,
        bool singleUser,
        address singleWallet
    ) internal {
        uint256 len = beneficiaryList.length;
        if (!singleUser) {
            require(len > 0, "No beneficiaries");
            require(start < endExclusive && endExclusive <= len, "Bad range");
        }

        uint256 snapshot = token.balanceOf(address(this));

        require(snapshot > 0, "No funds");

        if (singleUser) {
            Beneficiary storage b = beneficiaries[singleWallet];
            require(b.exists, "Not a beneficiary");

            uint256 last = isUSDTToken ? b.lastClaimUSDT : b.lastClaimWETH;
            require(last == 0 || block.timestamp >= last + distributionInterval, "Too soon to claim");
            uint256 amount = (snapshot * b.share) / 10000;
            require(amount > 0, "Amount zero");

            _distributeToUser(token, isUSDTToken, singleWallet, amount);
        } else {
            for (uint256 i = start; i < endExclusive; ) {
                address wallet = beneficiaryList[i];
                Beneficiary storage b = beneficiaries[wallet];
                uint256 amount = (snapshot * b.share) / 10000;
                uint256 last = isUSDTToken ? b.lastClaimUSDT : b.lastClaimWETH;

                if (last == 0 || block.timestamp >= last + distributionInterval) {
                    if (amount > 0) {
                        _distributeToUser(token, isUSDTToken, wallet, amount);
                    }
                }
                unchecked { ++i; }
            }
        }
    }

    function distributeToUser(address userAddr) external nonReentrant notPaused {
        // require(tokenAddr == address(usdt) || tokenAddr == address(weth), "Invalid token");
        //_distributeToken(IERC20(tokenAddr), tokenAddr == address(usdt), 0, 0, true, msg.sender);
        _distributeToken(usdt, true, 0, beneficiaryList.length, true, userAddr);
        _distributeToken(weth, false, 0, beneficiaryList.length, true, userAddr);

    }


    /// @dev 私有函数：向单个地址转账、更新最后领取时间并发出事件
    /// @param token 要发放的代币
    /// @param isUSDTToken 是否是 USDT（true=USDT，false=WETH）
    /// @param wallet 收款地址（应为受益人列表中的地址）
    /// @param amount 本次应发放的数量（已按份额计算完毕）
    function _distributeToUser(IERC20 token, bool isUSDTToken, address wallet, uint256 amount) private {
        token.safeTransfer(wallet, amount);
        if (isUSDTToken) {
            beneficiaries[wallet].lastClaimUSDT = block.timestamp;
        } else {
            beneficiaries[wallet].lastClaimWETH = block.timestamp;
        }
        emit FundsDistributed(wallet, address(token), amount);
    }

    // -----------------------
    // 只读方法
    // -----------------------

    /// @notice 获取受益人数量
    function beneficiariesCount() external view returns (uint256) {
        return beneficiaryList.length;
    }

    /// @notice 获取受益人信息（通过地址）
    function getBeneficiary(address wallet) external view returns (
        uint256 share,
        uint256 lastClaimUSDT,
        uint256 lastClaimWETH,
        bool exists
    ) {
        Beneficiary storage b = beneficiaries[wallet];
        return (b.share, b.lastClaimUSDT, b.lastClaimWETH, b.exists);
    }

    /// @notice 获取受益人信息（通过索引）
    function getBeneficiaryByIndex(uint256 index) external view returns (
        address wallet,
        uint256 share,
        uint256 lastClaimUSDT,
        uint256 lastClaimWETH
    ) {
        require(index < beneficiaryList.length, "Index OOB");
        wallet = beneficiaryList[index];
        Beneficiary storage b = beneficiaries[wallet];
        return (wallet, b.share, b.lastClaimUSDT, b.lastClaimWETH);
    }
}

//alice :  0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
//bob   :  0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db