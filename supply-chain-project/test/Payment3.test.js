const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SupplyChainPayment Contract", function () {
  let SupplyChainPayment, scp;
  let buyer, seller, arbitrator;
  let orderAmount, quantity, itemName;

  // Deploy a fresh contract before each test
  beforeEach(async function () {
    [buyer, seller, arbitrator] = await ethers.getSigners();

    // In Ethers v6, parseEther returns a bigint
    orderAmount = ethers.parseEther("1.0"); // 1 ETH as order amount
    quantity = 10; // default order quantity
    itemName = "Beef";

    SupplyChainPayment = await ethers.getContractFactory("SupplyChainPayment");
    scp = await SupplyChainPayment.connect(buyer).deploy(arbitrator.address);
    // deploy() automatically waits for transaction confirmation
  });

  /**
   * Utility function to find and parse a specific event from transaction receipt
   * @param {Object} receipt - Transaction receipt containing logs
   * @param {string} eventName - Name of the event to find
   * @returns {Object|null} Parsed event object or null if not found
   */
  function findEvent(receipt, eventName) {
    for (const log of receipt.logs) {
      try {
        const parsed = scp.interface.parseLog(log);
        if (parsed.name === eventName) {
          return parsed;
        }
      } catch (e) {
        // Not the event we're looking for
      }
    }
    return null;
  }

  it("should create an order and emit OrderCreated event", async function () {
    const orderId = "order1";
    const arbitrationFee = await scp.ARBITRATION_FEE();
    const totalValue = orderAmount + arbitrationFee; // combine order amount and arbitration fee

    // Send transaction to create the order (including itemName)
    const tx = await scp
      .connect(buyer)
      .createOrder(orderId, seller.address, quantity, itemName, { value: totalValue });
    const receipt = await tx.wait();

    // Verify that the OrderCreated event was emitted
    const event = findEvent(receipt, "OrderCreated");
    expect(event, "OrderCreated event not found").to.exist;

    // Check event parameters
    const expectedId = ethers.keccak256(ethers.toUtf8Bytes(orderId)); // keccak256 hash of orderId string
    expect(event.args.orderId).to.equal(expectedId);
    expect(event.args.buyer).to.equal(buyer.address);
    expect(event.args.seller).to.equal(seller.address);
    expect(event.args.amount).to.equal(orderAmount);
  });

  it("buyer can confirm delivery and release payment, status should be Completed", async function () {
    const orderId = "order2";
    const arbitrationFee = await scp.ARBITRATION_FEE();
    const totalValue = orderAmount + arbitrationFee;

    // Create order (including itemName)
    await scp
      .connect(buyer)
      .createOrder(orderId, seller.address, quantity, itemName, { value: totalValue });

    await scp.connect(buyer).confirmDelivery(orderId);
    await scp.connect(buyer).releasePaymentByBuyer(orderId);

    // Verify order status = Completed (enum value 2)
    const status = await scp.getOrderStatus(orderId);
    expect(status).to.equal(2n);
  });

  it("seller can raise a dispute and emit DisputeRaised event", async function () {
    const orderId = "order3";
    const arbitrationFee = await scp.ARBITRATION_FEE();
    const totalValue = orderAmount + arbitrationFee;

    // Create order with itemName
    await scp.connect(buyer).createOrder(orderId, seller.address, quantity, itemName, { value: totalValue });

    // Seller raises dispute
    const tx = await scp.connect(seller).raiseDispute(orderId);
    const receipt = await tx.wait();

    // Verify DisputeRaised event
    const event = findEvent(receipt, "DisputeRaised");
    expect(event, "DisputeRaised event not found").to.exist;

    // Check event parameters
    const expectedId = ethers.keccak256(ethers.toUtf8Bytes(orderId));
    expect(event.args.orderId).to.equal(expectedId);
    expect(event.args.raisedBy).to.equal(seller.address);

    // Verify status = Disputed (enum value 3)
    const status = await scp.getOrderStatus(orderId);
    expect(status).to.equal(3n);
  });

  it("arbitrator can resolve dispute and status becomes Completed", async function () {
    const orderId = "order4";
    const arbitrationFee = await scp.ARBITRATION_FEE();
    const totalValue = orderAmount + arbitrationFee;

    // Create order and raise dispute
    await scp.connect(buyer).createOrder(orderId, seller.address, quantity, itemName, { value: totalValue });
    await scp.connect(buyer).raiseDispute(orderId);

    // Arbitrator resolves dispute in favor of buyer
    await scp.connect(arbitrator).resolveDispute(orderId, true);

    // Verify status = Completed
    const status = await scp.getOrderStatus(orderId);
    expect(status).to.equal(2n);
  });

  it("non-participants should be reverted when calling sensitive functions", async function () {
    const orderId = "order5";
    const arbitrationFee = await scp.ARBITRATION_FEE();
    const totalValue = orderAmount + arbitrationFee;

    // Create order (including itemName)
    await scp.connect(buyer).createOrder(orderId, seller.address, quantity, itemName, { value: totalValue });

    // Attempt to confirm delivery by non-buyer
    try {
      await scp.connect(arbitrator).confirmDelivery(orderId);
      expect.fail("confirmDelivery did not revert");
    } catch (err) {
      expect(err.message).to.include("Only buyer can confirm");
    }

    // Attempt to release payment by non-buyer
    try {
      await scp.connect(arbitrator).releasePaymentByBuyer(orderId);
      expect.fail("releasePaymentByBuyer did not revert");
    } catch (err) {
      expect(err.message).to.include("Only buyer can release payment");
    }
  });
});
