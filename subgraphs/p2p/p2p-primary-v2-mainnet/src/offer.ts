import { NewOffer, UpdateOffer, CancelOffer } from "../generated/PIBP2P/PIBP2P";
import { NewOffer as NewOfferCommodity, UpdateOffer as UpdateOfferCommodity, CancelOffer as CancelOfferCommodity } from "../generated/PIBP2PCommodity/PIBP2PCommodity";
import { NewOffer as NewOfferPackable, UpdateOffer as UpdateOfferPackable, CancelOffer as CancelOfferPackable } from "../generated/PIBP2PPackable/PIBP2PPackable";
import { Offer, OfferCommodity, Commodity, Token, OfferPackable } from "../generated/schema";
import { pushP2P, popP2P } from "./commodity";
import { BigInt, BigDecimal } from "@graphprotocol/graph-ts";
import { getNickname } from "./user";

export function createOffer(event: NewOffer): void {
    let offer = new Offer(event.params.offerId.toHexString());

    offer.owner = event.params.owner.toHexString();
    offer.name = getNickname(event.params.owner.toHexString());
    offer.sellToken = event.params.sellToken.toHexString();
    offer.buyToken = event.params.buyToken.toHexString();
    offer.initialSellAmount = event.params.sellAmount;
    offer.sellAmount = event.params.sellAmount;
    offer.buyAmount = event.params.buyAmount;
    offer.isPartial = event.params.isPartial;
    offer.isBuyFiat = event.params.isBuyFiat;
    offer.isSellFiat = false;
    offer.auditor = event.params.auditor;
    let limits = event.params.limits;
    offer.minDealAmount = limits[0];
    offer.maxDealAmount = limits[1];
    offer.minReputation = limits[2];
    offer.description = event.params.description;
    offer.isOpen = true;
    offer.timestamp = event.block.timestamp;

    if (event.params.sellAmount > BigInt.fromI32(0)) {
        offer.price = event.params.buyAmount.times(getOneEther()).div(event.params.sellAmount);
    } else {
        offer.price = BigInt.fromI32(-1);
    }
    
    offer.deals = [];

    let metadata: Array<BigInt> = event.params.metadata;
    
    let isCountry = true;
    let isPayMethod = true;
    let countries: Array<BigInt> = [];
    let methods: Array<BigInt> = [];
    let accounts: Array<BigInt> = [];

    for (let i = 0; i < metadata.length; i++) {

        if (isCountry) {
            countries.push(metadata[i]);
            if (metadata[i] == BigInt.fromI32(0)) {
                isCountry = false;
            }
        } else if (isPayMethod) {
            methods.push(metadata[i]);
            if (metadata[i] == BigInt.fromI32(0)) {
                isPayMethod = false;
            }
        } else {
            accounts.push(metadata[i]);
        }
    }

    offer.country = countries;
    offer.payMethod = methods;
    offer.payAccount = accounts;

    offer.save();
}

export function createOfferCommodity(event: NewOfferCommodity): void {
    let offer = new OfferCommodity(event.params.offerId.toHexString());

    offer.owner = event.params.owner.toHexString();
    offer.name = getNickname(event.params.owner.toHexString());
    offer.sellToken = event.params.sellToken.toHexString();
    offer.buyToken = event.params.buyToken.toHexString();
    pushP2P(event.params.sellToken.toHexString(), event.params.sellId);
    let commodityId = event.params.sellToken.toHexString().concat("-").concat(event.params.sellId.toString());
    offer.sellId = commodityId;
    offer.buyAmount = event.params.buyAmount;
    offer.description = event.params.description;
    offer.isOpen = true;
    offer.isBuyFiat = event.params.isBuyFiat;
    offer.timestamp = event.block.timestamp;
    offer.minReputation = event.params.minReputation;
    offer.auditor = event.params.auditor;
    offer.price = event.params.buyAmount;
    let token = Token.load(event.params.sellToken.toHexString());
    offer.deals = [];

    let metadata: Array<BigInt> = event.params.metadata;
    
    let isCountry = true;
    let isPayMethod = true;
    let countries: Array<BigInt> = [];
    let methods: Array<BigInt> = [];
    let accounts: Array<BigInt> = [];

    for (let i = 0; i < metadata.length; i++) {

        if (isCountry) {
            countries.push(metadata[i]);
            if (metadata[i] == BigInt.fromI32(0)) {
                isCountry = false;
            }
        } else if (isPayMethod) {
            methods.push(metadata[i]);
            if (metadata[i] == BigInt.fromI32(0)) {
                isPayMethod = false;
            }
        } else {
            accounts.push(metadata[i]);
        }
    }

    offer.country = countries;
    offer.payMethod = methods;
    offer.payAccount = accounts;

    offer.save();
}

