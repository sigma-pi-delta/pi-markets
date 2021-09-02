const expect = require("chai").expect;
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
const PIBNameService = artifacts.require("PIBNameService");
const PIBIdentityFacet = artifacts.require("PIBIdentityFacet");
const PIBWalletFacet = artifacts.require("PIBWalletFacet");
const PiToken = artifacts.require("PiToken");
const PiNFToken = artifacts.require("PiNFToken");
const PIBMarketPT = artifacts.require("PIBMarketPT");

const DATA_HASH = "0x10409a6503a7ab8d1fdce245761bc2e0b89bf2d3416b093f87d03054e95ad9fe";
const DATA_HASH_2 = "0x32d221930b0cc9bc99daa6387493586285fe6f82c088e0154b4ea4666c43a063";
const DATA_HASH_3 = "0x6256691ba4c8b7629f076bbf1d5c6d0251865a187a2d684d8012140dfa2ab107";
const DATA_HASH_4 = "0x24333af14770542a9a32c822d6ef6432c2e4565af4ce29eada1327428130cab2";
const NAME = "name";
const NAME2 = "name2";
const NAME3 = "name3";
const NAME4 = "name4";
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
const ONE_ETHER = "1000000000000000000"
const TEN_ETHER = "10000000000000000000"
const HUNDRED_ETHER = "100000000000000000000";
const NFT_REF = "GLD-01";
const NFT_JSON = ["1250", "950", "1100", "0", "0"];
const GOLD_JSON_REFERENCE = "{'key0':'weight_brute','key1':'law','key2':'weight_fine'}"

