// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdfundedInsurance {
    address public owner;
    address public actuary;
    mapping(address => bool) public adjusters;

    uint256 public policyCounter;
    uint256 public claimCounter;

    struct Policy {
        uint256 id;
        address policyHolder;
        string terms;
        uint256 premium;
        uint256 nextPaymentDue;
        bool isActive;
        bool isApproved;
    }

    struct Claim {
        uint256 id;
        uint256 policyId;
        address policyHolder;
        string description;
        uint256 amountRequested;
        bool isEvaluated;
        bool isApproved;
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;

    event PolicyProposed(uint256 policyId, address proposer);
    event PolicyApproved(uint256 policyId);
    event PolicyRejected(uint256 policyId);
    event PremiumPaid(uint256 policyId, uint256 amount);
    event ClaimSubmitted(uint256 claimId, uint256 policyId);
    event ClaimEvaluated(uint256 claimId, bool approved);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyActuary() {
        require(msg.sender == actuary, "Not the actuary");
        _;
    }

    modifier onlyAdjuster() {
        require(adjusters[msg.sender], "Not an adjuster");
        _;
    }

    constructor(address _actuary) {
        owner = msg.sender;
        actuary = _actuary;
    }

    function addAdjuster(address _adjuster) public onlyOwner {
        adjusters[_adjuster] = true;
    }

    function removeAdjuster(address _adjuster) public onlyOwner {
        adjusters[_adjuster] = false;
    }

    function proposePolicy(string memory _terms, uint256 _premium) public {
        policyCounter++;
        policies[policyCounter] = Policy({
            id: policyCounter,
            policyHolder: msg.sender,
            terms: _terms,
            premium: _premium,
            nextPaymentDue: block.timestamp + 30 days,
            isActive: false,
            isApproved: false
        });
        emit PolicyProposed(policyCounter, msg.sender);
    }

    function approvePolicy(uint256 _policyId) public onlyActuary {
        Policy storage policy = policies[_policyId];
        require(!policy.isApproved, "Policy already approved");
        policy.isApproved = true;
        policy.isActive = true;
        emit PolicyApproved(_policyId);
    }

    function rejectPolicy(uint256 _policyId) public onlyActuary {
        Policy storage policy = policies[_policyId];
        require(!policy.isApproved, "Policy already approved");
        policy.isActive = false;
        emit PolicyRejected(_policyId);
    }

    function payPremium(uint256 _policyId) public payable {
        Policy storage policy = policies[_policyId];
        require(policy.policyHolder == msg.sender, "Not the policy holder");
        require(policy.isApproved, "Policy not approved");
        require(policy.isActive, "Policy is not active");
        require(msg.value == policy.premium, "Incorrect premium amount");
        require(block.timestamp <= policy.nextPaymentDue, "Payment overdue");

        policy.nextPaymentDue = block.timestamp + 30 days;
        emit PremiumPaid(_policyId, msg.value);
    }

    function submitClaim(uint256 _policyId, string memory _description, uint256 _amountRequested) public {
        Policy storage policy = policies[_policyId];
        require(policy.policyHolder == msg.sender, "Not the policy holder");
        require(policy.isActive, "Policy is not active");

        claimCounter++;
        claims[claimCounter] = Claim({
            id: claimCounter,
            policyId: _policyId,
            policyHolder: msg.sender,
            description: _description,
            amountRequested: _amountRequested,
            isEvaluated: false,
            isApproved: false
        });
        emit ClaimSubmitted(claimCounter, _policyId);
    }

    function evaluateClaim(uint256 _claimId, bool _approve) public onlyAdjuster {
        Claim storage claim = claims[_claimId];
        require(!claim.isEvaluated, "Claim already evaluated");

        claim.isEvaluated = true;
        claim.isApproved = _approve;

        if (_approve) {
            payable(claim.policyHolder).transfer(claim.amountRequested);
        }

        emit ClaimEvaluated(_claimId, _approve);
    }

    // Function to check and deactivate policies with overdue payments
    function checkPolicyStatus(uint256 _policyId) public {
        Policy storage policy = policies[_policyId];
        if (block.timestamp > policy.nextPaymentDue) {
            policy.isActive = false;
        }
    }

    // Fallback function to receive Ether
    receive() external payable {}
}