// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 < 0.8.0;

contract ERC20StdToken {
    // 각 계정이 소유한 토큰 수 저장
    mapping (address => uint256) balances;

    // 각 계정이 다른 계정들이 대리 전송할 수 있도록 허용한 토큰 수 저장
    mapping (address => mapping (address => uint256)) allowed;

    uint256 private total;  // 총 발행 토큰 수
    string public name;  // 토큰 이름
    string public symbol;  // 토큰 심볼
    uint8 public decimals;  // 토큰의 소수점 자리수

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);


    constructor(string memory _name, string memory _symbol, uint _totalSupply) {
        total = _totalSupply;
        name = _name;
        symbol = _symbol;
        decimals = 0;
        // 전체 발행량(_totalSupply)을 배포자에게 지급
        balances[msg.sender] = _totalSupply;
        emit Transfer(address(0x0), msg.sender, _totalSupply);
    }

    // 발행한 총 토큰 수 조회
    function totalSupply() public view returns (uint256) {
        return total;
    }

    // _owner가 소유한 토큰 수 반환
    function balanceOf (address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    // _spender가 _owner로부터 대리 인출할 수 있는 토큰 수 반환
    function allowance (address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    // 직접 전송
    function transfer(address _to, uint256 _value) public returns (bool success) {
        // 잔액 검증
        require(balances[msg.sender]>=_value, "Not enough balance");
        // 0(zero) 전송도 일반적인 전송으로 처리??

        //overflow 검사
        if (balances[_to]+_value >= balances[_to]) {
            
            // 토큰 이전 (from 잔액 조정)
            balances[msg.sender] -= _value;
            
            // 토큰 이전(to 잔액 조정)
            balances[_to] += _value;
            
            // 이벤트 발생
            emit Transfer(msg.sender, _to, _value);
            return true;
        }
        else {
            return false;
        }
    }

    //위임 전송
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // _from에게 토큰이 충분해야 함
        require(balances[_from]>=_value, "Not enough balance");
        // _from이 msg.sender에게 허용한 토큰 양(allowance)이 충분해야 함
        require(allowed[_from][msg.sender]>=_value, "Not enough allowance");


        // overflow 검사
        if (balances[_to]+_value >= balances[_to]) {
            
            // 토큰 이전 (from 잔액 조정)
            balances[_from] -= _value;

            // 토큰 이전(to 잔액 조정)
            balances[_to] += _value;

            // 토큰 이전 (allowance 잔액 조정)
            allowed[_from][msg.sender] -= _value;

            // 이벤트 발생
            emit Transfer(_from, _to, _value);
            return true;
        }
        else {
            return false;
        } 
    }

    // 특정 주소에게 토큰 사용 권한 부여
    function approve(address _spender, uint256 _value) public returns (bool success) {
        // _value만큼 인출할 수 있는 권한 _spender에게 위임
        allowed[msg.sender][_spender] = _value;
        // 이벤트 발생
        emit Approval(msg.sender, _spender, _value);
        
        return true;
    }
}