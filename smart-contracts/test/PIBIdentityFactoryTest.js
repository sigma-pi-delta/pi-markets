const expect = require("chai").expect;
const truffleAssert = require('truffle-assertions');
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
const ID_RECOVERY = "0x1d282D1A963Df08c1Dc19D837dDDd014A83922e1"
const DATA_HASH = "0x10409a6503a7ab8d1fdce245761bc2e0b89bf2d3416b093f87d03054e95ad9fe";
const NAME = "name"

contract("PIBIdentityFactory", async (accounts) => {

    it("should Toggle Switch", async () => {
        let idFactory = await PIBIdentityFactory.deployed();
        let status_0 = await idFactory.on.call();
        await idFactory.toggleSwitch({from: accounts[1]});
        let status_1 = await idFactory.on.call();

        expect(status_0).to.equal(!status_1);

        await idFactory.toggleSwitch({from: accounts[1]});
    })

    it("should deploy new Identity", async () => {
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

        let identity = await registry.identities.call(DATA_HASH);
        let hash = await registry.hashes.call(identity);
        let wallet = await nameService.addr.call(NAME);

        expect(hash).to.equal(DATA_HASH);

        truffleAssert.eventEmitted(response, 'DeployIdentity', (ev) => {
            return ev.identity == identity && 
                ev.owner == ID_OWNER &&
                ev.recovery == ID_RECOVERY &&
                ev.wallet == wallet &&
                ev.name == NAME &&
                ev.dataHash == DATA_HASH;
        });
    })
    
});