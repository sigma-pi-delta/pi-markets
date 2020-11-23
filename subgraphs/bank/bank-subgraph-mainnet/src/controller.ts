import { BigInt } from "@graphprotocol/graph-ts"
import { NewToken, NewNFToken, NewAddress, NewMarket, NewPNFToken } from "../generated/Controller/Controller";

import { createToken } from "./token"
import { Official, Token } from "../generated/schema";
import { createPackable } from "./packable";
import { createOfficialName } from "./nameService";

export function handleTokenCreated(event: NewToken): void {
    createToken(event.params.newToken, BigInt.fromI32(1), event.params.category);
}

export function handleNewNFToken(event: NewNFToken): void {
    createToken(event.params.newToken, BigInt.fromI32(2), event.params.category);
}

export function handleNewPNFToken(event: NewPNFToken): void {
    createToken(event.params.newToken, BigInt.fromI32(3), event.params.category);
    createPackable(event);
}

export function handleNewAddress(event: NewAddress): void {
    let official = Official.load(event.params.contractAddress.toHexString());
    
    if (official == null) {
        official = new Official(event.params.contractAddress.toHexString());
    }

    if (event.params.kind == BigInt.fromI32(1)) {
        official.category = event.params.kind;
        official.description = "REGISTRY";
        createOfficialName(event.params.contractAddress, "Registro PiMarkets");
    } else if (event.params.kind == BigInt.fromI32(2)) {
        official.category = event.params.kind;
        official.description = "IDENTITY-FACTORY";
    } else if (event.params.kind == BigInt.fromI32(3)) {
        official.category = event.params.kind;
        official.description = "WALLET-FACTORY";
    } else if (event.params.kind == BigInt.fromI32(4)) {
        official.category = event.params.kind;
        official.description = "STATE-CHECKER";
    } else if (event.params.kind == BigInt.fromI32(5)) {
        official.category = event.params.kind;
        official.description = "WALLET-MATH";
    } else if (event.params.kind == BigInt.fromI32(6)) {
        official.category = event.params.kind;
        official.description = "NAME-SERVICE";
    } else if (event.params.kind == BigInt.fromI32(7)) {
        official.category = event.params.kind;
        official.description = "COMMISSIONS";
    } else if (event.params.kind == BigInt.fromI32(8)) {
        official.category = event.params.kind;
        official.description = "DAY-MANAGER";
    } else if (event.params.kind == BigInt.fromI32(9)) {
        official.category = event.params.kind;
        official.description = "P2P";
        createOfficialName(event.params.contractAddress, "Mercado P2P (Secundario)");
    } else if (event.params.kind == BigInt.fromI32(10)) {
        official.category = event.params.kind;
        official.description = "P2P-COLLECTABLE";
        createOfficialName(event.params.contractAddress, "Mercado P2P (Secundario)");
    } else if (event.params.kind == BigInt.fromI32(11)) {
        official.category = event.params.kind;
        official.description = "P2P-PRIMARY";
        createOfficialName(event.params.contractAddress, "Mercado P2P (Primario)");
    } else if (event.params.kind == BigInt.fromI32(12)) {
        official.category = event.params.kind;
        official.description = "P2P-COLLECTABLE-PRIMARY";
        createOfficialName(event.params.contractAddress, "Mercado P2P (Primario)");
    } else if (event.params.kind == BigInt.fromI32(13)) {
        official.category = event.params.kind;
        official.description = "P2P-PACKABLE";
        createOfficialName(event.params.contractAddress, "Mercado P2P (Secundario)");
    } else if (event.params.kind == BigInt.fromI32(14)) {
        official.category = event.params.kind;
        official.description = "P2P-PACKABLE-PRIMARY";
        createOfficialName(event.params.contractAddress, "Mercado P2P (Primario)");
    } else if (event.params.kind == BigInt.fromI32(0)) {
        official.category = event.params.kind;
        official.description = "ZERO-ADDRESS";
        createOfficialName(event.params.contractAddress, "PiMarkets (Emisión oficial)");
    } else {
        official.category = event.params.kind;
        official.description = "Other";
    }

    official.save();
}

export function handleNewMarket(event: NewMarket): void {
    let official = Official.load(event.params.market.toHexString());
    
    if (official == null) {
        official = new Official(event.params.market.toHexString());
    }

    official.category = BigInt.fromI32(10);
    let market = "Market";
    let tokenA = Token.load(event.params.tokenA.toHexString());
    let tokenB = Token.load(event.params.tokenB.toHexString());

    if ((tokenA != null) && (tokenB != null)) {
        official.description = market.concat(tokenA.tokenSymbol).concat("-").concat(tokenB.tokenSymbol);
    } else {
        official.description = market.concat(event.params.tokenA.toHexString()).concat("-").concat(event.params.tokenB.toHexString());
    }
    
    official.save();
}