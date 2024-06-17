import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const GiveawayFactoryModule = buildModule("GiveawayFactoryModule", (m) => {
  const adminAddress = m.getParameter("adminAddress");

  const giveawayFactory = m.contract("GiveawayFactory", []);

  return { giveawayFactory };
});

export default GiveawayFactoryModule;
