pragma solidity ^0.4.24;

contract SelfDestruction{
    address public owner = msg.sender;
    function () public payable {

    }
    function close() public {
        require(owner == msg.sender);
        selfdestruct(owner);
    }
    function withdrawer() public view returns (uint){
        return this.balance;
    }
}



/*
contract A {
    uint public num =10;
    function getNum() public view returns (uint){
        return num;
    }
    function setNum(uint _num) public{
        num = _num;
    }
}
contract B{
    A a = new A();
    address public addr;
    function setA(A _a) public {
        addr = _a;
    }
    function aNum() public view returns(uint){
        return a.num();
    }
    function aGetNum() public view returns(uint){
        return a.getNum();
    }
    function getAddr() public view returns(address){
        return addr;
    }
}

/*Inherit test


contract A {
    uint public a ;
    function setA (uint _a) public {
        a = _a;
    }
    function getData() public view returns(uint){
        return a;
    }
}

contract B is A {
    function getData() public view  returns (uint){
        return a * 10;
    }
}

contract C{
    A[] internal c;
    function makeContract() public returns (uint, uint){
        c.length = 2;
        A a = new A();
        a.setA(1);
        c.push(a);
        B b = new B();
        b.setA(1);
        c.push(b);
        return (c[0].getData(),c[1].getData());
    }
}
*////////////////////////////