let EURO;
let DOLAR;
let NFT;
let FIAT_FACET_WEB3;
let COMMODITY_FACET_WEB3;

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
        await controller.setNewAddress("4", stateChecker.address, true, {from: accounts[0]});
        await controller.setNewAddress("5", walletMath.address, false, {from: accounts[0]});
		await controller.setNewAddress("6", nameService.address, false, {from: accounts[0]});
		await controller.setNewAddress("7", accounts[9], false, {from: accounts[0]});

        //SET COMMISSION
        await controller.setTxCommission("1000000000000000000", {from: accounts[0]});

        //DEPLOY IDENTITIES
        await idFactory.deployIdentity(accounts[2], accounts[3], DATA_HASH, NAME, {from: accounts[0]});
        await idFactory.deployIdentity(accounts[4], accounts[5], DATA_HASH_2, NAME2, {from: accounts[0]});

        let wallet1Address = await nameService.addr.call(NAME);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let wallet1 = await PIBWalletFacet.at(wallet1Address);
		let wallet2 = await PIBWalletFacet.at(wallet2Address);

        //CHARGE WALLETS WITH PI
        await web3.eth.sendTransaction({from: accounts[0], to: wallet1.address, value: 10000000000000000000});
		let info1 = await wallet1.getInfo.call();
		await web3.eth.sendTransaction({from: accounts[0], to: wallet2.address, value: 10000000000000000000});
		let info2 = await wallet2.getInfo.call();
        
        expect(info1[0][0]).to.equal(ZERO_ADDRESS);
        expect(info2[0][0]).to.equal(ZERO_ADDRESS)
        expect(info1[1][0].toString()).to.equal(TEN_ETHER);
        expect(info2[1][0].toString()).to.equal(TEN_ETHER);
        expect(info1[2][0]).to.equal("PI");
		expect(info2[2][0]).to.equal("PI");

        //DEPLOY TOKENS
        let euro = await PiToken.new("Pi Euro Token", "EURpi", accounts[0], HUNDRED_ETHER);
		let dolar = await PiToken.new("Pi Dolar Token", "USDpi", accounts[0], HUNDRED_ETHER);
		let nft = await PiNFToken.new("Gold Ingot Token", "GIT", accounts[0], GOLD_JSON_REFERENCE);
		
		EURO = euro;
		DOLAR = dolar;
		NFT = nft;

		//SET TOKENS IN CONTROLLER
		await controller.setNewToken(ZERO_ADDRESS, 0, true, {from: accounts[0]});
		await controller.setNewToken(euro.address, 1, true, {from: accounts[0]});
		await controller.setNewToken(dolar.address, 1, true, {from: accounts[0]});
		await controller.setNewNFToken(nft.address, "1", true, {from: accounts[0]});

		//CHARGE WALLETS WITH TOKENS

		await euro.transfer(wallet1.address, TEN_ETHER, {from: accounts[0]});
		await euro.transfer(wallet2.address, TEN_ETHER, {from: accounts[0]});
		await dolar.transfer(wallet1.address, TEN_ETHER, {from: accounts[0]});
		await dolar.transfer(wallet2.address, TEN_ETHER, {from: accounts[0]});

		info1 = await wallet1.getInfo.call();
		info2 = await wallet2.getInfo.call();

		expect(info1[0][0]).to.equal(euro.address);
        expect(info2[0][1]).to.equal(dolar.address)
        expect(info1[1][0].toString()).to.equal(TEN_ETHER);
        expect(info2[1][1].toString()).to.equal(TEN_ETHER);
        expect(info1[2][0]).to.equal("EURpi");
		expect(info2[2][1]).to.equal("USDpi");
		
		//DEPLOY MARKETS
		let market1 = await PIBMarketPT.new("1200000000000000000", "3000000000000000000", euro.address, controller.address);
		let market2 = await PIBMarketPT.new("1330000000000000000", "3000000000000000000", dolar.address, controller.address);

		await controller.setNewMarket(euro.address, ZERO_ADDRESS, market1.address, {from: accounts[0]});
		await controller.setNewMarket(dolar.address, ZERO_ADDRESS, market2.address, {from: accounts[0]});
	})
	
	it("should send PI TRANSFER transactions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);
		let wallet2 = new web3.eth.Contract(PIBWalletFacet.abi, wallet2Address);

		//GET PRE BALANCES
		let info1Pre = await wallet1.methods.getInfo().call();
		let info2Pre = await wallet2.methods.getInfo().call();
		let collectorPre = await web3.eth.getBalance(accounts[9]);

		//TRANSFERS
		let data = await wallet1.methods.transfer(ZERO_ADDRESS, wallet2Address, ONE_ETHER, "0x0", "1").encodeABI();
		let response = await identity1.forward(wallet1Address, data, {from: accounts[2]});

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				case identity2Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
			
				default:
					break;
			}
		});

		//CHECK EVENTS
		expect(events.Transfer.tokenAddress).to.equal(ZERO_ADDRESS);
		expect(events.Transfer.kind).to.equal('1');
		expect(events.Transfer.to).to.equal(wallet2Address);
		expect(events.Transfer.value).to.equal(ONE_ETHER);

		let commission = await controller.commission.call();
		let commissionBN = new BigNumber(commission);
		let valueBN = new BigNumber(ONE_ETHER);
		let txCommission = commissionBN.times(valueBN).div(HUNDRED_ETHER);

		expect(txCommission.toString()).to.equal(events.Transfer.commission);
		
		//GET POST BALANCES
		let info1Post = await wallet1.methods.getInfo().call();
		let info2Post = await wallet2.methods.getInfo().call();
		let collectorPost = await web3.eth.getBalance(accounts[9]);

		let preBalance1 = new BigNumber(info1Pre[1][info1Pre[1].length - 1]);
		let postBalance1 = new BigNumber(info1Post[1][info1Post[1].length - 1]);
		let expectedBalance1 = preBalance1.minus(valueBN.plus(txCommission));

		let preBalance2 = new BigNumber(info2Pre[1][info2Pre[1].length - 1]);
		let postBalance2 = new BigNumber(info2Post[1][info2Post[1].length - 1]);
		let expectedBalance2 = preBalance2.plus(valueBN);

		let preBalanceCollector = new BigNumber(collectorPre);
		let postBalanceCollector = new BigNumber(collectorPost);
		let expectedBalanceCollector = preBalanceCollector.plus(txCommission);

		let spent = valueBN.plus(txCommission);
		let spentToValue = await wallet1.methods.getSpendToValue(ONE_ETHER).call();

		//CHECK BALANCES
		expect(postBalance1.toString()).to.equal(expectedBalance1.toString());
		expect(postBalance2.toString()).to.equal(expectedBalance2.toString());
		expect(postBalanceCollector.toString()).to.equal(expectedBalanceCollector.toString());
		expect(spentToValue.toString()).to.equal(spent.toString());
	})
	
	it("should send TOKEN TRANSFER transactions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
		let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);
		let wallet2 = new web3.eth.Contract(PIBWalletFacet.abi, wallet2Address);

		//GET PRE BALANCES
		let info1Pre = await wallet1.methods.getInfo().call();
		let info2Pre = await wallet2.methods.getInfo().call();
		let collectorPre = await EURO.balanceOf.call(accounts[9]);

		//TRANSFERS
		let data = await wallet1.methods.transfer(EURO.address, wallet2Address, ONE_ETHER, "0x0", "1").encodeABI();
		let response = await identity1.forward(wallet1Address, data, {from: accounts[2]});

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				case identity2Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
			
				default:
					break;
			}
		});

		//CHECK EVENTS
		expect(events.Transfer.tokenAddress).to.equal(EURO.address);
		expect(events.Transfer.kind).to.equal('1');
		expect(events.Transfer.to).to.equal(wallet2Address);
		expect(events.Transfer.value).to.equal(ONE_ETHER);

		let commission = await controller.commission.call();
		let commissionBN = new BigNumber(commission);
		let valueBN = new BigNumber(ONE_ETHER);
		let txCommission = commissionBN.times(valueBN).div(HUNDRED_ETHER);

		expect(txCommission.toString()).to.equal(events.Transfer.commission);
		
		//GET POST BALANCES
		let info1Post = await wallet1.methods.getInfo().call();
		let info2Post = await wallet2.methods.getInfo().call();
		let collectorPost = await EURO.balanceOf.call(accounts[9]);

		let preBalance1 = new BigNumber(info1Pre[1][0]);
		let postBalance1 = new BigNumber(info1Post[1][0]);
		let expectedBalance1 = preBalance1.minus(valueBN.plus(txCommission));

		let preBalance2 = new BigNumber(info2Pre[1][0]);
		let postBalance2 = new BigNumber(info2Post[1][0]);
		let expectedBalance2 = preBalance2.plus(valueBN);

		let preBalanceCollector = new BigNumber(collectorPre);
		let postBalanceCollector = new BigNumber(collectorPost);
		let expectedBalanceCollector = preBalanceCollector.plus(txCommission);

		//CHECK BALANCES
		expect(postBalance1.toString()).to.equal(expectedBalance1.toString());
		expect(postBalance2.toString()).to.equal(expectedBalance2.toString());
		expect(postBalanceCollector.toString()).to.equal(expectedBalanceCollector.toString());
	})

	it("should send PI TRANSFER-SENDING transactions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity2 = await PIBIdentityFacet.at(identity2Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);
		let wallet2 = new web3.eth.Contract(PIBWalletFacet.abi, wallet2Address);

		//GET PRE BALANCES
		let info1Pre = await wallet1.methods.getInfo().call();
		let info2Pre = await wallet2.methods.getInfo().call();
		let collectorPre = await web3.eth.getBalance(accounts[9]);

		//TRANSFERS
		let data = await wallet2.methods.transferSending(ZERO_ADDRESS, wallet1Address, ONE_ETHER, "0x0", "1").encodeABI();
		let response = await identity2.forward(wallet2Address, data, {from: accounts[4]});

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				case identity2Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
			
				default:
					break;
			}
		});

		let valueToSpend = await wallet2.methods.getValueToSpend(ONE_ETHER).call();

		//CHECK EVENTS
		expect(events.Transfer.tokenAddress).to.equal(ZERO_ADDRESS);
		expect(events.Transfer.kind).to.equal('1');
		expect(events.Transfer.to).to.equal(wallet1Address);
		expect(events.Transfer.value).to.equal(valueToSpend);

		let commission = await controller.commission.call();
		let commissionBN = new BigNumber(commission);
		let valueBN = new BigNumber(valueToSpend);
		let txCommission = commissionBN.times(valueBN).div(HUNDRED_ETHER);
		txCommission = txCommission.toNumber();
		txCommission = new BigNumber(txCommission)

		expect(txCommission.toString()).to.equal(events.Transfer.commission);
		
		//GET POST BALANCES
		let info1Post = await wallet1.methods.getInfo().call();
		let info2Post = await wallet2.methods.getInfo().call();
		let collectorPost = await web3.eth.getBalance(accounts[9]);

		let preBalance1 = new BigNumber(info1Pre[1][info1Pre[1].length - 1]);
		let postBalance1 = new BigNumber(info1Post[1][info1Post[1].length - 1]);
		let expectedBalance1 = preBalance1.plus(valueBN);

		let preBalance2 = new BigNumber(info2Pre[1][info2Pre[1].length - 1]);
		let postBalance2 = new BigNumber(info2Post[1][info2Post[1].length - 1]);
		let expectedBalance2 = preBalance2.minus(valueBN.plus(txCommission));

		let preBalanceCollector = new BigNumber(collectorPre);
		let postBalanceCollector = new BigNumber(collectorPost);
		let expectedBalanceCollector = preBalanceCollector.plus(txCommission);

		//CHECK BALANCES
		expect(postBalance1.toString()).to.equal(expectedBalance1.toString());
		expect(postBalance2.toString()).to.equal(expectedBalance2.toString());
		expect(postBalanceCollector.toString()).to.equal(expectedBalanceCollector.toString());

		let error = new BigNumber("1");
		let oneBN = new BigNumber(ONE_ETHER);
		let aboveError = oneBN.plus(error);
		let bellowError = oneBN.minus(error);
		expect(valueBN.plus(txCommission).toNumber()).to.be.within(bellowError.toNumber(), aboveError.toNumber());
	})

	it("should send PI TRANSFER-DOMAIN transactions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);
		let wallet2 = new web3.eth.Contract(PIBWalletFacet.abi, wallet2Address);

		//GET PRE BALANCES
		let info1Pre = await wallet1.methods.getInfo().call();
		let info2Pre = await wallet2.methods.getInfo().call();
		let collectorPre = await web3.eth.getBalance(accounts[9]);

		//TRANSFERS
		let data = await wallet1.methods.transferDomain(ZERO_ADDRESS, NAME2, ONE_ETHER, "0x0", "2").encodeABI();
		let response = await identity1.forward(wallet1Address, data, {from: accounts[2]});

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				case identity2Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
			
				default:
					break;
			}
		});

		//CHECK EVENTS
		expect(events.Transfer.tokenAddress).to.equal(ZERO_ADDRESS);
		expect(events.Transfer.kind).to.equal('2');
		expect(events.Transfer.to).to.equal(wallet2Address);
		expect(events.Transfer.value).to.equal(ONE_ETHER);

		let commission = await controller.commission.call();
		let commissionBN = new BigNumber(commission);
		let valueBN = new BigNumber(ONE_ETHER);
		let txCommission = commissionBN.times(valueBN).div(HUNDRED_ETHER);

		expect(txCommission.toString()).to.equal(events.Transfer.commission);
		
		//GET POST BALANCES
		let info1Post = await wallet1.methods.getInfo().call();
		let info2Post = await wallet2.methods.getInfo().call();
		let collectorPost = await web3.eth.getBalance(accounts[9]);

		let preBalance1 = new BigNumber(info1Pre[1][info1Pre[1].length - 1]);
		let postBalance1 = new BigNumber(info1Post[1][info1Post[1].length - 1]);
		let expectedBalance1 = preBalance1.minus(valueBN.plus(txCommission));

		let preBalance2 = new BigNumber(info2Pre[1][info2Pre[1].length - 1]);
		let postBalance2 = new BigNumber(info2Post[1][info2Post[1].length - 1]);
		let expectedBalance2 = preBalance2.plus(valueBN);

		let preBalanceCollector = new BigNumber(collectorPre);
		let postBalanceCollector = new BigNumber(collectorPost);
		let expectedBalanceCollector = preBalanceCollector.plus(txCommission);

		//CHECK BALANCES
		expect(postBalance1.toString()).to.equal(expectedBalance1.toString());
		expect(postBalance2.toString()).to.equal(expectedBalance2.toString());
		expect(postBalanceCollector.toString()).to.equal(expectedBalanceCollector.toString());
	})

	it("should send PI TRANSFER-DOMAIN-SENDING transactions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity2 = await PIBIdentityFacet.at(identity2Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);
		let wallet2 = new web3.eth.Contract(PIBWalletFacet.abi, wallet2Address);

		//GET PRE BALANCES
		let info1Pre = await wallet1.methods.getInfo().call();
		let info2Pre = await wallet2.methods.getInfo().call();
		let collectorPre = await web3.eth.getBalance(accounts[9]);

		//TRANSFERS
		let data = await wallet2.methods.transferDomainSending(ZERO_ADDRESS, NAME, ONE_ETHER, "0x0", "2").encodeABI();
		let response = await identity2.forward(wallet2Address, data, {from: accounts[4]});

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				case identity2Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
			
				default:
					break;
			}
		});

		let valueToSpend = await wallet2.methods.getValueToSpend(ONE_ETHER).call();

		//CHECK EVENTS
		expect(events.Transfer.tokenAddress).to.equal(ZERO_ADDRESS);
		expect(events.Transfer.kind).to.equal('2');
		expect(events.Transfer.to).to.equal(wallet1Address);
		expect(events.Transfer.value).to.equal(valueToSpend);

		let commission = await controller.commission.call();
		let commissionBN = new BigNumber(commission);
		let valueBN = new BigNumber(valueToSpend);
		let txCommission = commissionBN.times(valueBN).div(HUNDRED_ETHER);
		txCommission = txCommission.toNumber();
		txCommission = new BigNumber(txCommission)

		expect(txCommission.toString()).to.equal(events.Transfer.commission);
		
		//GET POST BALANCES
		let info1Post = await wallet1.methods.getInfo().call();
		let info2Post = await wallet2.methods.getInfo().call();
		let collectorPost = await web3.eth.getBalance(accounts[9]);

		let preBalance1 = new BigNumber(info1Pre[1][info1Pre[1].length - 1]);
		let postBalance1 = new BigNumber(info1Post[1][info1Post[1].length - 1]);
		let expectedBalance1 = preBalance1.plus(valueBN);

		let preBalance2 = new BigNumber(info2Pre[1][info2Pre[1].length - 1]);
		let postBalance2 = new BigNumber(info2Post[1][info2Post[1].length - 1]);
		let expectedBalance2 = preBalance2.minus(valueBN.plus(txCommission));

		let preBalanceCollector = new BigNumber(collectorPre);
		let postBalanceCollector = new BigNumber(collectorPost);
		let expectedBalanceCollector = preBalanceCollector.plus(txCommission);

		//CHECK BALANCES
		expect(postBalance1.toString()).to.equal(expectedBalance1.toString());
		expect(postBalance2.toString()).to.equal(expectedBalance2.toString());
		expect(postBalanceCollector.toString()).to.equal(expectedBalanceCollector.toString());

		let error = new BigNumber("1");
		let oneBN = new BigNumber(ONE_ETHER);
		let aboveError = oneBN.plus(error);
		let bellowError = oneBN.minus(error);
		expect(valueBN.plus(txCommission).toNumber()).to.be.within(bellowError.toNumber(), aboveError.toNumber());
	})

	it("should transferNFT NFTs", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);

		//MINT NFTs
		await NFT.mint(wallet1Address, NFT_REF, NFT_JSON);

		//CHECK OWNER AND BALANCE
		let ownerPre = await NFT.ownerOfRef(NFT_REF);
		let balancePre = await NFT.balanceOf(wallet1Address);

		//TRANSFER FROM WALLET1 TO WALLET2
		let tokenId = "1";
		let concept = "First transferNFT";
		let kind = "5";

		let transferData = wallet1.methods.transferNFT(
			NFT.address,
			wallet2Address,
			tokenId,
			concept,
			kind
		).encodeABI();
		
		let response = await identity1.forward(wallet1Address, transferData, {from: accounts[2]})

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case NFT.address.toLowerCase():
					result = decodeEvent(PiNFToken, log);
					events[result[1]] = result[0];
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				default:
					break;
			}
		});

		let ownerPost = await NFT.ownerOfRef(NFT_REF);
		let balancePost = await NFT.balanceOf(wallet1Address);

		expect(events.Transfer.tokenAddress).to.equal(NFT.address);
		expect(events.Transfer.kind).to.equal(kind);
		expect(events.Transfer.to).to.equal(wallet2Address);
		expect(events.Transfer.value).to.equal(tokenId);
		expect(events.Transfer.data).to.equal(concept);
		expect(ownerPre).to.equal(wallet1Address);
		expect(ownerPost).to.equal(wallet2Address);
		expect(balancePre.toString()).to.equal('1');
		expect(balancePost.toString()).to.equal('0');
	})

	it("should transferNFTRef NFTs", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity2 = await PIBIdentityFacet.at(identity2Address)
		let wallet2 = new web3.eth.Contract(PIBWalletFacet.abi, wallet2Address);

		//CHECK OWNER AND BALANCE
		let ownerPre = await NFT.ownerOfRef(NFT_REF);
		let balancePre = await NFT.balanceOf(wallet2Address);

		//TRANSFER FROM WALLET1 TO WALLET2
		let tokenId = "1";
		let concept = "Second transferNFTRef";
		let kind = "5";

		let transferData = wallet2.methods.transferNFTRef(
			NFT.address,
			wallet1Address,
			NFT_REF,
			concept,
			kind
		).encodeABI();
		
		let response = await identity2.forward(wallet2Address, transferData, {from: accounts[4]})

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case NFT.address.toLowerCase():
					result = decodeEvent(PiNFToken, log);
					events[result[1]] = result[0];
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				default:
					break;
			}
		});

		let ownerPost = await NFT.ownerOfRef(NFT_REF);
		let balancePost = await NFT.balanceOf(wallet2Address);

		expect(events.Transfer.tokenAddress).to.equal(NFT.address);
		expect(events.Transfer.kind).to.equal(kind);
		expect(events.Transfer.to).to.equal(wallet1Address);
		expect(events.Transfer.value).to.equal(tokenId);
		expect(events.Transfer.data).to.equal(concept);
		expect(ownerPre).to.equal(wallet2Address);
		expect(ownerPost).to.equal(wallet1Address);
		expect(balancePre.toString()).to.equal('1');
		expect(balancePost.toString()).to.equal('0');
	})
	
	it("should transferNFTDomain NFTs", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);

		//CHECK OWNER AND BALANCE
		let ownerPre = await NFT.ownerOfRef(NFT_REF);
		let balancePre = await NFT.balanceOf(wallet1Address);

		//TRANSFER FROM WALLET1 TO WALLET2
		let tokenId = "1";
		let concept = "Third transferNFTDomain";
		let kind = "5";

		let transferData = wallet1.methods.transferNFTDomain(
			NFT.address,
			NAME2,
			tokenId,
			concept,
			kind
		).encodeABI();
		
		let response = await identity1.forward(wallet1Address, transferData, {from: accounts[2]})

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case NFT.address.toLowerCase():
					result = decodeEvent(PiNFToken, log);
					events[result[1]] = result[0];
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				default:
					break;
			}
		});

		let ownerPost = await NFT.ownerOfRef(NFT_REF);
		let balancePost = await NFT.balanceOf(wallet1Address);

		expect(events.Transfer.tokenAddress).to.equal(NFT.address);
		expect(events.Transfer.kind).to.equal(kind);
		expect(events.Transfer.to).to.equal(wallet2Address);
		expect(events.Transfer.value).to.equal(tokenId);
		expect(events.Transfer.data).to.equal(concept);
		expect(ownerPre).to.equal(wallet1Address);
		expect(ownerPost).to.equal(wallet2Address);
		expect(balancePre.toString()).to.equal('1');
		expect(balancePost.toString()).to.equal('0');
	})

	it("should transferNFTRefDomain NFTs", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity2 = await PIBIdentityFacet.at(identity2Address)
		let wallet2 = new web3.eth.Contract(PIBWalletFacet.abi, wallet2Address);

		//CHECK OWNER AND BALANCE
		let ownerPre = await NFT.ownerOfRef(NFT_REF);
		let balancePre = await NFT.balanceOf(wallet2Address);

		//TRANSFER FROM WALLET1 TO WALLET2
		let tokenId = "1";
		let concept = "Fourth transferNFTRefDomain";
		let kind = "5";

		let transferData = wallet2.methods.transferNFTRefDomain(
			NFT.address,
			NAME,
			NFT_REF,
			concept,
			kind
		).encodeABI();
		
		let response = await identity2.forward(wallet2Address, transferData, {from: accounts[4]})

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case NFT.address.toLowerCase():
					result = decodeEvent(PiNFToken, log);
					events[result[1]] = result[0];
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				default:
					break;
			}
		});

		let ownerPost = await NFT.ownerOfRef(NFT_REF);
		let balancePost = await NFT.balanceOf(wallet2Address);

		expect(events.Transfer.tokenAddress).to.equal(NFT.address);
		expect(events.Transfer.kind).to.equal(kind);
		expect(events.Transfer.to).to.equal(wallet1Address);
		expect(events.Transfer.value).to.equal(tokenId);
		expect(events.Transfer.data).to.equal(concept);
		expect(ownerPre).to.equal(wallet2Address);
		expect(ownerPost).to.equal(wallet1Address);
		expect(balancePre.toString()).to.equal('1');
		expect(balancePost.toString()).to.equal('0');
	})

	it("should limit TO of transactions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);

		await wallet1.methods.limitTo(accounts[4], true).send({from: accounts[3]})

		//TRANSFERS
		let data = await wallet1.methods.transfer(ZERO_ADDRESS, accounts[4], ONE_ETHER, "0x0", "1").encodeABI();
		let response = await identity1.forward(wallet1Address, data, {from: accounts[2]});
		let data2 = await wallet1.methods.transfer(ZERO_ADDRESS, accounts[5], ONE_ETHER, "0x0", "1").encodeABI();

		expect(response.receipt.status).to.equal(true);

		await truffleAssert.reverts(identity1.forward(wallet1Address, data2, {from: accounts[2]}));
	})

	it("should unlimit TO of transactions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);

		let data = await wallet1.methods.transfer(ZERO_ADDRESS, accounts[5], ONE_ETHER, "0x0", "1").encodeABI();

		await truffleAssert.reverts(identity1.forward(wallet1Address, data, {from: accounts[2]}));
		await wallet1.methods.unlimitTo().send({from: accounts[3]})
		let response = await identity1.forward(wallet1Address, data, {from: accounts[2]});

		expect(response.receipt.status).to.equal(true);
	})

	it("should limit VALUE of transactions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);

		await wallet1.methods.limitValue(ZERO_ADDRESS, ONE_ETHER).send({from: accounts[3]})

		//TRANSFERS
		let data = await wallet1.methods.transfer(ZERO_ADDRESS, accounts[4], "1", "0x0", "1").encodeABI();
		let response = await identity1.forward(wallet1Address, data, {from: accounts[2]});
		let data2 = await wallet1.methods.transfer(ZERO_ADDRESS, accounts[4], "2000000000000000000", "0x0", "1").encodeABI();

		expect(response.receipt.status).to.equal(true);

		await truffleAssert.reverts(identity1.forward(wallet1Address, data2, {from: accounts[2]}));
	})

	it("should unlimit VALUE of transactions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);

		let data = await wallet1.methods.transfer(ZERO_ADDRESS, accounts[4], "2000000000000000000", "0x0", "1").encodeABI();

		await truffleAssert.reverts(identity1.forward(wallet1Address, data, {from: accounts[2]}));
		await wallet1.methods.unlimitValue(ZERO_ADDRESS).send({from: accounts[3]})
		let response = await identity1.forward(wallet1Address, data, {from: accounts[2]});

		expect(response.receipt.status).to.equal(true);
	})


	//WE ARE NOT DEPLOYING THIS DEC-MARKETS YET
	/*it("should set MARKET COUNTERPARTS", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let idFactory = await PIBIdentityFactory.deployed();
		let nameService = await PIBNameService.deployed();

        //DEPLOY IDENTITIES
        await idFactory.deployIdentity(accounts[6], accounts[7], DATA_HASH_3, NAME3, {from: accounts[0]});
		await idFactory.deployIdentity(accounts[8], accounts[9], DATA_HASH_4, NAME4, {from: accounts[0]});

		let identity3Address = await registry.identities.call(DATA_HASH_3);
        let wallet3Address = await nameService.addr.call(NAME3);
        let identity4Address = await registry.identities.call(DATA_HASH_4);
        let wallet4Address = await nameService.addr.call(NAME4);

        //INSTANCE CONTRACTS
		let identity3 = await PIBIdentityFacet.at(identity3Address)
		let identity4 = await PIBIdentityFacet.at(identity4Address)
		let wallet3 = new web3.eth.Contract(PIBWalletFacet.abi, wallet3Address);
		let wallet4 = new web3.eth.Contract(PIBWalletFacet.abi, wallet4Address);
		let euroMarketAddress = await controller.markets.call(EURO.address, ZERO_ADDRESS);
		let dolarMarketAddress = await controller.markets.call(DOLAR.address, ZERO_ADDRESS);
		let euroMarket = new web3.eth.Contract(PIBMarketPT.abi, euroMarketAddress);
		let dolarMarket = new web3.eth.Contract(PIBMarketPT.abi, dolarMarketAddress);

		//CHARGE WALLETS WITH PI
        await web3.eth.sendTransaction({from: accounts[9], to: wallet3Address, value: 50000000000000000000});
        await web3.eth.sendTransaction({from: accounts[8], to: wallet4Address, value: 50000000000000000000});

		//CHARGE WALLETS WITH TOKENS
		//await EURO.transfer(wallet3Address, TEN_ETHER, {from: accounts[0]});
		//await DOLAR.transfer(wallet4Address, TEN_ETHER, {from: accounts[0]});
		let data1 = FIAT_FACET_WEB3.methods.transfer(wallet3Address, TEN_ETHER).encodeABI();
		let data2 = FIAT_FACET_WEB3.methods.transfer(wallet4Address, TEN_ETHER).encodeABI();
		await web3.eth.sendTransaction({from: accounts[0], to: EURO.address, data: data1, value: 0, gas: 1000000});
		await web3.eth.sendTransaction({from: accounts[0], to: DOLAR.address, data: data2, value: 0, gas: 1000000});

		//SET COUNTERPARTS
		let piCounterpartData = await euroMarket.methods.piCounterpart().encodeABI();
		let forwardValueData = await wallet3.methods.forwardValue(ZERO_ADDRESS, TEN_ETHER, euroMarketAddress, piCounterpartData).encodeABI();
		let forwardValueData2 = await wallet4.methods.forwardValue(ZERO_ADDRESS, TEN_ETHER, dolarMarketAddress, piCounterpartData).encodeABI();
		await identity3.forward(wallet3Address, forwardValueData, {from: accounts[6]});
		await identity4.forward(wallet4Address, forwardValueData2, {from: accounts[8]});
		let tokenCounterpartData = await euroMarket.methods.tokenCounterpart(TEN_ETHER).encodeABI();
		let forwardValueData3 = await wallet3.methods.forwardValue(EURO.address, TEN_ETHER, euroMarketAddress, tokenCounterpartData).encodeABI();
		let forwardValueData4 = await wallet4.methods.forwardValue(DOLAR.address, TEN_ETHER, dolarMarketAddress, tokenCounterpartData).encodeABI();
		await identity3.forward(wallet3Address, forwardValueData3, {from: accounts[6]});
		await identity4.forward(wallet4Address, forwardValueData4, {from: accounts[8]});

		//GET BALANCES
		//let euroMarketBalance = await euroMarket.methods.contractBalance().call();
		let euroMarketBalanceData = FIAT_FACET_WEB3.methods.balanceOf(euroMarketAddress).encodeABI();
		let euroMarketBalance = await web3.eth.call({to: EURO.address, data: euroMarketBalanceData});
		euroMarketBalance = web3.eth.abi.decodeParameter('uint256', euroMarketBalance);
		//let dolarMarketBalance = await dolarMarket.methods.contractBalance().call();
		let dolarMarketBalanceData = FIAT_FACET_WEB3.methods.balanceOf(dolarMarketAddress).encodeABI();
		let dolarMarketBalance = await web3.eth.call({to: DOLAR.address, data: dolarMarketBalanceData});
		dolarMarketBalance = web3.eth.abi.decodeParameter('uint256', dolarMarketBalance);
		//let euroCounterpartBalance = await euroMarket.methods.balanceOf(wallet3Address).call();
		let euroCounterpartBalanceData = FIAT_FACET_WEB3.methods.balanceOf(wallet3Address).encodeABI();
		let euroCounterpartBalance = await web3.eth.call({to: EURO.address, data: euroCounterpartBalanceData});
		euroCounterpartBalance = web3.eth.abi.decodeParameter('uint256', euroCounterpartBalance);
		//let dolarCounterpartBalance = await dolarMarket.methods.balanceOf(wallet4Address).call();
		let dolarCounterpartBalanceData = FIAT_FACET_WEB3.methods.balanceOf(wallet4Address).encodeABI();
		let dolarCounterpartBalance = await web3.eth.call({to: DOLAR.address, data: dolarCounterpartBalanceData});
		dolarCounterpartBalance = web3.eth.abi.decodeParameter('uint256', dolarCounterpartBalance);

		//CHECK BALANCES
		expect(euroMarketBalance).to.equal(euroCounterpartBalance);
		expect(euroMarketBalance).to.equal(euroCounterpartBalance);
		expect(dolarMarketBalance).to.equal(dolarCounterpartBalance);
		expect(dolarMarketBalance).to.equal(dolarCounterpartBalance);
		expect(euroMarketBalance).to.equal(TEN_ETHER);
		expect(euroMarketBalance).to.equal(TEN_ETHER);
		expect(dolarMarketBalance).to.equal(TEN_ETHER);
		expect(dolarMarketBalance).to.equal(TEN_ETHER);
	})

	it("should EXCHANGE in MARKETS", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
		let wallet1Address = await nameService.addr.call(NAME);
		let identity2Address = await registry.identities.call(DATA_HASH_2);
		let wallet2Address = await nameService.addr.call(NAME2);
		let identity3Address = await registry.identities.call(DATA_HASH_3);
		let wallet3Address = await nameService.addr.call(NAME3);
		let identity4Address = await registry.identities.call(DATA_HASH_4);
        let wallet4Address = await nameService.addr.call(NAME4);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);
		let identity2 = await PIBIdentityFacet.at(identity1Address)
		let wallet2 = new web3.eth.Contract(PIBWalletFacet.abi, wallet2Address);
		let identity3 = await PIBIdentityFacet.at(identity1Address)
		let wallet3 = new web3.eth.Contract(PIBWalletFacet.abi, wallet3Address);
		let identity4 = await PIBIdentityFacet.at(identity1Address)
		let wallet4 = new web3.eth.Contract(PIBWalletFacet.abi, wallet4Address);
	})*/

	it("should transfer all NFTs from wallet1 before killing it", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);

		//CHECK OWNER AND BALANCE
		let ownerPre = await NFT.ownerOfRef(NFT_REF);
		let balancePre = await NFT.balanceOf(wallet1Address);

		//TRANSFER FROM WALLET1 TO WALLET2
		let tokenId = "1";
		let concept = "First transferNFT";
		let kind = "5";

		let transferData = wallet1.methods.transferNFT(
			NFT.address,
			wallet2Address,
			tokenId,
			concept,
			kind
		).encodeABI();
		
		let response = await identity1.forward(wallet1Address, transferData, {from: accounts[2]})

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case NFT.address.toLowerCase():
					result = decodeEvent(PiNFToken, log);
					events[result[1]] = result[0];
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					events[result[1]] = result[0];
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					events[result[1]] = result[0];
					break;
				default:
					break;
			}
		});

		let ownerPost = await NFT.ownerOfRef(NFT_REF);
		let balancePost = await NFT.balanceOf(wallet1Address);

		expect(events.Transfer.tokenAddress).to.equal(NFT.address);
		expect(events.Transfer.kind).to.equal(kind);
		expect(events.Transfer.to).to.equal(wallet2Address);
		expect(events.Transfer.value).to.equal(tokenId);
		expect(events.Transfer.data).to.equal(concept);
		expect(ownerPre).to.equal(wallet1Address);
		expect(ownerPost).to.equal(wallet2Address);
		expect(balancePre.toString()).to.equal('1');
		expect(balancePost.toString()).to.equal('0');
	})


	it("should KILL the Wallet", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
		let wallet1Address = await nameService.addr.call(NAME);
		
		//PRE BALANCES
		let preEuroBalance = await EURO.balanceOf.call(wallet1Address);
		let preDolarBalance = await DOLAR.balanceOf.call(wallet1Address);
		let prePiBalance = await web3.eth.getBalance(wallet1Address);

		//ZERO BALANCES
		let preZeroEuroBalance = await EURO.balanceOf.call(ZERO_ADDRESS);
		let preZeroDolarBalance = await DOLAR.balanceOf.call(ZERO_ADDRESS);
		let preZeroPiBalance = await web3.eth.getBalance(ZERO_ADDRESS);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);

		let response = await wallet1.methods.kill(ZERO_ADDRESS).send({from: accounts[3], gas: 2000000})
		//let response = await identity1.forward(wallet1Address, data, {from: accounts[3], gas: 2000000});

		//POST BALANCES
		let postEuroBalance = await EURO.balanceOf.call(wallet1Address);
		let postDolarBalance = await DOLAR.balanceOf.call(wallet1Address);
		let postPiBalance = await web3.eth.getBalance(wallet1Address);

		//ZERO BALANCES
		let postZeroEuroBalance = await EURO.balanceOf.call(ZERO_ADDRESS);
		let postZeroDolarBalance = await DOLAR.balanceOf.call(ZERO_ADDRESS);
		let postZeroPiBalance = await web3.eth.getBalance(ZERO_ADDRESS);

		expect(preEuroBalance.toString()).not.to.equal("0");
		expect(preDolarBalance.toString()).not.to.equal("0");
		expect(prePiBalance.toString()).not.to.equal("0");

		expect(postEuroBalance.toString()).to.equal("0");
		expect(postDolarBalance.toString()).to.equal("0");
		expect(postPiBalance.toString()).to.equal("0");

		let preEuroBalanceBN = new BigNumber(preEuroBalance);
		let preDolarBalanceBN = new BigNumber(preDolarBalance);
		let prePiBalanceBN = new BigNumber(prePiBalance);
		let postZeroPiBalanceBN = new BigNumber(postZeroPiBalance);

		expect(postZeroEuroBalance.toString()).to.equal(preEuroBalanceBN.plus(preZeroEuroBalance).toString());
		expect(postZeroDolarBalance.toString()).to.equal(preDolarBalanceBN.plus(preZeroDolarBalance).toString());
		expect(postZeroPiBalanceBN.toNumber()).to.be.gte(prePiBalanceBN.plus(preZeroPiBalance).toNumber());
	})
    
});

