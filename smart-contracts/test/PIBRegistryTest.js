const expect = require("chai").expect;
const truffleAssert = require('truffle-assertions');
const BN = web3.utils.BN;
require('chai')
  .use(require('chai-bignumber')(BN))
  .should();

const PIBRegistry = artifacts.require("PIBRegistry");
const PIBController = artifacts.require("PIBController");

const IDENTITY = "0xdd4335b23Faccac6E6975303f6C857552E2AAc91";
const DATA_HASH = "0x10409a6503a7ab8d1fdce245761bc2e0b89bf2d3416b093f87d03054e95ad9fe";
const DATA_HASH_DD = "0x9b776d8e64864e1c7c2a4c9ae3270076bfdf1b92dab712b0a21f185bbc8f9d66";

contract("PIBRegistry", async (accounts) => {

    it("should Toggle Switch", async () => {
        let registry = await PIBRegistry.deployed();
        let status_0 = await registry.on.call();
        await registry.toggleSwitch({from: accounts[1]});
        let status_1 = await registry.on.call();

        expect(status_0).to.equal(!status_1);

        await registry.toggleSwitch({from: accounts[1]});
    })

    it("should revert trying to set a new dataHash with DD before id exists", async () => {
        let registry = await PIBRegistry.deployed();
        await truffleAssert.reverts(registry.setNewIdentityDD(IDENTITY, DATA_HASH_DD, {from: accounts[0]}));
    })

    it("should set a new Identity", async () => {
        let controller = await PIBController.deployed();
        await controller.setNewAddress("2", accounts[0], false, {from: accounts[0]});

        let registry = await PIBRegistry.deployed();
        let response = await registry.setNewIdentity(IDENTITY, DATA_HASH, {from: accounts[0]});
        let id = await registry.identities.call(DATA_HASH);
        let hash = await registry.hashes.call(IDENTITY);

        expect(id).to.equal(IDENTITY);
        expect(hash).to.equal(DATA_HASH);

        truffleAssert.eventEmitted(response, 'NewIdentity', (ev) => {
            return ev.identity == IDENTITY && ev._dataHash == DATA_HASH;
        });
    })

    it("should revert trying to modify id's dataHash", async () => {
        let registry = await PIBRegistry.deployed();
        await truffleAssert.reverts(registry.setNewIdentity(IDENTITY, DATA_HASH_DD, {from: accounts[0]}));
    })
    
    it("should revert trying to use an unavailable hash for another id", async () => {
        let registry = await PIBRegistry.deployed();
        //accounts[5] simulates a PIBIdentity contract...is just an address
        await truffleAssert.reverts(registry.setNewIdentity(accounts[5], DATA_HASH, {from: accounts[0]}));
    })

    it("should set a new dataHash with Due Diligence", async () => {
        let registry = await PIBRegistry.deployed();
        let response = await registry.setNewIdentityDD(IDENTITY, DATA_HASH_DD, {from: accounts[0]});
        let id = await registry.identitiesDD.call(DATA_HASH_DD);
        let hash = await registry.hashesDD.call(IDENTITY);

        expect(id).to.equal(IDENTITY);
        expect(hash).to.equal(DATA_HASH_DD);

        truffleAssert.eventEmitted(response, 'NewIdentityDD', (ev) => {
            return ev.identity == IDENTITY && ev._dataHashDD == DATA_HASH_DD;
        });
    })

    it("should revert trying to modify dataHashDD", async () => {
        let registry = await PIBRegistry.deployed();
        await truffleAssert.reverts(registry.setNewIdentityDD(IDENTITY, DATA_HASH, {from: accounts[0]}));
    })

    it("should revert trying to use an unavailable hashDD for another id", async () => {
        let registry = await PIBRegistry.deployed();
        //accounts[5] simulates a PIBIdentity contract...is just an address
        await truffleAssert.reverts(registry.setNewIdentityDD(accounts[5], DATA_HASH_DD, {from: accounts[0]}));
    })
    
});