import { CreateName } from "../generated/NameService/NameService";
import { Order, User, Deal } from "../generated/schema";

export function handleCreateName(event: CreateName): void {
    let user = createUserIfNull(event.params.wallet.toHexString());
    user.name = event.params.name;

    user.save();
}

export function createUserIfNull(userId: string): User {
    let user = User.load(userId);

    if (user == null) {
        user = new User(userId);
        user.orders = [];
        user.deals = [];

        user.save();
    }

    return user as User;
}


export function pushUserOrder(order: Order): void {
    let user = createUserIfNull(order.owner);

    let orders = user.orders;
    orders.push(order.id);
    user.orders = orders;

    user.save();
}

export function pushUserDeal(deal: Deal, userId: string): void {
    let user = createUserIfNull(userId);

    let deals = user.deals;
    deals.push(deal.id);
    user.deals = deals;

    user.save();
}