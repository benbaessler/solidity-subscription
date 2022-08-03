import { expect } from "chai";
import { ethers } from "hardhat";
import { SubscriptionFactory } from '../typechain-types/contracts/SubscriptionFactory';

describe("Subscription Model", () => {

  let source: SubscriptionFactory
  let user
  
  beforeEach(async () => {
    const SubscriptionFactory = ethers.getContractFactory('SubscriptionFactory')
    source = await (await SubscriptionFactory).deploy('0x0')
    user = ethers.getSigner
  })

  it('initiate a new subscription', async () => {
    await source.subscribe(1)
  })

})