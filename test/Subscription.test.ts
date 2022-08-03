import { expect } from "chai";
import { ethers } from "hardhat";
import { SubscriptionFactory } from "../typechain-types";
import { Token } from '../typechain-types';

describe('Subscription Contract', () => {

  let alice: any
  let bob: any
  let token: Token
  let source: SubscriptionFactory
  
  beforeEach(async () => {
    [alice, bob] = await ethers.getSigners()

    // Test ERC-20 payment token, 10000 tokens are minted to alice
    const PaymentToken = await ethers.getContractFactory('Token')
    token = await PaymentToken.deploy()
    
    const SubscriptionFactory = await ethers.getContractFactory('SubscriptionFactory')
    source = await SubscriptionFactory.deploy(token.address)

    await token.approve(source.address, 10000)
  })

  describe('subscribe', () => {
    it('adds a new subscription', async () => {
      await source.subscribe(1)
  
      const contractBalance = await token.balanceOf(source.address)
      const userBalance = await token.balanceOf(alice.address)
      const isSubscribed = await source.isSubscribed(alice.address)
      const subscriberCount = await source.subscriberCount()
  
      expect(contractBalance).to.equal(10)
      expect(userBalance).to.equal(9990)
      expect(isSubscribed).to.be.true
    })
  
    it('adds a subscription with forward payment', async () => {
      await source.subscribe(10)
  
      const totalReserve = await source.totalUserReserve()
      const userReserve = await source.reserveAmount(alice.address)
  
      expect(totalReserve).to.equal(90)
      expect(userReserve).to.equal(90)
    })
  
    it('reverts if the caller has insufficient funds', async () => {
      await token.transfer(bob.address, 5)
      await token.connect(bob).approve(source.address, 10)
      await expect(source.connect(bob).subscribe(1)).to.be.revertedWithCustomError(source, 'InsufficientFunds')
    })

    it('reverts if the caller is already subscribed', async () => {
      await source.subscribe(1)
      await expect(source.subscribe(1)).to.be.revertedWithCustomError(source, 'AlreadySubscribed')
    })
  })

  describe('unsubscribe', () => {
    it('removes subscription from caller', async () => {
      await source.subscribe(1)

      await source.unsubscribe()
      expect(await source.isSubscribed(alice.address)).to.equal(false)
    })

    it('withdraws all reserve tokens to caller', async () => {
      await source.subscribe(10)

      await source.unsubscribe()
      const totalReserve = await source.totalUserReserve()
      const userReserve = await source.reserveAmount(alice.address)

      expect(totalReserve).to.equal(0)
      expect(userReserve).to.equal(0)
      expect(await token.balanceOf(source.address)).to.equal(10)
      expect(await token.balanceOf(alice.address)).to.equal(9990)
    })

    it('reverts if the caller is not subscribed', async () => {
      await expect(source.unsubscribe()).to.be.revertedWithCustomError(source, 'NoSubscription') 
    })
  })  

  describe('deposit', async () => {

    it('deposits funds into user reserve', async () => {
      await source.subscribe(1)

      await source.deposit(9)

      const totalReserve = await source.totalUserReserve()
      const userReserve = await source.reserveAmount(alice.address)
  
      expect(totalReserve).to.equal(90)
      expect(userReserve).to.equal(90)
    })

    it('reverts if the caller is not subscribed', async () => {
      await expect(source.deposit(1)).to.be.revertedWithCustomError(source, 'NoSubscription') 
    })

    it('reverts if the caller has insufficient funds', async () => {
      await token.transfer(bob.address, 15)
      await token.connect(bob).approve(source.address, 15)

      await source.connect(bob).subscribe(1)

      await expect(source.connect(bob).deposit(1)).to.be.revertedWithCustomError(source, 'InsufficientFunds')
    })
  })

  describe('withdraw', () => {
    it('withdraws reserve funds to caller', async () => {
      await source.subscribe(10)
      await source.withdraw(9)

      const totalReserve = await source.totalUserReserve()
      const userReserve = await source.reserveAmount(alice.address)

      expect(totalReserve).to.equal(0)
      expect(userReserve).to.equal(0)
      expect(await token.balanceOf(source.address)).to.equal(10)
      expect(await token.balanceOf(alice.address)).to.equal(9990)
    })

    it('reverts if user reserve is empty', async () => {
      await source.subscribe(1)
      await expect(source.withdraw(1)).to.be.revertedWithCustomError(source, 'EmptyReserve')
    })

    it('reverts if withdraw amount exceeds user reserve', async () => {
      await source.subscribe(10)
      await expect(source.withdraw(10)).to.be.revertedWithCustomError(source, 'InsufficientReserve')
    })

    it('reverts if caller is not subscribed', async () => {
      await expect(source.withdraw(1)).to.be.revertedWithCustomError(source, 'NoSubscription')
    })
  })

  describe('withdrawFees', () => {
    it('withdraws accumulated fees to owner', async () => {
      await source.subscribe(1)
      await source.withdrawFees()

      expect(await token.balanceOf(source.address)).to.equal(0)
      expect(await token.balanceOf(alice.address)).to.equal(10000)
    })

    it('reverts if no fees have been accumulated', async () => {
      await expect(source.withdrawFees()).to.be.revertedWithCustomError(source, 'EmptyReserve')
    })

    it('reverts if caller is not owner', async () => {
      await source.subscribe(1)
      await expect(source.connect(bob).withdrawFees()).to.be.revertedWith('Ownable: caller is not the owner')
    })
  })

  describe('updateSubscription', () => {
    it('updates subscription status', async () => {
      await source.subscribe(2)
      await ethers.provider.send('evm_increaseTime', [30 * 24 * 60 * 60])
      await source.updateSubscription()

      const subscription = await source.getSubscription()
      expect(subscription.period).to.equal(2)
      expect(subscription.active).to.be.true
    })

    it('deactivates subscription if user has insuffient reserve', async () => {
      await source.subscribe(1)
      await ethers.provider.send('evm_increaseTime', [30 * 24 * 60 * 60])
      await source.updateSubscription()

      const subscription = await source.getSubscription()
      expect(subscription.active).to.be.false
    })

    it('takes periodical fee from user reserve', async () => {
      await source.subscribe(2)

      await ethers.provider.send('evm_increaseTime', [31 * 24 * 60 * 60])
      await source.updateSubscription()

      expect(await source.reserveAmount(alice.address)).to.equal(0)
    })

  })
})