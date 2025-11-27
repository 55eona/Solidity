// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 < 0.8.0;

contract Lottery {
    address public manager;     // 관리자 (배포자)
    address[] public players;       // 게임 참여자

    enum Stage {Open, Closed}
    Stage public currentStage;

    modifier restricted() {
        require(manager == msg.sender, "Only the manager can call this function");
        _;
    }

    constructor() {
        manager = msg.sender;
    }

    event PlayerInfo (address indexed player, uint indexed idx);
    event WinnerInfo (address indexed winner, uint indexed idx, uint amount);

    // 참여자 목록 반환
    function getPlayers() public view returns(address [] memory) {
        return(players);
    }

    // 사용자가 로또에 참여하는 함수
    function enter() payable public {
        // 1 Ether로만 참여 가능
        require(msg.value==1 ether, "Only 1 Ether is Allowed");
        // 배포자는 베팅 참여 불가
        require(msg.sender!=manager, "Manager can not participate");
        // 참여 단계에만 배팅 가능
        require(currentStage==Stage.Open, "Betting is closed");


        // 이미 참여했는지 확인
        for(uint idx; idx<players.length; idx++) {      
            if (players[idx] == msg.sender) {
                revert("You can participate only once");
            }
        }
        // players 배열에 참여자 주소 추가
        players.push(msg.sender); 
        // 참여자 정보 이벤트
        emit PlayerInfo(msg.sender, players.length-1); 

    }

    // 당첨자를 위한 무작위수 구하기
    function random() private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.number, block.timestamp, players.length)));
    }

    // 당첨자 무작위 선택
    function pickWinner() public restricted {

        // 당첨자 한번만 뽑기
        require(currentStage==Stage.Open, "Winner already picked");
        
        uint winneridx = random() % players.length;
        address winner = players[winneridx];
        payable(winner).transfer(players.length * 1 ether);
        
        // 우승자의 정보와 금액 이벤트
        emit WinnerInfo(winner, winneridx, players.length * 1 ether);    

        setStageClosed();
        
        // players 배열 초기화
        delete players;     
    }

    // 단계 변경
    function setStageOpen() public restricted {
        currentStage = Stage.Open;
    }
    function setStageClosed() public restricted {
        currentStage = Stage.Closed;
    }
}