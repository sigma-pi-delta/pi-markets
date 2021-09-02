const expect = require("chai").expect;
const sha3 = require('js-sha3').keccak_256
const truffleAssert = require('truffle-assertions');
const BigNumber = require('bignumber.js');
const BN = web3.utils.BN;
require('chai')
  .use(require('chai-bignumber')(BN))
  .should();

const PIBController = artifacts.require("PIBController");
const PIBRegistry = artifacts.require("PIBRegistry");
const PIBIdentityFactory = artifacts.require("PIBIdentityFactory");
const PIBWalletFactory = artifacts.require("PIBWalletFactory");
const PIBStateChecker = artifacts.require("PIBStateChecker");
const PIBWalletMath = artifacts.require("PIBWalletMath");
const PIBWalletFacet = artifacts.require("PIBWalletFacet");
const PIBNameService = artifacts.require("PIBNameService");
const PIBIdentityFacet = artifacts.require("PIBIdentityFacet");
const Helper = artifacts.require("Helper");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
const NAME = "name";
const DATA_HASH = "0x10409a6503a7ab8d1fdce245761bc2e0b89bf2d3416b093f87d03054e95ad9fe";
let IDENTITY;
let HELPER;

contract("PIBIdentityFactory", async (accounts) => {
    
    it("should set initial conditions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let idFactory = await PIBIdentityFactory.deployed();
        let walletFactory = await PIBWalletFactory.deployed();
        let stateChecker = await PIBStateChecker.deployed();
        let walletMath = await PIBWalletMath.deployed();
        let nameService = await PIBNameService.deployed();

        //SET ADDRESSES
        await controller.setNewAddress("1", registry.address, false, {from: accounts[0]});
        await controller.setNewAddress("2", idFactory.address, true, {from: accounts[0]});
        await controller.setNewAddress("3", walletFactory.address, true, {from: accounts[0]});
        await controller.setNewAddress("4", stateChecker.address, false, {from: accounts[0]});
        await controller.setNewAddress("5", walletMath.address, false, {from: accounts[0]});
		await controller.setNewAddress("6", nameService.address, false, {from: accounts[0]});
		await controller.setNewAddress("7", accounts[9], false, {from: accounts[0]});

        //SET COMMISSION
        await controller.setTxCommission("1000000000000000000", {from: accounts[0]});

        //DEPLOY IDENTITIES
        await idFactory.deployIdentity(accounts[2], accounts[3], DATA_HASH, NAME, {from: accounts[0]});

        //INSTANCE CONTRACTS
        let identity1Address = await registry.identities.call(DATA_HASH);
        IDENTITY = await PIBIdentityFacet.at(identity1Address)
        HELPER = await Helper.new();

        await IDENTITY.setState("00", {from: accounts[3]});
    })
    
    it("should Forward Value", async () => {
        let helper = new web3.eth.Contract(Helper.abi, HELPER.address);
        const arg = "777";
        let data = helper.methods.calledPi(arg).encodeABI();
        let response = await IDENTITY.forwardValue(HELPER.address, data, {from: accounts[2], value: parseInt(arg)});

        truffleAssert.eventEmitted(response, 'Forward', (ev) => {
            let result = web3.eth.abi.encodeParameter('uint256', arg);
            
            return ev.destination == HELPER.address && 
                ev.value == arg &&
                ev.data == data &&
                ev.result == result;
        });
    })
    
    it("should Forward Factory", async () => {
        let controller = await PIBController.deployed();
        await controller.setNewAddress("8", HELPER.address, true, {from: accounts[0]});
        let helper = new web3.eth.Contract(Helper.abi, HELPER.address);
        let data = helper.methods.factoryCall().encodeABI();
        let response = await IDENTITY.forwardFactory(HELPER.address, data, {from: accounts[2]});

        truffleAssert.eventEmitted(response, 'FactoryForward', (ev) => {
            return ev.kind == "8" && 
                ev.contractAddress == HELPER.address;
        });
    })
    
    it("should Recharge EOA", async () => {
        let nameService = await PIBNameService.deployed();
        let balance = await web3.eth.getBalance(accounts[2]);
        let balanceBN = new BigNumber(balance);
        let minBalance = await IDENTITY.minBalance.call();
        let minBalanceBN = new BigNumber(minBalance)
        let oneBN = new BigNumber("1");

        let value = balanceBN.minus(minBalanceBN.plus(oneBN));

        let wallet1Address = await nameService.addr.call(NAME);

        //WHEN TESTING CHANGE MINBALANCE TO 1 PI
        await web3.eth.sendTransaction({from: accounts[2], to: wallet1Address, value: value});

        let helper = new web3.eth.Contract(Helper.abi, HELPER.address);
        let data = helper.methods.factoryCall().encodeABI();
        let response = await IDENTITY.forwardValue(HELPER.address, data, {from: accounts[2]});

        //GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case IDENTITY.address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
			
				default:
					break;
			}
        });

        let tokenAddress = events.Transfer.tokenAddress;
        let kind = events.Transfer.kind;
        let to = events.Transfer.to;
        let evValue = events.Transfer.value;
        let evData = events.Transfer.data;
        let expectedData = "Recharge EOA";

        expect(tokenAddress).to.equal(ZERO_ADDRESS);
        expect(kind).to.equal("0");
        expect(to).to.equal(accounts[2]);
        expect(parseInt(evValue)).to.be.within(0, 1000000000000000000);
        expect(evData).to.equal(expectedData);
    })

    it("should Revert on transfer", async () => {
        await truffleAssert.reverts(web3.eth.sendTransaction({from: accounts[5], to: IDENTITY.address, value: 1}));        
    })

    it("should Revert on Bad Forward", async () => {
        let helper = new web3.eth.Contract(Helper.abi, HELPER.address);
        let data = helper.methods.factoryCall().encodeABI();
        await truffleAssert.reverts(IDENTITY.forwardValue(IDENTITY.address, data, {from: accounts[2]}));        
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