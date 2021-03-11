import { Address, BigInt, EthereumBlock } from '@graphprotocol/graph-ts';
import { Emisor, Price } from './../generated/schema';
import { PiComposition } from '../generated/PiComposition/PiComposition'

const EMISOR_ADDR = "0x0000000000000000000000000000000000000010";
const COMPOSITION_ADDR = "0x0000000000000000000000000000000000000011";
const COLLATERAL_ADDR = "0x0000000000000000000000000000000000000014";
const ONE_UTC_HOUR = 3600;

export function handleBlock(block: EthereumBlock): void {
    let emisor = Emisor.load(EMISOR_ADDR);

    if (emisor == null) {
        emisor = new Emisor(EMISOR_ADDR);
        emisor.lastPriceTimestamp = BigInt.fromI32(0);
        emisor.save();
    }

    if (emisor.lastPriceTimestamp.plus(BigInt.fromI32(ONE_UTC_HOUR)).lt(block.timestamp)) {
        let priceId = block.number.toString().concat("-").concat(block.timestamp.toString());
        let price = Price.load(priceId);

        if (price == null) {
            price = new Price(priceId);

            price.timestamp = block.timestamp;

            let contract = PiComposition.bind(Address.fromHexString(COMPOSITION_ADDR) as Address);
            let piSupply = contract.try_emisorTokenBalance(Address.fromHexString(EMISOR_ADDR) as Address);
            let collateral = contract.try_emisorTokenBalance(Address.fromHexString(COLLATERAL_ADDR) as Address);

            if ((!piSupply.reverted) && (!collateral.reverted)) {
                price.supply = piSupply.value;
                price.collateral = collateral.value;
                price.piPrice = collateral.value.toBigDecimal().div(piSupply.value.toBigDecimal());
                price.collateralPrice = piSupply.value.toBigDecimal().div(collateral.value.toBigDecimal());

                price.save();

                emisor.lastPriceTimestamp = block.timestamp;
                emisor.save();
            }
        }
    }
}