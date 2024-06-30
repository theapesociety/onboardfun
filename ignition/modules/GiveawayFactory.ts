import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const GiveawayFactoryModule = buildModule("GiveawayFactoryModule", (m) => {
  const giveawayFactory = m.contract("GiveawayFactory", [
    "0xc9Eddf31f1B8D7C2A9C0B4907E0d1948e4A2E045",
  ]);

  return { giveawayFactory };
});

export default GiveawayFactoryModule;
