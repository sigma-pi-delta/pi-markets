import { User, Reputation } from "../generated/schema";
import { BigInt, Address } from "@graphprotocol/graph-ts";
import { PIBP2P, HandleDealReputation } from "../generated/PIBP2P/PIBP2P";
import { NameService, CreateName } from "../generated/NameService/NameService";

export function handleCreateName(event: CreateName): void {
    createUserIfNull(event.params.wallet.toHexString());
}

export function pushOffer(userId: string, offerId: string): void {
    createUserIfNull(userId);
    let user = User.load(userId);

    let offers = user.offers;
    offers.push(offerId);
    user.offers = offers;

    user.save();
}

export function pushCommodityOffer(userId: string, offerId: string): void {
    createUserIfNull(userId);
    let user = User.load(userId);

    let offers = user.commodityOffers;
    offers.push(offerId);
    user.commodityOffers = offers;

    user.save();
}

export function pushPackableOffer(userId: string, offerId: string): void {
    createUserIfNull(userId);
    let user = User.load(userId);

    let offers = user.packableOffers;
    offers.push(offerId);
    user.packableOffers = offers;

    user.save();
}

export function pushPendingDeal(userId: string, dealId: string): void {
    createUserIfNull(userId);
    let user = User.load(userId);

    let deals = user.deals;
    deals.push(dealId);
    user.deals = deals;

    user.save();
}

export function pushCommodityDeal(userId: string, dealId: string): void {
    createUserIfNull(userId);
    let user = User.load(userId);

    let deals = user.commodityDeals;
    deals.push(dealId);
    user.commodityDeals = deals;

    user.save();
}

export function pushPackableDeal(userId: string, dealId: string): void {
    createUserIfNull(userId);
    let user = User.load(userId);

    let deals = user.packableDeals;
    deals.push(dealId);
    user.packableDeals = deals;

    user.save();
}

export function createUserIfNull(userId: string): void {
    let user = User.load(userId);

    if (user == null) {
        user = new User(userId);
        user.offers = [];
        user.commodityOffers = [];
        user.packableOffers = [];
        user.deals = [];
        user.commodityDeals = [];
        user.packableDeals = [];
        user.reputations = [];
        user.name = getNickname(userId);
        user.offchainReputation = BigInt.fromI32(0);
        user.isDealLocked = false;
        user.isCommodityDealLocked = false;
        user.isPackableDealLocked = false;
        user.isOfferLocked = [];
        user.isCommodityOfferLocked = [];
        user.isPackableOfferLocked = [];
        user.allowedTokens = [];

        user.save();
    }
}

export function getNickname(walletAddress: string): string {
    let nameService = NameService.bind(Address.fromString("0x3e4B7f25A608b3E4df696E79d2D2CC354e6D6b8E"));
    let name = nameService.try_name(Address.fromString(walletAddress));

    if (!name.reverted) {
        return name.value;
    } else {
        return "reverted";
    }
}

export function updateReputation(event: HandleDealReputation): void {
    createUserIfNull(event.params.seller.toHexString());
    let user = User.load(event.params.seller.toHexString());
    let reputationId = event.params.seller.toHexString().concat("-").concat(event.params.tokenAddress.toHexString());
    createReputationIfNull(reputationId, event.params.seller.toHexString(), event.params.tokenAddress.toHexString());
    let reputation = Reputation.load(reputationId);

    reputation.totalDeals = reputation.totalDeals.plus(BigInt.fromI32(1));

    if (event.params.isSuccess) {
        reputation.goodReputation = reputation.goodReputation.plus(event.params.dealAmount);
    } else {
        reputation.badReputation = reputation.badReputation.plus(event.params.dealAmount);
    }

    reputation.save();
}

function createReputationIfNull(id: string, user: string, tokenAddress: string): void {
    let reputation = Reputation.load(id);

    if (reputation == null) {
        reputation = new Reputation(id);

        reputation.user = user;
        reputation.token = tokenAddress;
        reputation.goodReputation = BigInt.fromI32(0);
        reputation.badReputation = BigInt.fromI32(0);
        reputation.totalDeals = BigInt.fromI32(0);

        reputation.save();

        pushReputation(user, id);
    }
}

function pushReputation(userId: string, reputationId: string): void {
    let user = User.load(userId);

    if (user != null) {
        let reputation = Reputation.load(reputationId);

        if (reputation != null) {
            let reputations = user.reputations;

            if (!reputations.includes(reputationId)) {
                reputations.push(reputationId);
                user.reputations = reputations;
                user.save();
            }
        }
    }
}