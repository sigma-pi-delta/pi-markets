import { Transfer, NewJson } from "../generated/templates/PNFTInterface/PNFTInterface";
import { BigDecimal, BigInt, Address, Bytes } from "@graphprotocol/graph-ts";
import { Token, PackableId, Packable, Wallet, Transaction } from "../generated/schema";
import { NewPNFToken } from "../generated/Controller/Controller";
import { updatePackableTokenBalance } from "./tokenBalance";
import { loadWallet, pushWalletTransaction } from "./wallet";
import { createTransaction } from "./transaction";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export function handleTransfer(event: Transfer): void {

    if (event.params._from != Address.fromHexString(ZERO_ADDRESS)) {
        updatePackableTokenBalance(event.params._from.toHexString(), event.address.toHexString(), event.params._tokenId.toHexString())
    }

    if (event.params._to != Address.fromHexString(ZERO_ADDRESS)) {
        updatePackableTokenBalance(event.params._to.toHexString(), event.address.toHexString(), event.params._tokenId.toHexString())
    }

    newPackableTransaction(event);
}

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
    let packableId = event.address.toHexString().concat("-").concat(event.params.tokenId.toHexString());
    let packableIdEntity = PackableId.load(packableId);

    if (packableIdEntity == null) {
        packableIdEntity = new PackableId(packableId);
    }

    packableIdEntity.packable = packable.id;
    packableIdEntity.tokenId = event.params.tokenId.toHexString();
    packableIdEntity.metadata = event.params.json;

    packableIdEntity.save();

    pushPackableId(event.address.toHexString(), packableId);
}

function pushPackableId(tokenAddress: string, packableId: string): void {
    let packable = Packable.load(tokenAddress);
    let ids = packable.ids;

    if (!ids.includes(packableId)) {
        ids.push(packableId);
        packable.ids = ids;
        packable.save();
    }
}

function newPackableTransaction(event: Transfer): void {

    let fromWallet = Wallet.load(event.params._from.toHexString());

    if (fromWallet == null) {
        fromWallet = loadWallet(event.params._from, false);
    }

    if (!fromWallet.isBankUser) {
        let txId = event.transaction.hash.toHex() + "-" + event.logIndex.toHexString();
        let tx = Transaction.load(txId);

        if (tx == null) {
            let txId = event.transaction.hash.toHex() + "-" + event.logIndex.toHexString();
            tx = createTransaction(
                txId, 
                event.params._from, 
                event.params._to, 
                event.address.toHexString(), 
                event.params._amount,
                event.params._tokenId.toHexString(),
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
