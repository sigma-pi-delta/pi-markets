const expect = require("chai").expect;
const sha3 = require('js-sha3').keccak_256
const truffleAssert = require('truffle-assertions');
const BN = web3.utils.BN;
require('chai')
  .use(require('chai-bignumber')(BN))
  .should();

const PIBController = artifacts.require("PIBController");
const PIBIdentityAddressManagerFacet = artifacts.require("PIBIdentityAddressManagerFacet");
const PIBIdentityDiamond = artifacts.require("PIBIdentityDiamond");

const WALLET = "0x1d282D1A963Df08c1Dc19D837dDDd014A83922e1";
const WALLET2 = "0xdd4335b23Faccac6E6975303f6C857552E2AAc91"
const NAME = "name";
const NAME2 = "name2";


contract("PIBNameService", async (accounts) => {
    
    it("owner should be able to setOwner", async () => {
        let controller = await PIBController.deployed();
        let identity = await PIBIdentityDiamond.new(accounts[0], accounts[1], NAME, controller.address);
        let manager = await PIBIdentityAddressManagerFacet.at(identity.address);

        let response = await manager.setOwner(accounts[2], {from: accounts[0]});

        let owner = await manager.owner.call();

        expect(owner).to.equal(accounts[2]);

        truffleAssert.eventEmitted(response, 'NewOwner', (ev) => {
            return ev.sender == accounts[0] && 
                ev.old == accounts[0] &&
                ev.current == accounts[2];
        });
    })

    it("recovery should be able to setOwner", async () => {
        let controller = await PIBController.deployed();
        let identity = await PIBIdentityDiamond.new(accounts[0], accounts[1], NAME, controller.address);
        let manager = await PIBIdentityAddressManagerFacet.at(identity.address);

        let response = await manager.setOwner(accounts[2], {from: accounts[1]});

        let owner = await manager.owner.call();

        expect(owner).to.equal(accounts[2]);

        truffleAssert.eventEmitted(response, 'NewOwner', (ev) => {
            return ev.sender == accounts[1] && 
                ev.old == accounts[0] &&
                ev.current == accounts[2];
        });
    })

    it("recovery should be able to setRecovery", async () => {
        let controller = await PIBController.deployed();
        let identity = await PIBIdentityDiamond.new(accounts[0], accounts[1], NAME, controller.address);
        let manager = await PIBIdentityAddressManagerFacet.at(identity.address);

        let response = await manager.setRecovery(accounts[2], {from: accounts[1]});

        let recovery = await manager.recovery.call();

        expect(recovery).to.equal(accounts[2]);

        truffleAssert.eventEmitted(response, 'NewRecovery', (ev) => {
            return ev.old == accounts[1] &&
                ev.current == accounts[2];
        });
    })

    it("should set the Name", async () => {
        let controller = await PIBController.deployed();
        let identity = await PIBIdentityDiamond.new(accounts[0], accounts[1], NAME, controller.address);
        let manager = await PIBIdentityAddressManagerFacet.at(identity.address);

        await controller.setNewAddress("6", accounts[0], false, {from: accounts[0]});
        let response = await manager.setName(NAME2, {from: accounts[0]});

        let name = await manager.name.call();

        expect(name).to.equal(NAME2);

        truffleAssert.eventEmitted(response, 'NewName', (ev) => {
            return ev.sender == accounts[0] && 
                ev.old == NAME &&
                ev.current == NAME2;
        });
    })

    it("should set the Wallet", async () => {
        let controller = await PIBController.deployed();
        let identity = await PIBIdentityDiamond.new(accounts[0], accounts[1], NAME, controller.address);
        let manager = await PIBIdentityAddressManagerFacet.at(identity.address);

        await controller.setNewAddress("3", accounts[0], false, {from: accounts[0]});
        let response = await manager.setWallet(accounts[3], {from: accounts[0]});

        let wallet = await manager.wallet.call();

        expect(wallet).to.equal(accounts[3]);

        truffleAssert.eventEmitted(response, 'NewWallet', (ev) => {
            return ev.sender == accounts[0] && 
                ev.current == accounts[3];
        });
    })
    
});