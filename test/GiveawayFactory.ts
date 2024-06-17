import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { Signer } from "ethers"; // Correctly import Signer from ethers
import { ERC20Mock, Giveaway, GiveawayFactory } from "../typechain-types";

describe("GiveawayFactory", function () {
  let factory: GiveawayFactory;
  let giveaway: Giveaway;
  let owner: Signer, addr1: Signer, addr2: Signer, funuser: Signer;
  let token: ERC20Mock;
  const amount = 1000;
  const numPeople = 10;
  const totalAmount = ethers.getBigInt(amount * numPeople);

  beforeEach(async function () {
    const MockIERC20 = await ethers.getContractFactory("ERC20Mock");
    token = await MockIERC20.deploy(
      "MockToken",
      "MTK",
      18,
      ethers.getBigInt(10000000)
    );

    const Factory = await ethers.getContractFactory("GiveawayFactory");
    [owner, addr1, addr2, funuser] = await ethers.getSigners();

    factory = (await upgrades.deployProxy(Factory, [await owner.getAddress()], {
      initializer: "initialize",
    })) as unknown as GiveawayFactory;

    // factory = (await Factory.deploy(owner)) as GiveawayFactory;

    await token.transfer(
      await owner.getAddress(),
      ethers.getBigInt(amount * numPeople * 2)
    );

    const tokenAddress = await token.getAddress();

    await token
      .connect(owner)
      .approve(
        await factory.getAddress(),
        ethers.getBigInt(amount * numPeople)
      );

    // Create a new Giveaway with a slug
    await factory
      .connect(owner)
      .createGiveaway(
        tokenAddress,
        amount,
        numPeople,
        "unique-slug",
        0,
        "http://examplebanner.com"
      );
    const giveawayAddress = await factory.giveaways(0);

    giveaway = (await ethers.getContractAt(
      "Giveaway",
      giveawayAddress
    )) as Giveaway;
    await giveaway.setStatus(1);
  });

  describe("Deployment", function () {
    it("Should start with zero giveaways", async function () {
      const freshFactory = await ethers.getContractFactory("GiveawayFactory");
      const freshInstance = (await upgrades.deployProxy(
        freshFactory,
        [await owner.getAddress()],
        {
          initializer: "initialize",
        }
      )) as unknown as GiveawayFactory;
      expect(await freshInstance.numGiveaways()).to.equal(0);
    });
  });

  describe("Creating Giveaways", function () {
    it("Should have 1 giveaway", async function () {
      expect(await factory.numGiveaways()).to.equal(1);
      expect(
        await factory.getGiveawaysByOwner(await owner.getAddress())
      ).to.have.lengthOf(1);
    });

    it("Should transfer the total amount of tokens to the Giveaway contract", async function () {
      expect(await token.balanceOf(await giveaway.getAddress())).to.equal(
        totalAmount
      );
    });

    it("Should have the giveaway admin as the set admin", async function () {
      expect(await factory.admin()).to.equal(await owner.getAddress());
    });

    it("Should have the correct initial banner", async function () {
      expect(await giveaway.banner()).to.equal("http://examplebanner.com");
    });

    it("Should create a giveaway with the correct slug", async function () {
      expect(await giveaway.customUrl()).to.equal("unique-slug");
    });
  });

  describe("Managing Giveaways", function () {
    it("Should allow the owner to update the status", async function () {
      await expect(giveaway.setStatus(1))
        .to.emit(giveaway, "StatusChange")
        .withArgs(1); // Activate the giveaway
      expect(await giveaway.status()).to.equal(1);
    });

    it("Should allow the owner to update the banner", async function () {
      const newBanner = "http://newbanner.com";
      await expect(giveaway.setBanner(newBanner))
        .to.emit(giveaway, "BannerChange")
        .withArgs(newBanner);
      expect(await giveaway.banner()).to.equal(newBanner);
    });

    it("Should prevent non-owners from updating status", async function () {
      const nonOwner = addr2;
      await expect(giveaway.connect(nonOwner).setStatus(1)).to.be.revertedWith(
        "Only owner can change status"
      );
    });

    it("Should prevent non-owners from updating the banner", async function () {
      const nonOwner = addr2;
      const newBanner = "http://anothernewbanner.com";
      await expect(
        giveaway.connect(nonOwner).setBanner(newBanner)
      ).to.be.revertedWith("Only owner can change the banner");
    });
  });

  describe("Admin and Authentication", function () {
    it("Should allow admin to set authentication status", async function () {
      await expect(
        giveaway
          .connect(owner)
          .setAuthenticated(await funuser.getAddress(), true)
      )
        .to.emit(giveaway, "Authenticated")
        .withArgs(await funuser.getAddress(), true);
      expect(await giveaway.isAuthenticated(await funuser.getAddress())).to.be
        .true;
    });

    it("Should prevent non-admins from setting authentication status", async function () {
      await expect(
        giveaway
          .connect(funuser)
          .setAuthenticated(await funuser.getAddress(), true)
      ).to.be.revertedWith("Only admin can perform this action");
    });

    it("Should allow authenticated users to claim tokens", async function () {
      await giveaway
        .connect(owner)
        .setAuthenticated(await funuser.getAddress(), true);
      expect(
        await giveaway.getClaimableTokens(await funuser.getAddress())
      ).to.equal(amount);
      await expect(giveaway.connect(funuser).claimTokens())
        .to.emit(giveaway, "TokensClaimed")
        .withArgs(await funuser.getAddress(), amount);
      expect(await giveaway.hasClaimed(await funuser.getAddress())).to.be.true;
    });

    it("Should prevent authenticated users from claiming tokens twice", async function () {
      await giveaway
        .connect(owner)
        .setAuthenticated(await funuser.getAddress(), true);
      await giveaway.connect(funuser).claimTokens();
      expect(
        await giveaway.getClaimableTokens(await funuser.getAddress())
      ).to.equal(0);
      await expect(giveaway.connect(funuser).claimTokens()).to.be.revertedWith(
        "Tokens already claimed."
      );
    });

    it("Should prevent unauthenticated users from claiming tokens", async function () {
      await expect(giveaway.connect(funuser).claimTokens()).to.be.revertedWith(
        "User not authenticated."
      );
    });

    it("Should prevent claims when closed", async function () {
      await giveaway
        .connect(owner)
        .setAuthenticated(await funuser.getAddress(), true);
      await giveaway.setStatus(2);
      await expect(giveaway.connect(funuser).claimTokens()).to.be.revertedWith(
        "Giveaway not open."
      );
    });
  });
});

