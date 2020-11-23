import { Transfer, ERC721, NewJson, FakeToken } from "../generated/templates/ERC721/ERC721";
import { Token, Commodity } from "../generated/schema";
import { BigDecimal, BigInt, Address } from "@graphprotocol/graph-ts";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export function handleTransfer(event: Transfer): void {

    if (event.params._to == Address.fromString(ZERO_ADDRESS)) {
        burnCommodity(event.address.toHexString(), event.params._tokenId);
    }

    if (event.params._from == Address.fromString(ZERO_ADDRESS)) {
        mintCommodity(event.address.toHexString(), event.params._tokenId);
    }
}

export function handleNewJson(event: NewJson): void {
    let token = Token.load(event.address.toHexString());
    let id = event.address.toHexString().concat("-").concat(event.params.tokenId.toString());

    let commodity = Commodity.load(id);

    if (commodity == null) {
        commodity = new Commodity(id);
    }

    commodity.token = token.id;
    commodity.tokenId = event.params.tokenId;

    let tokenNFT = ERC721.bind(event.address);
    let ref = tokenNFT.try_getRefById(event.params.tokenId);
    if (!ref.reverted) {
        commodity.reference = ref.value;
    } else {
        commodity.reference = "reverted";
    }

    commodity.isLive = true;
    commodity.isFake = false;
    commodity.isP2P = false;
    commodity.metadata = event.params.json;

    commodity.nftCategory = token.nftCategory;

    commodity.save();
}

export function pushP2P(tokenAddress: string, tokenId: BigInt): void {
    let id = tokenAddress.concat("-").concat(tokenId.toString());
    let commodity = Commodity.load(id);

    if (commodity == null) {
        commodity = new Commodity(id);
    }

    commodity.isP2P = true;

    commodity.save();
}

export function popP2P(tokenAddress: string, tokenId: BigInt): void {
    let token = Token.load(tokenAddress);
    let id = tokenAddress.concat("-").concat(tokenId.toString());
    let commodity = Commodity.load(id);

    if (commodity == null) {
        commodity = new Commodity(id);
    }

    commodity.isP2P = false;

    commodity.save();
}

function burnCommodity(tokenAddress: string, tokenId: BigInt): void {
    let id = tokenAddress.concat("-").concat(tokenId.toString());
    let commodity = Commodity.load(id);

    if (commodity != null) {
        commodity.isLive = false;
    }

    commodity.save();
}

export function mintCommodity(tokenAddress: string, tokenId: BigInt): void {
    let id = tokenAddress.concat("-").concat(tokenId.toString());
    let commodity = Commodity.load(id);

    if (commodity == null) {
        commodity = new Commodity(id);
    }

    commodity.isLive = true;

    commodity.save();
}


export function handleFakeToken(event: FakeToken): void {
    let id = event.address.toHexString().concat("-").concat(event.params.tokenId.toString());
    let commodity = Commodity.load(id);

    if (commodity != null) {
        commodity.isFake = true;
    }

    commodity.save();
}

export function getOneEther(): BigInt {
    let n = BigInt.fromI32(1);
    for(let i = 0; i < 18; i++) {
        n = n.times(BigInt.fromI32(10));
    }
    return n;
}