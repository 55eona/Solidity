// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.8.0;

contract CrowdFundcing {
    struct Investor {
        address addr;  // 투자자 주소
        uint amount;  // 투자액(wei 단위)
    }

    mapping (uint => Investor) public investors;  // 투자자 추가할 때, key 증가

    //fund() 호출될 때마다 이벤트(Funded) 발생
    event Funded(address indexed sender, uint amount);

    address public owner;  // 컨트랙트 소유자
    uint public numInvestors;  // 투자자 수
    uint public deadline;  // 마감일
    string public status;  // 모금활동 상태 (Funding, Campaign Succeeded, Campaign Failed)
    bool public ended;  // 모금 종료여부
    uint public goalAmount;  // 목표액 (ETH 단위)
    uint public totalAmount;  // 총 투자액

    // 소유자만 실행하게 하는 modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "Error: caller is now Owner");
        _;
    }
    
    constructor(uint _duration, uint _goalAmount) {
        owner = msg.sender;

        deadline = block.timestamp + _duration;
        goalAmount = _goalAmount * 1 ether;
        status = "Funding";
        ended = false;

        numInvestors = 0;  // 매핑 inventors의 인덱스로 사용 가능
        totalAmount = 0;
    }

    // 투자자가 투자할 때 호출하는 함수
    function fund() public payable{
        require(block.timestamp <= deadline, "Error: deadline is passed");  // 마감일 이전에만 실행 가능
        require(msg.value > 0, "Error: msg.value is 0");  // 투자금은 0보다 커야 함
        investors[numInvestors] = Investor(msg.sender, msg.value);
        // 투자자 수와 총 투자금액 추가해주기
        numInvestors += 1;
        totalAmount += msg.value;
        // fund() 호출됐으므로 이벤트 발생
        emit Funded(msg.sender, msg.value);
    }

    // 소유자가 모금을 종료할 때 호출하는 함수
    function checkGoalReached() public onlyOwner {
        
        require(block.timestamp >= deadline, "Error");  // 모금 마감 이후에만 실행 가능
        require(ended = false, "Error: status is ended");  // 모금 종료가 아닐 때만 실행 가능
        
        if (totalAmount >= goalAmount) {  // 모금 성공
            status = "Campaign Succeeded";
            payable(owner).transfer(totalAmount);  // 소유자에게 모금한 모든 이더 송금
        } else {  // 모금 실패
            status = "Campaign Failed";
            // 각 투자자에게 투자금 돌려줌
            for (uint i = 0; i < numInvestors; i++) {
                payable(investors[i].addr).transfer(investors[i].amount);
            }
        }
        // 모금 종료되었으니까 ended = true로 정의
        ended = true;
    }

    // 투자자 목록 조회: 주소타입의 배열 반환
   function getInvestors() public view returns (address[] memory) {
    address[] memory addrs = new address[](numInvestors);  // 투자자 수만큼 메모리 배열 생성
    // 배열에 투자자들의 주소 차례로 저장
    for (uint i = 0; i < numInvestors; i++) {
        addrs[i] = investors[i].addr;
    }
    return addrs;
}
}