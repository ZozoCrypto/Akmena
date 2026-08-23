import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { CONTRACT_ADDRESSES, NETWORK_CONFIG } from './config';

export function App() {
  const [account, setAccount] = useState<string | null>(null);
  const [balance, setBalance] = useState<string>("0.0");
  const [blockNumber, setBlockNumber] = useState<number>(0);
  const [status, setStatus] = useState<string>("Disconnected");
  const [txHash, setTxHash] = useState<string | null>(null);
  const [isTransacting, setIsTransacting] = useState<boolean>(false);

  const connectWallet = async () => {
    if (window.ethereum) {
      try {
        setStatus("Connecting...");
        const provider = new ethers.BrowserProvider(window.ethereum);
        const accounts = await provider.send("eth_requestAccounts", []);
        const bal = await provider.getBalance(accounts[0]);
        
        setAccount(accounts[0]);
        setBalance(ethers.formatEther(bal));
        setStatus("Connected (Base Sepolia)");
      } catch (err) {
        console.error(err);
        setStatus("Connection Failed");
      }
    } else {
      alert("Please install a web3 wallet.");
    }
  };

  const executeStealthPing = async () => {
    if (!account || !window.ethereum) return alert("Connect wallet first.");
    try {
      setIsTransacting(true);
      setTxHash(null);
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      
      // Sending a 0-value transaction to the PrivacyEngine to log an on-chain interaction
      const tx = await signer.sendTransaction({
        to: CONTRACT_ADDRESSES.privacyEngine,
        value: 0,
        data: ethers.hexlify(ethers.toUtf8Bytes("AKMENA_GHOST_PING"))
      });
      
      setTxHash(tx.hash);
      await tx.wait();
      setStatus("Stealth Ping Confirmed!");
    } catch (err) {
      console.error(err);
      setStatus("Transaction Failed");
    } finally {
      setIsTransacting(false);
    }
  };

  useEffect(() => {
    const fetchChainData = async () => {
      try {
        const provider = new ethers.JsonRpcProvider(NETWORK_CONFIG.rpcUrl);
        const block = await provider.getBlockNumber();
        setBlockNumber(block);
      } catch (err) {}
    };
    fetchChainData();
    const interval = setInterval(fetchChainData, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8 font-mono">
      <div className="max-w-4xl mx-auto">
        <header className="flex justify-between items-center border-b border-slate-800 pb-6 mb-8">
          <div>
            <h1 className="text-2xl font-bold tracking-wider text-emerald-400">AKMENA // SINGULARITY UI</h1>
            <p className="text-xs text-slate-500 mt-1">Base Batches 004 Deployment</p>
          </div>
          <button
            onClick={connectWallet}
            className="bg-emerald-500 hover:bg-emerald-600 text-slate-950 px-4 py-2 rounded text-sm font-semibold transition cursor-pointer"
          >
            {account ? `${account.substring(0, 6)}...${account.substring(38)}` : "Connect Wallet"}
          </button>
        </header>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div className="bg-slate-900 border border-slate-800 p-5 rounded-lg shadow-lg">
            <h3 className="text-xs text-slate-400 uppercase tracking-wider mb-2">Network Status</h3>
            <p className="text-lg font-semibold text-emerald-400">{status}</p>
            <p className="text-xs text-slate-500 mt-2">Block: #{blockNumber}</p>
          </div>

          <div className="bg-slate-900 border border-slate-800 p-5 rounded-lg shadow-lg">
            <h3 className="text-xs text-slate-400 uppercase tracking-wider mb-2">Wallet Balance</h3>
            <p className="text-lg font-semibold">{Number(balance).toFixed(4)} ETH</p>
            <p className="text-xs text-slate-500 mt-2">Target: Base Sepolia</p>
          </div>

          <div className="bg-slate-900 border border-slate-800 p-5 rounded-lg shadow-lg">
            <h3 className="text-xs text-slate-400 uppercase tracking-wider mb-2">Core Registry</h3>
            <p className="text-xs font-mono text-slate-300 truncate">{CONTRACT_ADDRESSES.akmenaCore}</p>
            <p className="text-xs text-emerald-500 mt-2">● ERC-8109 Diamond</p>
          </div>
        </div>

        <div className="bg-slate-900 border border-slate-800 p-6 rounded-lg shadow-lg">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-sm font-bold uppercase tracking-wider text-slate-300">Ghost Mode Operations</h2>
            <button 
              onClick={executeStealthPing}
              disabled={isTransacting || !account}
              className={`px-4 py-2 rounded text-sm font-semibold transition ${isTransacting || !account ? 'bg-slate-800 text-slate-500 cursor-not-allowed' : 'bg-emerald-500 hover:bg-emerald-600 text-slate-950 cursor-pointer'}`}
            >
              {isTransacting ? 'Executing...' : 'Trigger Stealth Ping'}
            </button>
          </div>
          
          <div className="space-y-4">
            <div className="flex items-center justify-between p-4 bg-slate-950 rounded border border-slate-800">
              <div>
                <p className="text-sm font-medium">Privacy Engine Status</p>
                <p className="text-xs text-slate-500">{CONTRACT_ADDRESSES.privacyEngine}</p>
              </div>
              <span className="text-xs bg-emerald-950 text-emerald-400 px-2.5 py-1 rounded border border-emerald-800">Active</span>
            </div>
            
            {txHash && (
              <div className="p-4 bg-emerald-950/30 rounded border border-emerald-900/50 text-xs text-emerald-400">
                <p className="font-semibold mb-1">On-Chain Interaction Successful:</p>
                <a href={`${NETWORK_CONFIG.blockExplorer}/tx/${txHash}`} target="_blank" rel="noreferrer" className="underline truncate block hover:text-emerald-300">
                  {txHash}
                </a>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
