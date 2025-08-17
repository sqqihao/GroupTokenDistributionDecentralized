import { useState } from 'react'
import { getSigner, getContract } from '../lib/eth'

function Field({ label, value, onChange, placeholder='' }) {
  return (
    <div>
      <label className="block text-sm text-gray-600 mb-1">{label}</label>
      <input value={value} onChange={e=>onChange(e.target.value)} placeholder={placeholder} className="w-full px-3 py-2 border rounded-xl"/>
    </div>
  )
}

export default function OwnerPanel({ address, onDone }) {
  const [addWallet, setAddWallet] = useState('')
  const [addShare, setAddShare] = useState('')
  const [rmWallet, setRmWallet] = useState('')
  const [updWallet, setUpdWallet] = useState('')
  const [updShare, setUpdShare] = useState('')
  const [interval, setInterval] = useState('')
  const [paused, setPaused] = useState(false)
  const [requireFull, setRequireFull] = useState(false)

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
      <div className="font-semibold">Owner 操作</div>
      <div className="grid md:grid-cols-3 gap-4">
        <Field label="addBeneficiary.wallet" value={addWallet} onChange={setAddWallet} placeholder="0x..." />
        <Field label="addBeneficiary.share(万分比)" value={addShare} onChange={setAddShare} placeholder="100"/>
        <div className="flex items-end"><button onClick={()=>call('addBeneficiary', addWallet, BigInt(addShare||'0'))} className="px-4 py-2 rounded-xl bg-black text-white w-full">addBeneficiary</button></div>

        <Field label="removeBeneficiary.wallet" value={rmWallet} onChange={setRmWallet} placeholder="0x..." />
        <div className="flex items-end"><button onClick={()=>call('removeBeneficiary', rmWallet)} className="px-4 py-2 rounded-xl bg-black text-white w-full">removeBeneficiary</button></div>

        <Field label="updateShare.wallet" value={updWallet} onChange={setUpdWallet} placeholder="0x..." />
        <Field label="updateShare.share(万分比)" value={updShare} onChange={setUpdShare} placeholder="100"/>
        <div className="flex items-end"><button onClick={()=>call('updateShare', updWallet, BigInt(updShare||'0'))} className="px-4 py-2 rounded-xl bg-black text-white w-full">updateShare</button></div>

        <Field label="setDistributionInterval(秒)" value={interval} onChange={setInterval} placeholder="86400"/>
        <div className="flex items-end"><button onClick={()=>call('setDistributionInterval', BigInt(interval||'0'))} className="px-4 py-2 rounded-xl bg-black text-white w-full">setDistributionInterval</button></div>

        <div className="flex items-center gap-2">
          <input id="paused" type="checkbox" checked={paused} onChange={e=>setPaused(e.target.checked)} />
          <label htmlFor="paused">setPaused 值</label>
        </div>
        <div className="flex items-end"><button onClick={()=>call('setPaused', paused)} className="px-4 py-2 rounded-xl bg-black text-white w-full">setPaused</button></div>

        <div className="flex items-center gap-2">
          <input id="requireFull" type="checkbox" checked={requireFull} onChange={e=>setRequireFull(e.target.checked)} />
          <label htmlFor="requireFull">lockContract.requireFull10000</label>
        </div>
        <div className="flex items-end"><button onClick={()=>call('lockContract', requireFull)} className="px-4 py-2 rounded-xl bg-black text-white w-full">lockContract</button></div>
      </div>
    </div>
  )
}
