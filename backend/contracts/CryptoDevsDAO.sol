// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Interface for the FakeNFTMarketplace
 */
//CryptoDevsDAO deployed to:  0x7c2db21ce0A89B3e53479a94eC79bC6360B85fa7
interface IFakeNFTMarketplace {
    /// @dev getPrice() returns the price of an NFT from the FakeNFTMarketplace
    /// @return Returns the price in Wei for an NFT
    function getPrice() external view returns (uint256);

    /// @dev available() returns whether or not the given _tokenId has already been purchased
    /// @return Returns a boolean value - true if available, false if not
    function available(uint256 _tokenId) external view returns (bool);

    /// @dev purchase() purchases an NFT from the FakeNFTMarketplace
    /// @param _tokenId - the fake NFT tokenID to purchase
    function purchase(uint256 _tokenId) external payable;
}

/**
 * Minimal interface for CryptoDevsNFT containing only two functions
 * that we are interested in
 */
interface ICryptoDevsNFT {
    /// @dev balanceOf returns the number of NFTs owned by the given address
    /// @param owner - address to fetch number of NFTs for
    /// @return Returns the number of NFTs owned
    function balanceOf(address owner) external view returns (uint256);

    /// @dev tokenOfOwnerByIndex returns a tokenID at given index for owner
    /// @param owner - address to fetch the NFT TokenID for
    /// @param index - index of NFT in owned tokens array to fetch
    /// @return Returns the TokenID of the NFT
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);
}

contract CryptoDevsDAO is Ownable {
    // definition of Proposal structure
    struct Proposal {
        //the Nft id to purchase from NFT market
        uint256 nftTokenId;
        //the deadline of this proposal
        uint256 deadline;
        //number of votes agrees with this proposal
        uint256 yayVotes;
        //number of votes against with this proposal
        uint256 nayVotes;
        //whether the proposal has been executed
        bool executed;
        // a mapping indicate whether a NFT ID has been used for vote or not
        mapping (uint256 => bool) voters;
    }
    //a mapping of NFT Id to proposal
    mapping(uint256 => Proposal) public proposals;
    // number of proposals 
    uint256 public numProposals;

    // NFT marketplace contract 
    IFakeNFTMarketplace nftMarketplace;
    // cryptoDevsNFT contract 
    ICryptoDevsNFT cryptoDevsNft;

    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNft = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    //modifier which only allow the member of DAO to call function
    modifier nftHolderOnly() {
        require(cryptoDevsNft.balanceOf(msg.sender) > 0, "not DAO member");
        _;
    }

    function createProposal(uint256 _nftTokenId) 
    external 
    nftHolderOnly 
    returns(uint256) 
    {
        require(nftMarketplace.available(_nftTokenId), "nft not for sale");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        proposal.deadline = block.timestamp + 5 minutes;
        numProposals ++;
        return numProposals - 1;
    }

    modifier activeProposalOnly(uint256 proposalIndex) {
        require(proposals[proposalIndex].deadline > block.timestamp
        , "deadline exceeded");
        _;
    }

    enum Vote {
        YAY,
        NAY
    }

    function voteOnProposal(uint256 proposalIndex, Vote vote) 
    external
    nftHolderOnly
    activeProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];
        uint256 voteNFTBalance = cryptoDevsNft.balanceOf(msg.sender);
        uint256 numVotes = 0;
        for(uint256 i = 0; i < voteNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNft.tokenOfOwnerByIndex(msg.sender, i);
            if(proposal.voters[tokenId] == false) {
                numVotes ++;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes > 0, "token has been used for voting");
        if(vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(proposals[proposalIndex].deadline < block.timestamp
        , "deadline not exceeded");
        require(proposals[proposalIndex].executed == false
        , "proposal has been excuted");
        _;
    }

    function executeProposal(uint proposalIndex)
    external
    nftHolderOnly
    inactiveProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];
        
        if(proposal.yayVotes > proposal.nayVotes) {
            //todo purchase
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "not enough funds");
            nftMarketplace.purchase{value:nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    function withDraw() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "nothing to withdraw");
        payable(owner()).transfer(amount);
    }

    // The following two functions allow the contract to accept ETH deposits
    // directly from a wallet without calling a function
    receive() external payable {}

    fallback() external payable {}
}