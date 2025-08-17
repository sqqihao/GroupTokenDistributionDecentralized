import { useEffect, useState } from 'react'
import { getContract, getProvider } from '../lib/eth'

export default function ReadPanel({ address, refreshFlag }) {
  const [count, setCount] = useState(0)
  const [list, setList] = useState([])
  const [queryAddr, setQueryAddr] = useState('')
  const [queryRes, setQueryRes] = useState(null)

  useEffect(() => { load() }, [address, refreshFlag])

  async function load() {
    try {
      const c = getContract(address, getProvider())
      const cnt = await c.beneficiariesCount()
      setCount(Number(cnt))
      const end = Math.min(Number(cnt), 200)
      const items = []
      for (let i = 0; i < end; i++) {
        const r = await c.getBeneficiaryByIndex(i)
        items.push({ idx: i, wallet: r[0], share: Number(r[1]), lastUSDT: Number(r[2]), lastWETH: Number(r[3]) })
      }
      setList(items)
    } catch (e) { console.error(e) }
  }

  async function doQuery() {
    try {
      const c = getContract(address, getProvider())
      const r = await c.getBeneficiary(queryAddr)
      setQueryRes({ share: Number(r[0]), lastUSDT: Number(r[1]), lastWETH: Number(r[2]), exists: Boolean(r[3]) })
    } catch (e) { alert(e.message || String(e)) }
  }

  return (
    <div className="rounded-2xl bg-white shadow p-4 space-y-4">
      <div className="font-semibold">只读信息</div>
      <div className="text-sm text-gray-700">总受益人数：{count}</div>

      <div className="grid md:grid-cols-3 gap-3">
        <div className="md:col-span-2">
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead><tr className="text-left border-b">
                <th className="py-2 pr-4">#</th><th className="py-2 pr-4">wallet</th>
                <th className="py-2 pr-4">share</th><th className="py-2 pr-4">lastUSDT</th><th className="py-2 pr-4">lastWETH</th>
              </tr></thead>
              <tbody>
              {list.map((x)=>(
                <tr key={x.idx} className="border-b">
                  <td className="py-2 pr-4">{x.idx}</td>
                  <td className="py-2 pr-4 font-mono">{x.wallet}</td>
                  <td className="py-2 pr-4">{x.share}</td>
                  <td className="py-2 pr-4">{x.lastUSDT}</td>
                  <td className="py-2 pr-4">{x.lastWETH}</td>
                </tr>
              ))}
              {list.length===0 && <tr><td className="py-3 text-gray-500" colSpan="5">暂无数据</td></tr>}
              </tbody>
            </table>
          </div>
        </div>

        <div className="space-y-2">
          <label className="block text-sm text-gray-600">getBeneficiary(address)</label>
          <input value={queryAddr} onChange={e=>setQueryAddr(e.target.value)} placeholder="0x..." className="w-full border rounded-xl px-3 py-2"/>
          <button onClick={doQuery} className="px-3 py-2 rounded-xl bg-black text-white w-full">查询</button>
          {queryRes && (
            <div className="text-xs bg-gray-50 rounded-xl p-2 space-y-1">
              <div>share: {queryRes.share}</div>
              <div>lastClaimUSDT: {queryRes.lastUSDT}</div>
              <div>lastClaimWETH: {queryRes.lastWETH}</div>
              <div>exists: {String(queryRes.exists)}</div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
