pragma solidity ^0.4.24;

contract Owner {
    address public owner;

    event OwnerChanged(address owner, address newOwner);

    modifier onlyOwner() { 
        require(msg.sender == owner, "You are not Owner."); 
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function transferOwnership ( address _newOwner ) public onlyOwner {
        address oldOwner = owner;
        owner = _newOwner;
        emit OwnerChanged(oldOwner, _newOwner);
    }
}

contract MembershipFeature is Owner {
    address public coin;
    TeerInfo[] public tiArr;
    mapping(address => History) public memberList;
    struct History{
        uint256 transferCount;
        uint256 transferAmount;
        uint256 teerIndex;
    }
    struct TeerInfo {
        string teerName;
        uint256 minTransferCount;
        uint256 minTransferAmount;
        int8 cashbackRatio;
    }
    modifier onlyCoin() {
        require(msg.sender == coin, "You don't have Token.");
        _;
    }

    function setCoin ( address _addr ) public onlyOwner  {
        coin = _addr;
    }
    function pushTeerInfo(string _name, uint256 _transferCount, uint256 _transferAmount, int8 _ratio) public onlyOwner{
        tiArr.push(TeerInfo({
            teerName : _name,
            minTransferCount : _transferCount,
            minTransferAmount : _transferAmount,
            cashbackRatio : _ratio
        }));
    }
    function editTeerInfo(uint256 index, string _name, uint256 _transferCount, uint256 _transferAmount, int8 _ratio) public onlyOwner{
        require(index < tiArr.length, "Index Null Error");
        tiArr[index].teerName = _name;
        tiArr[index].minTransferCount = _transferCount;
        tiArr[index].minTransferAmount = _transferAmount;
        tiArr[index].cashbackRatio = _ratio;
    }
    //push membership;
    //update membership;
    function pushHistory(address user, uint256 _value ) onlyCoin{
        memberList[user].transferCount += 1;
        memberList[user].transferAmount += _value;
        uint256 idx;
        int8 temp;
        for(uint i = 0 ; i < tiArr.length ; i++){
            if(memberList[user].transferCount >= tiArr[i].minTransferCount &&
               memberList[user].transferAmount >= tiArr[i].minTransferAmount &&
               temp < tiArr[i].cashbackRatio
            ){idx = i;}
        }
        memberList[user].teerIndex = idx;
    }
    function getCashbackRatio(address user) public view returns(int8 ratio){
        ratio = tiArr[memberList[user].teerIndex].cashbackRatio;
    }

}



contract eComCoin is Owner{
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => int8) public blacklist;
    mapping(address => MembershipFeature) public memberShip;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event blockAddress(address indexed target);
    event releaseAddress(address indexed target);
    event RejectPaymentFromBlockListedAddress(address indexed from, address indexed to, uint256 value);
    event RejectPaymentToBlockListedAddress(address indexed from, address indexed to, uint256 value);
    event setCashBack(address indexed from, int8 value);
    event refundCashBack(address indexed from, address indexed to, uint256 value);

    constructor (uint256 _supply, string _name, string _symbol, uint8 _decimals) public{
        owner = msg.sender;
        balanceOf[msg.sender] = _supply;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _supply;
    }
    function transfer ( address _to, uint256 _value) public{
        require(balanceOf[msg.sender] > _value, "Not enough Tokens");
        require(balanceOf[_to] + _value > balanceOf[_to], "No space for Tokens");
        if(blacklist[msg.sender] > 0){
            emit RejectPaymentFromBlockListedAddress(msg.sender, _to, _value);
        }else if(blacklist[_to] > 0){
            emit RejectPaymentToBlockListedAddress(msg.sender, _to, _value);
        }else{
            uint256 cashbackVal = 0;
            if(memberShip[_to] > address(0)){
                cashbackVal = _value / 100 * uint256(memberShip[_to].getCashbackRatio(msg.sender));
                memberShip[_to].pushHistory(msg.sender, _value);
            }
            
            balanceOf[msg.sender] -= (_value - cashbackVal);
            balanceOf[_to] += (_value - cashbackVal);
            emit Transfer(msg.sender, _to, _value);
            emit refundCashBack(_to, msg.sender, cashbackVal);
        }
    }
    function addAddressToBlacklist( address _to)  public onlyOwner {
        blacklist[_to] = 1;
        emit blockAddress(_to);
    }
    function removeAddressFromBlacklist( address _to)  public onlyOwner {
        blacklist[_to] = 0;
        emit releaseAddress(_to);
    }
    function setMember(MembershipFeature _members) public {
        memberShip[msg.sender] = MembershipFeature(_members);
    }
}
