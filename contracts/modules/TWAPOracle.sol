// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TWAPOracle
 * @dev Oracle de Preço Médio Ponderado pelo Tempo para proteção MEV
 */
contract TWAPOracle is ReentrancyGuard, Ownable {
    struct Observation {
        uint256 timestamp;
        uint256 price0;
        uint256 price1;
    }

    mapping(address => Observation[]) public observations;
    mapping(address => bool) public authorized;
    uint256 public minObservations = 5;
    uint256 public minInterval = 60;

    event ObservationAdded(address indexed pool, uint256 price0, uint256 price1, uint256 timestamp);
    event ManipulationDetected(address indexed pool, uint256 price0, uint256 twap0);
    event Authorized(address indexed addr, bool status);

    modifier onlyAuthorized() {
        require(authorized[msg.sender], "Not authorized");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function setAuthorized(address addr, bool status) external onlyOwner {
        authorized[addr] = status;
        emit Authorized(addr, status);
    }

    function addObservation(address pool, uint256 price0, uint256 price1) external onlyAuthorized {
        Observation[] storage obs = observations[pool];
        if (obs.length > 0) {
            require(block.timestamp - obs[obs.length - 1].timestamp >= minInterval, "Interval too short");
        }
        obs.push(Observation(block.timestamp, price0, price1));
        emit ObservationAdded(pool, price0, price1, block.timestamp);
    }

    function getTWAP(address pool, uint256 interval) external view returns (uint256 twap0, uint256 twap1) {
        Observation[] storage obs = observations[pool];
        require(obs.length >= minObservations, "Not enough observations");
        uint256 sum0;
        uint256 sum1;
        uint256 count = 0;
        uint256 cutoff = block.timestamp - interval;
        for (uint256 i = obs.length; i > 0; i--) {
            if (obs[i-1].timestamp < cutoff) {
                break;
            }
            sum0 += obs[i-1].price0;
            sum1 += obs[i-1].price1;
            count++;
        }
        require(count > 0, "No observations in interval");
        twap0 = sum0 / count;
        twap1 = sum1 / count;
    }

    function detectManipulation(address pool, uint256 currentPrice0, uint256 currentPrice1) external view returns (bool) {
        (uint256 twap0, uint256 twap1) = this.getTWAP(pool, 0);
        if (currentPrice0 > twap0 * 110 / 100 || currentPrice0 < twap0 * 90 / 100) {
            return true;
        }
        if (currentPrice1 > twap1 * 110 / 100 || currentPrice1 < twap1 * 90 / 100) {
            return true;
        }
        return false;
    }
} 