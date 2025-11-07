// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 < 0.8.0;

contract Bank {
    // 사용자별 주소 및 잔고 관리 (매핑 활용)
    mapping(address => uint256) public balances;

    // 배포자 주소 저장
    address private owner;  

    event Deposit(address _account, uint256 _deposit);     // 임금 시 이벤트 (주소와 금액 기록)
    event Withdrawal(address _account, uint256 _withdrawal);    // 주소와 금액

    // 배포 시, 배포자 주소 owner에 저장
    constructor() {
        owner = msg.sender; 
    }
    // owner가 아닐 경우, error 발생
    modifier onlyOwner() {
        require(owner == msg.sender, "Error: caller is now Owner");
        _;
    }

    // 본인 계좌에서 이더를 입금 Deposit 이벤트 
    function deposit() public payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);  // Deposit 이벤트 발생
    }

    // 본인 계좌에서 이더를 출금
    function withdraw(uint256 amount) public {
        require(address(this).balance >= amount, "Error: contract balance < amount");  // 예금보다 큰 금액 출금 불가
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);  // Withdrawal 이벤트 발생
    }

    // 호출자(사용자) 본인의 계좌 잔고 확인
    function getBalance() public view returns(uint256) {
        return balances[msg.sender];
    }

    // 컨트랙트 잔고 확인, 소유자에게만 허용
    function getContractBalance() public view onlyOwner returns(uint256) {
        return address(this).balance;
    }
}