describe("Slug Validation", function () {
  let factory: GiveawayFactory;
  let owner: Signer, addr1: Signer;
  let token: ERC20Mock;

  const amount = 1000;
  const numPeople = 10;

  beforeEach(async function () {
    const Factory = await ethers.getContractFactory("GiveawayFactory");
    [owner, addr1] = await ethers.getSigners();
    factory = (await upgrades.deployProxy(Factory, [await owner.getAddress()], {
      initializer: "initialize",
    })) as unknown as GiveawayFactory;

    const MockIERC20 = await ethers.getContractFactory("ERC20Mock");
    token = await MockIERC20.deploy(
      "MockToken",
      "MTK",
      18,
      ethers.getBigInt(10000000)
    );
    await token.transfer(
      await owner.getAddress(),
      ethers.getBigInt(amount * numPeople * 2)
    );

    await token
      .connect(owner)
      .approve(
        await factory.getAddress(),
        ethers.getBigInt(amount * numPeople)
      );
  });

  it("Should reject slugs with spaces", async function () {
    const invalidSlug = "invalid slug";
    const tokenAddress = await token.getAddress();
    await expect(
      factory
        .connect(owner)
        .createGiveaway(
          tokenAddress,
          amount,
          numPeople,
          invalidSlug,
          0,
          "http://examplebanner.com"
        )
    ).to.be.revertedWith("Invalid slug");
  });

  it("Should reject slugs with special characters", async function () {
    const tokenAddress = await token.getAddress();
    const invalidSlug = "invalid@slug!";
    await expect(
      factory
        .connect(owner)
        .createGiveaway(
          tokenAddress,
          amount,
          numPeople,
          invalidSlug,
          0,
          "http://examplebanner.com"
        )
    ).to.be.revertedWith("Invalid slug");
  });

  it("Should accept valid slugs", async function () {
    const tokenAddress = await token.getAddress();
    const validSlug = "valid-slug_123";
    await expect(
      factory
        .connect(owner)
        .createGiveaway(
          tokenAddress,
          amount,
          numPeople,
          validSlug,
          0,
          "http://examplebanner.com"
        )
    ).not.to.be.reverted;
  });

  it("Should ensure slug uniqueness", async function () {
    const tokenAddress = await token.getAddress();
    const slug = "unique-slug123";
    await factory
      .connect(owner)
      .createGiveaway(
        tokenAddress,
        amount,
        numPeople,
        slug,
        0,
        "http://examplebanner.com"
      ); // First time should work
    await expect(
      factory
        .connect(owner)
        .createGiveaway(
          tokenAddress,
          amount,
          numPeople,
          slug,
          0,
          "http://examplebanner.com"
        )
    ).to.be.revertedWith("Custom URL already used");
  });
});
