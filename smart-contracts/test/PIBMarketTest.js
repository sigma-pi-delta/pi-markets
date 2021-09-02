const expect = require("chai").expect;
const truffleAssert = require('truffle-assertions');
const BigNumber = require('bignumber.js');
const sha3 = require('js-sha3').keccak_256;
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
const PIBNameService = artifacts.require("PIBNameService");
const PIBMarketPT = artifacts.require("PIBMarketPT");
const PiToken = artifacts.require("PiToken");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
const ONE_ETHER = "1000000000000000000"
const TEN_ETHER = "10000000000000000000"
const HUNDRED_ETHER = "100000000000000000000";
const INITIAL_CHANGE = "1200000000000000000";
const INITIAL_COMMISSION = "3000000000000000000"
const NEW_CHANGE = "1205000000000000000";
const NEW_COMMISSION = "2500000000000000000"

let EURO;
let MARKET;
let FIAT_FACET_WEB3;

contract("PIBIdentityFactory", async (accounts) => {

    it("should set initial conditions", async () => {
        let controller = await PIBController.deployed();
        EURO = await PiToken.new("Pi Euro Token", "EURpi", accounts[0], HUNDRED_ETHER);
        MARKET = await PIBMarketPT.new(INITIAL_CHANGE, INITIAL_COMMISSION, EURO.address, controller.address);
    })
    
    it("should Toggle Switch", async () => {
        let status_0 = await MARKET.on.call();
        await MARKET.toggleSwitch({from: accounts[1]});
        let status_1 = await MARKET.on.call();

        expect(status_0).to.equal(!status_1);

        await MARKET.toggleSwitch({from: accounts[1]});
    })

    it("should Set Change", async () => {
        let preChange = await MARKET.change.call();
        let response = await MARKET.setChange(NEW_CHANGE, {from: accounts[0]});
        let postChange = await MARKET.change.call();
        
        expect(preChange.toString()).to.equal(INITIAL_CHANGE);
        expect(postChange.toString()).to.equal(NEW_CHANGE);

        truffleAssert.eventEmitted(response, 'NewChange', (ev) => {
            return ev.sender == accounts[0] && ev.change == NEW_CHANGE;
        });
      
    })

    it("should Set Commission", async () => {
        let preCommission = await MARKET.commission.call();
        let response = await MARKET.setCommission(NEW_COMMISSION, {from: accounts[0]});
        let postCommission = await MARKET.commission.call();
        
        expect(preCommission.toString()).to.equal(INITIAL_COMMISSION);
        expect(postCommission.toString()).to.equal(NEW_COMMISSION);

        truffleAssert.eventEmitted(response, 'NewCommission', (ev) => {
            return ev.prev == INITIAL_COMMISSION && ev.current == NEW_COMMISSION;
        });
      
    })

    it("should set EOA Counterparts", async () => {
        await EURO.approve(MARKET.address, TEN_ETHER, {from: accounts[0]});

        let response1 = await MARKET.tokenCounterpart(TEN_ETHER, {from: accounts[0]});
        let response2 = await MARKET.piCounterpart({from: accounts[0], value: new BigNumber(TEN_ETHER)});
      
        let marketBalance = await MARKET.contractBalance.call();
        let counterpartBalance = await MARKET.balanceOf.call(accounts[0]);
        
        expect(marketBalance['0'].toString()).to.equal(counterpartBalance['0'].toString());
        expect(marketBalance['0'].toString()).to.equal(TEN_ETHER);
        expect(marketBalance['1'].toString()).to.equal(counterpartBalance['1'].toString());
        expect(marketBalance['1'].toString()).to.equal(TEN_ETHER);

        truffleAssert.eventEmitted(response1, 'SetCounterpart', (ev) => {
            return ev.tokenAddress == EURO.address && ev.counterpart == accounts[0] && ev.amount == TEN_ETHER;
        });

        truffleAssert.eventEmitted(response2, 'SetCounterpart', (ev) => {
            return ev.tokenAddress == ZERO_ADDRESS && ev.counterpart == accounts[0] && ev.amount == TEN_ETHER;
        });
    })

    it("should Withdraw Counterparts", async () => {
        await EURO.transfer(accounts[1], TEN_ETHER, {from: accounts[0]});
        await EURO.approve(MARKET.address, TEN_ETHER, {from: accounts[1]});
        await MARKET.tokenCounterpart(TEN_ETHER, {from: accounts[1]});
        await MARKET.piCounterpart({from: accounts[1], value: new BigNumber(TEN_ETHER)});
        
        let counterpartBalance = await MARKET.balanceOf.call(accounts[1]);
        
        expect(counterpartBalance['0'].toString()).to.equal(TEN_ETHER);
        expect(counterpartBalance['1'].toString()).to.equal(TEN_ETHER);
        
        let response1 = await MARKET.withdrawCounterpart(ZERO_ADDRESS, {from: accounts[1]});
        let response2 = await MARKET.withdrawCounterpart(EURO.address, {from: accounts[1]});

        counterpartBalance = await MARKET.balanceOf.call(accounts[1]);
        
        expect(counterpartBalance['0'].toString()).to.equal("0");
        expect(counterpartBalance['1'].toString()).to.equal("0");

        truffleAssert.eventEmitted(response1, 'WithdrawCounterpart', (ev) => {
            return ev.tokenAddress == ZERO_ADDRESS && ev.counterpart == accounts[1] && ev.amount == TEN_ETHER;
        });

        truffleAssert.eventEmitted(response2, 'WithdrawCounterpart', (ev) => {
            return ev.tokenAddress == EURO.address && ev.counterpart == accounts[1] && ev.amount == TEN_ETHER;
        });
    })

    it("should Get Exchange Info Receiving (Sending PI)", async () => {
        let info = await MARKET.getExchangeInfoReceiving.call(ZERO_ADDRESS, ONE_ETHER);
        let sendingTokenRequiredAmountBN = new BigNumber(info['0']);
        let sendingTokenCommissionBN = new BigNumber(info['1']);
        let receivingAmountBN = new BigNumber(ONE_ETHER);
        let commissionBN = new BigNumber(NEW_COMMISSION);
        let changeBN = new BigNumber(NEW_CHANGE);
        let oneBN = new BigNumber(ONE_ETHER)
        let hundredBN = new BigNumber(HUNDRED_ETHER);
        let expectedRequired = (hundredBN.minus(commissionBN)).dividedBy(100);
        expectedRequired = expectedRequired.multipliedBy(changeBN.dividedBy(oneBN));
        expectedRequired = receivingAmountBN.dividedBy(expectedRequired).multipliedBy(oneBN);
        let expectedCommission = expectedRequired.multipliedBy(commissionBN.dividedBy(hundredBN));
        
        expect(expectedRequired.toNumber()).to.equal(sendingTokenRequiredAmountBN.toNumber());
        expect(expectedCommission.toNumber()).to.equal(sendingTokenCommissionBN.toNumber());
    })

    it("should Get Exchange Info Receiving (Sending TOKEN)", async () => {
        let info = await MARKET.getExchangeInfoReceiving.call(EURO.address, ONE_ETHER);
        let sendingTokenRequiredAmountBN = new BigNumber(info['0']);
        let sendingTokenCommissionBN = new BigNumber(info['1']);
        let receivingAmountBN = new BigNumber(ONE_ETHER);
        let commissionBN = new BigNumber(NEW_COMMISSION);
        let changeBN = new BigNumber(NEW_CHANGE);
        let oneBN = new BigNumber(ONE_ETHER)
        let hundredBN = new BigNumber(HUNDRED_ETHER);
        let expectedRequired = (hundredBN.minus(commissionBN)).dividedBy(100);
        expectedRequired = receivingAmountBN.multipliedBy(changeBN.dividedBy(expectedRequired));
        let expectedCommission = expectedRequired.multipliedBy(commissionBN.dividedBy(hundredBN));
        
        expect(expectedRequired.toNumber()).to.equal(sendingTokenRequiredAmountBN.toNumber());
        expect(expectedCommission.toNumber()).to.equal(sendingTokenCommissionBN.toNumber());
    })

    it("should Get Exchange Info Sending (Sending PI)", async () => {
        let info = await MARKET.getExchangeInfoSending.call(ZERO_ADDRESS, ONE_ETHER);
        let sendingTokenReceivingAmountBN = new BigNumber(info['0']);
        let sendingTokenCommissionBN = new BigNumber(info['1']);
        let sendingAmountBN = new BigNumber(ONE_ETHER);
        let commissionBN = new BigNumber(NEW_COMMISSION);
        let changeBN = new BigNumber(NEW_CHANGE);
        let oneBN = new BigNumber(ONE_ETHER)
        let hundredBN = new BigNumber(HUNDRED_ETHER);
        let expectedCommission = sendingAmountBN.multipliedBy(commissionBN.dividedBy(hundredBN));
        let expectedReceived = sendingAmountBN.minus(expectedCommission);
        expectedReceived = expectedReceived.multipliedBy(changeBN).dividedBy(oneBN);
        
        expect(expectedReceived.toNumber()).to.equal(sendingTokenReceivingAmountBN.toNumber());
        expect(expectedCommission.toNumber()).to.equal(sendingTokenCommissionBN.toNumber());
    })

    it("should Get Exchange Info Sending (Sending TOKEN)", async () => {
        let info = await MARKET.getExchangeInfoSending.call(EURO.address, ONE_ETHER);
        let sendingTokenReceivingAmountBN = new BigNumber(info['0']);
        let sendingTokenCommissionBN = new BigNumber(info['1']);
        let sendingAmountBN = new BigNumber(ONE_ETHER);
        let commissionBN = new BigNumber(NEW_COMMISSION);
        let changeBN = new BigNumber(NEW_CHANGE);
        let oneBN = new BigNumber(ONE_ETHER)
        let hundredBN = new BigNumber(HUNDRED_ETHER);
        let expectedCommission = sendingAmountBN.multipliedBy(commissionBN.dividedBy(hundredBN));
        let expectedReceived = sendingAmountBN.minus(expectedCommission);
        expectedReceived = expectedReceived.multipliedBy(oneBN).dividedBy(changeBN);
        
        expect(expectedReceived.toNumber()).to.equal(sendingTokenReceivingAmountBN.toNumber());
        expect(expectedCommission.toNumber()).to.equal(sendingTokenCommissionBN.toNumber());
    })  

    it("should Execute Exchange Info Receiving (Sending PI)", async () => {
        let preBalance = await EURO.balanceOf.call(accounts[0]);
        let info = await MARKET.getExchangeInfoReceiving.call(ZERO_ADDRESS, ONE_ETHER);
        let sendingTokenRequiredAmountBN = new BigNumber(info['0']);
        let response = await MARKET.sellPi({from: accounts[0], value: sendingTokenRequiredAmountBN});
        let postBalance = await EURO.balanceOf.call(accounts[0]);
        let preBalanceBN = new BigNumber(preBalance.toString());
        let postBalanceBN = new BigNumber(postBalance.toString());
        let difBalanceBN = postBalanceBN.minus(preBalanceBN);
        let error = new BigNumber("1");
		let oneBN = new BigNumber(ONE_ETHER);
		let aboveError = oneBN.plus(error);
        let bellowError = oneBN.minus(error);
        
        expect(difBalanceBN.toNumber()).to.be.within(bellowError.toNumber(), aboveError.toNumber());
        
        truffleAssert.eventEmitted(response, 'SellPi', (ev) => {
            let amountBN = new BigNumber(ev.tokenAmount);
            return ev.to == accounts[0] && amountBN.toNumber() >= bellowError.toNumber() && amountBN.toNumber() <= aboveError.toNumber();
        });

        truffleAssert.eventEmitted(response, 'PayCounterpart', (ev) => {
            return ev.tokenAddress == ZERO_ADDRESS && ev.counterpart == accounts[0] && ev.amount == sendingTokenRequiredAmountBN.toString();
        });
    })

    it("should Execute Exchange Info Receiving (Sending TOKEN)", async () => {
        let info = await MARKET.getExchangeInfoReceiving.call(EURO.address, ONE_ETHER);
        let sendingTokenRequiredAmountBN = new BigNumber(info['0']);
        await EURO.transfer(accounts[1], sendingTokenRequiredAmountBN, {from: accounts[0]});
        let response = await EURO.transfer(MARKET.address, sendingTokenRequiredAmountBN, {from: accounts[1]});

        //GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case EURO.address.toLowerCase():
					result = decodeEvent(PiToken, log);
					events[result[1]] = result[0];
					break;
				case MARKET.address.toLowerCase():
					result = decodeEvent(PIBMarketPT, log);
					events[result[1]] = result[0];
					break;
			
				default:
					break;
			}
        });

        expect(events.BuyPi.piAmount).to.equal(ONE_ETHER);
        expect(events.BuyPi.to).to.equal(accounts[1]);
    })

    it("should Execute Exchange Info Sending (Sending PI)", async () => {
        let preBalance = await EURO.balanceOf.call(accounts[0]);
        let info = await MARKET.getExchangeInfoSending.call(ZERO_ADDRESS, ONE_ETHER);
        let sendingTokenReceivingAmountBN = new BigNumber(info['0']);
        let response = await MARKET.sellPi({from: accounts[0], value: new BigNumber(ONE_ETHER)});
        let postBalance = await EURO.balanceOf.call(accounts[0]);
        let preBalanceBN = new BigNumber(preBalance.toString());
        let postBalanceBN = new BigNumber(postBalance.toString());
        let difBalanceBN = postBalanceBN.minus(preBalanceBN);
        let error = new BigNumber("1");
		let aboveError = sendingTokenReceivingAmountBN.plus(error);
        let bellowError = sendingTokenReceivingAmountBN.minus(error);
        
        expect(difBalanceBN.toNumber()).to.be.within(bellowError.toNumber(), aboveError.toNumber());
        
        truffleAssert.eventEmitted(response, 'SellPi', (ev) => {
            let amountBN = new BigNumber(ev.tokenAmount);
            return ev.to == accounts[0] && amountBN.toNumber() >= bellowError.toNumber() && amountBN.toNumber() <= aboveError.toNumber();
        });

        truffleAssert.eventEmitted(response, 'PayCounterpart', (ev) => {
            return ev.tokenAddress == ZERO_ADDRESS && ev.counterpart == accounts[0] && ev.amount == ONE_ETHER;
        });
    })

    it("should Execute Exchange Info Sending (Sending TOKEN)", async () => {
        let info = await MARKET.getExchangeInfoSending.call(EURO.address, ONE_ETHER);
        let sendingTokenRequiredAmountBN = new BigNumber(info['0']);
        await EURO.transfer(accounts[1], ONE_ETHER, {from: accounts[0]});
        let response = await EURO.transfer(MARKET.address, ONE_ETHER, {from: accounts[1]});

        //GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case EURO.address.toLowerCase():
					result = decodeEvent(PiToken, log);
					events[result[1]] = result[0];
					break;
				case MARKET.address.toLowerCase():
					result = decodeEvent(PIBMarketPT, log);
					events[result[1]] = result[0];
					break;
			
				default:
					break;
			}
        });

        expect(events.BuyPi.piAmount).to.equal(sendingTokenRequiredAmountBN.toString());
        expect(events.BuyPi.to).to.equal(accounts[1]);
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