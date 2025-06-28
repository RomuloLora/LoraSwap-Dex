'use client';

import { useState } from 'react';
import { CONTRACT_ADDRESSES } from '../lib/contracts';

export default function SimpleSwap() {
  const [inputAmount, setInputAmount] = useState('');
  const [outputAmount, setOutputAmount] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isConnected, setIsConnected] = useState(false);
  const [selectedTokenFrom, setSelectedTokenFrom] = useState('LORA');
  const [selectedTokenTo, setSelectedTokenTo] = useState('LORA2');

  const handleSwap = async () => {
    if (!inputAmount || !outputAmount) return;
    
    setIsLoading(true);
    try {
      // Simulate swap process
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      // Show success feedback
      alert('Swap completed successfully!');
      
      // Reset form
      setInputAmount('');
      setOutputAmount('');
    } catch (error) {
      alert('Swap failed. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleConnectWallet = () => {
    setIsConnected(true);
    alert('Wallet connected! (Demo mode)');
  };

  const calculateOutput = (input: string) => {
    if (!input || parseFloat(input) <= 0) {
      setOutputAmount('');
      return;
    }
    
    // Simple calculation for demo
    const inputValue = parseFloat(input);
    const outputValue = inputValue * 0.95; // 5% fee
    setOutputAmount(outputValue.toFixed(6));
  };

  const handleInputChange = (value: string) => {
    setInputAmount(value);
    calculateOutput(value);
  };

  const switchTokens = () => {
    const temp = selectedTokenFrom;
    setSelectedTokenFrom(selectedTokenTo);
    setSelectedTokenTo(temp);
    
    // Recalculate output
    if (inputAmount) {
      calculateOutput(inputAmount);
    }
  };

  if (!isConnected) {
    return (
      <div className="bg-white rounded-2xl shadow-lg p-8 border border-gray-200">
        <div className="text-center">
          <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <h3 className="text-xl font-semibold text-gray-900 mb-2">Connect Your Wallet</h3>
          <p className="text-gray-600 mb-6">Connect your wallet to start swapping tokens</p>
          <button
            onClick={handleConnectWallet}
            className="w-full bg-blue-600 hover:bg-blue-700 text-white py-3 px-6 rounded-xl font-medium transition-colors flex items-center justify-center space-x-2"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
            <span>Connect Wallet</span>
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-2xl shadow-lg p-6 border border-gray-200">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-semibold text-gray-900">Swap</h2>
        <div className="flex items-center space-x-2">
          <div className="w-2 h-2 bg-green-500 rounded-full"></div>
          <span className="text-sm text-green-600 font-medium">Connected</span>
        </div>
      </div>

      {/* Input Token */}
      <div className="bg-gray-50 rounded-xl p-4 mb-4">
        <div className="flex items-center justify-between mb-2">
          <label className="text-sm font-medium text-gray-700">From</label>
          <span className="text-sm text-gray-500">Balance: 1000.00</span>
        </div>
        <div className="flex items-center space-x-3">
          <input
            type="number"
            value={inputAmount}
            onChange={(e) => handleInputChange(e.target.value)}
            placeholder="0.0"
            className="flex-1 bg-transparent text-2xl font-semibold text-gray-900 outline-none"
            disabled={isLoading}
          />
          <button className="bg-white px-3 py-2 rounded-lg border border-gray-200 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors">
            {selectedTokenFrom}
          </button>
        </div>
      </div>

      {/* Switch Button */}
      <div className="flex justify-center mb-4">
        <button
          onClick={switchTokens}
          disabled={isLoading}
          className="w-10 h-10 bg-gray-100 hover:bg-gray-200 rounded-full flex items-center justify-center transition-colors disabled:opacity-50"
        >
          <svg className="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" />
          </svg>
        </button>
      </div>

      {/* Output Token */}
      <div className="bg-gray-50 rounded-xl p-4 mb-6">
        <div className="flex items-center justify-between mb-2">
          <label className="text-sm font-medium text-gray-700">To</label>
          <span className="text-sm text-gray-500">Balance: 500.00</span>
        </div>
        <div className="flex items-center space-x-3">
          <input
            type="number"
            value={outputAmount}
            onChange={(e) => setOutputAmount(e.target.value)}
            placeholder="0.0"
            className="flex-1 bg-transparent text-2xl font-semibold text-gray-900 outline-none"
            disabled={isLoading}
          />
          <button className="bg-white px-3 py-2 rounded-lg border border-gray-200 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors">
            {selectedTokenTo}
          </button>
        </div>
      </div>

      {/* Swap Details */}
      {inputAmount && outputAmount && (
        <div className="bg-blue-50 rounded-xl p-4 mb-6">
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-600">Rate</span>
              <span className="font-medium">1 {selectedTokenFrom} = {outputAmount ? (parseFloat(outputAmount) / parseFloat(inputAmount)).toFixed(6) : '0'} {selectedTokenTo}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Slippage</span>
              <span className="font-medium">0.5%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Fee</span>
              <span className="font-medium">0.3%</span>
            </div>
          </div>
        </div>
      )}

      {/* Swap Button */}
      <button
        onClick={handleSwap}
        disabled={!inputAmount || !outputAmount || isLoading}
        className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed text-white py-4 px-6 rounded-xl font-medium transition-colors flex items-center justify-center space-x-2"
      >
        {isLoading ? (
          <>
            <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span>Swapping...</span>
          </>
        ) : (
          <>
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
            </svg>
            <span>Swap {selectedTokenFrom} for {selectedTokenTo}</span>
          </>
        )}
      </button>

      {/* Contract Info */}
      <div className="mt-4 text-center">
        <p className="text-xs text-gray-500">
          Router: {CONTRACT_ADDRESSES.router.slice(0, 6)}...{CONTRACT_ADDRESSES.router.slice(-4)}
        </p>
      </div>
    </div>
  );
} 