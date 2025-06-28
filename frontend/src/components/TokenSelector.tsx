import React, { useState, useCallback, useMemo } from 'react';
import { MagnifyingGlassIcon, CheckIcon } from '@heroicons/react/24/outline';
import { useToken } from '../hooks/useDEX';
import { CONTRACT_ADDRESSES } from '../lib/contracts';

interface Token {
  address: string;
  symbol: string;
  name: string;
  decimals: number;
  logoURI?: string;
}

interface TokenSelectorProps {
  selectedToken: string;
  onTokenSelect: (tokenAddress: string) => void;
  onClose: () => void;
}

// Mock token list - in a real app, this would come from an API or token registry
const MOCK_TOKENS: Token[] = [
  {
    address: CONTRACT_ADDRESSES.loraToken,
    symbol: 'LORA',
    name: 'Lora Token',
    decimals: 18,
  },
  {
    address: CONTRACT_ADDRESSES.loraToken2,
    symbol: 'LORA2',
    name: 'Lora Token 2',
    decimals: 18,
  },
  {
    address: '0xA0b86a33E6441b8C4C8C8C8C8C8C8C8C8C8C8C8',
    symbol: 'USDC',
    name: 'USD Coin',
    decimals: 6,
  },
  {
    address: '0xB0b86a33E6441b8C4C8C8C8C8C8C8C8C8C8C8C8',
    symbol: 'USDT',
    name: 'Tether USD',
    decimals: 6,
  },
  {
    address: '0xC0b86a33E6441b8C4C8C8C8C8C8C8C8C8C8C8C8',
    symbol: 'WETH',
    name: 'Wrapped Ether',
    decimals: 18,
  },
];

const TokenSelector: React.FC<TokenSelectorProps> = ({
  selectedToken,
  onTokenSelect,
  onClose,
}) => {
  const [searchTerm, setSearchTerm] = useState('');

  // Filter tokens based on search term
  const filteredTokens = useMemo(() => {
    if (!searchTerm) return MOCK_TOKENS;
    
    const term = searchTerm.toLowerCase();
    return MOCK_TOKENS.filter(
      token =>
        token.symbol.toLowerCase().includes(term) ||
        token.name.toLowerCase().includes(term) ||
        token.address.toLowerCase().includes(term)
    );
  }, [searchTerm]);

  const handleTokenSelect = useCallback((tokenAddress: string) => {
    onTokenSelect(tokenAddress);
    onClose();
  }, [onTokenSelect, onClose]);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-xl shadow-xl max-w-md w-full mx-4 max-h-[600px] overflow-hidden">
        {/* Header */}
        <div className="p-6 border-b">
          <div className="flex justify-between items-center mb-4">
            <h3 className="text-lg font-semibold text-gray-900">Select Token</h3>
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600 transition-colors"
            >
              ✕
            </button>
          </div>
          
          {/* Search */}
          <div className="relative">
            <MagnifyingGlassIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="Search by name or paste address"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>
        </div>

        {/* Token List */}
        <div className="overflow-y-auto max-h-[400px]">
          {filteredTokens.length === 0 ? (
            <div className="p-6 text-center">
              <p className="text-gray-500">No tokens found</p>
            </div>
          ) : (
            <div className="p-2">
              {filteredTokens.map((token) => (
                <button
                  key={token.address}
                  onClick={() => handleTokenSelect(token.address)}
                  className={`w-full flex items-center justify-between p-3 rounded-lg hover:bg-gray-50 transition-colors ${
                    selectedToken === token.address ? 'bg-blue-50 border border-blue-200' : ''
                  }`}
                >
                  <div className="flex items-center">
                    {/* Token Icon */}
                    <div className="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center mr-3">
                      <span className="text-xs font-medium text-gray-600">
                        {token.symbol.charAt(0)}
                      </span>
                    </div>
                    
                    {/* Token Info */}
                    <div className="text-left">
                      <div className="font-medium text-gray-900">{token.symbol}</div>
                      <div className="text-sm text-gray-500">{token.name}</div>
                    </div>
                  </div>
                  
                  {/* Selected Indicator */}
                  {selectedToken === token.address && (
                    <CheckIcon className="w-5 h-5 text-blue-600" />
                  )}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t bg-gray-50">
          <p className="text-xs text-gray-500 text-center">
            Token list is managed by the community. Always verify token addresses.
          </p>
        </div>
      </div>
    </div>
  );
};

export default TokenSelector; 