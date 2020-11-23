import { BigInt } from "@graphprotocol/graph-ts"
import {
  PIBP2PFiat,
  NewOffer,
  NewDeal,
  NewPendingDeal,
  UpdateOffer,
  CancelOffer,
  VoteDeal,
  AuditorNotification,
  UpdateReputation,
  OfferLock,
  NewCommission
} from "../generated/PIBP2PFiat/PIBP2PFiat"
import {
  NewOffer as NewOfferOriginal,
  NewDeal as NewDealOriginal,
  NewPendingDeal as NewPendingDealOriginal,
  UpdateOffer as UpdateOfferOriginal,
  CancelOffer as CancelOfferOriginal,
  VoteDeal as VoteDealOriginal,
  AuditorNotification as AuditorNotificationOriginal,
  UpdateReputation as UpdateReputationOriginal,
  NewCommission as NewCommissionOriginal
} from "../generated/PIBP2P/PIBP2P"
import { Offer, Deal, Auditor, User, P2P, Lock } from "../generated/schema"
import { pushOffer, pushPendingDeal, createUserIfNull } from "./user";
import { createDeal, finishDeal, updateVote } from "./deal";
import { createOffer, updateOffer, cancelOffer } from "./offer";

export function handleNewOffer(event: NewOffer): void {
  createOffer(event as NewOfferOriginal);
  pushOffer(event.params.owner.toHexString(), event.params.offerId.toHexString());
  let offer = Offer.load(event.params.offerId.toHexString());
  offer.isSellFiat = true;
  offer.isBuyFiat = false;
  offer.save();
}

export function handleNewDeal(event: NewDeal): void {
  finishDeal(event.params.dealId.toHexString(), event.params.success, event.params.sender);
}

export function handleNewPendingDeal(event: NewPendingDeal): void {
  createDeal(event as NewPendingDealOriginal);
  pushPendingDeal(event.params.buyer.toHexString(), event.params.dealId.toHexString());
  let offer = Offer.load(event.params.offerId.toHexString());

  if (offer != null) {
    pushPendingDeal(offer.owner, event.params.dealId.toHexString());
  }
}

export function handleUpdateOffer(event: UpdateOffer): void {
  updateOffer(event as UpdateOfferOriginal);
}

export function handleCancelOffer(event: CancelOffer): void {
  cancelOffer(event as CancelOfferOriginal);
}

export function handleVoteDeal(event: VoteDeal): void {
  updateVote(event as VoteDealOriginal);
}

export function handleAuditorNotification(event: AuditorNotification): void {
  let deal = Deal.load(event.params.dealId.toHexString());

  if (deal != null) {
    let offer = Offer.load(deal.offer);

    if (offer != null) {
      let auditor = Auditor.load(offer.auditor.toHexString());

      if (auditor == null) {
        auditor = new Auditor(offer.auditor.toHexString());
        let requests = auditor.requests;
        requests.push(deal.id);
        auditor.requests = requests;

        auditor.save();
      }
    }
  }
}

export function handleUpdateReputation(event: UpdateReputation): void {
  createUserIfNull(event.params.user.toHexString());
  let user = User.load(event.params.user.toHexString());

  user.offchainReputation = event.params.reputation;

  user.save();
}

export function handleOfferLock(event: OfferLock): void {
  createUserIfNull(event.params.user.toHexString());
  let user = User.load(event.params.user.toHexString());
  let lockId = event.params.user.toHexString().concat("-CURRENCY-").concat(event.params.tokenAddress.toHexString());
  let offerLock = Lock.load(lockId);

  if (offerLock == null) {
    offerLock = new Lock(lockId);
    offerLock.token = event.params.tokenAddress.toHexString();
  }

  offerLock.isLocked = event.params.isLocked;

  offerLock.save();

  let locks = user.isOfferLocked;

  if (!locks.includes(lockId)) {
    locks.push(lockId);
    user.isOfferLocked = locks;
    user.save();
  }
}

export function handleNewCommission(event: NewCommission): void {
  let p2p = P2P.load(event.address.toHexString());

  if (p2p == null) {
    p2p = new P2P(event.address.toHexString());
  }

  p2p.commission = event.params.commission;

  p2p.save();
}