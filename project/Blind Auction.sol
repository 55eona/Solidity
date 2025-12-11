// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;


// 블라인드 경매 위한 해시값
contract Khash {
    bytes32 public hashedValue;

    function hashMe(uint value, bytes32 passward) public {
        hashedValue = keccak256(abi.encodePacked(value, passward));
    }
}

contract BlindAuction {
    struct Bid {
        bytes32 blindBid;
        uint deposit;
    }

    // Init-0; Bidding-1; Reveal-2; Done-3
    enum Phase {Init, Bidding, Reveal, Done}

    // 소유자
    address payable public beneficiary;

    // 최고 입찰가, 입찰자
    address public highestBidder;
    uint public highestBid = 0;

    // 입찰자의 입찰 해시값과 예치금에 대한 매핑
    mapping(address => Bid) public bids;

    // 입찰금 반환을 위한 매핑
    mapping(address => uint) pendingReturns;

    // Events
    event AuctionEnded(address winner, uint highestBid);
    event BiddingStarted();
    event RevealStarted();
    event AuctionInit();

    Phase public currentPhase = Phase.Init;

    // Modifiers
    // 경매 단계별로 실행 가능한 함수 제한하는 Modifier
    modifier onlyPhase(Phase _phase) {
        require(currentPhase==_phase, "Invalid phase");
        _;
    }

    // 소유자만 실행 가능하게 제어하는 Modifier
    modifier onlyBeneficiary {
        require(msg.sender==beneficiary, "Only Beneficiary");
        _;
    }

    constructor() {
        beneficiary = payable(msg.sender);
        emit AuctionInit();
    }

    // 경매 단계 변경, 각 단계에 맞게 이벤트 발생
    // Move to next phase 버튼
    function advancePhase() public onlyBeneficiary {
        if  (currentPhase == Phase.Init) { 
            currentPhase = Phase.Bidding;
            emit BiddingStarted();
        } else if (currentPhase == Phase.Bidding) {
            currentPhase = Phase.Reveal;
            emit RevealStarted();
        } else {
            revert("Cannot advance phase further");
        }
    }

    // 입찰 정보 저장
    function bid(bytes32 blindBid) public payable onlyPhase(Phase.Init) {
        require(blindBid != bytes32(0), "Blind bid hash is required");
        
        // 최소 예치금: 1 ether
        require(msg.value > 1 ether, "Deposit must be at least 1 ether");

        // 입찰자는 한번씩만 입찰 가능
        require(bids[msg.sender].deposit == 0, "Bid already submitted");

        bids[msg.sender].blindBid = blindBid;
        bids[msg.sender].deposit = msg.value;

    }

    // 입찰가와 비밀번호 확인
    // 예치금에서 입찰가 뺀 나머지 되돌려준다
    // 최고 입찰가 비교
    // 최고 입찰가보다 작으면 입찰 탈락자의 입찰금 반환을 위한 매핑 추가
    function reveal(uint value, bytes32 secret) public onlyPhase(Phase.Bidding) {
        uint _value = bids[msg.sender].deposit;
        bytes32 _secret = bids[msg.sender].blindBid;

        // 경매 참여한 입찰자만
        require(_value>0, "No bid to reveal");
        
        // 비밀번호가 맞는지
        if (keccak256(abi.encodePacked(value, secret)) != _secret) {
            pendingReturns[msg.sender] += _value;
            // 같은 예치금으로 다시 시도 못하게 초기화
            _value = 0;

        } else {
            // 예치금이 실제 입찰가 이상이라면 유효 입찰로 인정
            if (_value >= value) {
                // 최고 입찰가 갱신
                if (value > highestBid) {
                    // 이전 최고 입찰자에게는 입찰가만큼 돌려줘야 함
                    if (highestBidder != address(0)) {
                        pendingReturns[highestBidder] += highestBid;
                    }
                    highestBid = value;
                    highestBidder = msg.sender;

                    // 낙찰 후보자의 예치금 중 입찰가만큼은 계약에 남기고 나머지 환불
                    pendingReturns[msg.sender] += (_value - value);
                } 
            
                else {
                    // 최고 입찰가보다 작으면 전액 환불(refund=_value 그대로)
                    pendingReturns[msg.sender] += _value;
                }

                _value = 0;
            }

        }
    }


    // 소유자에게 가장 높은 입찰가 보내고, 경매 종료
    function auctionEnd() public onlyPhase(Phase.Reveal) {
        currentPhase = Phase.Done;
        emit AuctionEnded(highestBidder, highestBid);

        if(highestBid > 0) {
            beneficiary.transfer(highestBid);
        }
        // uint amount = pendingReturns[highestBidder];
        // payable(highestBidder).transfer(amount);            
    }

    // 낙찰되지 않은 입찰금 반환
    // withdraw 버튼
    function withdraw() public onlyPhase(Phase.Done) {
        
        uint amount = pendingReturns[msg.sender];

        // 경매 참여한 입찰자만 출금 가능
        require(amount>0, "Nothing to withdraw");
        // require(auctionParticipants[msg.sender], "You are not a participant");
        
        // 새로운 기능: 재진입 방지
        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}