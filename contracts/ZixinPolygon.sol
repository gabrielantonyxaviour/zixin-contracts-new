// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.0 <0.9.0;

import "@routerprotocol/evm-gateway-contracts/contracts/IDapp.sol";
import "@routerprotocol/evm-gateway-contracts/contracts/IGateway.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import {Functions, FunctionsClient} from "./dev/functions/FunctionsClient.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ZixinPolygon is ERC721, ERC721URIStorage, IDapp, FunctionsClient, ConfirmedOwner {
    using Counters for Counters.Counter;
    using Functions for Functions.Request;

    struct TransferParams {
        uint256 zixinId;
        bytes metadataUrl;
        bytes recipient;
    }

    struct ZixinClaimRequest {
        address claimer;
        uint256 zixinId;
    }
    // Router variables
    IGateway public gatewayContract;
    mapping(string => string) public ourContractOnChains;

    // Zixin Variables
    Counters.Counter private _zixinIds;
    Counters.Counter private _tokenIds;
    mapping(uint256 => string) public zixinToSourceCode;
    mapping(uint256 => mapping(address => uint256)) public zixinToTokenId;

    // Chainlink Variables
    mapping(bytes32 => ZixinClaimRequest) public requestRegistry;

    // Events
    event ErrorOccured(bytes32 indexed requestId, address claimer, bytes error);
    event ZixinClaimed(
        bytes32 indexed requestId,
        uint256 zixinId,
        uint256 tokenId,
        address claimer,
        string metadataUrl,
        uint256 timestamp
    );

    constructor(
        address oracle,
        address payable gatewayAddress,
        string memory feePayerAddress,
        string memory googleSourceCode,
        string memory githubSourceCode,
        string memory twitterSourceCode
    ) FunctionsClient(oracle) ConfirmedOwner(msg.sender) ERC721("ZixinPolygon", "ZXP") {
        gatewayContract = IGateway(gatewayAddress);
        zixinToSourceCode[0] = googleSourceCode;
        zixinToSourceCode[1] = githubSourceCode;
        zixinToSourceCode[2] = twitterSourceCode;
        _zixinIds.increment();
        _zixinIds.increment();
        _zixinIds.increment();
        _tokenIds.increment();
        gatewayContract.setDappMetadata(feePayerAddress);
    }

    function createZixin(string memory sourceCode) external onlyOwner returns (uint256 _zixinId) {
        _zixinId = _zixinIds.current();
        _zixinIds.increment();
        zixinToSourceCode[_zixinId] = sourceCode;
    }

    function claimZixin(
        uint256 zixinId,
        string[] calldata args,
        bytes memory secrets,
        uint64 subscriptionId,
        uint32 gasLimit
    ) external payable {
        require(zixinId < _zixinIds.current(), "Zixin does not exist");
        require(zixinToTokenId[zixinId][msg.sender] == 0, "Zixin already claimed");
        bytes32 requestId = _executeRequest(
            zixinToSourceCode[zixinId],
            secrets,
            args,
            subscriptionId,
            gasLimit
        );
        requestRegistry[requestId] = ZixinClaimRequest(msg.sender, zixinId);
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
        if (requestRegistry[requestId].claimer != address(0)) {
            if (response.length > 0) {
                string memory metadataUrl = string(response);

                if (bytes(metadataUrl).length > 0) {
                    uint256 _tokenId = _tokenIds.current();
                    _safeMint(requestRegistry[requestId].claimer, _tokenId);
                    _setTokenURI(_tokenId, metadataUrl);
                    _tokenIds.increment();
                    zixinToTokenId[requestRegistry[requestId].zixinId][msg.sender] = _tokenId;
                    emit ZixinClaimed(
                        requestId,
                        requestRegistry[requestId].zixinId,
                        _tokenId,
                        requestRegistry[requestId].claimer,
                        metadataUrl,
                        block.timestamp
                    );
                } else {
                    emit ErrorOccured(requestId, requestRegistry[requestId].claimer, "");
                }
            } else {
                emit ErrorOccured(requestId, requestRegistry[requestId].claimer, err);
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
        require(transferParams.zixinId < _zixinIds.current(), "Zixin does not exist");
        require(zixinToTokenId[transferParams.zixinId][msg.sender] != 0, "Zixin unavailable");
        transferParams.metadataUrl = bytes(
            tokenURI(zixinToTokenId[transferParams.zixinId][msg.sender])
        );
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

    // Utils functions
    function bytes32ToString(bytes32 value) internal pure returns (string memory) {
        bytes memory byteArray = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            byteArray[i] = value[i];
        }
        return string(byteArray);
    }
}