export function createOfferPackable(event: NewOfferPackable): void {
    let offer = new OfferPackable(event.params.offerId.toHexString());

    offer.owner = event.params.owner.toHexString();
    offer.sellToken = event.params.sellToken.toHexString();
    offer.sellId = event.params.tokenId.toHexString();
    offer.sellAmount = event.params.sellAmount;
    offer.buyToken = event.params.buyToken.toHexString();
    offer.buyAmount = event.params.buyAmount;
    offer.price = event.params.buyAmount;
    if (event.params.sellAmount > BigInt.fromI32(0)) {
        offer.price_per_unit = event.params.buyAmount.times(getOneEther()).div(event.params.sellAmount);
    } else {
        offer.price_per_unit = BigInt.fromI32(0);
    }
    offer.initialSellAmount = event.params.sellAmount;
    offer.isPartial = event.params.isPartial;
    offer.isBuyFiat = false;
    offer.isSellFiat = false;
    let limits = event.params.limits;
    offer.minDealAmount = limits[0];
    offer.maxDealAmount = limits[1];
    offer.minReputation = limits[2];
    offer.description = event.params.description;
    offer.isOpen = true;
    offer.timestamp = event.block.timestamp;
    offer.deals = [];

    let metadata: Array<BigInt> = event.params.metadata;
    
    let isCountry = true;
    let isPayMethod = true;
    let countries: Array<BigInt> = [];
    let methods: Array<BigInt> = [];
    let accounts: Array<BigInt> = [];

    for (let i = 0; i < metadata.length; i++) {

        if (isCountry) {
            countries.push(metadata[i]);
            if (metadata[i] == BigInt.fromI32(0)) {
                isCountry = false;
            }
        } else if (isPayMethod) {
            methods.push(metadata[i]);
            if (metadata[i] == BigInt.fromI32(0)) {
                isPayMethod = false;
            }
        } else {
            accounts.push(metadata[i]);
        }
    }

    offer.country = countries;
    offer.payMethod = methods;
    offer.payAccount = accounts;

    offer.save();
}

export function updateOffer(event: UpdateOffer): void {
    let offer = Offer.load(event.params.offerId.toHexString());

    if ((event.params.sellAmount == BigInt.fromI32(0)) && (event.params.buyAmount == BigInt.fromI32(0))) {
        offer.isOpen = false;
        offer.sellAmount = event.params.sellAmount;
        offer.buyAmount = event.params.buyAmount;
    } else {
        offer.sellAmount = event.params.sellAmount;
        offer.buyAmount = event.params.buyAmount;

        if (event.params.sellAmount > BigInt.fromI32(0)) {
            offer.price = event.params.buyAmount.times(getOneEther()).div(event.params.sellAmount as BigInt);
        } else {
            offer.price = BigInt.fromI32(-1);
        }
    }

    offer.save();
}

export function updateOfferCommodity(event: UpdateOfferCommodity): void {
    let offer = OfferCommodity.load(event.params.offerId.toHexString());

    offer.buyAmount = event.params.buyAmount;
    offer.price = event.params.buyAmount;

    if ((event.params.sellId == BigInt.fromI32(0)) && (event.params.buyAmount == BigInt.fromI32(0))) {
        offer.isOpen = false;
    }

    offer.save();
}

export function updateOfferPackable(event: UpdateOfferPackable): void {
    let offer = OfferPackable.load(event.params.offerId.toHexString());

    offer.sellAmount = event.params.sellAmount;
    offer.buyAmount = event.params.buyAmount;
    offer.price = event.params.buyAmount;
    if (offer.sellAmount > BigInt.fromI32(0)) {
        offer.price_per_unit = offer.price.times(getOneEther()).div(offer.sellAmount);
    } else {
        offer.price_per_unit = BigInt.fromI32(0);
    }
    

    if ((event.params.sellAmount == BigInt.fromI32(0)) && (event.params.buyAmount == BigInt.fromI32(0))) {
        offer.isOpen = false;
    }

    offer.save();
}

export function cancelOffer(event: CancelOffer): void {
    let offer = Offer.load(event.params.offerId.toHexString());

    offer.isOpen = false;

    offer.save();
}

export function cancelOfferCommodity(event: CancelOfferCommodity): void {
    let offer = OfferCommodity.load(event.params.offerId.toHexString());

    offer.isOpen = false;

    let commodity = Commodity.load(offer.sellId);
    popP2P(offer.sellToken, commodity.tokenId as BigInt);

    offer.save();
}

export function cancelOfferPackable(event: CancelOfferPackable): void {
    let offer = OfferPackable.load(event.params.offerId.toHexString());

    offer.isOpen = false;

    offer.save();
}

export function pushDealToOffer(offerId: string, dealId: string): void {
    let offer = Offer.load(offerId);

    if (offer != null) {
        let array = offer.deals;
        array.push(dealId);
        offer.deals = array;

        offer.save();
    }
}

export function pushDealToOfferCommodity(offerId: string, dealId: string): void {
    let offer = OfferCommodity.load(offerId);

    if (offer != null) {
        let array = offer.deals;
        array.push(dealId);
        offer.deals = array;

        offer.save();
    }
}

export function pushDealToOfferPackable(offerId: string, dealId: string): void {
    let offer = OfferPackable.load(offerId);

    if (offer != null) {
        let array = offer.deals;
        array.push(dealId);
        offer.deals = array;

        offer.save();
    }
}

export function getOneEther(): BigInt {
    let n = BigInt.fromI32(1);
    for(let i = 0; i < 18; i++) {
        n = n.times(BigInt.fromI32(10));
    }
    return n;
}