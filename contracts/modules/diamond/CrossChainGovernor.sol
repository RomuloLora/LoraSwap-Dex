// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILoraBridgeManager {
    function sendCrossChainMessage(bytes calldata data, uint256 dstChainId) external;
}

contract CrossChainGovernor {
    address public owner;
    address public bridgeManager;
    uint256 public proposalCount;

    struct Proposal {
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
    }
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public voted;

    event ProposalCreated(uint256 indexed proposalId, address proposer, string description, uint256 startTime, uint256 endTime);
    event VoteCast(uint256 indexed proposalId, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event CrossChainProposalSync(uint256 indexed proposalId, uint256 dstChainId);
    event ProposalSynced(uint256 indexed proposalId, uint256 srcChainId);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyBridgeManager() { require(msg.sender == bridgeManager, "Not bridgeManager"); _; }

    constructor(address _bridgeManager) { owner = msg.sender; bridgeManager = _bridgeManager; }

    function createProposal(string calldata description, uint256 duration) external {
        proposalCount++;
        proposals[proposalCount] = Proposal(msg.sender, description, 0, 0, block.timestamp, block.timestamp + duration, false);
        emit ProposalCreated(proposalCount, msg.sender, description, block.timestamp, block.timestamp + duration);
    }

    function vote(uint256 proposalId, bool support, uint256 weight) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.startTime && block.timestamp <= p.endTime, "Voting closed");
        require(!voted[proposalId][msg.sender], "Already voted");
        voted[proposalId][msg.sender] = true;
        if (support) p.votesFor += weight;
        else p.votesAgainst += weight;
        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(block.timestamp > p.endTime, "Voting not ended");
        require(p.votesFor > p.votesAgainst, "Not passed");
        p.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function syncProposalToChain(uint256 proposalId, uint256 dstChainId) external onlyOwner {
        bytes memory data = abi.encodeWithSignature("syncProposal(uint256)", proposalId);
        ILoraBridgeManager(bridgeManager).sendCrossChainMessage(data, dstChainId);
        emit CrossChainProposalSync(proposalId, dstChainId);
    }

    function receiveProposalSync(uint256 proposalId, uint256 srcChainId) external onlyBridgeManager {
        // Lógica de sincronização de proposta
        emit ProposalSynced(proposalId, srcChainId);
    }
} 