import { Transfer, ERC721, NewJson, FakeToken } from "../generated/templates/ERC721/ERC721";
import { Token, Commodity, Wallet, Transaction } from "../generated/schema";
import { BigDecimal, BigInt, Address, Bytes } from "@graphprotocol/graph-ts";
import { pushCommodity, popCommodity, getOneEther } from "./tokenBalance";
import { addTokenHolder } from "./token";
import { loadWallet, pushWalletTransaction } from "./wallet";
import { createTransaction } from "./transaction";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export function handleTransfer(event: Transfer): void {

    let commodityId = event.address.toHexString().concat("-").concat(event.params._tokenId.toString());

    if (event.params._from == Address.fromString(ZERO_ADDRESS)) {
        mintCommodity(event.address.toHexString(), event.params._tokenId);
    } else {
        popCommodity(commodityId, event.address, event.params._from.toHexString());
    }

    if (event.params._to == Address.fromString(ZERO_ADDRESS)) {
        burnCommodity(event.address.toHexString(), event.params._tokenId);
    } else {
        pushCommodity(commodityId, event.address, event.params._to.toHexString());
        addTokenHolder(event.address.toHexString(), event.params._to.toHexString());
    }

    updateOwner(event.address.toHexString(), event.params._tokenId, event.params._from, event.params._to);
    newTransaction(event);
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
    commodity.metadata = event.params.json;

    commodity.nftCategory = token.nftCategory;

    commodity.save();
}

function updateOwner(tokenAddress: string, tokenId: BigInt, from: Address, to: Address): void {
    let token = Token.load(tokenAddress);
    let id = tokenAddress.concat("-").concat(tokenId.toString());
    let commodity = Commodity.load(id);

    if (commodity != null) {
        commodity.owner = to.toHexString();
    }

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

function newTransaction(event: Transfer): void {

    let fromWallet = Wallet.load(event.params._from.toHexString());

    if (fromWallet == null) {
        fromWallet = loadWallet(event.params._from, false);
    }

    if (!fromWallet.isBankUser) {
        let txId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
        let tx = Transaction.load(txId);

        if (tx == null) {
            let txId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
            tx = createTransaction(
                txId, 
                event.params._from, 
                event.params._to, 
                event.address.toHexString(), 
                event.params._tokenId,
                "",
                new Bytes(0), 
                event.block.timestamp, 
                event.transaction.gasUsed.times(event.transaction.gasPrice),
                false
            );
        }

        pushWalletTransaction(tx as Transaction, event.params._to.toHexString());
        pushWalletTransaction(tx as Transaction, event.params._from.toHexString());
    }
}

export function handleFakeToken(event: FakeToken): void {
    let id = event.address.toHexString().concat("-").concat(event.params.tokenId.toString());
    let commodity = Commodity.load(id);

    if (commodity != null) {
        commodity.isFake = true;
    }

    commodity.save();
}