// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OnePieceMint is VRFConsumerBaseV2, ERC721URIStorage, Ownable {
    string[] internal characterTokenURIs = [
        "https://scarlet-live-iguana-759.mypinata.cloud/ipfs/QmNp4sHf4ccqPpqMBUCSG1CpFwFR4D6kgHesxc1mLs75am",
        "https://scarlet-live-iguana-759.mypinata.cloud/ipfs/QmPHaFt55PeidgCuXe2kaeRYmLaBUPE1Y7Kg4tDyzapZHy",
        "https://scarlet-live-iguana-759.mypinata.cloud/ipfs/QmP9pC9JuUpKcnjUk8GBXEWVTGvK3FTjXL91Q3MJ2rhA16",
        "https://scarlet-live-iguana-759.mypinata.cloud/ipfs/QmSnNXo5hxrFnpbyBeb7jY7jhkm5eyknaCXtr8muk31AHK",
        "https://scarlet-live-iguana-759.mypinata.cloud/ipfs/QmarkkgDuBUcnqksatPzU8uNS4o6LTbEtuK43P7Jyth9NH"
    ];

    uint256 private s_tokenCounter; // Used to keep track of the number of NFTs being minted
    VRFCoordinatorV2Interface private i_vrfCoordinator; // Used to store VRF coordinator link
    uint64 private i_subscriptionId; // Used to store subscription ID from VRF chainlink
    bytes32 private i_keyHash; // Used to store key hash from VRF chainlink
    uint32 private i_callbackGasLimit; // Used to specify the gas limit

    mapping(uint256 => address) private requestIdToSender; // Allows the contract to keep track of which address made a request
    mapping(address => uint256) private userCharacter; // Enables the contract to associate each user with their selected character
    mapping(address => bool) public hasMinted; // Prevents users from minting multiple NFTs with the same address
    mapping(address => uint256) public s_addressToCharacter; // Allows users to query which character they received based on their address

    event NftRequested(uint256 requestId, address requester);
    event CharacterTraitDetermined(uint256 characterId);
    event NftMinted(uint256 characterId, address minter);

    constructor(
        address vrfCoordinatorV2Address,
        uint64 subId,
        bytes32 keyHash,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2Address) ERC721("OnePiece NFT", "OPN") {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2Address);
        i_subscriptionId = subId;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
    }

    function mintNFT(address recipient, uint256 characterId) internal {
        require(!hasMinted[recipient], "You have already minted your NFT");

        uint256 tokenId = s_tokenCounter;
        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, characterTokenURIs[characterId]);

        s_addressToCharacter[recipient] = characterId;
        userCharacter[recipient] = characterId;
        hasMinted[recipient] = true;
        s_tokenCounter += 1;

        emit NftMinted(characterId, recipient);
    }

    function requestNFT(uint256[5] memory answers) public {
        userCharacter[msg.sender] = determineCharacter(answers);
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            3,
            i_callbackGasLimit,
            1
        );
        requestIdToSender[requestId] = msg.sender;
        emit NftRequested(requestId, msg.sender);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        address nftOwner = requestIdToSender[requestId];
        uint256 characterBasedId = userCharacter[nftOwner];
        uint256 randomCharacterId = (randomWords[0] % 5);
        uint256 finalCharacterId = (characterBasedId + randomCharacterId) % 5;

        mintNFT(nftOwner, finalCharacterId);
    }

    function determineCharacter(
        uint256[5] memory answers
    ) private returns (uint256) {
        uint256 characterId = 0;
        for (uint256 i = 0; i < 5; i++) {
            characterId += answers[i];
        }
        return (characterId % 5);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /* tokenId */,
        uint256 /* amount */
    ) internal virtual override {
        require(
            from == address(0) || to == address(0),
            "Soulbound tokens cannot be transferred."
        );
    }
}
