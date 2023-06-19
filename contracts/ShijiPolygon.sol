// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.0 <0.9.0;

import "@routerprotocol/evm-gateway-contracts/contracts/IDapp.sol";
import "@routerprotocol/evm-gateway-contracts/contracts/IGateway.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import {Functions, FunctionsClient} from "./dev/functions/FunctionsClient.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ShijiPolygon is ERC1155, ERC1155URIStorage, IDapp, FunctionsClient, ConfirmedOwner {
    using Counters for Counters.Counter;
    using Functions for Functions.Request;

    struct TransferParams {
        uint256 shijiId;
        bytes recipient;
    }

    // Router variables
    IGateway public gatewayContract;
    mapping(string => string) public ourContractOnChains;

    // Shiji Variables
    Counters.Counter private _shijiIds;
    mapping(uint256 => string) public shijiToSourceCode;

    // Chainlink Variables
    mapping(bytes32 => TransferParams) public requestRegistry;

    // Events
    event ErrorOccured(bytes32 indexed requestId, address claimer, bytes error);
    event ShijiClaimed(
        bytes32 indexed requestId,
        uint256 shijiId,
        address claimer,
        uint256 timestamp
    );

    constructor(
        address oracle,
        address payable gatewayAddress,
        string memory feePayerAddress
    ) FunctionsClient(oracle) ConfirmedOwner(msg.sender) ERC1155("") {
        gatewayContract = IGateway(gatewayAddress);
        gatewayContract.setDappMetadata(feePayerAddress);
    }

    function createShiji(string memory sourceCode, string memory metadataUrl)
        external
        onlyOwner
        returns (uint256 _shijiId)
    {
        _shijiId = _shijiIds.current();
        _shijiIds.increment();
        shijiToSourceCode[_shijiId] = sourceCode;
        _setURI(_shijiId, metadataUrl);
    }

    function claimShiji(
        uint256 shijiId,
        string[] calldata args,
        bytes memory secrets,
        uint64 subscriptionId,
        uint32 gasLimit
    ) external payable {
        require(shijiId < _shijiIds.current(), "Shiji does not exist");
        require(balanceOf(msg.sender, shijiId) > 0, "Shiji already claimed");
        bytes32 requestId = _executeRequest(
            shijiToSourceCode[shijiId],
            secrets,
            args,
            subscriptionId,
            gasLimit
        );
        requestRegistry[requestId] = TransferParams(shijiId, addressToBytes(msg.sender));
    }

    // Chainlink Functions
    function _executeRequest(
        string memory source,
        bytes memory secrets,
        string[] memory args,
        uint64 subscriptionId,
        uint32 gasLimit
    ) internal returns (bytes32) {
        Functions.Request memory req;
        req.initializeRequest(Functions.Location.Inline, Functions.CodeLanguage.JavaScript, source);
        if (secrets.length > 0) {
            req.addRemoteSecrets(secrets);
        }
        if (args.length > 0) req.addArgs(args);

        bytes32 assignedReqID = sendRequest(req, subscriptionId, gasLimit);
        return assignedReqID;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        address recipient = toAddress(requestRegistry[requestId].recipient);
        if (recipient != address(0)) {
            if (response.length > 0) {
                uint256 condition = abi.decode(response, (uint256));

                if (condition > 0) {
                    _mint(recipient, requestRegistry[requestId].shijiId, 1, "");
                    emit ShijiClaimed(
                        requestId,
                        requestRegistry[requestId].shijiId,
                        recipient,
                        block.timestamp
                    );
                } else {
                    emit ErrorOccured(requestId, recipient, "Claim Failed");
                }
            } else {
                emit ErrorOccured(requestId, recipient, err);
            }
        }
    }

    function updateOracleAddress(address oracle) public onlyOwner {
        setOracle(oracle);
    }

    function addSimulatedRequestId(address oracleAddress, bytes32 requestId) public onlyOwner {
        addExternalRequest(oracleAddress, requestId);
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
        require(transferParams.shijiId < _shijiIds.current(), "Shiji does not exist");
        require(balanceOf(msg.sender, transferParams.shijiId) > 0, "Shiji unavailable");

        bytes memory packet = abi.encode(transferParams);
        bytes memory requestPacket = abi.encode(ourContractOnChains[destChainId], packet);

        gatewayContract.iSend{value: msg.value}(
            1,
            0,
            string(""),
            destChainId,
            requestMetadata,
            requestPacket
        );
    }

    function iReceive(
        string memory, // requestSender,
        bytes memory packet,
        string memory srcChainId
    ) external override returns (bytes memory) {
        require(msg.sender == address(gatewayContract), "only gateway");

        // Do Nothing

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
    function bytes32ToString(bytes32 value) internal pure returns (string memory) {
        bytes memory byteArray = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            byteArray[i] = value[i];
        }
        return string(byteArray);
    }

    function addressToBytes(address a) public pure returns (bytes memory b) {
        assembly {
            let m := mload(0x40)
            a := and(a, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
            mstore(0x40, add(m, 52))
            b := m
        }
    }

    function toAddress(bytes memory _bytes) internal pure returns (address addr) {
        bytes20 srcTokenAddress;
        assembly {
            srcTokenAddress := mload(add(_bytes, 0x20))
        }
        addr = address(srcTokenAddress);
    }
}
