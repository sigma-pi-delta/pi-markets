const expect = require("chai").expect;
const sha3 = require('js-sha3').keccak_256
const truffleAssert = require('truffle-assertions');
const BN = web3.utils.BN;
require('chai')
  .use(require('chai-bignumber')(BN))
  .should();

const PIBController = artifacts.require("PIBController");
const PIBRegistry = artifacts.require("PIBRegistry");
const PIBIdentityFactory = artifacts.require("PIBIdentityFactory");
const PIBWalletFactory = artifacts.require("PIBWalletFactory");
const PIBStateChecker = artifacts.require("PIBStateChecker");
const PIBNameService = artifacts.require("PIBNameService");
const PIBIdentityFacet = artifacts.require("PIBIdentityFacet");
const PIBIdentityDiamond = artifacts.require("PIBIdentityDiamond");

const WALLET = "0x1d282D1A963Df08c1Dc19D837dDDd014A83922e1";
const WALLET2 = "0xdd4335b23Faccac6E6975303f6C857552E2AAc91"
const NAME = "name";
const NAME2 = "name2";
const DATA_HASH = "0x10409a6503a7ab8d1fdce245761bc2e0b89bf2d3416b093f87d03054e95ad9fe";
const DATA_HASH_2 = "0x32d221930b0cc9bc99daa6387493586285fe6f82c088e0154b4ea4666c43a063";

contract("PIBNameService", async (accounts) => {
    
    it("should create a Name", async () => {
        let controller = await PIBController.deployed();
        let nameService = await PIBNameService.deployed();

        await controller.setNewAddress("2", accounts[0], false, {from: accounts[0]});
        let response = await nameService.createName(NAME, WALLET, accounts[0], {from: accounts[0]});

        truffleAssert.eventEmitted(response, 'CreateName', (ev) => {
            return ev.name == NAME && 
                ev.wallet == WALLET &&
                ev.owner == accounts[0];
        });
    })

    it("should check Names availability", async () => {
        let nameService = await PIBNameService.deployed();

        let nameHash = '0x' + sha3("invent");
        let availableName = await nameService.nameIsAvailable(nameHash);
        expect(availableName).to.equal(true);

        let nameHash2 = '0x' + sha3(NAME);
        let usedName = await nameService.nameIsAvailable(nameHash2);
        expect(usedName).to.equal(false);
    })

    it("should check Name Owner", async () => {
        let nameService = await PIBNameService.deployed();

        let nameHash2 = '0x' + sha3(NAME);
        let isOwner = await nameService.isNameOwner(nameHash2, {from: accounts[0]});
        expect(isOwner).to.equal(true);

        let isOwner2 = await nameService.isNameOwner(nameHash2, {from: accounts[1]});
        expect(isOwner2).to.equal(false);
    })

    it("should check return Name of an Address", async () => {
        let nameService = await PIBNameService.deployed();

        let name = await nameService.name(WALLET);
        expect(name).to.equal(NAME);
    })

    it("should check return Address of a Name", async () => {
        let nameService = await PIBNameService.deployed();

        let addr = await nameService.addr(NAME);
        expect(addr).to.equal(WALLET);
    })

    /*it("should check return Address of a NameHash", async () => {
        let nameService = await PIBNameService.deployed();

        let nameHash = '0x' + sha3(NAME);
        let addr = await nameService.addr(nameHash);
        expect(addr).to.equal(WALLET);
    })*/

    it("should change Wallet of a Name and set free map of the old wallet", async () => {
        let nameService = await PIBNameService.deployed();

        let response = await nameService.changeWallet(NAME, WALLET2);
        let addr = await nameService.addr(NAME);
        let oldName = await nameService.name(WALLET);
        let name = await nameService.name(WALLET2);

        expect(addr).to.equal(WALLET2);
        expect(oldName).not.to.equal(NAME);
        expect(name).to.equal(NAME);

        truffleAssert.eventEmitted(response, 'ChangeWallet', (ev) => {
            return ev.name == NAME && ev.wallet == WALLET2;
        });
    })

    it("should deploy new Wallet (after deploying Identity)", async () => {
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let idFactory = await PIBIdentityFactory.deployed();
        let walletFactory = await PIBWalletFactory.deployed();
        let stateChecker = await PIBStateChecker.deployed();
        let nameService = await PIBNameService.deployed();

        //SET ADDRESSES
        await controller.setNewAddress("1", registry.address, false, {from: accounts[0]});
        await controller.setNewAddress("2", idFactory.address, true, {from: accounts[0]});
        await controller.setNewAddress("3", walletFactory.address, true, {from: accounts[0]});
        await controller.setNewAddress("4", stateChecker.address, true, {from: accounts[0]});
        await controller.setNewAddress("6", nameService.address, false, {from: accounts[0]});

        //DEPLOY IDENTITY
        await idFactory.deployIdentity(accounts[2], accounts[2], DATA_HASH_2, NAME2, {from: accounts[0]});

        let identityAddress = await registry.identities.call(DATA_HASH_2);
        let identity = await PIBIdentityFacet.at(identityAddress);

        let identity2 = await PIBIdentityDiamond.new(accounts[0], accounts[1], "new", controller.address);

        let nameService2 = new web3.eth.Contract(PIBNameService.abi, nameService.address);
        let calldata = nameService2.methods.changeNameOwner(NAME2, identity2.address).encodeABI();
        
        let response = await identity.forward(nameService.address, calldata, {from: accounts[2]});

        //GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case identity.address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case nameService.address.toLowerCase():
					result = decodeEvent(PIBNameService, log);
					events[result[1]] = result[0];
					break;
			
				default:
					break;
			}
        });

        expect(events.ChangeOwner.name).to.equal(NAME2);
        expect(events.ChangeOwner.newOwner).to.equal(identity2.address);

        let nameHash = '0x' + sha3(NAME2);
        let owner = await nameService.nameOwners.call(nameHash);

        expect(owner).to.equal(identity2.address);
    })
    
});

function decodeEvent(contract, log) {
	let inputs = contract.events[log.topics[0]].inputs;
	let data = log.data;
	let topics = log.topics.slice(1);
	let event = web3.eth.abi.decodeLog(inputs, data, topics);
	let name = contract.events[log.topics[0]].name

	return [event, name];
}