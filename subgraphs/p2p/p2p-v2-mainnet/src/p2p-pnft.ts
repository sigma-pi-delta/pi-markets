import { NewOffer, NewDeal, UpdateOffer, CancelOffer, NewCommission, NewPendingDeal, VoteDeal, AuditorNotification, DealLock, OfferLock } from "../generated/PIBP2PPackable/PIBP2PPackable";
import { P2PPackable, OfferPackable, DealPackable, Auditor, User, Lock } from "../generated/schema";
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

export function handleOfferLock(event: OfferLock): void {
    createUserIfNull(event.params.user.toHexString());
    let user = User.load(event.params.user.toHexString());
    let lockId = event.params.user.toHexString().concat("-PACKABLE-").concat(event.params.tokenAddress.toHexString());
    let offerLock = Lock.load(lockId);

    if (offerLock == null) {
        offerLock = new Lock(lockId);
        offerLock.token = event.params.tokenAddress.toHexString();
    }

    offerLock.isLocked = event.params.isLocked;

    offerLock.save();

    let locks = user.isPackableOfferLocked;

    if (!locks.includes(lockId)) {
        locks.push(lockId);
        user.isPackableOfferLocked = locks;
        user.save();
    }
}