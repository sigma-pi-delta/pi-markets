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
const PIBP2P = artifacts.require("PIBP2P");
const PIBP2PCollectable = artifacts.require("PIBP2PCollectable");
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
const ONE_POINT_TWO_ETHER = "1200000000000000000";
const ZERO_POINT_SIX_ETHER = "600000000000000000"
const TEN_ETHER = "10000000000000000000"
const HUNDRED_ETHER = "100000000000000000000";
const NFT_REF = "GLD-01";
const NFT_JSON = "{'peso':1000,'ley':95}";
const GOLD_JSON_REFERENCE = "{'key0':'weight_brute','key1':'law','key2':'weight_fine'}"

let EURO;
let DOLAR;
let NFT;
let FIAT_FACET_WEB3;
let COMMODITY_FACET_WEB3;
let OFFER_ID;
let DEAL_ID;

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
		let p2p = await PIBP2P.deployed();
		let p2pNft = await PIBP2PCollectable.deployed();

        //SET ADDRESSES
        await controller.setNewAddress("1", registry.address, false, {from: accounts[0]});
        await controller.setNewAddress("2", idFactory.address, true, {from: accounts[0]});
        await controller.setNewAddress("3", walletFactory.address, true, {from: accounts[0]});
        await controller.setNewAddress("4", stateChecker.address, true, {from: accounts[0]});
        await controller.setNewAddress("5", walletMath.address, false, {from: accounts[0]});
		await controller.setNewAddress("6", nameService.address, false, {from: accounts[0]});
		await controller.setNewAddress("7", accounts[9], false, {from: accounts[0]});
		await controller.setNewAddress("8", p2p.address, false, {from: accounts[0]});
		await controller.setNewAddress("9", p2pNft.address, false, {from: accounts[0]});

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
		let market = await PIBMarketPT.new("1200000000000000000", "3000000000000000000", euro.address, controller.address);

		await controller.setNewMarket(euro.address, ZERO_ADDRESS, market.address, {from: accounts[0]});

		await euro.approve(market.address, TEN_ETHER, {from: accounts[0]});
        await market.tokenCounterpart(TEN_ETHER, {from: accounts[0]});
        await market.piCounterpart({from: accounts[0], value: new BigNumber(TEN_ETHER)});
    })
    
	it("should set an offer in PI", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
		let nameService = await PIBNameService.deployed();
        let p2pWeb3 = new web3.eth.Contract(PIBP2P.abi, PIBP2P.address);

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity1 = await PIBIdentityFacet.at(identity1Address)
        let wallet1 = new web3.eth.Contract(PIBWalletFacet.abi, wallet1Address);
		
		let tokens = [ZERO_ADDRESS, EURO.address];
		let amounts = [ONE_ETHER, ONE_POINT_TWO_ETHER];
		let settings = [true, true];
		let limits = ["120000000000000000", "700000000000000000", "0"];
		let description = "PI/EUR offer (token-fiat)";
		let metadata = ["724", "725", "0", "3", "4", "0"];

		let offerData = p2pWeb3.methods.offer(
            tokens, 
            amounts, 
            settings, 
            limits,
            accounts[9],
			description,
			metadata
        ).encodeABI();

        let walletData = wallet1.methods.forwardValue(ZERO_ADDRESS, ONE_ETHER, PIBP2P.address, offerData).encodeABI();
        let response = await identity1.forward(wallet1Address, walletData, {from: accounts[2]});

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case PIBP2P.address.toLowerCase():
					result = decodeEvent(PIBP2P, log);
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
		
		let commission = await p2pWeb3.methods.commission().call();
		let commissionAmount = parseInt(ONE_ETHER) * parseInt(commission) / (100 * parseInt(ONE_ETHER));
		let offerAmount = parseInt(ONE_ETHER) - commissionAmount;

        expect(events.NewOffer.owner).to.equal(wallet1Address);
        expect(events.NewOffer.sellToken).to.equal(ZERO_ADDRESS);
        expect(events.NewOffer.buyToken).to.equal(EURO.address);
        expect(events.NewOffer.sellAmount).to.equal(offerAmount.toString());
        expect(events.NewOffer.buyAmount).to.equal(ONE_POINT_TWO_ETHER);
        expect(events.NewOffer.isPartial).to.equal(true);
        expect(events.NewOffer.isBuyFiat).to.equal(true);
        expect(events.NewOffer.auditor).to.equal(accounts[9]);
        expect(events.NewOffer.description).to.equal(description);

        OFFER_ID = events.NewOffer.offerId;
    })
    
    it("should deal half of the offer", async () => {
        //INSTANCE CONTRACTS
        let controller = await PIBController.deployed();
        let registry = await PIBRegistry.deployed();
		let nameService = await PIBNameService.deployed();
        let p2pWeb3 = new web3.eth.Contract(PIBP2P.abi, PIBP2P.address);

        let identity1Address = await registry.identities.call(DATA_HASH);
        let wallet1Address = await nameService.addr.call(NAME);
        let identity2Address = await registry.identities.call(DATA_HASH_2);
        let wallet2Address = await nameService.addr.call(NAME2);

        //INSTANCE CONTRACTS
        let identity2 = await PIBIdentityFacet.at(identity2Address)
        let wallet2 = new web3.eth.Contract(PIBWalletFacet.abi, wallet2Address);
        
        let description = "PI/EUR offer (token-fiat)";

		let dealData = p2pWeb3.methods.deal(
            OFFER_ID,
            ZERO_POINT_SIX_ETHER
        ).encodeABI();

        let walletData = wallet2.methods.forwardValue(EURO.address, ZERO_POINT_SIX_ETHER, PIBP2P.address, dealData).encodeABI();
        let response = await identity2.forward(wallet2Address, walletData, {from: accounts[4]});

		//GET EVENTS
		let events = {}
		let result;
		response.receipt.rawLogs.forEach(function(log) {
			switch (log.address.toLowerCase()) {
				case PIBP2P.address.toLowerCase():
					result = decodeEvent(PIBP2P, log);
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

        expect(events.NewPendingDeal.offerId).to.equal(OFFER_ID);
        expect(events.UpdateOffer.buyAmount).to.equal(ZERO_POINT_SIX_ETHER);

        DEAL_ID = events.NewPendingDeal.dealId;
	})
});

function decodeEvent(contract, log) {
	let inputs = contract.events[log.topics[0]].inputs;
	let data = log.data;
	let topics = log.topics.slice(1);
	let event = web3.eth.abi.decodeLog(inputs, data, topics);
	let name = contract.events[log.topics[0]].name;

	return [event, name, log.address];
}