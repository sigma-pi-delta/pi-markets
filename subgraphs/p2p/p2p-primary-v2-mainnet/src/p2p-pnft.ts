import { NewOffer, NewDeal, UpdateOffer, CancelOffer, NewCommission, NewPendingDeal, VoteDeal, AuditorNotification, DealLock, SetAllowedOffer, SetOfferer } from "../generated/PIBP2PPackable/PIBP2PPackable";
import { P2PPackable, OfferPackable, DealPackable, Auditor, User, Lock, Pair } from "../generated/schema";
import { cancelOfferPackable, updateOfferPackable, createOfferPackable } from "./offer";
import { pushPackableOffer, pushPackableDeal, createUserIfNull } from "./user";
import { createPackableDeal, finishDealPackable, updateVotePackable } from "./deal";


export function handleNewOffer(event: NewOffer): void {
    createOfferPackable(event);
    let offer = OfferPackable.load(event.params.offerId.toHexString());
    if (offer != null) {
        offer.isBuyFiat = event.params.isBuyFiat;
        offer.save();
    }
    pushPackableOffer(event.params.owner.toHexString(), event.params.offerId.toHexString());
}

export function handleNewOfferRequest(event: NewOffer): void {
    createOfferPackable(event);
    let offer = OfferPackable.load(event.params.offerId.toHexString());
    if (offer != null) {
        offer.isSellFiat = event.params.isBuyFiat;
        offer.save();
    }
    pushPackableOffer(event.params.owner.toHexString(), event.params.offerId.toHexString());
}

export function handleNewPendingDeal(event: NewPendingDeal): void {
    createPackableDeal(event);
    let offer = OfferPackable.load(event.params.offerId.toHexString());
    if (offer != null) {
        pushPackableDeal(offer.owner, event.params.dealId.toHexString());
    }

    pushPackableDeal(event.params.buyer.toHexString(), event.params.dealId.toHexString());

}

export function handleNewDeal(event: NewDeal): void {
    finishDealPackable(event.params.dealId.toHexString(), event.params.success, event.params.sender);
}

export function handleUpdateOffer(event: UpdateOffer): void {
    updateOfferPackable(event);
}

export function handleCancelOffer(event: CancelOffer): void {
    cancelOfferPackable(event);
}

export function handleVoteDeal(event: VoteDeal): void {
    updateVotePackable(event);
}

export function handleAuditorNotification(event: AuditorNotification): void {
    let deal = DealPackable.load(event.params.dealId.toHexString());

    if (deal != null) {
        let offer = OfferPackable.load(deal.offer);

        if (offer != null) {
            let auditor = Auditor.load(offer.auditor.toHexString());

            if (auditor == null) {
                auditor = new Auditor(offer.auditor.toHexString());
                let requests = auditor.packableRequests;
                requests.push(deal.id);
                auditor.packableRequests = requests;

                auditor.save();
            }
        }
    }
}

export function handleNewCommission(event: NewCommission): void {
    let p2p = P2PPackable.load(event.address.toHexString());

    if (p2p == null) {
        p2p = new P2PPackable(event.address.toHexString());
    }

    p2p.commission = event.params.commission;

    p2p.save();
}

export function handleDealLock(event: DealLock): void {
    createUserIfNull(event.params.user.toHexString());
    let user = User.load(event.params.user.toHexString());

    user.isPackableDealLocked = event.params.isLocked;

    user.save();
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