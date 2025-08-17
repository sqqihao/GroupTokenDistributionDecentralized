import { useState } from 'react'
import { ethers } from 'ethers'
import { getSigner } from '../lib/eth'
import GroupTokenDistributionDecentralized from "../abi/GroupTokenDistributionDecentralized.json"; // 完整 ABI + bytecode

export default function DeployContract() {
  const [usdt, setUsdt] = useState('0xe5bd85ae7726a17bf445fe498c9b855574a4c4ad')
  const [weth, setWeth] = useState('0x21343dbd0ed437293b64257225e57bb6debe8b61')
  const [interval, setInterval] = useState(60)
  // const [artifact, setArtifact] = useState(null)
  const [deploying, setDeploying] = useState(false)
  const [addr, setAddr] = useState(localStorage.getItem('gtd_contract')||'')

  // setArtifact(GroupTokenDistributionDecentralized)
  /*
  function onFile(e) {
    const f = e.target.files?.[0]
    if (!f) return
    const reader = new FileReader()
    reader.onload = () => {
      try {
        const json = JSON.parse(reader.result)
        if (!json.abi || !json.bytecode) throw new Error('JSON 必须包含 abi 和 bytecode')
        setArtifact(json)
      } catch (err) { alert('解析失败: '+err.message) }
    }
    reader.readAsText(f)
  }
  */

  async function deploy() {
    try {
      // if (!artifact) return alert('请先上传 Hardhat 生成的 JSON（含 abi + bytecode）')
      if (!ethers.isAddress(usdt) || !ethers.isAddress(weth)) return alert('USDT/WETH 地址不合法')
      if (Number(interval) <= 0) return alert('间隔必须 > 0')
      setDeploying(true)
      const signer = await getSigner()
      const factory = new ethers.ContractFactory(GroupTokenDistributionDecentralized.abi, GroupTokenDistributionDecentralized.bytecode, signer)
      const contract = await factory.deploy(usdt, weth, BigInt(interval))
      await contract.waitForDeployment()
      setAddr(contract.target)
      localStorage.setItem('gtd_contract', contract.target)
      alert('部署成功: '+contract.target)
    } catch(e) {
      console.error(e); alert(e.message || String(e))
    } finally { setDeploying(false) }
  }

  return (
    <div className="space-y-4">
      <div className="rounded-2xl bg-white shadow p-4 grid md:grid-cols-3 gap-4">
        <div><label className="text-sm text-gray-600">USDT 地址</label><input value={usdt} onChange={e=>setUsdt(e.target.value)} className="w-full border rounded-xl px-3 py-2" placeholder="0x..."/></div>
        <div><label className="text-sm text-gray-600">WETH 地址</label><input value={weth} onChange={e=>setWeth(e.target.value)} className="w-full border rounded-xl px-3 py-2" placeholder="0x..."/></div>
        <div><label className="text-sm text-gray-600">分发间隔(秒)</label><input type="number" value={interval} onChange={e=>setInterval(e.target.value)} className="w-full border rounded-xl px-3 py-2"/></div>
        <div className="md:col-span-3"><button onClick={deploy} disabled={deploying} className="px-4 py-2 rounded-xl bg-black text-white">{deploying?'部署中...':'部署合约'}</button></div>
        {addr && <div className="md:col-span-3 text-sm">✅ 最近部署/缓存：{addr}</div>}
      </div>
    </div>
  )
}