contract("PIBIdentityFactory", async (accounts) => {


    it("should set initial conditions 2", async () => {
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
        await controller.setNewAddress("4", stateChecker.address, true, {from: accounts[0]});
        await controller.setNewAddress("5", walletMath.address, false, {from: accounts[0]});
		await controller.setNewAddress("6", nameService.address, false, {from: accounts[0]});
		await controller.setNewAddress("7", accounts[9], false, {from: accounts[0]});

        //SET COMMISSION
        await controller.setTxCommission("1000000000000000000", {from: accounts[0]});

        //DEPLOY IDENTITIES
        await idFactory.deployIdentity(accounts[2], accounts[3], DATA_HASH, NAME, {from: accounts[0]});
        await idFactory.deployIdentity(accounts[4], accounts[5], DATA_HASH_2, NAME2, {from: accounts[0]});

        let wallet1Address = await nameService.addr.call(NAME);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let wallet1 = await PIBWalletFacet.at(wallet1Address);
        let wallet2 = await PIBWalletFacet.at(wallet2Address);

        //CHARGE WALLETS WITH PI
        await web3.eth.sendTransaction({from: accounts[0], to: wallet1.address, value: 10000000000000000000});
		let info1 = await wallet1.getInfo.call();
		await web3.eth.sendTransaction({from: accounts[0], to: wallet2.address, value: 10000000000000000000});
		let info2 = await wallet2.getInfo.call();
        
        expect(info1[0][0]).to.equal(ZERO_ADDRESS);
        expect(info2[0][0]).to.equal(ZERO_ADDRESS)
        expect(info1[1][0].toString()).to.equal(TEN_ETHER);
        expect(info2[1][0].toString()).to.equal(TEN_ETHER);
        expect(info1[2][0]).to.equal("PI");
		expect(info2[2][0]).to.equal("PI");

        //DEPLOY TOKENS
        let euro = await PiToken.new("Pi Euro Token", "EURpi", accounts[0], HUNDRED_ETHER);
		let dolar = await PiToken.new("Pi Dolar Token", "USDpi", accounts[0], HUNDRED_ETHER);
		let nft = await PiNFToken.new("Gold Ingot Token", "GIT", accounts[0], GOLD_JSON_REFERENCE);

		EURO = euro;
		DOLAR = dolar;
		NFT = nft;

		//SET TOKENS IN CONTROLLER
		await controller.setNewToken(ZERO_ADDRESS, 0, true, {from: accounts[0]});
		await controller.setNewToken(euro.address, 1, true, {from: accounts[0]});
        await controller.setNewToken(dolar.address, 1, true, {from: accounts[0]});

		//CHARGE WALLETS WITH TOKENS

		await euro.transfer(wallet1.address, TEN_ETHER, {from: accounts[0]});
		await euro.transfer(wallet2.address, TEN_ETHER, {from: accounts[0]});
		await dolar.transfer(wallet1.address, TEN_ETHER, {from: accounts[0]});
		await dolar.transfer(wallet2.address, TEN_ETHER, {from: accounts[0]});

		info1 = await wallet1.getInfo.call();
		info2 = await wallet2.getInfo.call();

		expect(info1[0][0]).to.equal(euro.address);
        expect(info2[0][1]).to.equal(dolar.address)
        expect(info1[1][0].toString()).to.equal(TEN_ETHER);
        expect(info2[1][1].toString()).to.equal(TEN_ETHER);
        expect(info1[2][0]).to.equal("EURpi");
		expect(info2[2][1]).to.equal("USDpi");
		
		//DEPLOY MARKETS
		let market1 = await PIBMarketPT.new("1200000000000000000", "3000000000000000000", euro.address, controller.address);
		let market2 = await PIBMarketPT.new("1330000000000000000", "3000000000000000000", dolar.address, controller.address);

		await controller.setNewMarket(euro.address, ZERO_ADDRESS, market1.address, {from: accounts[0]});
		await controller.setNewMarket(dolar.address, ZERO_ADDRESS, market2.address, {from: accounts[0]});
	})

	//NOT GOING TO USE THIS KIND OF MARKETS YET
	//NEED TO CHARGE MARKETS BEFORE EXCHANGES
	/*it("should send TRANSFER-EXCHANGE(PI/TOKEN) RECEIVING transactions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);
		let wallet2 = new web3.eth.Contract(PIBWalletFacet.abi, wallet2Address);

		//TRANSFERS
		let data = await wallet1.methods.transferExchangeReceiving(ZERO_ADDRESS, EURO.address, ONE_ETHER, wallet2Address, "0x0", "3").encodeABI();
		let response = await identity1.forward(wallet1Address, data, {from: accounts[2]});
		
		let euroMarket = await controller.markets.call(EURO.address, ZERO_ADDRESS);

		//GET EVENTS
		let eventsIdentity1 = {}
		let eventsIdentity2 = {}
		let eventsWallet1 = {}
		let eventsWallet2 = {}
		let eventsMarket = {}
		let eventsToken = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					
					if (eventsIdentity1[result[1]] == undefined) {
						eventsIdentity1[result[1]] = [];
					}

					eventsIdentity1[result[1]].push(result[0]);
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					
					if (eventsWallet1[result[1]] == undefined) {
						eventsWallet1[result[1]] = [];
					}

					eventsWallet1[result[1]].push(result[0]);
					break;
				case identity2Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					
					if (eventsIdentity2[result[1]] == undefined) {
						eventsIdentity2[result[1]] = [];
					}

					eventsIdentity2[result[1]].push(result[0]);
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					
					if (eventsWallet2[result[1]] == undefined) {
						eventsWallet2[result[1]] = [];
					}

					eventsWallet2[result[1]].push(result[0]);
					break;
				case euroMarket.toLowerCase():
					result = decodeEvent(PIBMarketPT, log);

					if (eventsMarket[result[1]] == undefined) {
						eventsMarket[result[1]] = [];
					}

					eventsMarket[result[1]].push(result[0]);
					break;
				case EURO.address.toLowerCase():
					result = decodeEvent(PiToken, log);

					if (eventsToken[result[1]] == undefined) {
						eventsToken[result[1]] = [];
					}

					eventsToken[result[1]].push(result[0]);
					break;
			
				default:
					break;
			}
		});

		//CHECK EVENTS
		expect(eventsWallet1.Receive[0].tokenAddress).to.equal(EURO.address);
		expect(eventsWallet1.Receive[0]._from).to.equal(euroMarket);

		let exchangeTokenAmount = eventsWallet1.Receive[0].value;
		let expectedExchangeTokenAmount = await wallet1.methods.getSpendToValue(ONE_ETHER).call();
		let exchangePiAmount = eventsWallet1.Transfer[0].value;
		let expectedExchangePiAmount = await wallet1.methods.getTransferExchangeInfoReceiving(ZERO_ADDRESS, EURO.address, ONE_ETHER).call();

		expect(expectedExchangeTokenAmount).to.equal(exchangeTokenAmount);
		expect(expectedExchangePiAmount).to.equal(exchangePiAmount);

		expect(eventsWallet1.Receive[0]._from).to.equal(eventsWallet1.Transfer[0].to)
		expect(eventsWallet1.Transfer[0].data).to.equal("Exchange");

		let transferTokenAmount = eventsWallet1.Transfer[1].value;
		let transferTokenAmountBN = new BigNumber(transferTokenAmount);
		let commissionBN = new BigNumber(eventsWallet1.Transfer[1].commission);
		let exchangeTokenAmountBN = new BigNumber(exchangeTokenAmount);

		expect(exchangeTokenAmountBN.toString()).to.equal(transferTokenAmountBN.plus(commissionBN).toString());

		expect(eventsWallet1.Transfer[1].kind).to.equal('3');
		expect(eventsWallet1.Transfer[1].to).to.equal(wallet2Address);
		expect(eventsWallet1.Transfer[1].value).to.equal(ONE_ETHER);
		expect(eventsWallet1.Transfer[1].value).to.equal(eventsWallet2.Receive[0].value);
		expect(eventsWallet2.Receive[0]._from).to.equal(wallet1Address);

		expect(exchangeTokenAmount).to.equal(eventsMarket.SellPi[0].tokenAmount);
		expect(wallet1Address).to.equal(eventsMarket.SellPi[0].to);
		expect(eventsMarket.PayCounterpart[0].counterpart).to.equal(accounts[0]);
		expect(eventsMarket.PayCounterpart[0].tokenAddress).to.equal(ZERO_ADDRESS);
	})

	it("should send TRANSFER-EXCHANGE(TOKEN/PI) RECEIVING transactions", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
        let nameService = await PIBNameService.deployed();

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
		let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);
		let wallet2 = new web3.eth.Contract(PIBWalletFacet.abi, wallet2Address);

		//TRANSFERS
		let data = await wallet1.methods.transferExchangeReceiving(EURO.address, ZERO_ADDRESS, ONE_ETHER, wallet2Address, "0x0", "3").encodeABI();
		let response = await identity1.forward(wallet1Address, data, {from: accounts[2]});
		
		let euroMarket = await controller.markets.call(EURO.address, ZERO_ADDRESS);

		//GET EVENTS
		let eventsIdentity1 = {}
		let eventsIdentity2 = {}
		let eventsWallet1 = {}
		let eventsWallet2 = {}
		let eventsMarket = {}
		let eventsToken = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case identity1Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					
					if (eventsIdentity1[result[1]] == undefined) {
						eventsIdentity1[result[1]] = [];
					}

					eventsIdentity1[result[1]].push(result[0]);
					break;
				case wallet1Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					
					if (eventsWallet1[result[1]] == undefined) {
						eventsWallet1[result[1]] = [];
					}

					eventsWallet1[result[1]].push(result[0]);
					break;
				case identity2Address.toLowerCase():
					result = decodeEvent(PIBIdentityFacet, log);
					
					if (eventsIdentity2[result[1]] == undefined) {
						eventsIdentity2[result[1]] = [];
					}

					eventsIdentity2[result[1]].push(result[0]);
					break;
				case wallet2Address.toLowerCase():
					result = decodeEvent(PIBWalletFacet, log);
					
					if (eventsWallet2[result[1]] == undefined) {
						eventsWallet2[result[1]] = [];
					}

					eventsWallet2[result[1]].push(result[0]);
					break;
				case euroMarket.toLowerCase():
					result = decodeEvent(PIBMarketPT, log);

					if (eventsMarket[result[1]] == undefined) {
						eventsMarket[result[1]] = [];
					}

					eventsMarket[result[1]].push(result[0]);
					break;
				case EURO.address.toLowerCase():
					result = decodeEvent(PiToken, log);

					if (eventsToken[result[1]] == undefined) {
						eventsToken[result[1]] = [];
					}

					eventsToken[result[1]].push(result[0]);
					break;
			
				default:
					break;
			}
		});

		//CHECK EVENTS
		expect(eventsWallet1.Receive[0].tokenAddress).to.equal(ZERO_ADDRESS);
		expect(eventsWallet1.Receive[0]._from).to.equal(euroMarket);

		let exchangeTokenAmount = eventsWallet1.Receive[0].value;
		let expectedExchangeTokenAmount = await wallet1.methods.getSpendToValue(ONE_ETHER).call();
		let exchangePiAmount = eventsWallet1.Transfer[0].value;
		let expectedExchangePiAmount = await wallet1.methods.getTransferExchangeInfoReceiving(EURO.address, ZERO_ADDRESS, ONE_ETHER).call();

		expect(expectedExchangeTokenAmount).to.equal(exchangeTokenAmount);
		expect(expectedExchangePiAmount).to.equal(exchangePiAmount);

		expect(eventsWallet1.Receive[0]._from).to.equal(eventsWallet1.Transfer[0].to)
		expect(eventsWallet1.Transfer[0].data).to.equal("Exchange");

		let transferTokenAmount = eventsWallet1.Transfer[1].value;
		let transferTokenAmountBN = new BigNumber(transferTokenAmount);
		let commissionBN = new BigNumber(eventsWallet1.Transfer[1].commission);
		let exchangeTokenAmountBN = new BigNumber(exchangeTokenAmount);

		expect(exchangeTokenAmountBN.toString()).to.equal(transferTokenAmountBN.plus(commissionBN).toString());

		expect(eventsWallet1.Transfer[1].kind).to.equal('3');
		expect(eventsWallet1.Transfer[1].to).to.equal(wallet2Address);
		expect(eventsWallet1.Transfer[1].value).to.equal(ONE_ETHER);
		expect(eventsWallet1.Transfer[1].value).to.equal(eventsWallet2.Receive[0].value);
		expect(eventsWallet2.Receive[0]._from).to.equal(wallet1Address);

		expect(exchangeTokenAmount).to.equal(eventsMarket.BuyPi[0].piAmount);
		expect(wallet1Address).to.equal(eventsMarket.BuyPi[0].to);
		expect(eventsMarket.PayCounterpart[0].counterpart).to.equal(accounts[0]);
		expect(eventsMarket.PayCounterpart[0].tokenAddress).to.equal(EURO.address);
	})*/
    
});

function decodeEvent(contract, log) {
	let inputs = contract.events[log.topics[0]].inputs;
	let data = log.data;
	let topics = log.topics.slice(1);
	let event = web3.eth.abi.decodeLog(inputs, data, topics);
	let name = contract.events[log.topics[0]].name;

	return [event, name, log.address];
}