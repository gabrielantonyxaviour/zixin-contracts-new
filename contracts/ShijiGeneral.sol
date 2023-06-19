// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.0 <0.9.0;

import "@routerprotocol/evm-gateway-contracts/contracts/IDapp.sol";
import "@routerprotocol/evm-gateway-contracts/contracts/IGateway.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ShijiGeneral is ERC1155, ERC1155URIStorage, IDapp, Ownable {
    using Counters for Counters.Counter;

    struct TransferParams {
        uint256 shijiId;
        bytes recipient;
    }

    // Router variables
    IGateway public gatewayContract;
    mapping(string => string) public ourContractOnChains;

    // Shiji Variables
    Counters.Counter private _shijiIds;

    // Events
    event ShijiMinted(uint256 shijiId, address claimer, uint256 timestamp);

    constructor(address payable gatewayAddress, string memory feePayerAddress) ERC1155("") {
        gatewayContract = IGateway(gatewayAddress);
        gatewayContract.setDappMetadata(feePayerAddress);
    }

    function createShiji(string memory metadataUrl) external onlyOwner returns (uint256 _shijiId) {
        _shijiId = _shijiIds.current();
        _shijiIds.increment();
        _setURI(_shijiId, metadataUrl);
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
        TransferParams memory transferParams = abi.decode(packet, (TransferParams));

        _mint(toAddress(transferParams.recipient), transferParams.shijiId, 1, "");
        emit ShijiMinted(
            transferParams.shijiId,
            toAddress(transferParams.recipient),
            block.timestamp
        );
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

    // Overrides

    function uri(uint256 tokenId)
        public
        view
        override(ERC1155, ERC1155URIStorage)
        returns (string memory)
    {
        return super.uri(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Utils functions

    function toAddress(bytes memory _bytes) internal pure returns (address addr) {
        bytes20 srcTokenAddress;
        assembly {
            srcTokenAddress := mload(add(_bytes, 0x20))
        }
        addr = address(srcTokenAddress);
    }
}
