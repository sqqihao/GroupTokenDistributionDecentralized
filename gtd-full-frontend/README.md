# Group Token Distributor dApp (Full)

功能：
- 部署合约（上传 Hardhat artifact：abi+bytecode）
- 加载合约（自动识别是否为 owner）
  - Owner：addBeneficiary / removeBeneficiary / updateShare / setDistributionInterval / setPaused / lockContract
  - 普通用户：distributeUSDT / distributeWETH / distributeToUser
  - 只读：beneficiariesCount / getBeneficiary / getBeneficiaryByIndex（列表展示前 200 条 + 单地址查询）

## 启动
```bash
npm install
cp .env.example .env   # 可选：设置默认链ID和默认合约地址
npm run dev
```

> 所有写操作需连接钱包；部署需上传包含 `abi` 和 `bytecode` 的 JSON，然后填写 USDT/WETH 地址与分发间隔。
