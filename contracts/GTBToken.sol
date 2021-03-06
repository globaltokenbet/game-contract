pragma solidity ^0.4.21;

interface GTBToken {
    function balanceOf(address _owner) public view returns (uint256 balance);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
}