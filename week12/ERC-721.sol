// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 < 0.9.0;


interface ERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}
interface ERC721 is ERC165 {
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata data) external payable;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}
interface ERC721TokenReceiver {
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external returns(bytes4);
}



contract ERC721StdNFT is ERC721 {
    address public founder;
    
    // Mapping from token ID to owner address (각 NFT의 소유자 주소)
    mapping(uint => address) internal _ownerOf; // tokenId → owner
    
    // Mapping owner address to token count (특정 주소가 보유한 NFT의 개수)
    mapping(address => uint) internal _balanceOf; // owner → number of NFTs
    
    // Mapping from token ID to approved address (특정 NFT를 대신 전송할 권리를 부여받은 주소를 저장)
    mapping(uint => address) internal _approvals; // tokenId → approved
    
    // Mapping from owner to operator approvals (특정 주소가 소유자의 모든 NFT를 관리할 권한이 있는지)
    mapping(address => mapping(address => bool)) internal _operatorApprovals;
    
    string public name;
    string public symbol;
    
    constructor (string memory _name, string memory _symbol) {
        founder = msg.sender;
        name = _name;
        symbol = _symbol;
        for (uint tokenID=1; tokenID<=5; tokenID    ++) { // 1~5번 tokenID를 배포자에게 자동 발행
            _mint(msg.sender, tokenID);
        }
    }

    // 새 토큰 발행하기 위한 내부 함수
    function _mint(address to, uint id) internal {
        // 빈 주소일 때는 발행 X
        require(to != address(0), "mint to zero address");
        // 이미 존재하는 tokenId이면, 발행 X
        require(_ownerOf[id] == address(0), "already minted");
        
        // to의 보유량 +1
        _balanceOf[to]++;
        // id 토큰 소유자로 등록
        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    // 새 토큰 발행
    function mintNFT(address to, uint256 tokenID) public {
        // founder만 호출 가능
        require(msg.sender == founder, "not an authorized minter");
        _mint(to, tokenID);
    }

    // 특정 tokenId의 현재 소유자 주소 반환
    function ownerOf(uint256 _tokenId) external view override returns (address) {
        address owner = _ownerOf[_tokenId];
        require(owner != address(0), "token doesn't exist");
        return owner;
    }

    // 해당 주소가 보유하고 있는 NFT 개수 반환
    function balanceOf(address _owner) external view override returns (uint256) {
        require(_owner != address(0), "balance query for the zero address");
        return _balanceOf[_owner];
    }

    // 해당 tokenID에 대한 전송 권한이 있는 주소 반환
    function getApproved(uint256 _tokenId) external view override returns (address) {
        require(_ownerOf[_tokenId] != address(0), "token doesn't exist");
        return _approvals[_tokenId];
    }

    // owner가 operator에게 전체 NFT 전송 줬는지 여부 반환
    function isApprovedForAll(address _owner, address _operator) external view override returns (bool) {
        return _operatorApprovals[_owner][_operator];
    }

    // 특정 token ID에 대해 전송 권한을 _apporved 주소에 위임
    function approve(address _approved, uint256 _tokenId) external payable override {
        address owner = _ownerOf[_tokenId];
        require(
            msg.sender == owner || _operatorApprovals[owner][msg.sender],
            "not authorized"
        );
        _approvals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    // operator 주소에 대해 소유자의 모든 NFT 전송 권한 부여 or 해제
    function setApprovalForAll(address _operator, bool _approved) external override {
        _operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    // 주어진 토큰 ID의 소유권 다른 주소로 전송
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable override {
        _transferFrom( _from, _to, _tokenId);
    }

    // 주어진 토큰 ID의 소유권 다른 주소로 전송하기 위한 내부 함수    
    function _transferFrom(address _from, address _to, uint256 _tokenId) private {
        address owner = _ownerOf[_tokenId];
        require(_from == owner, "from != owner");
        require(_to != address(0), "transfer to zero address");
        
        require(msg.sender == owner || msg.sender == _approvals[_tokenId] || _operatorApprovals[owner][msg.sender]); 
        //"msg.sender not in {owner,operator,approved}");

        _balanceOf[_from]--; // 보내는 사람 balance 감소
        _balanceOf[_to]++; // 받는 사람 balance 증가
        _ownerOf[_tokenId] = _to; // 토큰 소유자 변경
        delete _approvals[_tokenId]; // approval 초기화 (ERC721 규칙)
        
        emit Transfer(_from, _to, _tokenId); // Transfer 이벤트 발생
    }

    // 주어진 토큰 ID의 소유권 다른 주소로 '안전하게' 전송 (인자가 4개일 때)
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata data) external payable override {
        _transferFrom(_from, _to, _tokenId);
        
        require(
            _to.code.length == 0 ||  // 받는 주소에 코드가 없으면(EOA 지갑)
            ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, data) == 
            ERC721TokenReceiver.onERC721Received.selector,
            "unsafe recipient"
        );
    }

    // 주어진 토큰 ID의 소유권 다른 주소로 '안전하게' 전송 (인자가 3개일 때)
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable override {
        _transferFrom(_from, _to, _tokenId);
        require(
            _to.code.length == 0 ||  // 받는 주소에 코드가 없으면(EOA 지갑)
            ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, "") == 
            ERC721TokenReceiver.onERC721Received.selector,
            "unsafe recipient"
        );
    }

    // 어떤 인터페이스 구현하는지 알려주는 함수
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
        interfaceId == type(ERC721).interfaceId || interfaceId == type(ERC165).interfaceId;
    }

}