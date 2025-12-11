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

    // 추가 이벤트
    event BidSubmitted(address bidder, bytes32 blindBid, uint amount);
    event BidRevealed(address bidder, bool hash, uint value, bool highest);
    event Withdrawal(address bidder, uint amount, bool highest);

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

    // 최소 상승폭
    uint public bidStep = 0.1 ether;

    uint public bidDur;
    uint public revealDur;
    uint public bidEnd;
    uint public revealEnd;

    constructor(uint _bidHours, uint _revealHours) {
        beneficiary = payable(msg.sender);

        bidDur = _bidHours * 1 hours;
        revealDur = _revealHours * 1 hours;

        emit AuctionInit();
    }


    // 경매 단계 변경, 각 단계에 맞게 이벤트 발생
    // Move to next phase 버튼
    function advancePhase() public onlyBeneficiary {

        if  (currentPhase == Phase.Init) { 
            currentPhase = Phase.Bidding;
            bidEnd = block.timestamp + bidDur;
            emit BiddingStarted();

        } else if (currentPhase == Phase.Bidding) {
            currentPhase = Phase.Reveal;
            bidEnd = 0;
            revealEnd = block.timestamp + revealDur;
            emit RevealStarted();

        } else if (currentPhase == Phase.Reveal) {
            currentPhase = Phase.Done;
            revealEnd = 0;
            emit AuctionEnded(highestBidder, highestBid);

        } else {
            revert("Cannot advance phase further");
        }
    }


    // 입찰 정보 저장
    function bid(bytes32 blindBid) public payable onlyPhase(Phase.Bidding) {
        require(blindBid != bytes32(0), "Blind bid hash is required");
        require(block.timestamp<bidEnd, "Bidding time over");
        
        // 최소 예치금: 1 ether
        require(msg.value >= 1 ether, "Deposit must be at least 1 ether");

        // 입찰자는 한번씩만 입찰 가능
        require(bids[msg.sender].deposit == 0, "Bid already submitted");

        bids[msg.sender].blindBid = blindBid;
        bids[msg.sender].deposit = msg.value;
        
        emit BidSubmitted(msg.sender, blindBid, msg.value);

    }

    // 입찰가와 비밀번호 확인
    // 예치금에서 입찰가 뺀 나머지 되돌려준다
    // 최고 입찰가 비교
    // 최고 입찰가보다 작으면 입찰 탈락자의 입찰금 반환을 위한 매핑 추가
    function reveal(uint value, bytes32 secret) public onlyPhase(Phase.Reveal) {
        require(block.timestamp<revealEnd, "Reveal time over");

        uint _value = bids[msg.sender].deposit;
        bytes32 _secret = bids[msg.sender].blindBid;
        uint amount = value * 1 ether;

        // 경매 참여한 입찰자만
        require(_value>0, "No bid to reveal");
        
        // 해시값이 맞는지
        if (keccak256(abi.encodePacked(value, secret)) != _secret) {
            // 해시값이 틀리면, 예치금 돌려주기
            pendingReturns[msg.sender] += _value;
            // 같은 예치금으로 다시 시도 못하게 초기화
            bids[msg.sender].deposit = 0;
            emit BidRevealed(msg.sender, false, amount, false);

        } else {
            // 예치금이 실제 입찰가 이상이라면 유효 입찰로 인정
            if (_value >= amount) {

                // 최고 입찰가 갱신
                // 최고 입찰가 중복일 때 → 먼저 입력한 사람한테 낙찰
                if (amount > highestBid + bidStep) {

                    // 이전 최고 입찰자에게는 입찰가만큼 돌려주기
                    if (highestBidder != address(0)) {
                        pendingReturns[highestBidder] += highestBid;
                    }
                    highestBid = amount;
                    highestBidder = msg.sender;

                    // 낙찰 후보자의 예치금 중 입찰가만큼은 계약에 남기고 나머지 환불
                    pendingReturns[msg.sender] += (_value - amount);

                    emit BidRevealed(msg.sender, true, amount, true);

                } 
                else {
                    // 최고 입찰가(+최소 상승폭)보다 작으면 전액 환불(refund=_value 그대로)
                    pendingReturns[msg.sender] += _value;

                    emit BidRevealed(msg.sender, true, amount, false);
                }

                // 재진입 방지를 위한 초기화
                bids[msg.sender].deposit = 0;
                bids[msg.sender].blindBid = 0;
            } else {
                
                // 유효 입찰이 아니면, 예치금 돌려주기
                pendingReturns[msg.sender] += _value;
                // 같은 예치금으로 다시 시도 못하게 초기화
                bids[msg.sender].deposit = 0;
                emit BidRevealed(msg.sender, true, amount, false);
            }
        }
    }


    // 소유자(수혜자)에게 가장 높은 입찰가를 보내고 경매를 종료
    // Show winning bid 버튼
    function auctionEnd() public onlyBeneficiary {
        // Reveal 단계 이후에만 강제 종료 허용
        require(
            currentPhase == Phase.Reveal || currentPhase == Phase.Done,
            "Auction not ready to end"
        );

        // 상태를 Done으로 고정
        currentPhase = Phase.Done;

        emit AuctionEnded(highestBidder, highestBid);

        if (highestBid > 0) {
            beneficiary.transfer(highestBid);
        }
    }


    // 낙찰되지 않은 입찰금 반환
    // withdraw 버튼
    function withdraw() public onlyPhase(Phase.Done) {
        
        uint amount = pendingReturns[msg.sender];

        // 경매 참여한 입찰자만 출금 가능
        require(amount>0, "Nothing to withdraw");
        
        if (msg.sender == highestBidder) {
            emit Withdrawal(msg.sender, amount, true);
        } else {
            emit Withdrawal(msg.sender, amount, false);
        }

        // 새로운 기능: 재진입 방지
        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}