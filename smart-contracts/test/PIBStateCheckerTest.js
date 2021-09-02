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

const RAND_DESTINATION = "0x627306090abaB3A6e1400e9345bC60c78a8BEf57";

contract("PIBStateChecker", async (accounts) => {
    
    it("should check state (BIT 0)", async () => {
        let controller = await PIBController.deployed();
        let nameService = await PIBNameService.deployed();
        let stateChecker = await PIBStateChecker.deployed();

        await controller.setNewAddress("6", nameService.address, false, {from: accounts[0]});

        let state1 = "0"; //ACTIVE
        let state2 = "1"; //INACTIVE

        let check1A = await stateChecker.checkState.call(state1, "0", RAND_DESTINATION);
        let check1B = await stateChecker.checkState.call(state1, "6", RAND_DESTINATION);
        let check1C = await stateChecker.checkState.call(state1, "0", nameService.address);
        let check1D = await stateChecker.checkState.call(state1, "6", nameService.address);

        let check2A = await stateChecker.checkState.call(state2, "0", RAND_DESTINATION);
        let check2B = await stateChecker.checkState.call(state2, "6", RAND_DESTINATION);
        let check2C = await stateChecker.checkState.call(state2, "0", nameService.address);
        let check2D = await stateChecker.checkState.call(state2, "6", nameService.address);

        expect(check1A).to.equal(true);
        expect(check1B).to.equal(true);
        expect(check1C).to.equal(true);
        expect(check1D).to.equal(true);

        expect(check2A).to.equal(false);
        expect(check2B).to.equal(false);
        expect(check2C).to.equal(false);
        expect(check2D).to.equal(false);

    })

    it("should check state (BIT 1)", async () => {
        let controller = await PIBController.deployed();
        let nameService = await PIBNameService.deployed();
        let stateChecker = await PIBStateChecker.deployed();

        await controller.setNewAddress("6", nameService.address, false, {from: accounts[0]});

        let state1 = "00"; //ACTIVE & ALL DESTINATION
        let state2 = "01"; //INACTIVE & ALL DESTINATION
        let state3 = "10"; //ACTIVE & OFFICIAL DESTINATION
        let state4 = "11"; //INACTIVE & OFFICIAL DESTINATION

        let check1A = await stateChecker.checkState.call(state1, "0", RAND_DESTINATION);
        let check1B = await stateChecker.checkState.call(state1, "6", RAND_DESTINATION);
        let check1C = await stateChecker.checkState.call(state1, "0", nameService.address);
        let check1D = await stateChecker.checkState.call(state1, "6", nameService.address);

        let check2A = await stateChecker.checkState.call(state2, "0", RAND_DESTINATION);
        let check2B = await stateChecker.checkState.call(state2, "6", RAND_DESTINATION);
        let check2C = await stateChecker.checkState.call(state2, "0", nameService.address);
        let check2D = await stateChecker.checkState.call(state2, "6", nameService.address);

        let check3A = await stateChecker.checkState.call(state3, "0", RAND_DESTINATION);
        let check3B = await stateChecker.checkState.call(state3, "6", RAND_DESTINATION);
        let check3C = await stateChecker.checkState.call(state3, "0", nameService.address);
        let check3D = await stateChecker.checkState.call(state3, "6", nameService.address);

        let check4A = await stateChecker.checkState.call(state4, "0", RAND_DESTINATION);
        let check4B = await stateChecker.checkState.call(state4, "6", RAND_DESTINATION);
        let check4C = await stateChecker.checkState.call(state4, "0", nameService.address);
        let check4D = await stateChecker.checkState.call(state4, "6", nameService.address);

        expect(check1A).to.equal(true);
        expect(check1B).to.equal(true);
        expect(check1C).to.equal(true);
        expect(check1D).to.equal(true);

        expect(check2A).to.equal(false);
        expect(check2B).to.equal(false);
        expect(check2C).to.equal(false);
        expect(check2D).to.equal(false);

        expect(check3A).to.equal(false);
        expect(check3B).to.equal(true);
        expect(check3C).to.equal(true);
        expect(check3D).to.equal(true);

        expect(check4A).to.equal(false);
        expect(check4B).to.equal(false);
        expect(check4C).to.equal(false);
        expect(check4D).to.equal(false);

    })

    it("should check state (BIT 3)", async () => {
        let controller = await PIBController.deployed();
        let nameService = await PIBNameService.deployed();
        let stateChecker = await PIBStateChecker.deployed();

        await controller.setNewAddress("6", nameService.address, false, {from: accounts[0]});

        //NOTE BIT 2 IS INSIGNIFICANT (0000 = 0100)
        let state1 = "0000"; //ACTIVE & ALL DESTINATION & WALLET_ON
        let state2 = "0001"; //INACTIVE & ALL DESTINATION & WALLET_ON
        let state3 = "0010"; //ACTIVE & OFFICIAL DESTINATION & WALLET_ON
        let state4 = "0011"; //INACTIVE & OFFICIAL DESTINATION & WALLET_ON
        //let state1 = "0100"; 
        //let state2 = "0101";
        //let state3 = "0110";
        //let state4 = "0111";
        let state5 = "1000"; //ACTIVE & ALL DESTINATION & WALLET_OFF
        let state6 = "1001"; //INACTIVE & ALL DESTINATION & WALLET_OFF
        let state7 = "1010"; //ACTIVE & OFFICIAL DESTINATION & WALLET_OFF
        let state8 = "1011"; //INACTIVE & OFFICIAL DESTINATION & WALLET_OFF
        //let state5 = "1100";
        //let state6 = "1101";
        //let state7 = "1110";
        //let state8 = "1111";

        let check1A = await stateChecker.checkState.call(state1, "0", RAND_DESTINATION);
        let check1B = await stateChecker.checkState.call(state1, "3", RAND_DESTINATION);
        let check1C = await stateChecker.checkState.call(state1, "0", nameService.address);
        let check1D = await stateChecker.checkState.call(state1, "3", nameService.address);

        let check2A = await stateChecker.checkState.call(state2, "0", RAND_DESTINATION);
        let check2B = await stateChecker.checkState.call(state2, "3", RAND_DESTINATION);
        let check2C = await stateChecker.checkState.call(state2, "0", nameService.address);
        let check2D = await stateChecker.checkState.call(state2, "3", nameService.address);

        let check3A = await stateChecker.checkState.call(state3, "0", RAND_DESTINATION);
        let check3B = await stateChecker.checkState.call(state3, "3", RAND_DESTINATION);
        let check3C = await stateChecker.checkState.call(state3, "0", nameService.address);
        let check3D = await stateChecker.checkState.call(state3, "3", nameService.address);

        let check4A = await stateChecker.checkState.call(state4, "0", RAND_DESTINATION);
        let check4B = await stateChecker.checkState.call(state4, "3", RAND_DESTINATION);
        let check4C = await stateChecker.checkState.call(state4, "0", nameService.address);
        let check4D = await stateChecker.checkState.call(state4, "3", nameService.address);

        let check5A = await stateChecker.checkState.call(state5, "0", RAND_DESTINATION);
        let check5B = await stateChecker.checkState.call(state5, "3", RAND_DESTINATION);
        let check5C = await stateChecker.checkState.call(state5, "0", nameService.address);
        let check5D = await stateChecker.checkState.call(state5, "3", nameService.address);

        let check6A = await stateChecker.checkState.call(state6, "0", RAND_DESTINATION);
        let check6B = await stateChecker.checkState.call(state6, "3", RAND_DESTINATION);
        let check6C = await stateChecker.checkState.call(state6, "0", nameService.address);
        let check6D = await stateChecker.checkState.call(state6, "3", nameService.address);

        let check7A = await stateChecker.checkState.call(state7, "0", RAND_DESTINATION);
        let check7B = await stateChecker.checkState.call(state7, "3", RAND_DESTINATION);
        let check7C = await stateChecker.checkState.call(state7, "0", nameService.address);
        let check7D = await stateChecker.checkState.call(state7, "3", nameService.address);

        let check8A = await stateChecker.checkState.call(state8, "0", RAND_DESTINATION);
        let check8B = await stateChecker.checkState.call(state8, "3", RAND_DESTINATION);
        let check8C = await stateChecker.checkState.call(state8, "0", nameService.address);
        let check8D = await stateChecker.checkState.call(state8, "3", nameService.address);

        expect(check1A).to.equal(true);
        expect(check1B).to.equal(true);
        expect(check1C).to.equal(true);
        expect(check1D).to.equal(true);

        expect(check3A).to.equal(false);
        expect(check3B).to.equal(true);
        expect(check3C).to.equal(true);
        expect(check3D).to.equal(true);

        expect(check2A).to.equal(false);
        expect(check2B).to.equal(false);
        expect(check2C).to.equal(false);
        expect(check2D).to.equal(false);

        expect(check4A).to.equal(false);
        expect(check4B).to.equal(false);
        expect(check4C).to.equal(false);
        expect(check4D).to.equal(false);

        expect(check5A).to.equal(true);
        expect(check5B).to.equal(false);
        expect(check5C).to.equal(true);
        expect(check5D).to.equal(false);

        expect(check6A).to.equal(false);
        expect(check6B).to.equal(false);
        expect(check6C).to.equal(false);
        expect(check6D).to.equal(false);

        expect(check7A).to.equal(false);
        expect(check7B).to.equal(false);
        expect(check7C).to.equal(true);
        expect(check7D).to.equal(false);

        expect(check8A).to.equal(false);
        expect(check8B).to.equal(false);
        expect(check8C).to.equal(false);
        expect(check8D).to.equal(false);

    })

    it("should check state (BIT 4)", async () => {
        let controller = await PIBController.deployed();
        let nameService = await PIBNameService.deployed();
        let stateChecker = await PIBStateChecker.deployed();

        await controller.setNewAddress("6", nameService.address, false, {from: accounts[0]});

        let state1 = "00000"; //ALL DESTINATION & SAVING_POTS_ON
        let state2 = "10000"; //ALL DESTINATION & SAVING_POTS_OFF
        let state3 = "00010"; //OFFICIAL DESTINATION & SAVING_POTS_ON
        let state4 = "10010"; //OFFICIAL DESTINATION & SAVING_POTS_OFF

        let check1A = await stateChecker.checkState.call(state1, "0", RAND_DESTINATION);
        let check1B = await stateChecker.checkState.call(state1, "4", RAND_DESTINATION);
        let check1C = await stateChecker.checkState.call(state1, "0", nameService.address);
        let check1D = await stateChecker.checkState.call(state1, "4", nameService.address);

        let check2A = await stateChecker.checkState.call(state2, "0", RAND_DESTINATION);
        let check2B = await stateChecker.checkState.call(state2, "4", RAND_DESTINATION);
        let check2C = await stateChecker.checkState.call(state2, "0", nameService.address);
        let check2D = await stateChecker.checkState.call(state2, "4", nameService.address);

        let check3A = await stateChecker.checkState.call(state3, "0", RAND_DESTINATION);
        let check3B = await stateChecker.checkState.call(state3, "4", RAND_DESTINATION);
        let check3C = await stateChecker.checkState.call(state3, "0", nameService.address);
        let check3D = await stateChecker.checkState.call(state3, "4", nameService.address);

        let check4A = await stateChecker.checkState.call(state4, "0", RAND_DESTINATION);
        let check4B = await stateChecker.checkState.call(state4, "4", RAND_DESTINATION);
        let check4C = await stateChecker.checkState.call(state4, "0", nameService.address);
        let check4D = await stateChecker.checkState.call(state4, "4", nameService.address);

        expect(check1A).to.equal(true);
        expect(check1B).to.equal(true);
        expect(check1C).to.equal(true);
        expect(check1D).to.equal(true);

        expect(check2A).to.equal(true);
        expect(check2B).to.equal(false);
        expect(check2C).to.equal(true);
        expect(check2D).to.equal(false);

        expect(check3A).to.equal(false);
        expect(check3B).to.equal(true);
        expect(check3C).to.equal(true);
        expect(check3D).to.equal(true);

        expect(check4A).to.equal(false);
        expect(check4B).to.equal(false);
        expect(check4C).to.equal(true);
        expect(check4D).to.equal(false);

    })

    it("should stop ALL actions", async () => {
        let controller = await PIBController.deployed();
        let nameService = await PIBNameService.deployed();
        let stateChecker = await PIBStateChecker.deployed();

        await controller.setNewAddress("6", nameService.address, false, {from: accounts[0]});
        await stateChecker.toggleStop({from: accounts[0]});
        let stopAll = await stateChecker.stopAll.call();

        let state1 = "0"; //ALL ACTIVE

        let check1A = await stateChecker.checkState.call(state1, "0", RAND_DESTINATION);
        let check1B = await stateChecker.checkState.call(state1, "3", RAND_DESTINATION);
        let check1C = await stateChecker.checkState.call(state1, "0", nameService.address);
        let check1D = await stateChecker.checkState.call(state1, "6", nameService.address);

        expect(check1A).to.equal(false);
        expect(check1B).to.equal(false);
        expect(check1C).to.equal(false);
        expect(check1D).to.equal(false);

        expect(stopAll).to.equal(true);

    })

    it("should set a future stateChecker", async () => {
        let stateChecker = await PIBStateChecker.deployed();

        await stateChecker.setFutureStateChecker(accounts[3], {from: accounts[0]});
        let futureStateChecker = await stateChecker.futureStateCheckerAddress.call();

        expect(futureStateChecker).to.equal(accounts[3]);

    })
    
});