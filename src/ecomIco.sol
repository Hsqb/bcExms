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


//crowdSale
contract EcomIco is Owner{
//state
    uint256 public fundingGoal;
    uint256 public deadline;
    uint256 public price;
    uint256 public transferableToken;
    uint256 public soldToken;
    uint256 public startTime;
    eComCoin public tokenReward;
    bool public fundingGoalReached;
    bool public isOpened;
    mapping (address => Property) public funderProperty;

    struct Property{
        uint256 paymentEther;
        uint256 reservedToken;
        bool withdrawed;
    }

//events
    event CrowdsaleStart(uint fundingGoal, uint deadline, uint transferableToekn, address beneficiary);
    event ReservedToken(address backer, uint amount, uint token);
    event CheckGoalReached (address beneficiary, uint fundingGoal, uint amountRaised, bool reached, uint rasiedToken);
    event WithdrawalToken(address addr, uint amount, bool result);
    event WithdrawalEther(address addr, uint amount, bool result);
//modifiers
    modifier adfterDeadline(){ if( now >= deadline) {_;}}

//constructor
    constructor(
        uint _fundingGoalInEthers,
        uint _transferableToken,
        uint _amountOfTokenPerEther,
        eComCoin _addrOfTokenUsedAsReward
    ) public {
        fundingGoal = _fundingGoalInEthers;
        price = 1 ether / _amountOfTokenPerEther;
        transferableToken = _transferableToken;
        tokenReward = eComCoin(_addrOfTokenUsedAsReward);
    }
//payable
    function () public payable  {
        require(isOpened && now <= deadline, "CrowdSale is not opened." );
        uint amount  = msg.value;
        uint token = amount / price * (100 + currentSwapRate()) / 100;
        require(token != 0 && soldToken + token < transferableToken, "There is not enough tokens.");
        funderProperty[msg.sender].paymentEther += amount;
        funderProperty[msg.sender].reservedToken += token;
        soldToken += token;
        emit ReservedToken(msg.sender, amount, token);
    }

//start
    function start(uint _durationInMinutes) public onlyOwner{
        require(fundingGoal != 0 && price != 0 && 
                 transferableToken != 0 && tokenReward != address(0) && 
                 _durationInMinutes != 0 && startTime == 0, "Not enough trigger");
        if(tokenReward.balanceOf(this) >= transferableToken){
            startTime = now;
            deadline = now + _durationInMinutes * 1 minutes;
            isOpened = true;
            emit CrowdsaleStart(fundingGoal, deadline, transferableToken, owner);
        }
    }
//currentSwapRate
    function currentSwapRate() public view returns(uint){
        if(startTime + 3 minutes > now){
            return 100;
        }else if(startTime + 3 minutes > now){
            return 50;
        }
        else if(startTime + 3 minutes > now){
            return 20;
        }else{
            return 0;
        }
    }

//getRemainingTimeEthToken()
    function getRemainingTimeEthToken() public view returns(uint min, uint shortage, uint remainToken){
        if(now < deadline){
            min = (deadline - now) / (1 minutes);
        }
        shortage = (fundingGoal - this.balance) / (1 ether);
        remainToken = transferableToken - soldToken;
    }
//checkGoalReached()
    function checkGoalReached() public{
        if(isOpened){
            if(this.balance >= fundingGoal){
                fundingGoalReached = true;
            }
            isOpened = false;
            emit CheckGoalReached (owner, fundingGoal, this.balance, fundingGoalReached, soldToken);
        }
    }
//withdrawalOwner()
    function withdrawalOwner() public onlyOwner{
        require(!isOpened, "ICO is not finished.");
        if(fundingGoalReached){
            //success, so get Ether to Owner
            uint amount = this.balance;
            if(amount > 0){
                bool ok = msg.sender.call.value(amount)();
                emit WithdrawalEther(msg.sender, amount, ok);
            }
            uint val = transferableToken - soldToken;
            emit WithdrawalToken(msg.sender, val, true);
        }else{
            //token withdrawal
            uint val2 = tokenReward.balanceOf(this);
            tokenReward.transfer(msg.sender, val2);
            emit WithdrawalToken(msg.sender, val2, true);
        }
    }
//withdrawal()
    function withdrawal() public {
        require(!isOpened, "ICO is not finished.");
        require(!funderProperty[msg.sender].withdrawed, "Already be Withdrawed");

        if(fundingGoalReached){
            if(funderProperty[msg.sender].reservedToken > 0){
                tokenReward.transfer(msg.sender, funderProperty[msg.sender].reservedToken);
                funderProperty[msg.sender].withdrawed = true;
                emit WithdrawalToken(msg.sender, funderProperty[msg.sender].reservedToken, funderProperty[msg.sender].withdrawed);
            }
        }else{
            if(msg.sender.call.value(funderProperty[msg.sender].paymentEther)()){
                funderProperty[msg.sender].withdrawed = true;
            }
            emit WithdrawalEther(msg.sender, funderProperty[msg.sender].paymentEther, funderProperty[msg.sender].withdrawed);
        }
    }
}

contract Now{
    function GetNow() public view returns(uint){
        return uint(now);
    }
}

