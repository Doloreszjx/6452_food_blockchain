// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Traceability {
    /// Current status: origin field removed
    struct ProductTrace {
        string currentLocation;
        int256 temperature;
        uint256 lastUpdated;
    }

    /// Corresponding to the structure of the off-chain JSON
    struct TraceRecord {
        uint256 ts;
        int256 temp;
        int256 hum;
        string location;
        string productName;
        bytes32 dataHash;
    }

    address public manager;
    mapping(string => ProductTrace)  private products;
    mapping(string => TraceRecord[]) private traceHistory;
    string[] public batchIds;

    /// Issued when registering a product (excluding origin)
    event ProductRegistered(
        string indexed batchId,
        uint256 timestamp
    );

    /// Oracle triggers upload request
    event RequestDataUpload(string indexed batchId);

    /// Record complete fields when uploading
    event DataUploaded(
        string indexed batchId,
        uint256 ts,
        int256  temp,
        int256  hum,
        string  location,
        string  productName,
        bytes32 dataHash
    );

    constructor() {
        manager = msg.sender;
    }

    /// Register a new product with just a batch ID
    function registerProduct(string memory batchId) public {
        require(msg.sender == manager, "Only manager");
        // lastUpdated==0 表示还没注册过
        require(products[batchId].lastUpdated == 0, "Already registered");

        products[batchId] = ProductTrace({
            currentLocation: "",
            temperature:     0,
            lastUpdated:     block.timestamp
        });

        batchIds.push(batchId);
        emit ProductRegistered(batchId, block.timestamp);
    }

    /// On-chain triggers off-chain uploads
    function requestOracleUpload(string memory batchId) public {
        require(products[batchId].lastUpdated != 0, "Not registered");
        emit RequestDataUpload(batchId);
    }

    /// Chain data (must first registerProduct)
    function uploadData(
        string memory batchId,
        uint256        ts,
        int256         temp,
        int256         hum,
        string memory  location,
        string memory  productName,
        bytes32        dataHash
    ) public {
        require(products[batchId].lastUpdated != 0, "Not registered");

        // Update current status
        products[batchId].currentLocation = location;
        products[batchId].temperature     = temp;
        products[batchId].lastUpdated     = ts;

        // Show history
        traceHistory[batchId].push(
            TraceRecord({
                ts:          ts,
                temp:        temp,
                hum:         hum,
                location:    location,
                productName: productName,
                dataHash:    dataHash
            })
        );

        emit DataUploaded(
            batchId,
            ts,
            temp,
            hum,
            location,
            productName,
            dataHash
        );
    }

    /// Check the latest status (remove origin)
    function getTraceInfo(string memory batchId) public view returns (
        string memory currentLocation,
        int256 temperature,
        uint256 lastUpdated
    ) {
        ProductTrace storage t = products[batchId];
        require(t.lastUpdated != 0, "Not found");
        return (t.currentLocation, t.temperature, t.lastUpdated);
    }

    /// Check history
    function getTraceHistory(string memory batchId) public view returns (
        uint256[] memory tss,
        int256[]  memory temps,
        int256[]  memory hums,
        string[]  memory locations,
        string[]  memory productNames,
        bytes32[] memory dataHashes
    ) {
        uint256 n = traceHistory[batchId].length;
        tss          = new uint256[](n);
        temps        = new int256[](n);
        hums         = new int256[](n);
        locations    = new string[](n);
        productNames = new string[](n);
        dataHashes   = new bytes32[](n);

        for (uint256 i = 0; i < n; i++) {
            TraceRecord storage r = traceHistory[batchId][i];
            tss[i]          = r.ts;
            temps[i]        = r.temp;
            hums[i]         = r.hum;
            locations[i]    = r.location;
            productNames[i] = r.productName;
            dataHashes[i]   = r.dataHash;
        }
        return (tss, temps, hums, locations, productNames, dataHashes);
    }

    /// Get all batchId
    function getAllBatchIds() public view returns (string[] memory) {
        return batchIds;
    }

    /// Delete products and history
    function deleteProduct(string memory batchId) public {
        require(msg.sender == manager, "Only manager");
        require(products[batchId].lastUpdated != 0, "Not exist");

        delete products[batchId];
        delete traceHistory[batchId];

        // Remove from the batchIds array
        for (uint i = 0; i < batchIds.length; i++) {
            if (keccak256(bytes(batchIds[i])) == keccak256(bytes(batchId))) {
                batchIds[i] = batchIds[batchIds.length - 1];
                batchIds.pop();
                break;
            }
        }
    }
}
