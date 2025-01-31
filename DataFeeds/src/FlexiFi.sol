///SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*///////////////////////////////////
            Imports
///////////////////////////////////*/
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*///////////////////////////////////
            Interfaces
///////////////////////////////////*/

/*///////////////////////////////////
            Libraries
///////////////////////////////////*/

contract FlexiFi is Ownable{

    /*///////////////////////////////////
            Type declarations
    ///////////////////////////////////*/
    using SafeERC20 for IERC20;

    /*///////////////////////////////////
            State variables
    ///////////////////////////////////*/
    IERC20 immutable i_77EduToken;
    ///@notice variable to store the maximum amount an user can borrow against its collateral
    uint256 constant BORROW_LIMIT = 80;
    uint16 constant FEED_HEARTBEAT = 3600;

    ///@notice variable to store the Chainlink Data Feed address
    AggregatorV3Interface s_feeds;

    ///@notice variable to store the eth last price
    uint256 s_ethLastPrice;
    uint256 s_interestRate;

    ///@notice function to store the value of eth deposited by the user
    mapping(address user => uint256 amount) public s_userBalances;
    ///@notice function to store the value of 77Edu tokens borrowed against the eth deposited
    mapping(address user => uint256 amount) public s_userBorrows;

    /*///////////////////////////////////
                Events
    ///////////////////////////////////*/
    ///@notice event emitted when a deposit is successfully performed
    event FlexiFi_DepositedSuccessfully(address user, uint256 amount);
    ///@notice event emitted when the Chainlink Price Feeds address is updated
    event FlexiFi_FeedAddressUpdated(address newFeed);
    ///@notice event emitted when an amount is borrowed
    event FlexiFi_AmountBorrowedSuccessfully(address user, uint256 amount);
    ///@notice event emitted when the user repays a borrow
    event FlexiFi_BorrowRepaid(address user, uint256 amount);

    /*///////////////////////////////////
                Errors
    ///////////////////////////////////*/
    ///@notice error emitted when the value is zero
    error FlexiFi_InsufficientAmount(uint256 amount);
    ///@notice error emitted when an user tries to borrow more than he can.
    error FlexiFi_NotEnoughCollateral(uint256 amount, uint256 maxAmountToBorrow);
    ///@notice error emitted when the user doesn't have an open position
    error FlexiFi_NoneBorrowsToRepay(uint256 borrowedAmount);
    ///@notice error emitted if the roundId of a feed is invalid
    error FlexiFi_InvalidFeedRound(uint80 roundId);
    ///@notice error emitted when the last update of a feed is bigger than the heartbeat
    error FlexiFi_StalePrice();

    /*///////////////////////////////////
                Modifiers
    ///////////////////////////////////*/

    /*///////////////////////////////////
                Functions
    ///////////////////////////////////*/

    /*///////////////////////////////////
                constructor
    ///////////////////////////////////*/
    constructor(address _77token, address _feeds, uint256 _rate, address _owner) Ownable(_owner){
        i_77EduToken = IERC20(_77token);
        s_feeds = AggregatorV3Interface(_feeds);
        s_interestRate = _rate;
    }

    /*///////////////////////////////////
            Receive&Fallback
    ///////////////////////////////////*/

    /*///////////////////////////////////
                external
    ///////////////////////////////////*/
    /**
        *@notice function for users to deposit collateral (eth)
    */
    function depositCollateral() external payable {
        if(msg.value == 0) revert FlexiFi_InsufficientAmount(msg.value);
        s_userBalances[msg.sender] = s_userBalances[msg.sender] + msg.value;

        emit FlexiFi_DepositedSuccessfully(msg.sender, msg.value);
    }

    /**
        *@notice function for users to borrow 77Edu Tokens
        *@param _amount the amount to borrow
        *@dev the amount to borrow must be at max, 80% of the collateral deposited
    */
    function borrow(uint256 _amount) external {
        uint256 maxAmountToBorrow = (s_userBalances[msg.sender] * BORROW_LIMIT)/100;
        if(_amount > maxAmountToBorrow) revert FlexiFi_NotEnoughCollateral(_amount, maxAmountToBorrow);

        s_userBorrows[msg.sender] = s_userBorrows[msg.sender] + _amount;

        i_77EduToken.safeTransfer(msg.sender, _amount);

        emit FlexiFi_AmountBorrowedSuccessfully(msg.sender, _amount);
    }

    function repayLoan(uint256 _amount) external {
        uint256 borrowedAmount = s_userBorrows[msg.sender];
        if(borrowedAmount == 0) revert FlexiFi_NoneBorrowsToRepay(borrowedAmount);

        s_userBorrows[msg.sender] = s_userBorrows[msg.sender] - _amount;

        emit FlexiFi_BorrowRepaid(msg.sender, _amount);

        i_77EduToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
        *@notice function to update the feed address
        *@param _newFeed the new feed address
    */
    function setFeeds(address _newFeed) external payable onlyOwner{
        s_feeds = AggregatorV3Interface(_newFeed);

        emit FlexiFi_FeedAddressUpdated(_newFeed);
    }

    /*///////////////////////////////////
                public
    ///////////////////////////////////*/

    /*///////////////////////////////////
                internal
    ///////////////////////////////////*/

    /*///////////////////////////////////
                private
    ///////////////////////////////////*/

    /*///////////////////////////////////
                View & Pure
    ///////////////////////////////////*/

    function getCurrentPrice() public view returns (uint256 price_) {
        (uint80 roundId, int256 price, , uint256 updatedAt, ) = s_feeds.latestRoundData();
        if(roundId == 0) revert FlexiFi_InvalidFeedRound(roundId);
        if(block.timestamp - updatedAt > FEED_HEARTBEAT) revert FlexiFi_StalePrice();

        price_ = uint256(price);
    }

    function getInterestRate() public view returns (uint256) {
        return s_interestRate;
    }
}

