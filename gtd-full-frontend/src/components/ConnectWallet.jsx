import { useEffect, useState } from 'react'
import { getAccount, chainId, getProvider } from '../lib/eth'

export default function ConnectWallet({ expectedChainId = 0 }) {
  const [account, setAccount] = useState(null)
  const [cid, setCid] = useState(null)

  async function refresh() {
    setAccount(await getAccount())
    setCid(await chainId())
  }

  useEffect(() => {
    if (!window.ethereum) return
    refresh()
    const onAcc = (a)=>refresh()
    const onChain = ()=>refresh()
    window.ethereum.on?.('accountsChanged', onAcc)
    window.ethereum.on?.('chainChanged', onChain)
    return ()=>{
      window.ethereum.removeListener?.('accountsChanged', onAcc)
      window.ethereum.removeListener?.('chainChanged', onChain)
    }
  }, [])

  async function connect() {
    const p = getProvider()
    await p.send('eth_requestAccounts', [])
    await refresh()
  }

  const ok = expectedChainId == 0 || expectedChainId == cid

  return (
    <div className="flex items-center gap-2">
      <button onClick={connect} className="px-3 py-2 rounded-xl bg-black text-white">{account?'已连接':'连接钱包'}</button>
      {account && <span className="text-sm">{account}</span>}
      {cid!==null && (
        <span className={`text-xs px-2 py-1 rounded ${ok?'bg-green-100 text-green-700':'bg-yellow-100 text-yellow-700'}`}>
          chainId: {cid}{expectedChainId?` / 期望: ${expectedChainId}`:''}
        </span>
      )}
    </div>
  )
}
