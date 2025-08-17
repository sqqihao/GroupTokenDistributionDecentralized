import { useEffect, useMemo, useState } from 'react'
import { ethers } from 'ethers'
import { getProvider, getSigner, getContract } from '../lib/eth'
import OwnerPanel from './OwnerPanel'
import UserPanel from './UserPanel'
import ReadPanel from './ReadPanel'

function Row({ label, children }) {
  return (
    <div className="flex items-center justify-between py-2 border-b last:border-b-0">
      <div className="text-gray-600">{label}</div>
      <div className="font-mono">{children}</div>
    </div>
  )
}

export default function ContractPanel() {
  const [addr, setAddr] = useState(localStorage.getItem('gtd_contract') || (import.meta.env.VITE_DEFAULT_CONTRACT || ''))
  const [isOwner, setIsOwner] = useState(false)
  const [owner, setOwner] = useState('')
  const [stats, setStats] = useState({ totalShares:'-', interval:'-', paused:'-', locked:'-', usdt:'-', weth:'-' })
  const [refreshFlag, setRefreshFlag] = useState(0)
  const valid = useMemo(() => ethers.isAddress(addr), [addr])

  useEffect(() => {
    if (!valid) return
    localStorage.setItem('gtd_contract', addr || "0x1bac3c4b370504f789e33a34cc6dc066f5661a7d");
    refresh()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [addr])

  async function refresh() {
    try {
      const c = getContract(addr, getProvider())
      // console.log(await c.totalShares())
      
      const [o, total, interval, paused, locked, usdt, weth] = await Promise.all([
        c.owner(), c.totalShares(), c.distributionInterval(), c.isPaused(), c.isLocked(), c.usdt(), c.weth()
      ])
      setOwner(o)
      setStats({ totalShares:String(total), interval:String(interval), paused:String(paused), locked:String(locked), usdt, weth })
      
      try {
        const signer = await getSigner()
        const me = await signer.getAddress()
        setIsOwner(me.toLowerCase() === o.toLowerCase())
      } catch {}
      setRefreshFlag(x=>x+1)
    } catch (e) { console.error(e) }
  }

  return (
    <div className="space-y-6">
      <div className="rounded-2xl bg-white shadow p-4 flex items-center gap-3">
        <input value={addr} onChange={e=>setAddr(e.target.value)} className="flex-1 px-3 py-2 border rounded-xl" placeholder="合约地址 0x..." />
        <button onClick={refresh} className="px-4 py-2 rounded-xl bg-black text-white">加载</button>
      </div>

      {valid && (
        <div className="grid md:grid-cols-3 gap-6">
          <div className="rounded-2xl bg-white shadow p-4">
            <div className="font-semibold mb-2">合约信息</div>
            <Row label="owner">{owner}</Row>
            <Row label="USDT">{stats.usdt}</Row>
            <Row label="WETH">{stats.weth}</Row>
            <Row label="totalShares">{stats.totalShares}</Row>
            <Row label="interval">{stats.interval}s</Row>
            <Row label="paused">{String(stats.paused)}</Row>
            <Row label="locked">{String(stats.locked)}</Row>
            <div className="text-xs text-gray-500 mt-2">我是 Owner? {String(isOwner)}</div>
          </div>

          <div className="md:col-span-2">
            <ReadPanel address={addr} refreshFlag={refreshFlag}/>
          </div>
        </div>
      )}

      {valid && (isOwner ? <OwnerPanel address={addr} onDone={refresh}/> : <UserPanel address={addr} onDone={refresh}/>)}
    </div>
  )
}
