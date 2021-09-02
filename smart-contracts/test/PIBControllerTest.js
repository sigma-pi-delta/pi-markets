const expect = require("chai").expect;
const truffleAssert = require('truffle-assertions');
const BN = web3.utils.BN;
require('chai')
  .use(require('chai-bignumber')(BN))
  .should();

const PIBController = artifacts.require("PIBController");

const TOKEN1 = "0x1d282D1A963Df08c1Dc19D837dDDd014A83922e1";
const TOKEN2 = "0x0358D2B7D5Da73419137D8dD0f9482D4BCf9fDcB";
const NFTOKEN = "0x9132AebD8E9b5AC549Efe3ecb53c40C299B247Ba";
const MARKET = "0xdd4335b23Faccac6E6975303f6C857552E2AAc91";

/*
    '0x627306090abaB3A6e1400e9345bC60c78a8BEf57',
    '0xf17f52151EbEF6C7334FAD080c5704D77216b732',
    '0xC5fdf4076b8F3A5357c5E395ab970B5B54098Fef',
    '0x821aEa9a577a9b44299B9c15c88cf3087F3b5544',
    '0x0d1d4e623D10F9FBA5Db95830F7d3839406C6AF2',
    '0x2932b7A2355D6fecc4b5c0B6BD44cC31df247a2e',
    '0x2191eF87E392377ec08E7c08Eb105Ef5448eCED5',
    '0x0F4F2Ac550A1b4e2280d04c21cEa7EBD822934b5',
    '0x6330A553Fc93768F612722BB8c2eC78aC90B3bbc',
    '0x5AEDA56215b167893e80B4fE645BA6d5Bab767DE'
*/

