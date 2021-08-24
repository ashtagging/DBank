// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./Token.sol";

contract dBank {

  Token private token;

  mapping(address => uint) public depositStart;
  mapping(address => uint) public etherBalanceOf;
  mapping(address => uint) public collateralEther;
  mapping(address => bool) public isDeposited;
  mapping(address => bool) public isBorrowed;

  event Deposit(address indexed user, uint etherAmount, uint timeStart);
  event Withdraw(address indexed user, uint etherAmount, uint depositTime, uint interest);
  event Borrow(address indexed user, uint collateralEtherAmount, uint borrowedTokenAmount);
  event PayOff(address indexed user, uint fee);

  constructor(Token _token) public {
    token = _token;
  }

  function deposit() payable public {
    //Check if msg.sender didn't already deposited funds
    require(isDeposited[msg.sender] == false, 'Error, deposit already active');
    
    //Check if msg.value is >= than 0.01 ETH
    require(msg.value>=1e16, 'Error, deposit must be >= 0.01 ETH');

    //Increase msg.sender ether deposit balance
    etherBalanceOf[msg.sender] = etherBalanceOf[msg.sender] + msg.value;
    
    //Deposit start time required to calculate holding time
    depositStart[msg.sender] = depositStart[msg.sender] + block.timestamp;
    
    //Set msg.sender deposit status to true
    isDeposited[msg.sender] = true; //activate deposit status

    //Emit Deposit event
    emit Deposit(msg.sender, msg.value, block.timestamp);
  }


  function withdraw() public {
    
    //check if msg.sender deposit status is true
    require(isDeposited[msg.sender]==true, 'Error, no previous deposit');

    //assign msg.sender ether deposit balance to variable for event
    uint userBalance = etherBalanceOf[msg.sender]; 

    //check user's token hold time
    uint depositTime = block.timestamp - depositStart[msg.sender];

    //calculate interest per second & accrued interest
    //31668017 - interest(10% APY) per second for min. deposit amount (0.01 ETH), cuz:
    //1e15(10% of 0.01 ETH) / 31577600 (seconds in 365.25 days)
    //(etherBalanceOf[msg.sender] / 1e16) - calc. how much higher interest will be (based on deposit), e.g.:
    //For min. deposit (0.01 ETH), (etherBalanceOf[msg.sender] / 1e16) = 1 (the same, 31668017/s)
    //For deposit 0.02 ETH, (etherBalanceOf[msg.sender] / 1e16) = 2 (doubled, (2*31668017)/s)
    uint interestPerSecond = 31668017 * (etherBalanceOf[msg.sender] / 1e16);
    uint interest = interestPerSecond * depositTime;

    //Send ETH back to user
    msg.sender.transfer(etherBalanceOf[msg.sender]); 
     
    //Send interest in tokens to user
    token.mint(msg.sender, interest);

    //Reset depositers data
    etherBalanceOf[msg.sender] = 0;
    depositStart[msg.sender] = 0;
    isDeposited[msg.sender] = false;

    //Emit event
    emit Withdraw(msg.sender, userBalance, depositTime, interest);
  }

  function borrow() payable public {

    //Check if collateral is >= than 0.01 ETH
    require(msg.value>=1e16, 'Error, collateral must be >= 0.01 ETH');

    //Check if user doesn't have active loan
    require(isBorrowed[msg.sender] == false, 'Error, loan already taken');

    //This Ether is locked until user payOff the loan
    collateralEther[msg.sender] = collateralEther[msg.sender] + msg.value;

    //Calc tokens amount to mint, 50% of msg.value
    uint tokensToMint = collateralEther[msg.sender] / 2;

    //Mint & send tokens to user
    token.mint(msg.sender, tokensToMint);

    //Change borrower's loan status to true
    isBorrowed[msg.sender] = true;

    //Emit event
    emit Borrow(msg.sender, collateralEther[msg.sender], tokensToMint); 
  }

  function payOff() public {
    //Check if loan is active
    require(isBorrowed[msg.sender] == true, 'Error, loan not active');

    //Transfer tokens from user back to the contract
    require(token.transferFrom(msg.sender, address(this), collateralEther[msg.sender]/2), "Error, can't receive tokens"); //must approve dBank 1st

    //Calculate fee
    uint fee = collateralEther[msg.sender]/10; //calc 10% fee

    //Send user's collateral minus fee
    msg.sender.transfer(collateralEther[msg.sender]-fee);

    //Reset borrower's data
    collateralEther[msg.sender] = 0;
    isBorrowed[msg.sender] = false;

    //Emit event
    emit PayOff(msg.sender, fee);
  }
}