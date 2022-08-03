// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SubscriptionFactory is Ownable {

  uint256 constant public SUBSCRIPTION_FEE = 10;
  uint256 constant public PERIOD_LENGTH = 30 days;

  IERC20 immutable private token;
  uint256 private totalUserReserve;

  struct Subscription {
    uint256 period;
    uint256 lastPeriodStart;
    bool active;
  }

  // Total subscriber count
  uint256 public subscribers;
  // User address -> Subscription
  mapping(address => Subscription) private subscriptions;
  // User address -> Reserve amount
  mapping(address => uint256) private reserveAmount;

  error InsufficientBalance(uint256 balance, uint256 amountNeeded);
  error EmptyReserve();
  error NoSubscription();
  error AlreadySubscribed();

  modifier onlySubscriber {
    if (!subscriptions[msg.sender].active) revert NoSubscription();
    _;
  }

  modifier availableBalance(uint256 multiplier) {
    uint256 balance = token.balanceOf(msg.sender);
    uint256 paymentAmount = multiplier * SUBSCRIPTION_FEE;
    if (paymentAmount > balance) revert InsufficientBalance(balance, paymentAmount);
    _;
  }

  constructor(address _paymentToken) {
    token = IERC20(_paymentToken);
  }

  /// @notice Adds subscription to caller and takes (minimum) first periodical fee
  /// @dev User needs to approve tokens to the contract first
  /// @param periodAmount: the amount of periods that the user wants to pay forward
  function subscribe(uint256 periodAmount) external availableBalance(periodAmount) {
    if (subscriptions[msg.sender].active) revert AlreadySubscribed();

    token.transferFrom(msg.sender, address(this), periodAmount * SUBSCRIPTION_FEE);

    subscriptions[msg.sender] = Subscription(1, block.timestamp, true);
    if (periodAmount > 1) {
      reserveAmount[msg.sender] = SUBSCRIPTION_FEE * (periodAmount - 1);
      totalUserReserve = totalUserReserve + SUBSCRIPTION_FEE * (periodAmount - 1);
    }
  }

  /// @notice Removes subscription from caller and withdraws any excess tokens from userReserve to the caller
  function unsubscribe() external onlySubscriber {
    uint256 _reserveAmount = reserveAmount[msg.sender];

    subscriptions[msg.sender] = Subscription(0, 0, false);

    // Withdraw user deposited reserve tokens
    if (_reserveAmount != 0) {
      _reserveAmount = 0;
      totalUserReserve = totalUserReserve - _reserveAmount;
      token.transfer(msg.sender, _reserveAmount);
    }
  }

  /// @notice Deposits subscriber's funds into reserve
  /// @dev User needs to approve tokens to the contract first
  /// @param amount of periods to pay for
  function deposit(uint256 amount) external onlySubscriber availableBalance(amount) {
    _updateSubscription(msg.sender);
    uint256 _reserveAmount = reserveAmount[msg.sender];
    uint256 paymentAmount = amount * SUBSCRIPTION_FEE;

    _reserveAmount = _reserveAmount + paymentAmount;
    totalUserReserve = totalUserReserve + paymentAmount;

    token.transferFrom(msg.sender, address(this), paymentAmount);
  }

  /// @notice Withdraws tokens from reserve to subscriber wallet
  /// @param amount to withdraw
  function withdraw(uint256 amount) public onlySubscriber {
    _updateSubscription(msg.sender);
    uint256 _reserveAmount = reserveAmount[msg.sender];
    if (_reserveAmount == 0) revert EmptyReserve();

    uint256 total = amount * SUBSCRIPTION_FEE;

    _reserveAmount = _reserveAmount - total;
    totalUserReserve = totalUserReserve - total;

    token.transfer(msg.sender, total);
  }

  /// @notice Withdraws accumulated fees to owner
  function withdrawFees() external payable onlyOwner {
    uint256 balance = token.balanceOf(address(this));
    if (balance == 0) revert EmptyReserve();

    uint256 total = balance - totalUserReserve;
    if (total == 0) revert EmptyReserve();

    token.transfer(msg.sender, total);
  }

  /// @notice Updates subscription status, checks for new period and payment
  /// @param user wallet address
  function _updateSubscription(address user) internal {
    Subscription storage _subscription = subscriptions[user];

    uint256 newPeriodStart = _subscription.lastPeriodStart + PERIOD_LENGTH;
    if (newPeriodStart > block.timestamp) return;

    _subscription.period = _subscription.period + 1;
    _subscription.lastPeriodStart = newPeriodStart;

    uint256 reserve = reserveAmount[user];
    if (reserve < SUBSCRIPTION_FEE) {
      _subscription.active = false;
    } else {
      _subscription.active = true;
      reserve = reserve - SUBSCRIPTION_FEE;
    }
  } 

  /// @notice Returns subscription tied to caller address
  function getSubscription() external returns (Subscription memory) {
    _updateSubscription(msg.sender);
    return subscriptions[msg.sender];
  }

  function isSubscriber(address _address) public view returns (bool) {
    return subscriptions[_address].active;
  } 

}