contract("PIBController", async (accounts) => {

    it("should set a new Owner", async () => {
        let controller = await PIBController.deployed();
        let oldOwner = await controller.owner.call();
        let response = await controller.setOwner(accounts[1], {from: accounts[0]});
        let newOwner = await controller.owner.call();

        expect(oldOwner).to.equal(accounts[0]);
        expect(newOwner).to.equal(accounts[1]);

        truffleAssert.eventEmitted(response, 'NewOwner', (ev) => {
            return ev.old == accounts[0] && ev.current == accounts[1];
        });
    })

    it("should set a new Switcher", async () => {
        let controller = await PIBController.deployed();
        let oldSwitcher = await controller.switcher.call();
        let response = await controller.setSwitcher(accounts[0], {from: accounts[1]});
        let newSwitcher = await controller.switcher.call();

        expect(oldSwitcher).to.equal(accounts[1]);
        expect(newSwitcher).to.equal(accounts[0]);

        truffleAssert.eventEmitted(response, 'NewSwitcher', (ev) => {
            return ev.old == accounts[1] && ev.current == accounts[0];
        });
    })

    it("should Toggle Switch", async () => {
        let controller = await PIBController.deployed();
        let status_0 = await controller.on.call();
        await controller.toggleSwitch({from: accounts[0]});
        let status_1 = await controller.on.call();

        expect(status_0).to.equal(!status_1);

        await controller.toggleSwitch({from: accounts[0]});
    })

    it("should set a new Address", async () => {
        let controller = await PIBController.deployed();
        let response = await controller.setNewAddress("7", accounts[2], false, {from: accounts[1]});
        let kind = await controller.kinds.call(accounts[2]);
        let addr = await controller.addresses.call("7");

        expect(kind.toString()).to.equal("7");
        expect(addr).to.equal(accounts[2])

        truffleAssert.eventEmitted(response, 'NewAddress', (ev) => {
            return ev.kind == "7" && ev.contractAddress == accounts[2] && ev.isFactory == false;
        });
    })

    it("should set a new Factory Address", async () => {
        let controller = await PIBController.deployed();
        let response = await controller.setNewAddress("7", accounts[3], true, {from: accounts[1]});
        let kind = await controller.kinds.call(accounts[3]);
        let addr = await controller.addresses.call("7");
        let isFactory = await controller.isFactory.call(accounts[3]);

        expect(kind.toString()).to.equal("7");
        expect(addr).to.equal(accounts[3]);
        expect(isFactory).to.equal(true);

        truffleAssert.eventEmitted(response, 'NewAddress', (ev) => {
            return ev.kind == "7" && ev.contractAddress == accounts[3] && ev.isFactory == true;
        });
    })

    it("should set a new Token", async () => {
        let controller = await PIBController.deployed();
        let response = await controller.setNewToken(TOKEN1, 1, true, {from: accounts[1]});
        let isToken = await controller.isToken.call(TOKEN1);

        expect(isToken).to.equal(true);

        truffleAssert.eventEmitted(response, 'NewToken', (ev) => {
            return ev.newToken == TOKEN1;
        });
    })

    it("should set a new NFToken", async () => {
        let controller = await PIBController.deployed();
        let response = await controller.setNewNFToken(NFTOKEN, "1", true, {from: accounts[1]});
        let isNFToken = await controller.isNFToken.call(NFTOKEN);

        expect(isNFToken).to.equal(true);

        truffleAssert.eventEmitted(response, 'NewNFToken', (ev) => {
            return ev.newToken == NFTOKEN;
        });
    })

    it("should set a new Market", async () => {
        let controller = await PIBController.deployed();
        await controller.setNewToken(TOKEN2, 1, true, {from: accounts[1]});
        let response = await controller.setNewMarket(TOKEN1, TOKEN2, MARKET, {from: accounts[1]});
        let market1 = await controller.markets.call(TOKEN1, TOKEN2);
        let market2 = await controller.markets.call(TOKEN2, TOKEN1);

        expect(market1).to.equal(MARKET);
        expect(market2).to.equal(MARKET);

        truffleAssert.eventEmitted(response, 'NewMarket', (ev) => {
            return ev.tokenA == TOKEN1 && ev.tokenB == TOKEN2 && ev.market == MARKET;
        });
    })

    it("should set commission", async () => {
        let controller = await PIBController.deployed();
        let initial_commission = await controller.commission.call();
        let zero_BN = new BN(0);
        let one_BN = new BN("1000000000000000000");
        let response = await controller.setTxCommission("1000000000000000000", {from: accounts[1]});
        let setted_commission = await controller.commission.call();
        
        expect(initial_commission.toString()).to.equal(zero_BN.toString());
        expect(setted_commission.toString()).to.equal(one_BN.toString());

        truffleAssert.eventEmitted(response, 'NewCommission', (ev) => {
            return ev.newCommission == one_BN.toString();
        });
      
    })

    it("should revert trying to setOwner from no-owner", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setOwner(accounts[1], {from: accounts[2]}));
    })

    it("should revert trying to setSwitcher from no-owner", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setSwitcher(accounts[0], {from: accounts[2]}));
    })

    it("should revert trying to toggleSwitch from no-owner", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.toggleSwitch({from: accounts[2]}));
    })

    it("should revert trying to setNewAddress from no-owner", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setNewAddress("7", accounts[2], false, {from: accounts[2]}));
    })

    it("should revert trying to setNewToken from no-owner", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setNewToken(TOKEN1, 1, true, {from: accounts[2]}));
    })

    it("should revert trying to setNewNFToken from no-owner", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setNewNFToken(NFTOKEN, "1", true, {from: accounts[2]}));
    })

    it("should revert trying to setTxCommission from no-owner", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setTxCommission("1000000000000000000", {from: accounts[2]}));
    })

    it("should toggleSwitch to revert all after that", async () => {
        let controller = await PIBController.deployed();
        await controller.toggleSwitch({from: accounts[0]});
    })

    it("should revert trying to setOwner after toggleOff", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setOwner(accounts[1], {from: accounts[1]}));
    })

    it("should revert trying to setSwitcher after toggleOff", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setSwitcher(accounts[0], {from: accounts[1]}));
    })

    it("should revert trying to setNewAddress after toggleOff", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setNewAddress("7", accounts[2], false, {from: accounts[1]}));
    })

    it("should revert trying to setNewToken after toggleOff", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setNewToken(TOKEN1, 1, true, {from: accounts[1]}));
    })

    it("should revert trying to setNewNFToken after toggleOff", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setNewNFToken(NFTOKEN, 1, true, {from: accounts[1]}));
    })

    it("should revert trying to setTxCommission after toggleOff", async () => {
        let controller = await PIBController.deployed();
        await truffleAssert.reverts(controller.setTxCommission("1000000000000000000", {from: accounts[1]}));
    })
    
});