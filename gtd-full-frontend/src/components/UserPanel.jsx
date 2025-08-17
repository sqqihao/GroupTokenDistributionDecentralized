import { useState } from 'react'
import { getSigner, getContract } from '../lib/eth'

export default function UserPanel({ address, onDone }) {
  const [user, setUser] = useState('')

  async function call(fn, ...args) {
    try {
      const signer = await getSigner()
      const c = getContract(address, signer)
      const tx = await c[fn](...args)
      await tx.wait()
      onDone?.()
      alert('成功：' + fn)
    } catch (e) { alert(e.message || String(e)) }
  }

  return (
    <div className="rounded-2xl bg-white shadow p-4 space-y-4">
      <div className="font-semibold">用户操作</div>
      <div className="grid md:grid-cols-3 gap-4">
        <div className="flex items-end"><button onClick={()=>call('distributeUSDT')} className="px-4 py-2 rounded-xl bg-black text-white w-full">distributeUSDT</button></div>
        <div className="flex items-end"><button onClick={()=>call('distributeWETH')} className="px-4 py-2 rounded-xl bg-black text-white w-full">distributeWETH</button></div>
        <div>
          <label className="block text-sm text-gray-600 mb-1">distributeToUser.user</label>
          <input value={user} onChange={e=>setUser(e.target.value)} className="w-full px-3 py-2 border rounded-xl" placeholder="0x..."/>
        </div>
        <div className="flex items-end"><button onClick={()=>call('distributeToUser', user)} className="px-4 py-2 rounded-xl bg-black text-white w-full">distributeToUser</button></div>
      </div>
    </div>
  )
}
