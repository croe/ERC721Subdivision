const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("ERC721Subdivision", function () {
  async function deployFixture() {
    const [owner, otherAccount] = await ethers.getSigners();
    const artist = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8'
    const executive = [
      '0x71bE63f3384f5fb98995898A86B02Fb2426c5788',
      '0xFABB0ac9d68B0B445fB7357272Ff202C5651694a',
      '0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec',
    ]
    const closingTime = 1659285295
    const baseURI = 'https://mf22.3331.jp/'
    const basePrice = [
      // ETH換算でいれる -> どうやってやるか
      // ethers.utils.BigNumber.from(1000000000000000000),
      // ethers.utils.BigNumber.from(2000000000000000000),
      // ethers.utils.BigNumber.from(3000000000000000000),
      ethers.BigNumber.from('1000000000000000000'),
      ethers.BigNumber.from('2000000000000000000'),
      ethers.BigNumber.from('3000000000000000000'),
    ]

    const tempTotalEdition = [0, 0, 0]

    const ERC721Subdivision = await ethers.getContractFactory("ERC721Subdivision");
    const contract = await ERC721Subdivision.deploy(
      'My First Digital Data',
      'MFDD',
      baseURI,
      artist,
      executive,
      basePrice,
      tempTotalEdition,
      closingTime,
    );
    return { contract, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should default totalSupply is zero", async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.name()).to.equal("My First Digital Data");
      expect(await contract.symbol()).to.equal("MFDD");
      expect(await contract.totalSupply()).to.equal(0);
    })

    it("Should set the right owner", async function () {
      const { contract, owner } = await loadFixture(deployFixture);
      expect(await contract.owner()).to.equal(owner.address);
    })

    it('Should mint when before close', async function () {
      const { contract, owner, otherAccount} = await loadFixture(deployFixture)
      await contract.connect(owner).setClosingTime(1679285295)
      const tx1 = await contract.connect(otherAccount).buy(0, {value: ethers.BigNumber.from('1000000000000000000')})
      tx1.wait()
      console.log(await contract.tokenURI(1))
      expect(await contract.totalSupply()).to.equal(1)
    })

    it('Should refund when after close', async function () {
      const { contract, owner, otherAccount } = await loadFixture(deployFixture)
      await contract.connect(owner).setClosingTime(1679285295)
      const tx1 = await contract.connect(otherAccount).buy(0, {value: ethers.BigNumber.from('1000000000000000000')})
      tx1.wait()
      const tx2 = await contract.connect(owner).buy(0, {value: ethers.BigNumber.from('500000000000000000')})
      await contract.connect(owner).setClosingTime(1659285295)
      tx2.wait()
      console.log('oa: ', await otherAccount.getBalance())
      console.log(await contract.provider.getBalance(contract.address))
      const tx3 = await contract.connect(otherAccount).refund()
      tx3.wait()
      await contract.connect(owner).setContractURI('http://example.com')
      console.log('ow: ', await owner.getBalance())
      console.log('oa: ', await otherAccount.getBalance())
      console.log(await contract.contractURI())
      console.log(await contract.getEditionFromToken(0))
      console.log(await contract.provider.getBalance(contract.address))
      expect(await contract.totalSupply()).to.equal(2)
    })

    it('should withdraw correctly', async function () {
      const { contract, owner, otherAccount } = await loadFixture(deployFixture)
      await contract.connect(owner).setClosingTime(1679285295)
    })

    // it("Should set the contract uri", async function () {
    //   const { contract, owner } = await loadFixture(deployFixture);
    //
    //   await contract.setContractURI = 'https://mf22.3331.jp'
    //   expect(await  contract.contractURI).to.equal('https://mf22.3331.jp')
    // });
  });
});
