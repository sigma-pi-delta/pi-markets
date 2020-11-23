import { Deal, Offer, DealCommodity, DealPackable, OfferPackable, OfferCommodity } from "../generated/schema";
import { NewPendingDeal, VoteDeal } from "../generated/PIBP2P/PIBP2P";
import { BigDecimal, Address, BigInt } from "@graphprotocol/graph-ts";
import { NewPendingDeal as NewPendingDealCommodity, VoteDeal as VoteDealCommodity } from "../generated/PIBP2PCommodity/PIBP2PCommodity";
import { NewDeal as NewDealPackable, NewPendingDeal as NewPendingDealPackable, VoteDeal as VoteDealPackable } from "../generated/PIBP2PPackable/PIBP2PPackable";
import { pushDealToOffer, pushDealToOfferCommodity, pushDealToOfferPackable } from "./offer";

export function createDeal(event: NewPendingDeal): void {
    let deal = Deal.load(event.params.dealId.toHexString());
    let offer = Offer.load(event.params.offerId.toHexString());

    if (deal == null) {
        deal = new Deal(event.params.dealId.toHexString());

        deal.offer = event.params.offerId.toHexString();
        deal.seller = offer.owner;
        deal.buyer = event.params.buyer.toHexString();
        deal.sellAmount = event.params.sellAmount;
        deal.buyAmount = event.params.buyAmount;
        deal.sellerVote = BigInt.fromI32(0);
        deal.buyerVote = BigInt.fromI32(0);
        deal.auditorVote = BigInt.fromI32(0);
        deal.isPending = true;
        deal.timestamp = event.block.timestamp;

        deal.save();

        pushDealToOffer(event.params.offerId.toHexString(), event.params.dealId.toHexString());
    }
}

export function createCommodityDeal(event: NewPendingDealCommodity): void {
    let deal = DealCommodity.load(event.params.dealId.toHexString());
    let offer = OfferCommodity.load(event.params.dealId.toHexString());

    if (deal == null) {
        deal = new DealCommodity(event.params.dealId.toHexString());

        deal.offer = event.params.dealId.toHexString();
        deal.seller = offer.owner;
        deal.buyer = event.params.buyer.toHexString();
        deal.buyAmount = event.params.buyAmount;
        deal.sellerVote = BigInt.fromI32(0);
        deal.buyerVote = BigInt.fromI32(0);
        deal.auditorVote = BigInt.fromI32(0);
        deal.isPending = true;
        deal.timestamp = event.block.timestamp;

        deal.save();

        pushDealToOfferCommodity(event.params.dealId.toHexString(), event.params.dealId.toHexString());
    }
}

export function createPackableDeal(event: NewPendingDealPackable): void {
    let deal = DealPackable.load(event.params.dealId.toHexString());
    let offer = OfferPackable.load(event.params.offerId.toHexString());

    if (deal == null) {
        deal = new DealPackable(event.params.dealId.toHexString());

        deal.offer = event.params.offerId.toHexString();
        deal.seller = offer.owner;
        deal.buyer = event.params.buyer.toHexString();
        deal.sellAmount = event.params.sellAmount;
        deal.buyAmount = event.params.buyAmount;
        deal.sellerVote = BigInt.fromI32(0);
        deal.buyerVote = BigInt.fromI32(0);
        deal.auditorVote = BigInt.fromI32(0);
        deal.isPending = true;
        deal.timestamp = event.block.timestamp;

        deal.save();

        pushDealToOfferPackable(event.params.offerId.toHexString(), event.params.dealId.toHexString());
    }
}

export function finishDeal(dealId: string, success: boolean, executor: Address): void {
    let deal = Deal.load(dealId);

    if (deal != null) {
        deal.isPending = false;
        deal.isSuccess = success;
        deal.executor = executor;

        deal.save();
    }
}

export function finishDealPackable(dealId: string, success: boolean, executor: Address): void {
    let deal = DealPackable.load(dealId);

    if (deal != null) {
        deal.isPending = false;
        deal.isSuccess = success;
        deal.executor = executor;

        deal.save();
    }
}

export function finishDealCommodity(dealId: string, success: boolean, executor: Address): void {
    let deal = DealCommodity.load(dealId);

    if (deal != null) {
        deal.isPending = false;
        deal.isSuccess = success;
        deal.executor = executor;

        deal.save();
    }
}

export function updateVote(event: VoteDeal): void {
    let deal = Deal.load(event.params.dealId.toHexString());

    if (deal != null) {
        
        if (event.params.sender == Address.fromString(deal.buyer)) {
            deal.buyerVote = BigInt.fromI32(event.params.vote);
            deal.sellerVote = BigInt.fromI32(event.params.counterpartVote);
        } else {
            deal.sellerVote = BigInt.fromI32(event.params.vote);
            deal.buyerVote = BigInt.fromI32(event.params.counterpartVote);
        }

        deal.save();
    }
}

export function updateVotePackable(event: VoteDealPackable): void {
    let deal = DealPackable.load(event.params.dealId.toHexString());

    if (deal != null) {
        
        if (event.params.sender == Address.fromString(deal.buyer)) {
            deal.buyerVote = BigInt.fromI32(event.params.vote);
            deal.sellerVote = BigInt.fromI32(event.params.counterpartVote);
        } else {
            deal.sellerVote = BigInt.fromI32(event.params.vote);
            deal.buyerVote = BigInt.fromI32(event.params.counterpartVote);
        }

        deal.save();
    }
}

export function updateVoteCommodity(event: VoteDealCommodity): void {
    let deal = DealCommodity.load(event.params.dealId.toHexString());

    if (deal != null) {
        
        if (event.params.sender == Address.fromString(deal.buyer)) {
            deal.buyerVote = BigInt.fromI32(event.params.vote);
            deal.sellerVote = BigInt.fromI32(event.params.counterpartVote);
        } else {
            deal.sellerVote = BigInt.fromI32(event.params.vote);
            deal.buyerVote = BigInt.fromI32(event.params.counterpartVote);
        }

        deal.save();
    }
}