// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EscrowContract {
    IDAO public daoContract;
    address payable public daoTreasury;
    enum DisputeStatus { NoDispute, Raised, Resolved }

    struct ServiceAgreement {
        address payable seller;
        address payable buyer;
        uint256 price;
        uint256 sellerFee;
        uint256 buyerFee;
        bool isCompleted;
        bool fundsDisbursed;
        DisputeStatus disputeStatus;
    }

    mapping(uint256 => ServiceAgreement) public agreements;

    // Event declarations
    event FundsDeposited(uint256 indexed serviceId, uint256 amount, address indexed buyer);
    event FundsReleased(uint256 indexed serviceId, uint256 amount, address indexed seller);
    event RefundIssued(uint256 indexed serviceId, uint256 amount, address indexed buyer);
    event DisputeRaised(uint256 indexed serviceId, address indexed raiser);
    event DisputeResolved(uint256 indexed serviceId, bool refunded);

    uint256 constant MIN_FEE = 5 * 10**18;  // 5 xDai in wei
    uint256 constant MAX_FEE = 10 * 10**18; // 10 xDai in wei
    uint256 constant FEE_PERCENTAGE = 2;    // 2%

     constructor(address _daoAddress) {
        daoContract = IDAO(_daoAddress);
    }

    function calculateFee(uint256 amount) public pure returns (uint256) {
        uint256 fee = amount * FEE_PERCENTAGE / 100;
        if (fee < MIN_FEE) {
            return MIN_FEE;
        }
        if (fee > MAX_FEE) {
            return MAX_FEE;
        }
        return fee;
    }

    function depositFunds(uint256 serviceId, address payable seller) external payable {
        require(agreements[serviceId].buyer == address(0), "Service ID already in use");
        
        uint256 fee = calculateFee(msg.value);
        uint256 totalAmount = msg.value + fee;      
        require(totalAmount > 0, "Total amount must be greater than 0"); //do we still need this?
        require(totalAmount > msg.value, "Total amount must be greater than the service amount");

        agreements[serviceId] = ServiceAgreement({
            seller: seller,
            buyer: payable(msg.sender),
            price: msg.value,
            sellerFee: 0,
            buyerFee: fee,
            isCompleted: false,
            fundsDisbursed: false,
            disputeStatus: DisputeStatus.NoDispute
        });

        // Transfer fee to DAO treasury
        daoTreasury.transfer(fee);

        emit FundsDeposited(serviceId, msg.value, msg.sender);
    }

    function depositSellerFee(uint256 serviceId) external payable {
        ServiceAgreement storage agreement = agreements[serviceId];
        require(msg.sender == agreement.seller, "Only the seller can deposit the fee");
        require(agreement.sellerFee == 0, "Fee already deposited");
        
        uint256 fee = calculateFee(agreement.price);
        require(msg.value == fee, "Incorrect fee amount");

        agreement.sellerFee = fee;
        // Transfer seller's fee to DAO treasury
        daoTreasury.transfer(fee);
    }

    function releaseFunds(uint256 serviceId) external {
        ServiceAgreement storage agreement = agreements[serviceId];

        require(msg.sender == agreement.buyer, "Only the buyer can release funds");
        require(agreement.disputeStatus != DisputeStatus.Raised, "Dispute raised, cannot release funds");
        require(agreement.price > 0, "No funds to release");
        require(!agreement.isCompleted, "Service already completed");
        require(!agreement.fundsDisbursed, "Funds already disbursed");

        agreement.isCompleted = true;
        agreement.fundsDisbursed = true;
        agreement.seller.transfer(agreement.price);

        emit FundsReleased(serviceId, agreement.price, agreement.seller);
    }

    function refundBuyer(uint256 serviceId) external {
        ServiceAgreement storage agreement = agreements[serviceId];

        require(msg.sender == agreement.buyer, "Only the buyer can request a refund");
        require(agreement.disputeStatus != DisputeStatus.Raised, "Dispute raised, cannot refund");
        require(agreement.price > 0, "No funds to refund");
        require(!agreement.isCompleted, "Service already completed");
        require(!agreement.fundsDisbursed, "Funds already disbursed");

        agreement.fundsDisbursed = true;
        agreement.buyer.transfer(agreement.price);

        emit RefundIssued(serviceId, agreement.price, agreement.buyer);
    }

    function raiseDispute(uint256 serviceId) external {
        ServiceAgreement storage agreement = agreements[serviceId];
        require(msg.sender == agreement.buyer || msg.sender == agreement.seller, "Only parties involved can raise a dispute");
        require(agreement.disputeStatus == DisputeStatus.NoDispute, "Dispute already raised");

        agreement.disputeStatus = DisputeStatus.Raised;
        emit DisputeRaised(serviceId, msg.sender);
    }

    function resolveDispute(uint256 serviceId, bool _refundBuyer) external {
        require(msg.sender == address(daoContract), "Only DAO can resolve disputes");
        ServiceAgreement storage agreement = agreements[serviceId];
        require(agreement.disputeStatus == DisputeStatus.Raised, "No dispute raised for this service");

        agreement.disputeStatus = DisputeStatus.Resolved;
        if (_refundBuyer) {
            agreement.buyer.transfer(agreement.price);
            emit RefundIssued(serviceId, agreement.price, agreement.buyer);
        } else {
            agreement.seller.transfer(agreement.price);
            emit FundsReleased(serviceId, agreement.price, agreement.seller);
        }
        agreement.fundsDisbursed = true;
        agreement.isCompleted = true;

        emit DisputeResolved(serviceId, _refundBuyer);
    }
}