// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SubscriptionFactory is Ownable {

  uint256 immutable private subscriptionFee;
  uint256 immutable private periodLength;
  IERC20 immutable private token;

  uint256 public totalUserReserve;
  uint256 public subscriberCount;

  struct Subscription {
    uint256 period;
    uint256 lastPeriodStart;
    bool active;
  }

  // Total subscriber count
  // User address -> Subscription
  mapping(address => Subscription) public subscriptions;
  // User address -> Reserve amount
  mapping(address => uint256) public reserveAmount;

  error InsufficientFunds();
  error InsufficientReserve();
  error EmptyReserve();
  error NoSubscription();
  error AlreadySubscribed();

  modifier onlySubscriber {
    if (!subscriptions[msg.sender].active) revert NoSubscription();
    _;
  }

  modifier availableBalance(uint256 multiplier) {
    if (multiplier * subscriptionFee > token.balanceOf(msg.sender)) revert InsufficientFunds();
    _;
  }

  constructor(uint256 _fee, uint256 _periodLength, address _paymentToken) {
    subscriptionFee = _fee;
    periodLength = _periodLength;
    token = IERC20(_paymentToken);
  }

  /// @notice Adds subscription to caller and takes (minimum) first periodical fee
  /// @dev User needs to approve tokens to the contract first
  /// @param periodAmount: the amount of periods that the user wants to pay forward
  function subscribe(uint256 periodAmount) external availableBalance(periodAmount) {
    if (subscriptions[msg.sender].active) revert AlreadySubscribed();

    token.transferFrom(msg.sender, address(this), periodAmount * subscriptionFee);

    subscriptions[msg.sender] = Subscription(1, block.timestamp, true);
    ++subscriberCount;
    if (periodAmount > 1) {
      reserveAmount[msg.sender] = subscriptionFee * (periodAmount - 1);
      totalUserReserve = totalUserReserve + subscriptionFee * (periodAmount - 1);
    }
  }

  /// @notice Removes subscription from caller and withdraws any excess tokens from userReserve to the caller
  function unsubscribe() external onlySubscriber {
    subscriptions[msg.sender] = Subscription(0, 0, false);
    --subscriberCount;

    // Withdraw user deposited reserve tokens
    uint256 _reserveAmount = reserveAmount[msg.sender];
    if (_reserveAmount != 0) {
      reserveAmount[msg.sender] = 0;
      totalUserReserve = totalUserReserve - _reserveAmount;
      token.transfer(msg.sender, _reserveAmount);
    }
  }

  /// @notice Deposits subscriber's funds into reserve
  /// @dev User needs to approve tokens to the contract first
  /// @param amount of periods to pay for
  function deposit(uint256 amount) external onlySubscriber availableBalance(amount) {
    _updateSubscription(msg.sender);
    uint256 paymentAmount = amount * subscriptionFee;

    reserveAmount[msg.sender] = reserveAmount[msg.sender] + paymentAmount;
    totalUserReserve = totalUserReserve + paymentAmount;

    token.transferFrom(msg.sender, address(this), paymentAmount);
  }

  /// @notice Withdraws tokens from reserve to subscriber wallet
  /// @param amount to withdraw
  function withdraw(uint256 amount) external onlySubscriber {
    _updateSubscription(msg.sender);
    uint256 _reserveAmount = reserveAmount[msg.sender];
    if (_reserveAmount == 0) revert EmptyReserve();
    if (amount * subscriptionFee > _reserveAmount) revert InsufficientReserve();

    uint256 total = amount * subscriptionFee;

    reserveAmount[msg.sender] = _reserveAmount - total;
    totalUserReserve = totalUserReserve - total;

    token.transfer(msg.sender, total);
  }

  /// @notice Withdraws accumulated fees to owner
  function withdrawFees() external payable onlyOwner {
    uint256 total = token.balanceOf(address(this)) - totalUserReserve;
    if (total == 0) revert EmptyReserve();

    token.transfer(msg.sender, total);
  }

  /// @notice Updates subscription status, checks for new period and payment
  /// @param user wallet address
  function _updateSubscription(address user) internal {
    Subscription storage _subscription = subscriptions[user];
    if (!_subscription.active) revert NoSubscription();

    uint256 newPeriodStart = _subscription.lastPeriodStart + periodLength;
    if (newPeriodStart > block.timestamp) return;

    ++_subscription.period;
    _subscription.lastPeriodStart = newPeriodStart;

    uint256 reserve = reserveAmount[user];
    if (reserve < subscriptionFee) {
      _subscription.active = false;
    } else {
      _subscription.active = true;
      reserveAmount[user] = reserve - subscriptionFee;
    }
  } 

  function updateSubscription() external {
    _updateSubscription(msg.sender);
  }

  /// @notice Returns subscription tied to caller address
  function getSubscription() external view returns (Subscription memory) {
    return subscriptions[msg.sender];
  }

  function isSubscribed(address _address) public view returns (bool) {
    return subscriptions[_address].active;
  } 

}