import { useState } from 'react'
import ConnectWallet from './components/ConnectWallet.jsx'
import DeployContract from './components/DeployContract.jsx'
import ContractPanel from './components/ContractPanel.jsx'

const expected = Number(import.meta.env.VITE_EXPECTED_CHAIN_ID || 11155111)

export default function App() {
  const [tab, setTab] = useState('deploy')

  return (
    <div className="max-w-6xl mx-auto p-6 space-y-6">
      <header className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Group Token Distributor dApp</h1>
        <ConnectWallet expectedChainId={expected} />
      </header>

      <div className="flex gap-3">
        <button onClick={()=>setTab('deploy')} className={`px-4 py-2 rounded-xl shadow ${tab==='deploy'?'bg-blue-600 text-white':'bg-gray-200'}`}>部署合约</button>
        <button onClick={()=>setTab('panel')} className={`px-4 py-2 rounded-xl shadow ${tab==='panel'?'bg-blue-600 text-white':'bg-gray-200'}`}>加载合约</button>
      </div>

      <div className="rounded-2xl bg-white shadow p-4">
        {tab==='deploy' ? <DeployContract /> : <ContractPanel />}
      </div>

      <footer className="text-xs text-gray-500 pt-4">React + Vite + Tailwind + ethers v6</footer>
    </div>
  )
}
