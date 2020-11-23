import { BigInt } from "@graphprotocol/graph-ts"
import {
  PIBP2P,
  NewOffer,
  NewDeal,
  NewPendingDeal,
  UpdateOffer,
  CancelOffer,
  VoteDeal,
  AuditorNotification,
  UpdateReputation,
  DealLock,
  NewCommission,
  HandleDealReputation
} from "../generated/PIBP2P/PIBP2P"
import { Offer, Deal, Auditor, User, P2P } from "../generated/schema"
import { pushOffer, pushPendingDeal, createUserIfNull, updateReputation } from "./user";
import { createDeal, finishDeal, updateVote } from "./deal";
import { createOffer, updateOffer, cancelOffer } from "./offer";

export function handleNewOffer(event: NewOffer): void {
  createOffer(event);
  pushOffer(event.params.owner.toHexString(), event.params.offerId.toHexString());
}

export function handleNewDeal(event: NewDeal): void {
  finishDeal(event.params.dealId.toHexString(), event.params.success, event.params.sender);
}

export function handleNewPendingDeal(event: NewPendingDeal): void {
  createDeal(event);
  pushPendingDeal(event.params.buyer.toHexString(), event.params.dealId.toHexString());
  let offer = Offer.load(event.params.offerId.toHexString());

  if (offer != null) {
    pushPendingDeal(offer.owner, event.params.dealId.toHexString());
  }
}

export function handleUpdateOffer(event: UpdateOffer): void {
  updateOffer(event);
}

export function handleCancelOffer(event: CancelOffer): void {
  cancelOffer(event);
}

export function handleVoteDeal(event: VoteDeal): void {
  updateVote(event);
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
  createUserIfNull(event.params.user .toHexString());
  let user = User.load(event.params.user.toHexString());

  user.offchainReputation = event.params.reputation;

  user.save();
}

export function handleDealLock(event: DealLock): void {
  createUserIfNull(event.params.user .toHexString());
  let user = User.load(event.params.user.toHexString());

  user.isDealLocked = event.params.isLocked;

  user.save();
}

export function handleNewCommission(event: NewCommission): void {
  let p2p = P2P.load(event.address.toHexString());

  if (p2p == null) {
    p2p = new P2P(event.address.toHexString());
  }

  p2p.commission = event.params.commission;

  p2p.save();
}

export function handleHandleDealReputation(event: HandleDealReputation): void {
  updateReputation(event);
}