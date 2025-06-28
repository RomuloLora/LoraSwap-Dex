'use client';

import { useState } from 'react';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function SettingsModal({ isOpen, onClose }: SettingsModalProps) {
  const [slippage, setSlippage] = useState('0.5');
  const [deadline, setDeadline] = useState('20');

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-2xl p-6 w-full max-w-md mx-4">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold text-gray-900">Settings</h2>
          <button
            onClick={onClose}
            className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Slippage Tolerance */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Slippage Tolerance
          </label>
          <div className="flex space-x-2 mb-2">
            {['0.1', '0.5', '1.0'].map((value) => (
              <button
                key={value}
                onClick={() => setSlippage(value)}
                className={`flex-1 py-2 px-3 rounded-lg text-sm font-medium transition-colors ${
                  slippage === value
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {value}%
              </button>
            ))}
          </div>
          <div className="relative">
            <input
              type="number"
              value={slippage}
              onChange={(e) => setSlippage(e.target.value)}
              className="w-full bg-gray-50 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="Custom"
              min="0.1"
              max="50"
              step="0.1"
            />
            <span className="absolute right-3 top-2 text-gray-500 text-sm">%</span>
          </div>
        </div>

        {/* Transaction Deadline */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Transaction Deadline
          </label>
          <div className="relative">
            <input
              type="number"
              value={deadline}
              onChange={(e) => setDeadline(e.target.value)}
              className="w-full bg-gray-50 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="20"
              min="1"
              max="4320"
            />
            <span className="absolute right-3 top-2 text-gray-500 text-sm">minutes</span>
          </div>
        </div>

        {/* Network Settings */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Network
          </label>
          <div className="bg-gray-50 rounded-lg p-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                <span className="text-sm font-medium text-gray-900">Hardhat Local</span>
              </div>
              <span className="text-xs text-gray-500">Chain ID: 31337</span>
            </div>
          </div>
        </div>

        {/* Contract Addresses */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Contract Addresses
          </label>
          <div className="space-y-2 text-xs">
            <div className="flex justify-between">
              <span className="text-gray-600">Factory:</span>
              <span className="font-mono text-gray-900">0xe7f1...0512</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Router:</span>
              <span className="font-mono text-gray-900">0x9fE4...fa6e0</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">LORA Token:</span>
              <span className="font-mono text-gray-900">0x5FbD...1aa3</span>
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="flex space-x-3">
          <button
            onClick={onClose}
            className="flex-1 bg-gray-100 hover:bg-gray-200 text-gray-700 py-2 px-4 rounded-lg font-medium transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={() => {
              // Save settings logic here
              onClose();
            }}
            className="flex-1 bg-blue-600 hover:bg-blue-700 text-white py-2 px-4 rounded-lg font-medium transition-colors"
          >
            Save Settings
          </button>
        </div>
      </div>
    </div>
  );
} 