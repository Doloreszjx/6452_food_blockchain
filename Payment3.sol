// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title SupplyChainPayment
 * @dev Facilitates secure payments between buyer and seller with an integrated arbitration mechanism.
 */
contract SupplyChainPayment {
    // Possible states of an order lifecycle
    enum OrderStatus { Created, Received, Completed, Disputed }

    /**
     * @dev Stores all relevant information for a single order
     * @param buyer Address of the purchaser
     * @param seller Address of the vendor
     * @param amount Net value (in wei) to be transferred to seller upon completion
     * @param quantity Number of items purchased
     * @param itemName Name or description of the purchased item
     * @param creationTime Timestamp when order was created
     * @param status Current state of the order
     * @param disputeRaised Flag indicating if a dispute has been filed
     * @param completionTime Timestamp when order was finalized
     */
    struct Order {
        address buyer;
        address seller;
        uint256 amount;
        uint256 quantity;
        string itemName;
        uint256 creationTime;
        OrderStatus status;
        bool disputeRaised;
        uint256 completionTime;
    }

    // Mapping from hashed order ID to Order struct
    mapping(bytes32 => Order) private orders;

    // Address authorized to resolve disputes
    address public arbitrator;

    // Fixed fee (in ether) paid to arbitrator per dispute
    uint256 public constant ARBITRATION_FEE = 0.001 ether;

    /**
     * @dev Emitted when a new order is created
     * @param orderId Unique identifier for the order
     * @param buyer Address of the purchaser
     * @param seller Address of the vendor
     * @param amount Funds reserved for seller (msg.value minus arbitration fee)
     * @param quantity Number of items ordered
     * @param itemName Description of the item
     */
    event OrderCreated(
        bytes32 indexed orderId,
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        uint256 quantity,
        string itemName
    );

    /**
     * @dev Emitted when payment is released to seller
     * @param orderId Identifier of the completed order
     * @param amount Funds transferred to seller
     */
    event PaymentReleased(bytes32 orderId, uint256 amount);

    /**
     * @dev Emitted when a dispute is raised by either party
     * @param orderId Identifier of the disputed order
     * @param raisedBy Address that initiated the dispute
     */
    event DisputeRaised(bytes32 orderId, address raisedBy);

    /**
     * @dev Emitted when arbitrator resolves a dispute
     * @param orderId Identifier of the resolved order
     * @param buyerWins True if buyer is refunded, false if seller receives funds
     */
    event DisputeResolved(bytes32 orderId, bool buyerWins);

    // Modifier to restrict function access to buyer or seller of a given order
    modifier onlyParticipant(bytes32 orderId) {
        require(
            msg.sender == orders[orderId].buyer || msg.sender == orders[orderId].seller,
            "Unauthorized participant"
        );
        _;
    }

    // Modifier to restrict call to the arbitrator only
    modifier onlyArbitrator() {
        require(msg.sender == arbitrator, "Unauthorized arbitrator");
        _;
    }

    /**
     * @dev Constructor sets the arbitrator address
     * @param _arbitrator Address responsible for dispute resolution
     */
    constructor(address _arbitrator) {
        require(_arbitrator != msg.sender, "Arbitrator cannot be the deployer");
        arbitrator = _arbitrator;
    }

    /**
     * @dev Converts a string-based ID into bytes32 hash
     * @param orderId String identifier provided by buyer
     * @return bytes32 Hashed order ID
     */
    function _toOrderId(string memory orderId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(orderId));
    }

    /**
     * @notice Creates a new order and locks funds in contract
     * @param orderId Unique string for this order
     * @param seller Address of the seller
     * @param quantity Number of items to purchase
     * @param itemName Description of the item
     * Requirements:
     * - Quantity must be positive
     * - Buyer must send value covering arbitration fee + item cost
     * - Arbitrator must not be buyer or seller
     */
    function createOrder(
        string memory orderId,
        address seller,
        uint256 quantity,
        string memory itemName
    ) external payable {
        require(quantity > 0, "Quantity must be greater than 0");
        require(bytes(itemName).length > 0, "Item name required");
        require(msg.value > ARBITRATION_FEE, "Must cover at least arbitration fee");
        require(arbitrator != address(0), "Arbitrator address cannot be zero");
        require(arbitrator != seller, "Arbitrator and seller cannot be the same");
        require(arbitrator != msg.sender, "Arbitrator and buyer cannot be the same");

        bytes32 oid = _toOrderId(orderId);
        require(orders[oid].buyer == address(0), "Order ID exists");

        // Net amount for seller after reserving arbitration fee
        uint256 amount = msg.value - ARBITRATION_FEE;

        orders[oid] = Order({
            buyer: msg.sender,
            seller: seller,
            amount: amount,
            quantity: quantity,
            itemName: itemName,
            creationTime: block.timestamp,
            status: OrderStatus.Created,
            disputeRaised: false,
            completionTime: 0
        });

        emit OrderCreated(oid, msg.sender, seller, amount, quantity, itemName);
    }

    /**
     * @notice Buyer confirms receipt of goods
     * @param orderId String ID of the order
     * Requirements:
     * - Only buyer can call
     * - Order must be in Created status
     */
    function confirmDelivery(string memory orderId) external {
        bytes32 oid = _toOrderId(orderId);
        Order storage order = orders[oid];

        require(msg.sender == order.buyer, "Only buyer can confirm");
        require(order.status == OrderStatus.Created, "Invalid order status");

        order.status = OrderStatus.Received;
    }

    /**
     * @notice Buyer releases payment to seller
     * @param orderId String ID of the order
     * Requirements:
     * - Only buyer can call
     * - Order must be in Received status
     * - No active dispute
     */
    function releasePaymentByBuyer(string memory orderId) external {
        bytes32 oid = _toOrderId(orderId);
        Order storage order = orders[oid];

        require(msg.sender == order.buyer, "Only buyer can release payment");
        require(order.status == OrderStatus.Received, "Order not in Received status");
        require(!order.disputeRaised, "Order under dispute");

        _releasePayment(oid);
    }

    /**
     * @notice Allows buyer or seller to raise a dispute
     * @param orderId String ID of the order
     * Requirements:
     * - Only buyer or seller can call
     * - Order must be in Created or Received status
     */
    function raiseDispute(string memory orderId) external {
        bytes32 oid = _toOrderId(orderId);
        Order storage order = orders[oid];

        require(
            msg.sender == order.buyer || msg.sender == order.seller,
            "Unauthorized participant"
        );
        require(
            order.status == OrderStatus.Created || order.status == OrderStatus.Received,
            "Invalid status"
        );

        order.status = OrderStatus.Disputed;
        order.disputeRaised = true;
        emit DisputeRaised(oid, msg.sender);
    }

    /**
     * @notice Arbitrator resolves an active dispute
     * @param orderId String ID of the order
     * @param buyerWins True to refund buyer, false to pay seller
     * Requirements:
     * - Only arbitrator can call
     * - Order must be in Disputed status
     */
    function resolveDispute(string memory orderId, bool buyerWins) external onlyArbitrator {
        bytes32 oid = _toOrderId(orderId);
        Order storage order = orders[oid];
        require(order.status == OrderStatus.Disputed, "No active dispute");

        if (buyerWins) {
            (bool sent1, ) = payable(order.buyer).call{value: order.amount}("");
            require(sent1, "Transfer to buyer failed");
        } else {
            (bool sent2, ) = payable(order.seller).call{value: order.amount}("");
            require(sent2, "Transfer to seller failed");
        }

        // Pay arbitration fee to arbitrator
        (bool sent, ) = payable(arbitrator).call{value: ARBITRATION_FEE}("");
        require(sent, "Transfer to arbitrator failed");

        order.disputeRaised = false;
        order.status = OrderStatus.Completed;
        order.completionTime = block.timestamp;

        emit DisputeResolved(oid, buyerWins);
    }

    /**
     * @dev Internal function to handle normal payment release workflow
     * @param orderId Bytes32 hash of order ID
     */
    function _releasePayment(bytes32 orderId) private {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.Received, "Payment not releasable");

        order.status = OrderStatus.Completed;
        order.completionTime = block.timestamp;

        // Transfer net amount to seller
        (bool sent1, ) = payable(order.seller).call{value: order.amount}("");
        require(sent1, "Transfer to seller failed");

        // Refund arbitration fee back to buyer
        (bool sent2, ) = payable(order.buyer).call{value: ARBITRATION_FEE}("");
        require(sent2, "Transfer to buyer failed");

        emit PaymentReleased(orderId, order.amount);
    }

    /**
     * @notice Retrieves order details by ID
     * @param orderId String identifier of the order
     * @return buyer Address of the purchaser
     * @return seller Address of the vendor
     * @return amount Net funds reserved for the seller (in wei)
     * @return quantity Number of items in the order
     * @return itemName Description of the purchased item
     * @return creationTime Timestamp when order was created
     * @return completionTime Timestamp when order was finalized
     * @return status Current status of the order
     * @return disputeRaised Flag indicating if a dispute was raised
     */
    function getOrderById(string memory orderId)
        external
        view
        returns (
            address buyer,
            address seller,
            uint256 amount,
            uint256 quantity,
            string memory itemName,
            uint256 creationTime,
            uint256 completionTime,
            OrderStatus status,
            bool disputeRaised
        )
    {
        bytes32 oid = _toOrderId(orderId);
        Order storage order = orders[oid];
        require(order.buyer != address(0), "Order not found");
        return (
            order.buyer,
            order.seller,
            order.amount,
            order.quantity,
            order.itemName,
            order.creationTime,
            order.completionTime,
            order.status,
            order.disputeRaised
        );
    }

    /**
     * @notice Returns only the status of an order
     * @param orderId String identifier of the order
     * @return status Current order status
     */
    function getOrderStatus(string memory orderId) external view returns (OrderStatus status) {
        status = orders[_toOrderId(orderId)].status;
    }
}
