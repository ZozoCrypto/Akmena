import React, { useState } from 'react';
import { useAccount, useBlockNumber, useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { parseEther, formatEther, keccak256, toHex } from 'viem';
import { 
  ConnectWallet, 
  Wallet, 
  WalletDropdown, 
  WalletDropdownDisconnect 
} from '@coinbase/onchainkit/wallet';
import {
  Address,
  Avatar,
  Name,
  Identity,
  EthBalance,
} from '@coinbase/onchainkit/identity';
import { Cpu, Shield, Lock, Coins, ArrowRight, CheckCircle2, RefreshCw } from 'lucide-react';
import { CONTRACT_ADDRESSES, NETWORK_CONFIG } from './config';
import { ESCROW_ENGINE_ABI, POLICY_BOUNDARY_ABI, PRIVACY_ENGINE_ABI } from './abi/contracts';

export function App() {
  const { address, isConnected } = useAccount();
  const { data: blockNumber } = useBlockNumber({ watch: true });
  const [activeTab, setActiveTab] = useState<'escrow' | 'agent' | 'privacy'>('escrow');

  // Transaction state hooks
  const { data: hash, isPending, writeContract, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });

  // Escrow Form State
  const [sellerAddr, setSellerAddr] = useState<string>('0x2D4888499D765d387f9CbC48061b28CDe6bC2601');
  const [escrowAmount, setEscrowAmount] = useState<string>('0.001');
  const [queryEscrowId, setQueryEscrowId] = useState<string>('1');

  // Agent Policy Form State
  const [agentAddr, setAgentAddr] = useState<string>('0x2D4888499D765d387f9CbC48061b28CDe6bC2601');
  const [maxSpendTx, setMaxSpendTx] = useState<string>('0.01');
  const [maxSpendTotal, setMaxSpendTotal] = useState<string>('0.1');
  const [requiresProof, setRequiresProof] = useState<boolean>(true);

  // Privacy Engine Read State
  const [nullifierText, setNullifierText] = useState<string>('akmena_ghost_mode_test_2026');
  const computedNullifier = keccak256(toHex(nullifierText));

  // Query live nullifier spent state
  const { data: isSpent, refetch: refetchNullifier } = useReadContract({
    address: CONTRACT_ADDRESSES.privacyEngine as `0x${string}`,
    abi: PRIVACY_ENGINE_ABI,
    functionName: 'nullifiers',
    args: [computedNullifier],
  });

  // Query live escrow details
  const { data: escrowData, refetch: refetchEscrow } = useReadContract({
    address: CONTRACT_ADDRESSES.escrowEngine as `0x${string}`,
    abi: ESCROW_ENGINE_ABI,
    functionName: 'getEscrow',
    args: [BigInt(queryEscrowId || '1')],
  });

  // Handle Escrow Creation
  const handleCreateEscrow = (e: React.FormEvent) => {
    e.preventDefault();
    if (!sellerAddr || !escrowAmount) return;
    writeContract({
      address: CONTRACT_ADDRESSES.escrowEngine as `0x${string}`,
      abi: ESCROW_ENGINE_ABI,
      functionName: 'createEscrow',
      args: [sellerAddr as `0x${string}`, parseEther(escrowAmount)],
      value: parseEther(escrowAmount),
    });
  };

  // Handle Setting Agent Policy
  const handleSetPolicy = (e: React.FormEvent) => {
    e.preventDefault();
    if (!agentAddr) return;
    writeContract({
      address: CONTRACT_ADDRESSES.policyBoundary as `0x${string}`,
      abi: POLICY_BOUNDARY_ABI,
      functionName: 'setAgentPolicy',
      args: [
        agentAddr as `0x${string}`,
        parseEther(maxSpendTx),
        parseEther(maxSpendTotal),
        requiresProof
      ],
    });
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-6 md:p-10 font-mono">
      <div className="max-w-5xl mx-auto">
        
        {/* Header */}
        <header className="flex flex-col md:flex-row justify-between items-start md:items-center border-b border-slate-800 pb-6 mb-8 gap-4">
          <div>
            <h1 className="text-2xl font-bold tracking-wider text-emerald-400 flex items-center gap-2">
              <Shield className="w-6 h-6" /> AKMENA // SINGULARITY UI
            </h1>
            <p className="text-xs text-slate-500 mt-1">Autonomous Execution & Privacy Protocol (Base Sepolia)</p>
          </div>
          
          <div className="bg-slate-900 rounded-xl border border-slate-800">
            <Wallet>
              <ConnectWallet>
                <Avatar className="h-6 w-6" />
                <Name />
              </ConnectWallet>
              <WalletDropdown>
                <Identity className="px-4 pt-3 pb-2" hasCopyAddressOnClick>
                  <Avatar />
                  <Name />
                  <Address />
                  <EthBalance />
                </Identity>
                <WalletDropdownDisconnect />
              </WalletDropdown>
            </Wallet>
          </div>
        </header>

        {/* Network & Protocol Status Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div className="bg-slate-900 border border-slate-800 p-5 rounded-lg shadow-lg">
            <h3 className="text-xs text-slate-400 uppercase tracking-wider mb-2 flex items-center gap-2">
              <Cpu className="w-4 h-4 text-emerald-400" /> Network Status
            </h3>
            <p className="text-lg font-semibold text-emerald-400">
              {isConnected ? "Connected" : "Disconnected"}
            </p>
            <p className="text-xs text-slate-500 mt-2">Base Sepolia Block: #{blockNumber?.toString() || "Syncing..."}</p>
          </div>

          <div className="bg-slate-900 border border-slate-800 p-5 rounded-lg shadow-lg">
            <h3 className="text-xs text-slate-400 uppercase tracking-wider mb-2 flex items-center gap-2">
              <Coins className="w-4 h-4 text-emerald-400" /> Active Python Agent
            </h3>
            <p className="text-xs font-mono text-slate-300 truncate">0x2D4888499D765d387f9CbC48061b28CDe6bC2601</p>
            <p className="text-xs text-emerald-500 mt-2">● Synced via web3.py</p>
          </div>

          <div className="bg-slate-900 border border-slate-800 p-5 rounded-lg shadow-lg">
            <h3 className="text-xs text-slate-400 uppercase tracking-wider mb-2 flex items-center gap-2">
              <Lock className="w-4 h-4 text-emerald-400" /> Core Registry
            </h3>
            <p className="text-xs font-mono text-slate-300 truncate">{CONTRACT_ADDRESSES.akmenaCore}</p>
            <p className="text-xs text-emerald-500 mt-2">● ERC-8109 Diamond Proxy</p>
          </div>
        </div>

        {/* Navigation Tabs */}
        <div className="flex border-b border-slate-800 mb-6 gap-2">
          <button
            onClick={() => setActiveTab('escrow')}
            className={`px-4 py-2 text-sm font-semibold border-b-2 transition cursor-pointer ${activeTab === 'escrow' ? 'border-emerald-400 text-emerald-400' : 'border-transparent text-slate-400 hover:text-slate-200'}`}
          >
            Escrow Engine
          </button>
          <button
            onClick={() => setActiveTab('agent')}
            className={`px-4 py-2 text-sm font-semibold border-b-2 transition cursor-pointer ${activeTab === 'agent' ? 'border-emerald-400 text-emerald-400' : 'border-transparent text-slate-400 hover:text-slate-200'}`}
          >
            Agent Delegation Policy
          </button>
          <button
            onClick={() => setActiveTab('privacy')}
            className={`px-4 py-2 text-sm font-semibold border-b-2 transition cursor-pointer ${activeTab === 'privacy' ? 'border-emerald-400 text-emerald-400' : 'border-transparent text-slate-400 hover:text-slate-200'}`}
          >
            Ghost Mode Privacy Engine
          </button>
        </div>

        {/* Global Transaction Status Feedback */}
        {hash && (
          <div className="mb-6 p-4 bg-slate-900 border border-emerald-500/50 rounded-lg text-xs">
            <div className="flex items-center gap-2 text-emerald-400 font-semibold mb-1">
              {isConfirmed ? <CheckCircle2 className="w-4 h-4" /> : <RefreshCw className="w-4 h-4 animate-spin" />}
              {isConfirming ? "Broadcasting to Base Sepolia..." : isConfirmed ? "Transaction Confirmed on-chain!" : "Transaction Submitted"}
            </div>
            <p className="text-slate-400 truncate">Tx Hash: {hash}</p>
            <a href={`${NETWORK_CONFIG.blockExplorer}/tx/${hash}`} target="_blank" rel="noreferrer" className="text-emerald-400 underline mt-1 block">
              View on BaseScan Explorer →
            </a>
          </div>
        )}

        {error && (
          <div className="mb-6 p-4 bg-red-950/40 border border-red-800 rounded-lg text-xs text-red-400">
            <strong>Execution Error:</strong> {error.message.split('\n')[0]}
          </div>
        )}

        {/* Tab 1: Escrow Engine */}
        {activeTab === 'escrow' && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-slate-900 border border-slate-800 p-6 rounded-lg shadow-lg">
              <h2 className="text-sm font-bold uppercase tracking-wider text-slate-300 mb-4 flex items-center gap-2">
                <Coins className="w-4 h-4 text-emerald-400" /> Create Task Escrow
              </h2>
              <form onSubmit={handleCreateEscrow} className="space-y-4 text-xs">
                <div>
                  <label className="block text-slate-400 mb-1">Seller / Agent Recipient Address</label>
                  <input
                    type="text"
                    value={sellerAddr}
                    onChange={(e) => setSellerAddr(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded p-2.5 font-mono text-slate-200 focus:border-emerald-500 outline-none"
                    placeholder="0x..."
                  />
                </div>
                <div>
                  <label className="block text-slate-400 mb-1">Escrow Amount (ETH)</label>
                  <input
                    type="text"
                    value={escrowAmount}
                    onChange={(e) => setEscrowAmount(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded p-2.5 font-mono text-slate-200 focus:border-emerald-500 outline-none"
                    placeholder="0.001"
                  />
                </div>
                <button
                  type="submit"
                  disabled={!isConnected || isPending}
                  className={`w-full py-2.5 rounded font-semibold text-xs transition cursor-pointer flex items-center justify-center gap-2 ${!isConnected || isPending ? 'bg-slate-800 text-slate-500 cursor-not-allowed' : 'bg-emerald-500 hover:bg-emerald-600 text-slate-950'}`}
                >
                  {isPending ? 'Signing Transaction...' : 'Fund & Create On-Chain Escrow'} <ArrowRight className="w-3.5 h-3.5" />
                </button>
              </form>
            </div>

            <div className="bg-slate-900 border border-slate-800 p-6 rounded-lg shadow-lg">
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-sm font-bold uppercase tracking-wider text-slate-300">Escrow State Query</h2>
                <button onClick={() => refetchEscrow()} className="text-xs text-emerald-400 hover:underline flex items-center gap-1">
                  <RefreshCw className="w-3 h-3" /> Refresh
                </button>
              </div>
              <div className="space-y-4 text-xs">
                <div>
                  <label className="block text-slate-400 mb-1">Escrow ID Search</label>
                  <input
                    type="number"
                    value={queryEscrowId}
                    onChange={(e) => setQueryEscrowId(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded p-2.5 font-mono text-slate-200 focus:border-emerald-500 outline-none"
                  />
                </div>
                <div className="p-4 bg-slate-950 rounded border border-slate-800 space-y-2 font-mono">
                  <p className="text-slate-400"><span className="text-slate-500">Buyer:</span> {escrowData?.buyer || 'None'}</p>
                  <p className="text-slate-400"><span className="text-slate-500">Seller:</span> {escrowData?.seller || 'None'}</p>
                  <p className="text-slate-400"><span className="text-slate-500">Locked ETH:</span> {escrowData ? formatEther(escrowData.amount) : '0'} ETH</p>
                  <p className="text-slate-400"><span className="text-slate-500">Status Code:</span> {escrowData ? escrowData.status.toString() : '0'} (1=Created, 2=Settled)</p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Tab 2: Agent Delegation Policy */}
        {activeTab === 'agent' && (
          <div className="bg-slate-900 border border-slate-800 p-6 rounded-lg shadow-lg">
            <h2 className="text-sm font-bold uppercase tracking-wider text-slate-300 mb-4 flex items-center gap-2">
              <Shield className="w-4 h-4 text-emerald-400" /> Delegate AI Agent Execution Policy
            </h2>
            <form onSubmit={handleSetPolicy} className="space-y-4 text-xs">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-slate-400 mb-1">Target Agent Address</label>
                  <input
                    type="text"
                    value={agentAddr}
                    onChange={(e) => setAgentAddr(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded p-2.5 font-mono text-slate-200 focus:border-emerald-500 outline-none"
                  />
                </div>
                <div>
                  <label className="block text-slate-400 mb-1">Max Spend Per Tx (ETH)</label>
                  <input
                    type="text"
                    value={maxSpendTx}
                    onChange={(e) => setMaxSpendTx(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded p-2.5 font-mono text-slate-200 focus:border-emerald-500 outline-none"
                  />
                </div>
                <div>
                  <label className="block text-slate-400 mb-1">Max Spend Total (ETH)</label>
                  <input
                    type="text"
                    value={maxSpendTotal}
                    onChange={(e) => setMaxSpendTotal(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded p-2.5 font-mono text-slate-200 focus:border-emerald-500 outline-none"
                  />
                </div>
                <div className="flex items-center gap-3 pt-6">
                  <input
                    type="checkbox"
                    id="proofReq"
                    checked={requiresProof}
                    onChange={(e) => setRequiresProof(e.target.checked)}
                    className="w-4 h-4 accent-emerald-500 rounded cursor-pointer"
                  />
                  <label htmlFor="proofReq" className="text-slate-300 cursor-pointer">Require EIP-1153 Transient Proof Verification</label>
                </div>
              </div>
              <button
                type="submit"
                disabled={!isConnected || isPending}
                className={`w-full py-2.5 rounded font-semibold text-xs transition cursor-pointer flex items-center justify-center gap-2 ${!isConnected || isPending ? 'bg-slate-800 text-slate-500 cursor-not-allowed' : 'bg-emerald-500 hover:bg-emerald-600 text-slate-950'}`}
              >
                {isPending ? 'Signing Transaction...' : 'Set Agent Policy Boundary'} <ArrowRight className="w-3.5 h-3.5" />
              </button>
            </form>
          </div>
        )}

        {/* Tab 3: Ghost Mode Privacy Engine */}
        {activeTab === 'privacy' && (
          <div className="bg-slate-900 border border-slate-800 p-6 rounded-lg shadow-lg">
            <h2 className="text-sm font-bold uppercase tracking-wider text-slate-300 mb-4 flex items-center gap-2">
              <Lock className="w-4 h-4 text-emerald-400" /> Ghost Mode Stealth Nullifier Inspector
            </h2>
            <div className="space-y-4 text-xs">
              <div>
                <label className="block text-slate-400 mb-1">Nullifier Raw Secret String</label>
                <input
                  type="text"
                  value={nullifierText}
                  onChange={(e) => setNullifierText(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded p-2.5 font-mono text-slate-200 focus:border-emerald-500 outline-none"
                />
              </div>
              
              <div className="p-4 bg-slate-950 rounded border border-slate-800 space-y-2 font-mono">
                <p className="text-slate-400"><span className="text-slate-500">Keccak256 Hash:</span> {computedNullifier}</p>
                <div className="flex items-center gap-2 pt-2">
                  <span className="text-slate-500">On-Chain Spent Status:</span>
                  <span className={`px-2 py-0.5 rounded text-[11px] font-semibold ${isSpent ? 'bg-red-950 text-red-400 border border-red-800' : 'bg-emerald-950 text-emerald-400 border border-emerald-800'}`}>
                    {isSpent ? 'SPENT (Nullifier Claimed)' : 'UNSPENT (Valid Fresh Nullifier)'}
                  </span>
                </div>
              </div>

              <button
                onClick={() => refetchNullifier()}
                className="w-full py-2.5 bg-slate-800 hover:bg-slate-700 text-slate-200 font-semibold rounded text-xs transition cursor-pointer flex items-center justify-center gap-2"
              >
                <RefreshCw className="w-3.5 h-3.5" /> Re-Query Privacy Engine State
              </button>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}

export default App;
