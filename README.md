# Food/agriculture supply chain(meat and fresh produce sector)

This project is a food traceability system based on blockchain technology, aiming to enhance the transparency and security of the supply chain through smart contracts. The project includes the functions of the traceability and payment systems, and achieves data tracking by combining distributed storage technology.

## Project Structure
```
6452_food_blockchain/
├── traceability_backend/      # Python backend modules and scripts
│   ├── create_db.py           # Database initialisation script
│   ├── data_cleaner.py        # Data cleaning script
│   ├── gateway.py             # Gateway service script
│   ├── get_trace_history.py   # Get trace history script
│   ├── publish_test.py        # Data publishing test script
│   ├── publish_to_chain.py    # Data publishing to blockchain script
│   ├── show_db.py             # Display database content script
│   ├── upload_to_ipfs.py      # Upload data to IPFS script
│   ├── abi.json               # Smart contract ABI file
│   ├── .env                   # Environment variable configuration file

├── supply-chain-project/      # Payment3 smart contract test code
├── Payment3.sol               # Supply chain payment contract file
├── Traceability.sol           # Traceability function contract file
├── Traceability_test.sol      # Traceability function test file
├── index.html                 # Project-related HTML file
```
---

## Function Introduction
### Traceability.sol Contract Introduction

`Traceability.sol` is one of the core smart contracts in the project, mainly used to implement food traceability functions, providing the following capabilities:

1. **Product Registration**:
   - Use the `registerProduct` method to register a new product batch (`batchId`).
   - Record the product registration time through the `ProductRegistered` event.

2. **Data Upload Request**:
   - Use the `requestOracleUpload` method to trigger an off-chain data upload request.
   - Notify the Oracle to perform data upload via the `RequestDataUpload` event.

3. **Data Upload**:
   - Use the `uploadData` method to store product tracking information on-chain, including location, temperature, humidity, product name, etc.
   - Record the uploaded data content via the `DataUploaded` event.

4. **Query Latest Status**:
   - Use the `getTraceInfo` method to query the latest status of the product (location, temperature, last update time).

5. **Query trace history**:
   - Use the `getTraceHistory` method to obtain the complete trace history of the product, including timestamps, temperature, humidity, location, product name, and data hash.

6. **Batch management**:
   - Use the `getAllBatchIds` method to obtain all registered batch IDs.
   - Use the `deleteProduct` method to delete the product and its traceability records for a specified batch.

#### Events in the contract
- **`ProductRegistered`**: Records the registration time of the product batch.
- **`RequestDataUpload`**: Triggers an off-chain data upload request.
- **`DataUploaded`**: Records the content of the uploaded data.

---

### Payment3.sol Contract Introduction

`Payment3.sol` is the supply chain payment contract in the project, designed to provide secure payment functionality for buyers and sellers and integrate a dispute resolution mechanism. The contract primarily includes the following features:

1. **Order Creation**:
   - Use the `createOrder` method to create an order and lock funds.
   - Record order information via the `OrderCreated` event, including buyer, seller, order amount, product name, etc.

2. **Order Confirmation and Payment**:  
   - The buyer uses the `confirmDelivery` method to confirm receipt of the goods.  
   - The buyer uses the `releasePaymentByBuyer` method to release payment to the seller.
   - Record payment information via the `PaymentReleased` event.

3. **Dispute Resolution**:  
   - The buyer or seller uses the `raiseDispute` method to raise a dispute.  
   - The arbitrator uses the `resolveDispute` method to resolve the dispute and decide the flow of funds (buyer refund or seller payment).
   - Record the dispute status and outcome using the `DisputeRaised` and `DisputeResolved` events.

4. **Order Query**:  
   - Use the `getOrderById` method to query order details.  
   - Use the `getOrderStatus` method to query the order status.

#### Events in the contract
- **`OrderCreated`**: Records order creation information.
- **`PaymentReleased`**: Records payment completion information.
- **`DisputeRaised`**: Records the initiation of a dispute.
- **`DisputeResolved`**: Records the resolution status and outcome of a dispute.

#### Unique Features of the Contract
- **Funds Escrow**: The contract locks the buyer's funds to ensure the seller receives payment after fulfilling the order.
- **Arbitration Mechanism**: Disputes between buyers and sellers are resolved through an arbitrator, enhancing transaction security.
- **Event Logging**: All operations are recorded on the blockchain via events, ensuring transparency and traceability.

---

### Python backend modules and scripts
#### Data Cleaning and Processing
- **Clean up abnormal data**: Run the `data_cleaner.py` script to clean up abnormal values in the supply chain data and ensure data integrity.

#### Database Operations
- **Create a database**: Use `create_db.py` to initialise the database to store traceability data.
- **Display database content**: Use `show_db.py` to view the data in the database.

#### Data Publication and Tracking
- **Publish Data to Blockchain**: Run the `publish_to_chain.py` script to publish supply chain data to the blockchain.
- **Query Trace History**: Run `get_trace_history.py` to query trace history in the blockchain.

#### IPFS Support
- **Upload Data to IPFS**: Run `upload_to_ipfs.py` to store data in the distributed file system IPFS.

#### Gateway Service
- **Provide Gateway Service**: Run `gateway.py` to enable data interaction between the backend and the blockchain.

---

## Environment Requirements

- Docker
- Python 3.x
- IPFS
- Mosquitto MQTT Broker

---
## Instructions
### Python backend modules and scripts (traceability_backend/)
#### Mosquitto certificate download
First, you need to download the Mosquitto certificate for MQTT connection.

#### 1  IPFS initialisation
You need to initialise IPFS the first time you use it:
```bash
ipfs init
```

#### 2. Start the IPFS daemon
```bash
ipfs daemon
```

#### 3. Start the gateway service
```bash
python3 gateway.py
```

#### 4. Start the data cleaner
```bash
python3 data_cleaner.py
```

#### 5. Start the IPFS upload service
```bash
python3 upload_to_ipfs.py
```

### Data operation process

### Transfer data
Use the test script to transfer data:
```bash
python3 publish_test.py
```

#### Database operations
Data storage consists of three steps:

1. **Create a database**
```bash
   python3 create_db.py
   ```

2. **Upload to IPFS**
   ```bash
   python3 upload_to_ipfs.py
   ```

3. **Publish to the blockchain**
   ```bash
   python3 publish_to_chain.py
   ```

---

### Supply-chain-project/ (Payment3 smart contract test code)

#### 1. Install dependencies
Enter the `supply-chain-project` directory and install Hardhat and related dependencies:
```bash
cd supply-chain-project
npm install
```

#### 2. Start the local test network
```bash
npx hardhat node
```

#### 3. Compile smart contracts
```bash
npx hardhat compile
```

#### 4. Deploy the smart contract
Use the deployment script to deploy the contract to the local network:
```bash
npx hardhat run scripts/deploy.js --network localhost
```

#### 5. Test the smart contract
Run the test script to verify the contract functionality:
```bash
npx hardhat test
```

---

## Project Technology Stack

- **Blockchain**: Ethereum
- **Smart Contract Development**: Solidity, Hardhat
- **Distributed Storage**: IPFS
- **Backend Development**: Python
- **Message Queuing**: MQTT
- **Containerisation**: Docker

---

## Contribution

HD_plz </br>
Jiaxiao Han z5568557 </br>
Jiaxin Zhang z5491108 </br>
Mingxuan Zhang z5542095 </br>
Yichen Bai z5339365 </br>
Yinan Cai z5547906 </br>











