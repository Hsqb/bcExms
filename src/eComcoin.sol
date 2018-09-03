pragma solidity ^0.4.24;

contract eComCoin{
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    address private owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => int8) public blacklist;
    mapping(address => int8) public cashback;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event blockAddress(address indexed target);
    event releaseAddress(address indexed target);
    event RejectPaymentFromBlockListedAddress(address indexed from, address indexed to, uint256 value);
    event RejectPaymentToBlockListedAddress(address indexed from, address indexed to, uint256 value);
    event setCashBack(address indexed from, int8 value);
    event refundCashBack(address indexed from, address indexed to, uint256 value);

    modifier onlyOwner() { 
        require(msg.sender == owner, "Sender is not owner");
        _;
    }
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
            uint256 cashbackVal = _value / 100 * uint256(cashback[_to]) ;
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
    function setCashbackPercentage(int8 cashbackVal)  public {
        //require(cashbackVal >= 0 && cashbackVal <= 100, "Cashback Value should be in between 0 to 100.");
        if(cashbackVal < 1){
            cashbackVal = 0;
        }else if(cashbackVal > 100){
            cashbackVal = 100;
        }
        cashback[msg.sender] = cashbackVal;
        if(cashbackVal < 1)
        {
            cashbackVal = 0;
        }
        emit setCashBack(msg.sender, cashbackVal);
    }
}
