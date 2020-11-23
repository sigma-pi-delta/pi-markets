import { Transfer, NewJson } from "../generated/templates/PNFTInterface/PNFTInterface";
import { BigDecimal, BigInt, Address, Bytes } from "@graphprotocol/graph-ts";
import { NewPNFToken } from "../generated/Controller/Controller";
import { Packable, PackableId } from "../generated/schema";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export function handleNewJson(event: NewJson): void {
    createPackableId(event);
}

export function createPackable(event: NewPNFToken): void {
    let packable = new Packable(event.params.newToken.toHexString());
    packable.token = event.params.newToken.toHexString();
    packable.tokenKind = event.params.category;
    packable.ids = [];
    packable.save();
}

function createPackableId(event: NewJson): void {
    let packable = Packable.load(event.address.toHexString());
    let packableId = event.params.tokenId.toHexString();
    let packableIdEntity = PackableId.load(packableId);

    if (packableIdEntity == null) {
        packableIdEntity = new PackableId(packableId);
    }

    packableIdEntity.packable = packable.id;
    packableIdEntity.tokenId = event.params.tokenId.toHexString();
    packableIdEntity.metadata = event.params.json;

    packableIdEntity.save();
}