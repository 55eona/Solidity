// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 < 0.8.0;

contract NameRegistry {
    // 컨트랙트 정보 나타낼 구조체
    struct ContractInfo {
        address contractOwner;  // 컨트랙트를 등록한 사람 (소유자)
        address contractAddress;  // 실제 배포된 컨트랙트 주소
        string description;  // 컨트랙트에 대한 설명
    }

    // 등록된 컨트랙트 수
    uint public numContracts;

    // 등록한 컨트랙트들을 저장할 매핑 (이름 -> 컨트랙트 정보 구조체)
    mapping(string=>ContractInfo) public registeredContracts;

    // 지정된 이름의 컨트랙트에 대해 소유자만 접근하도록 제한하는 modifier
    modifier onlyOwner(string memory _name) {
        // 컨트랙트 소유자만 접근 가능
        require(registeredContracts[_name].contractOwner == msg.sender, "Error: Only owner can call this function.");
        _;
    }

    //ContractRegistered, ContractDeleted, ContractUpdated(어떤 변경인지 포함) 세 가지 이벤트를 포함
    event ContractRegistered(string indexed name, address indexed contractAddress, address indexed owner);
    event ContractDeleted(string indexed name, address indexed contractAddress, address indexed owner);
    event ContractUpdated(string indexed name, address indexed contractAddress, address indexed owner, string description);
    
    constructor() {
        numContracts = 0;
    }

    // 컨트랙트 등록
    function registerContract(string memory _name, address _contractAddress, string memory _description) public {
        // 이미 등록된 것인지 확인: 매핑에서 등록된 컨트랙트 주소가 address(0)이어야 신규 가능
        require(registeredContracts[_name].contractOwner == address(0), "Error");
        // 매핑에 등록된 컨트랙트 정보 추가
        registeredContracts[_name] = ContractInfo(msg.sender, _contractAddress, _description);
        numContracts++;  // 컨트랙스 수 추가
        emit ContractRegistered(_name, _contractAddress, msg.sender);
    }

    // 컨트랙트 삭제 (소유자만 가능)
    function unregisterContract(string memory _name) public onlyOwner(_name) {
        emit ContractDeleted(_name, registeredContracts[_name].contractAddress, msg.sender);  // 컨트랙트 삭제 이벤트 발생 (삭제 전 기존 정보를 이벤트로 기록)
        delete registeredContracts[_name];  // 매개변수로 받은 _name에 해당하는 컨트랙트 삭제
        numContracts--;  // 컨트랙스 수 감소
    }

    // 컨트랙트 소유자 변경 (소유자만 가능)
    function changeOwner(string memory _name, address _newOwner) public onlyOwner(_name) {
        registeredContracts[_name].contractOwner = _newOwner;
        emit ContractUpdated(_name, registeredContracts[_name].contractAddress, _newOwner, "Change Owner");
    }
    // 컨트랙트 소유자 정보 확인
    function getOwner(string memory _name) public view returns(address) {
        return registeredContracts[_name].contractOwner;
    }

    // 컨트랙트 어드레스 변경 (소유자만 가능)
    function setAddr(string memory _name, address _addr) public onlyOwner(_name) {
        registeredContracts[_name].contractAddress = _addr;
        emit ContractUpdated(_name, _addr, registeredContracts[_name].contractOwner, "Change Address");
    }
    // 컨트랙트 어드레스 확인
    function getAddr(string memory _name) public view returns(address) {
        return registeredContracts[_name].contractAddress;
    }

    // 컨트랙트 설명 변경 (소유자만 가능)
    function setDescription(string memory _name, string memory _description) public onlyOwner(_name) {
        registeredContracts[_name].description = _description;
        emit ContractUpdated(_name, registeredContracts[_name].contractAddress, registeredContracts[_name].contractOwner, "Change Description");
    }
    // 컨트랙트 설명 확인
    function getDescription(string memory _name) public view returns(string memory) { 
        return registeredContracts[_name].description;
    }

}