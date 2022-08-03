import { expect } from "chai";
import { describe } from 'mocha'
import { ethers } from "hardhat";
import { SubscriptionFactory } from '../typechain-types/contracts/SubscriptionFactory';
import { Token } from '../typechain-types/contracts/PaymentToken.sol/Token';

describe('eth-subscription', () => {

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
  })

  describe('subscribe()', () => {
    it('should add a new subscription', async () => {
      await token.approve(source.address, 10)
      await source.subscribe(1)
  
      const contractBalance = await token.balanceOf(source.address)
      const userBalance = await token.balanceOf(alice.address)
      const isSubscriber = await source.isSubscriber(alice.address)
  
      expect(contractBalance).to.equal(10)
      expect(userBalance).to.equal(9990)
      expect(isSubscriber).to.be.true
    })
  
    it('should add a subscription with forward payment', async () => {
      await token.approve(source.address, 100)
      await source.subscribe(10)
  
      const totalReserve = await source.totalUserReserve()
      const userReserve = await source.reserveAmount(alice.address)
  
      expect(totalReserve).to.equal(90)
      expect(userReserve).to.equal(90)
    })
  
    it('should revert if the caller has insufficient funds', async () => {
      await token.transfer(alice.address, 5)
      await token.connect(alice).approve(source.address, 5)
      await expect(source.connect(alice).subscribe(1)).to.be.revertedWithCustomError
    })

    it('should revert if the caller is already subscribed', async () => {
      await token.approve(source.address, 20)
      await source.subscribe(1)
      await expect(source.subscribe(1)).to.be.revertedWithCustomError
    })
  })

  describe('unsubscribe()', () => {
    it('should remove subscription from caller', async () => {
      await token.approve(source.address, 10)
      await source.subscribe(1)

      await source.unsubscribe()
      const isSubsc
    })
  })  

})