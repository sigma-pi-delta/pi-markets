import { Address, BigInt } from "@graphprotocol/graph-ts";
import { CancelOrder, Deal, NewCommission, SetOrder, UpdateOrder } from "../generated/DEX/DEX";
import { Order, Deal as DealEntity, Cancelation, Commission } from "../generated/schema";
import { pushUserDeal, pushUserOrder } from "./user";

export function handleSetOrder(event: SetOrder): void {
    let order = Order.load(event.params.id.toHexString());

    if (order == null) {
        order = new Order(event.params.id.toHexString());

        order.orderId = event.params.id.toHexString();
        order.owner = event.params.owner.toHexString();
        order.sellToken = event.params.selling.toHexString();
        order.buyToken = event.params.buying.toHexString();
        order.isPackable = false;
        let settings = event.params.settings;
        order.initialAmount = settings[0];
        order.amount = settings[0];
        order.price = settings[1];
        order.side = settings[2];
        order.open = true;
        order.cancelled = false;
        order.dealed = false;
        order.deals = [];
        order.timestamp = event.block.timestamp;
        order.blockNumber = event.block.number;

        order.save();

        pushUserOrder(order as Order);
    }
}

export function handleUpdateOrder(event: UpdateOrder): void {
    let order = Order.load(event.params.id.toHexString());

    if (order != null) {
        order.amount = event.params.amount;

        if (event.params.amount == BigInt.fromI32(0)) {
            order.open = false;
        }

        order.save();
    }
}

export function handleCancelOrder(event: CancelOrder): void {
    let order = Order.load(event.params.id.toHexString());

    if (order != null) {
        order.amount = event.params.amount;
        order.open = false;
        order.cancelled = true;

        order.save();

        let cancelation = Cancelation.load(order.id);

        if (cancelation == null) {
            cancelation = new Cancelation(order.id);
            cancelation.order = order.id;
            cancelation.timestamp = event.block.timestamp;
            cancelation.blockNumber = event.block.number;

            cancelation.save();
        }
    }
}

export function handleDeal(event: Deal): void {
    let dealId = event.transaction.hash.toHexString().concat(event.transactionLogIndex.toString());
    let deal = DealEntity.load(dealId);

    if (deal == null) {
        deal = new DealEntity(dealId);

        let orderA = Order.load(event.params.orderA.toHexString());
        let orderB = Order.load(event.params.orderB.toHexString());

        deal.dealId = dealId;
        deal.orderA = orderA.id;
        deal.orderB = orderB.id;
        deal.tokenA = orderA.sellToken;
        deal.tokenB = orderB.sellToken;
        deal.amountA = event.params.amountA;
        deal.amountB = event.params.amountB;
        deal.side = event.params.side;
        deal.price = orderB.price;
        deal.timestamp = event.block.timestamp;
        deal.blockNumber = event.block.number;

        deal.save();

        orderA.dealed = true;
        orderB.dealed = true;

        let dealsA = orderA.deals;
        dealsA.push(deal.id);
        orderA.deals = dealsA;

        let dealsB = orderB.deals;
        dealsB.push(deal.id);
        orderB.deals = dealsB;

        orderA.save();
        orderB.save();

        pushUserDeal(deal as DealEntity, orderA.owner);
        pushUserDeal(deal as DealEntity, orderB.owner);
    }
}

export function handleNewCommission(event: NewCommission): void {
    let commission = Commission.load(Address.fromI32(0).toHexString());

    if (commission == null) {
        commission = new Commission(Address.fromI32(0).toHexString());
        commission.dexPackable = BigInt.fromI32(0);
    }

    commission.dex = event.params.newCommission;

    commission.save();
}