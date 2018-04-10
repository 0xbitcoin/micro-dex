pragma solidity ^0.4.9;

import "./ECRecovery.sol";
import "./SafeMath.sol";


/*
Universal ERC20 Token DEX compatible with LavaWallet




-- General DEX Flow --

A user has tokens deposited in LavaWallet
They approve the DEX as a spender (either onchain or most typically offchain)
The user signs an offchain 'Make' order to the DEX

A counterparty 'takes' the order .  (this counterparty already put tokens in the DEX and approved them)
When this occurs, both of the spending approvals must have been done and then trade() is done


Interestingly, the traders can 'preapprove' an enormouse amount of tokens for trading by the dex.  Also, this can be done offchain.
*/




contract Token {
  /// @return total amount of tokens
  function totalSupply() constant returns (uint256 supply) {}

  /// @param _owner The address from which the balance will be retrieved
  /// @return The balance
  function balanceOf(address _owner) constant returns (uint256 balance) {}

  /// @notice send `_value` token to `_to` from `msg.sender`
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return Whether the transfer was successful or not
  function transfer(address _to, uint256 _value) returns (bool success) {}

  /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
  /// @param _from The address of the sender
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return Whether the transfer was successful or not
  function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {}

  /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
  /// @param _spender The address of the account able to transfer the tokens
  /// @param _value The amount of wei to be approved for transfer
  /// @return Whether the approval was successful or not
  function approve(address _spender, uint256 _value) returns (bool success) {}

  /// @param _owner The address of the account owning tokens
  /// @param _spender The address of the account able to transfer the tokens
  /// @return Amount of remaining tokens allowed to spent
  function allowance(address _owner, address _spender) constant returns (uint256 remaining) {}

  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);

  uint public decimals;
  string public name;
}

contract StandardToken is Token {

  function transfer(address _to, uint256 _value) returns (bool success) {
    //Default assumes totalSupply can't be over max (2^256 - 1).
    //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
    //Replace the if with this one instead.
    if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
    //if (balances[msg.sender] >= _value && _value > 0) {
      balances[msg.sender] -= _value;
      balances[_to] += _value;
      Transfer(msg.sender, _to, _value);
      return true;
    } else { return false; }
  }

  function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
    //same as above. Replace this line with the following if you want to protect against wrapping uints.
    if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
    //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
      balances[_to] += _value;
      balances[_from] -= _value;
      allowed[_from][msg.sender] -= _value;
      Transfer(_from, _to, _value);
      return true;
    } else { return false; }
  }

  function balanceOf(address _owner) constant returns (uint256 balance) {
    return balances[_owner];
  }

  function approve(address _spender, uint256 _value) returns (bool success) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  mapping(address => uint256) balances;

  mapping (address => mapping (address => uint256)) allowed;

  uint256 public totalSupply;
}

contract ReserveToken is StandardToken, SafeMath {
  address public minter;
  function ReserveToken() {
    minter = msg.sender;
  }
  function create(address account, uint amount) {
    if (msg.sender != minter) throw;
    balances[account] = safeAdd(balances[account], amount);
    totalSupply = safeAdd(totalSupply, amount);
  }
  function destroy(address account, uint amount) {
    if (msg.sender != minter) throw;
    if (balances[account] < amount) throw;
    balances[account] = safeSub(balances[account], amount);
    totalSupply = safeSub(totalSupply, amount);
  }
}

contract LavaWallet {

  function transferTokenFrom( address from, address to,address token,  uint tokens) public returns (bool success);

  function transferFromWithSignature(address from, address to, uint256 tokensApproved,
                                    uint256 tokens, address token,
                                    uint256 nonce, bytes signature) public returns (bool);



}




contract LavaDex is SafeMath {

  bool locked;
  //check account balances for this token; we do not use ether


  //The only way to get 'tokens' is via LavaWallet
  //mapping (address => mapping (address => uint)) public balance; //mapping of token addresses to mapping of account balances (token=0 means Ether)

  mapping (address => mapping (bytes32 => bool)) public orders; //mapping of user accounts to mapping of order hashes to booleans (true = submitted by user, equivalent to offchain signature)
  mapping (address => mapping (bytes32 => uint)) public orderFills; //mapping of user accounts to mapping of order hashes to uints (amount of order that has been filled)

  event Order(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user);
  event Cancel(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user);
  event Trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, address get, address give);
  event Deposit(address token, address user, uint amount, uint balance);
  event Withdraw(address token, address user, uint amount, uint balance);

  function MicroDex( ) {

    if(locked)revert();
    locked = true;
  }

  function() {
    throw;
  }

 
  function order(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce) {
    bytes32 orderHash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce);
    orders[msg.sender][orderHash] = true;
    Order(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, msg.sender);
  }




  function trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive,
    uint expires, uint nonce, address user, uint amount, bytes orderSignature , address wallet  ) {

    //amount is in amountGet terms
    bytes32 orderHash = sha3(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce);

    bytes32 expectedSigHash = sha3("\x19Ethereum Signed Message:\n32",orderHash);
    address recoveredSignatureSigner = ECRecovery.recover(expectedSigHash,orderSignature);

    if (!(
      (orders[user][orderHash] || recoveredSignatureSigner == user) && //there is an on chain order or an offchain order
      block.number <= expires &&
      safeAdd(orderFills[user][orderHash], amount) <= amountGet
    )) throw;

    tradeWalletBalancesWithApproval(wallet, tokenGet, amountGet, tokenGive, amountGive, user, amount);

    orderFills[user][orderHash] = safeAdd(orderFills[user][orderHash], amount);
    Trade(tokenGet, amount, tokenGive, amountGive * amount / amountGet, user, msg.sender);
  }



  function tradeWalletBalancesWithApproval(address wallet, address tokenGet, uint amountGet, address tokenGive, uint amountGive, address user, uint amount) private {

    if(!LavaWallet(wallet).transferTokenFrom( msg.sender, user, tokenGet, amount   ))revert();
    if(!LavaWallet(wallet).transferTokenFrom( user, msg.sender, tokenGive, safeMul(amountGive, amount) / amountGet   ))revert();

  }




  function amountFilled(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user) constant returns(uint) {
    bytes32 hash = sha3(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce);
    return orderFills[user][hash];
  }

  function cancelOrder(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, bytes signature) {
    bytes32 hash = sha3(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce);


    if (!(orders[msg.sender][hash] || ECRecovery.recover(sha3("\x19Ethereum Signed Message:\n32",hash),signature) == msg.sender)) throw;
    orderFills[msg.sender][hash] = amountGet;
    Cancel(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, msg.sender);
  }
}
