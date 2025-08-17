import { ethers } from 'ethers'
import GroupTokenDistributionDecentralized from '../abi/GroupTokenDistributionDecentralized.json'

export function getProvider() {
  if (!window.ethereum) throw new Error('未检测到 MetaMask')
  return new ethers.BrowserProvider(window.ethereum)
}
export async function getSigner() {
  const p = getProvider()
  await p.send('eth_requestAccounts', [])
  return await p.getSigner()
}
export function getContract(address, signerOrProvider) {
  if (!ethers.isAddress(address)) throw new Error('合约地址不合法')
  return new ethers.Contract(address, GroupTokenDistributionDecentralized.abi, signerOrProvider)
}
export async function getAccount() {
  const p = getProvider()
  const accs = await p.send('eth_accounts', [])
  return accs[0] || null
}
export async function chainId() {
  const p = getProvider()
  const { chainId } = await p.getNetwork()
  return Number(chainId)
}
