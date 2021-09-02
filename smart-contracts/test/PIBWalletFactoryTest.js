const expect = require("chai").expect;
const truffleAssert = require('truffle-assertions');
const sha3 = require('js-sha3').keccak_256
const BN = web3.utils.BN;
require('chai')
  .use(require('chai-bignumber')(BN))
  .should();

const PIBController = artifacts.require("PIBController");
const PIBRegistry = artifacts.require("PIBRegistry");
const PIBIdentityFactory = artifacts.require("PIBIdentityFactory");
const PIBWalletFactory = artifacts.require("PIBWalletFactory");
const PIBNameService = artifacts.require("PIBNameService");

const ID_OWNER = "0xdd4335b23Faccac6E6975303f6C857552E2AAc91"
const ID_RECOVERY = "0xdd4335b23Faccac6E6975303f6C857552E2AAc91"
const DATA_HASH = "0x10409a6503a7ab8d1fdce245761bc2e0b89bf2d3416b093f87d03054e95ad9fe";
const NAME = "name"

contract("PIBIdentityFactory", async (accounts) => {


    it("should deploy new Wallet (after deploying Identity)", async () => {
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let idFactory = await PIBIdentityFactory.deployed();
        let walletFactory = await PIBWalletFactory.deployed();
        let nameService = await PIBNameService.deployed();

        //SET ADDRESSES
        await controller.setNewAddress("1", registry.address, false, {from: accounts[0]});
        await controller.setNewAddress("2", idFactory.address, true, {from: accounts[0]});
        await controller.setNewAddress("3", walletFactory.address, true, {from: accounts[0]});
        await controller.setNewAddress("6", nameService.address, false, {from: accounts[0]});

        //DEPLOY IDENTITY
        let response = await idFactory.deployIdentity(ID_OWNER, ID_RECOVERY, DATA_HASH, NAME, {from: accounts[0]});

        let event;

        response.receipt.rawLogs.forEach(function(log) {
            if (log.topics[0] == '0x' + sha3("NewWallet(address,address)")) {
                event = log;
            }
        });

        let eventIdentity = event.topics[1].replace("0x000000000000000000000000", "0x");
        let eventWallet = event.topics[2].replace("0x000000000000000000000000", "0x");

        let identity = await registry.identities.call(DATA_HASH);
        let wallet = await nameService.addr.call(NAME);

        expect(eventIdentity).to.equal(identity.toLowerCase());
        expect(eventWallet).to.equal(wallet.toLowerCase());
    })
    
});