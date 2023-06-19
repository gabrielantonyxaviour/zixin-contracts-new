// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.0 <0.9.0;

import "@routerprotocol/evm-gateway-contracts/contracts/IDapp.sol";
import "@routerprotocol/evm-gateway-contracts/contracts/IGateway.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ZixinGeneral is ERC721, ERC721URIStorage, IDapp, Ownable {
    using Counters for Counters.Counter;

    struct TransferParams {
        uint256 zixinId;
        bytes metadataUrl;
        bytes recipient;
    }

    // Router variables
    IGateway public gatewayContract;
    mapping(string => string) public ourContractOnChains;

    // Zixin Variables
    Counters.Counter private _tokenIds;

    // Events
    event ZixinMinted(
        uint256 zixinId,
        uint256 tokenId,
        address claimer,
        string metadataUrl,
        uint256 timestamp
    );

    constructor(
        string memory _name,
        string memory _symbol,
        address payable gatewayAddress,
        string memory feePayerAddress
    ) ERC721(_name, _symbol) {
        gatewayContract = IGateway(gatewayAddress);
        gatewayContract.setDappMetadata(feePayerAddress);
    }

    // Router functions
    function setDappMetadata(string memory feePayerAddress) external onlyOwner {
        gatewayContract.setDappMetadata(feePayerAddress);
    }

    function setGateway(address gateway) external onlyOwner {
        gatewayContract = IGateway(gateway);
    }

    function setContractOnChain(string calldata chainId, string calldata contractAddress)
        external
        onlyOwner
    {
        ourContractOnChains[chainId] = contractAddress;
    }

    function transferCrossChain(
        string calldata destChainId,
        TransferParams memory transferParams,
        bytes calldata requestMetadata
    ) public payable {
        require(
            keccak256(abi.encodePacked(ourContractOnChains[destChainId])) !=
                keccak256(abi.encodePacked("")),
            "contract on dest not set"
        );
        // DO NOTHING
    }

    function iReceive(
        string memory, // requestSender,
        bytes memory packet,
        string memory srcChainId
    ) external override returns (bytes memory) {
        require(msg.sender == address(gatewayContract), "only gateway");
        // decoding our payload
        TransferParams memory transferParams = abi.decode(packet, (TransferParams));
        uint256 _tokenId = _tokenIds.current();
        _safeMint(toAddress(transferParams.recipient), _tokenId);
        _setTokenURI(_tokenId, bytesToString(transferParams.metadataUrl));
        _tokenIds.increment();
        return abi.encode(srcChainId);
    }

    function getRequestMetadata(
        uint64 destGasLimit,
        uint64 destGasPrice,
        uint64 ackGasLimit,
        uint64 ackGasPrice,
        uint128 relayerFees,
        uint8 ackType,
        bool isReadCall,
        bytes memory asmAddress
    ) public pure returns (bytes memory) {
        bytes memory requestMetadata = abi.encodePacked(
            destGasLimit,
            destGasPrice,
            ackGasLimit,
            ackGasPrice,
            relayerFees,
            ackType,
            isReadCall,
            asmAddress
        );
        return requestMetadata;
    }

    function iAck(
        uint256 requestIdentifier,
        bool execFlag,
        bytes memory execData
    ) external override {}

    function toAddress(bytes memory _bytes) internal pure returns (address addr) {
        bytes20 srcTokenAddress;
        assembly {
            srcTokenAddress := mload(add(_bytes, 0x20))
        }
        addr = address(srcTokenAddress);
    }

    // Overrides
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function bytesToString(bytes memory _bytes) public pure returns (string memory) {
        if (_bytes.length == 0) {
            return "";
        }
        string memory result = new string(_bytes.length);
        for (uint256 i = 0; i < _bytes.length; i++) {
            bytes1 char = _bytes[i];
            require(uint8(char) >= 32 && uint8(char) <= 126, "Invalid character");
            bytes(result)[i] = char;
        }
        return result;
    }
}
