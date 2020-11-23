import { Address, BigDecimal, Bytes, BigInt } from "@graphprotocol/graph-ts"
import { Transfer } from "../generated/templates/Token/Token"

import { 
    Transaction, Wallet, Official, Token
} from "../generated/schema"

import { pushWalletTransaction, loadWallet } from "./wallet"
import { handleTokenMint, handleTokenBurn } from "./token";

export function newTransaction(event: Transfer): void {

    let fromWallet = Wallet.load(event.params.from.toHexString());

    if (fromWallet == null) {
        fromWallet = loadWallet(event.params.from, false);
    }

    if (!fromWallet.isBankUser) {
        let txId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
        let tx = Transaction.load(txId);

        if (tx == null) {
            let txId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
            tx = createTransaction(
                txId, 
                event.params.from, 
                event.params.to, 
                event.address.toHexString(), 
                event.params.value, 
                "",
                event.params.data, 
                event.block.timestamp, 
                event.transaction.gasUsed.times(event.transaction.gasPrice),
                false
            );
        }

        pushWalletTransaction(tx as Transaction, event.params.to.toHexString());
        pushWalletTransaction(tx as Transaction, event.params.from.toHexString());
    }

    if (event.params.from == Address.fromI32(0)) {
        handleTokenMint(event.address.toHexString(), event.params.value);
    }

    if (event.params.to == Address.fromI32(0)) {
        handleTokenBurn(event.address.toHexString(), event.params.value);
    }
}

export function createTransaction(
    txId: string,
    from: Address,
    to: Address,
    currency: string,
    amount: BigInt,
    packableId: string,
    data: Bytes,
    timestamp: BigInt,
    fee: BigInt,
    isBankTransaction: boolean
): 
    Transaction 
{
    let tx = new Transaction(txId);

    let fromWallet = loadWallet(from, false);
    let toWallet = loadWallet(to, false);

    tx.from = fromWallet.id;
    tx.to = toWallet.id;
    tx.currency = currency;
    tx.amount = amount;
    tx.packableId = packableId;
    tx.data = data;
    tx.timestamp = timestamp;
    tx.fee = fee;
    tx.isBankTransaction = isBankTransaction;

    let token = Token.load(currency);

    if (token.tokenKind == BigInt.fromI32(2)) {
        let commodityId = currency.concat("-").concat(amount.toString());
        tx.nftCategory = token.nftCategory;
        tx.nftDescription = commodityId;
    } else if (token.tokenKind == BigInt.fromI32(3)) {
        let id = currency.concat("-").concat(packableId);
        tx.pnftCategory = token.pnftCategory;
        tx.pnftDescription = id;
    }

    let officialFrom = Official.load(fromWallet.id);
    let officialTo = Official.load(toWallet.id);

    if (officialFrom != null) {
        tx.officialCategory = officialFrom.category;
        tx.officialDescription = officialFrom.id;
    } else if (officialTo != null) {
        tx.officialCategory = officialTo.category;
        tx.officialDescription = officialTo.id;
    } else {
        tx.officialCategory = BigInt.fromI32(0);
        tx.officialDescription = "";
    }

    tx.save();

    return tx as Transaction;
}