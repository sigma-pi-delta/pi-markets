import { NewOffer, NewDeal, UpdateOffer, CancelOffer, NewCommission, NewPendingDeal, VoteDeal, DealLock, AuditorNotification, SetAllowedOffer, SetOfferer } from "../generated/PIBP2PCommodity/PIBP2PCommodity";
import { createOfferCommodity, updateOfferCommodity, cancelOfferCommodity } from "./offer";
import { pushCommodityOffer, pushCommodityDeal, createUserIfNull } from "./user";
import { createCommodityDeal, finishDealCommodity, updateVoteCommodity } from "./deal";
import { OfferCommodity, Commodity, P2PCommodity, User, DealPackable, Auditor, Pair } from "../generated/schema";
import { popP2P } from "./commodity";
import { BigInt } from "@graphprotocol/graph-ts";


export function handleNewOffer(event: NewOffer): void {
    createOfferCommodity(event);
    pushCommodityOffer(event.params.owner.toHexString(), event.params.offerId.toHexString());
}

export function handleNewPendingDeal(event: NewPendingDeal): void {
    createCommodityDeal(event);
    let offer = OfferCommodity.load(event.params.dealId.toHexString());
    if (offer != null) {
        pushCommodityDeal(offer.owner, event.params.dealId.toHexString());
    }

    pushCommodityDeal(event.params.buyer.toHexString(), event.params.dealId.toHexString());
    let commodity = Commodity.load(offer.sellId)
    popP2P(offer.sellToken, commodity.tokenId as BigInt);
}

export function handleNewDeal(event: NewDeal): void {
    finishDealCommodity(event.params.dealId.toHexString(), event.params.success, event.params.sender);
}

export function handleUpdateOffer(event: UpdateOffer): void {
    updateOfferCommodity(event);
}

export function handleCancelOffer(event: CancelOffer): void {
    cancelOfferCommodity(event);
}

export function handleVoteDeal(event: VoteDeal): void {
    updateVoteCommodity(event);
}

export function handleNewCommission(event: NewCommission): void {
    let p2p = P2PCommodity.load(event.address.toHexString());

    if (p2p == null) {
        p2p = new P2PCommodity(event.address.toHexString());
    }

    p2p.commission = event.params.commission;

    p2p.save();
}

export function handleDealLock(event: DealLock): void {
    createUserIfNull(event.params.user.toHexString());
    let user = User.load(event.params.user.toHexString());

    user.isCommodityDealLocked = event.params.isLocked;

    user.save();
}

export function handleAuditorNotification(event: AuditorNotification): void {
    let deal = DealPackable.load(event.params.dealId.toHexString());

    if (deal != null) {
        let offer = OfferCommodity.load(deal.offer);

        if (offer != null) {
            let auditor = Auditor.load(offer.auditor.toHexString());

            if (auditor == null) {
                auditor = new Auditor(offer.auditor.toHexString());
                let requests = auditor.commodityRequests;
                requests.push(deal.id);
                auditor.commodityRequests = requests;

                auditor.save();
            }
        }
    }
}

export function handleSetOfferer(event: SetOfferer): void {
    createUserIfNull(event.params.offerer.toHexString());
    let user = User.load(event.params.offerer.toHexString());

    let allowedTokens = user.allowedTokens;

    if (event.params.isOfferer) {
        if (!allowedTokens.includes(event.params.token.toHexString())) {
            allowedTokens.push(event.params.token.toHexString());
            user.allowedTokens = allowedTokens;
        }
    } else {
        let index = allowedTokens.indexOf(event.params.token.toHexString());

        if (index > -1) {
            allowedTokens.splice(index, 1);
        }

        user.allowedTokens = allowedTokens;
    }

    user.save();
}

export function handleSetAllowedOffer(event: SetAllowedOffer): void {
    createPairIfNull(event.params.sellToken.toHexString(), event.params.buyToken.toHexString());
    let pairId = event.params.sellToken.toHexString().concat("-").concat(event.params.buyToken.toHexString());
    let pair = Pair.load(pairId);
    pair.isAllowed = event.params.isAllowed;
    pair.save();
}

function createPairIfNull(sellToken: string, buyToken: string): void {
    let pairId = sellToken.concat("-").concat(buyToken);
    let pair = Pair.load(pairId);

    if (pair == null) {
        pair = new Pair(pairId);
        pair.sellToken = sellToken;
        pair.buyToken = buyToken;
        pair.isAllowed = false;
        pair.save();
    }
}