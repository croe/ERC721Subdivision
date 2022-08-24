const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("ERC721Subdivision", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000;

    const lockedAmount = ONE_GWEI;
    const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS;

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const ERC721Subdivision = await ethers.getContractFactory("ERC721Subdivision");
    const contract = await ERC721Subdivision.deploy('Brave New Commons', 'BNC', owner.address, 10000000000, 1659285295);
    return { contract, unlockTime, lockedAmount, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should default totalSupply is zero", async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.name()).to.equal("Brave New Commons");
      expect(await contract.symbol()).to.equal("BNC");
      expect(await contract.totalSupply()).to.equal(0);
    });

    it("Should set the right owner", async function () {
      const { contract, owner } = await loadFixture(deployFixture);

      expect(await contract.owner()).to.equal(owner.address);
    });

    it("Should set the right recipient", async function () {
      const { contract, owner } = await loadFixture(deployFixture);

      expect(await contract.latestPrice()).to.equal(10000000000);
    });

    it("Buy token", async function () {
      const { contract, owner, lockedAmount } = await loadFixture(deployFixture);
      const openTx = await contract.connect(owner).setClosingTime(1661958000);
      const mint0Tx = await contract.connect(owner).buy({value: 10000000000});
      await mint0Tx.wait();
      const token0 = await contract.tokenURI(0);
      console.log(token0);
      expect(await contract.totalSupply()).to.eq(1);
      const mint1Tx = await contract.connect(owner).buy({value: 5000000000});
      await mint1Tx.wait();
      const token1 = await contract.tokenURI(1);
      console.log(token1);
      expect(await contract.totalSupply()).to.eq(2);
      const closeTx = await contract.connect(owner).setClosingTime(1659285295);
      // console.log(refundTx);
      expect(await contract.connect(owner).getRefund()).to.changeEtherBalances(
        [owner, contract],
        [10000000000, -10000000000]
      );
    })

    // it("Should fail if the unlockTime is not in the future", async function () {
    //   // We don't use the fixture here because we want a different deployment
    //   const latestTime = await time.latest();
    //   const contract = await ethers.getContractFactory("ERC721Subdivision");
    //   await expect(contract.deploy(latestTime, { value: 1 })).to.be.revertedWith(
    //     "Unlock time should be in the future"
    //   );
    // });
  });

  // describe("Withdrawals", function () {
  //   describe("Validations", function () {
  //     it("Should revert with the right error if called too soon", async function () {
  //       const { contract } = await loadFixture(deployFixture);
  //
  //       await expect(contract.withdraw()).to.be.revertedWith("You can't withdraw yet");
  //     });
  //
  //     it("Should revert with the right error if called from another account", async function () {
  //       const { contract, unlockTime, otherAccount } = await loadFixture(deployFixture);
  //
  //       // We can increase the time in Hardhat Network
  //       await time.increaseTo(unlockTime);
  //
  //       // We use lock.connect() to send a transaction from another account
  //       await expect(contract.connect(otherAccount).withdraw()).to.be.revertedWith(
  //         "You aren't the owner"
  //       );
  //     });
  //
  //     it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
  //       const { contract, unlockTime } = await loadFixture(deployFixture);
  //
  //       // Transactions are sent using the first signer by default
  //       await time.increaseTo(unlockTime);
  //
  //       await expect(contract.withdraw()).not.to.be.reverted;
  //     });
  //   });
  //
  //   describe("Events", function () {
  //     it("Should emit an event on withdrawals", async function () {
  //       const { contract, unlockTime, lockedAmount } = await loadFixture(deployFixture);
  //
  //       await time.increaseTo(unlockTime);
  //
  //       await expect(contract.withdraw())
  //         .to.emit(contract, "Withdrawal")
  //         .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
  //     });
  //   });
  //
  //   describe("Transfers", function () {
  //     it("Should transfer the funds to the owner", async function () {
  //       const { contract, unlockTime, lockedAmount, owner } = await loadFixture(deployFixture);
  //
  //       await time.increaseTo(unlockTime);
  //
  //       await expect(contract.withdraw()).to.changeEtherBalances(
  //         [owner, contract],
  //         [lockedAmount, -lockedAmount]
  //       );
  //     });
  //   });
  // });
});
