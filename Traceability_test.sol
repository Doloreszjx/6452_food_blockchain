// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "remix_tests.sol";        
import "../contracts/Traceability.sol";   

contract TraceabilityTest {
    Traceability t;

    // Fixed test data
    string  constant BATCH1     = "batch1";
    string  constant LOC1       = "loc1";
    string  constant PROD1      = "prod1";
    uint256 constant TS1        = 1000;
    int256  constant TEMP1      = 25;
    int256  constant HUM1       = 50;
    bytes32 constant HASH1      = keccak256(abi.encodePacked("data1"));

    /// Deploy a contract for use in all of the following tests.
    function beforeAll() public {
        t = new Traceability();
    }

    /// Initially, batchIds should be empty.
    function testInitialBatchIdsEmpty() public {
        string[] memory ids = t.getAllBatchIds();
        Assert.equal(ids.length, uint(0), "initial batchIds should be empty");
    }

    /// When the batch is not registered, requestOracleUpload must revert.
    function testRequestUploadNotRegisteredReverts() public {
        bool reverted = false;
        try t.requestOracleUpload(BATCH1) {
            // no-op
        } catch Error(string memory reason) {
            Assert.equal(reason, "Not registered", "requestOracleUpload must revert 'Not registered'");
            reverted = true;
        }
        Assert.ok(reverted, "requestOracleUpload did not revert on unknown batch");
    }

    /// Register a batch normally
    function testRegisterProduct() public {
        t.registerProduct(BATCH1);
        string[] memory ids = t.getAllBatchIds();
        Assert.equal(ids.length, uint(1), "batchIds length should be 1");
        Assert.equal(ids[0], BATCH1, "batchIds[0] should equal BATCH1");
    }

    function testRegisterDuplicateReverts() public {
        bool reverted = false;
        try t.registerProduct(BATCH1) {
        } catch Error(string memory reason) {
            Assert.equal(reason, "Already registered", "duplicate register must revert 'Already registered'");
            reverted = true;
        }
        Assert.ok(reverted, "duplicate register did not revert");
    }

    /// After registering, initiate an upload request. Do not revert.
    function testRequestUploadAfterRegisterSucceeds() public {
        t.requestOracleUpload(BATCH1);
    }

    function testGetTraceInfoNotFoundReverts() public {
        bool reverted = false;
        try t.getTraceInfo("noexist") {
        } catch Error(string memory reason) {
            Assert.equal(reason, "Not found", "getTraceInfo must revert 'Not found'");
            reverted = true;
        }
        Assert.ok(reverted, "getTraceInfo on unknown batch did not revert");
    }

    /// Check getTraceInfo to return the latest status.
    function testUploadDataAndGetTraceInfo() public {
        t.uploadData(BATCH1, TS1, TEMP1, HUM1, LOC1, PROD1, HASH1);
        ( string memory loc, int256 temp, uint256 lu ) = t.getTraceInfo(BATCH1);
        Assert.equal(loc, LOC1,   "location mismatch");
        Assert.equal(temp, TEMP1, "temp mismatch");
        Assert.equal(lu,   TS1,   "timestamp mismatch");
    }

    /// Check the history array
    function testGetTraceHistory() public {
        (
            uint256[] memory tss,
            int256[]  memory temps,
            int256[]  memory hums,
            string[]  memory locs,
            string[]  memory names,
            bytes32[] memory hashes
        ) = t.getTraceHistory(BATCH1);

        Assert.equal(tss.length,   uint(1),    "history length mismatch");
        Assert.equal(tss[0],       TS1,        "history ts mismatch");
        Assert.equal(temps[0],     TEMP1,      "history temp mismatch");
        Assert.equal(hums[0],      HUM1,       "history hum mismatch");
        Assert.equal(locs[0],      LOC1,       "history loc mismatch");
        Assert.equal(names[0],     PROD1,      "history name mismatch");
        Assert.equal(hashes[0],    HASH1,      "history hash mismatch");
    }

    /// After deleting the product, batchIds is empty, getTraceInfo revert
    function testDeleteProduct() public {
        t.deleteProduct(BATCH1);

        string[] memory ids = t.getAllBatchIds();
        Assert.equal(ids.length, uint(0), "batchIds should be empty after delete");

        bool reverted = false;
        try t.getTraceInfo(BATCH1) {
        } catch Error(string memory reason) {
            Assert.equal(reason, "Not found", "getTraceInfo deleted must revert 'Not found'");
            reverted = true;
        }
        Assert.ok(reverted, "getTraceInfo on deleted batch did not revert");
    }

    /// Delete the same batch again to revert (‘Not exist’)
    function testDeleteNotExistReverts() public {
        bool reverted = false;
        try t.deleteProduct(BATCH1) {
        } catch Error(string memory reason) {
            Assert.equal(reason, "Not exist", "deleteProduct must revert 'Not exist'");
            reverted = true;
        }
        Assert.ok(reverted, "deleteProduct on non-existent batch did not revert");
    }
}
