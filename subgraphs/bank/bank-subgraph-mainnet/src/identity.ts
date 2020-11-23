import { BigInt } from "@graphprotocol/graph-ts"
import { Forward, FactoryForward, NewOwner, NewRecovery, NewName, NewWallet } from "../generated/templates/Identity/Identity"

import { 
    Identity
} from "../generated/schema"

import { loadWallet } from "./wallet"

export function handleForward(event: Forward): void {
    updateLastModification(event.address.toHexString(), event.block.timestamp);
}

export function handleFactoryForward(event: FactoryForward): void {
    updateLastModification(event.address.toHexString(), event.block.timestamp);
}

export function handleIdentityNewOwner(event: NewOwner): void {
    let identity = Identity.load(event.address.toHexString());

    if (identity !== null) {
        identity.owner = event.params.current;
        identity.save();
        updateLastModification(event.address.toHexString(), event.block.timestamp);
    }
}
  
export function handleIdentityNewRecovery(event: NewRecovery): void {
    let identity = Identity.load(event.address.toHexString());

    if (identity !== null) {
        identity.recovery = event.params.current;
        identity.save();
        updateLastModification(event.address.toHexString(), event.block.timestamp);
    }
}

export function handleIdentityNewWallet(event: NewWallet): void {
    let identity = Identity.load(event.address.toHexString());

    if (identity !== null) {
        let wallet = loadWallet(event.params.current, true);
        identity.wallet = wallet.id;
        identity.save();
        updateLastModification(event.address.toHexString(), event.block.timestamp);
    }
}
  
function updateLastModification(identityAddress: string, timestamp: BigInt): void {
    let identity = Identity.load(identityAddress);

    if (identity !== null) {
        identity.lastModification = timestamp;
        identity.save();
    }
}