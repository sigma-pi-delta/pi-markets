import { Address, BigDecimal, Bytes, BigInt } from "@graphprotocol/graph-ts"
import { Transfer } from "../generated/templates/Token/Token"

import { 
    Transaction,
    Token,
    TokenBalance
} from "../generated/schema"

import { Token as TokenContract } from "../generated/templates/Token/Token"
import { Token as TokenTemplate } from "../generated/templates"
import { pushWalletTransaction } from "./wallet"
import { updateTokenBalance, createTokenBalance } from "./tokenBalance"
import { newTransaction } from "./transaction"
import { ERC721 as ERC721Template } from "../generated/templates"
import { PNFTInterface as PNFTInterfaceTemplate } from "../generated/templates"

const PI_ADDRESS = "0x0000000000000000000000000000000000000000";

export function handleTransfer(event: Transfer): void {
    //creo la entidad si no existe, aunque siempre existirá
    createToken(event.address, BigInt.fromI32(1), BigInt.fromI32(0));
    //actualizo los tokenBalance de ambas partes y si no existe lo crea
    updateTokenBalance(event.address, event.params.to.toHexString());
    updateTokenBalance(event.address, event.params.from.toHexString());
    //actualizo el array de holders del token
    addTokenHolder(event.address.toHexString(), event.params.to.toHexString());
    //creo la entidad Transaction
    newTransaction(event);
}

/***************************************************************/
// TOKEN
/***************************************************************/

export function createToken(tokenAddress: Address, tokenKind: BigInt, category: BigInt): void {
    let token = Token.load(tokenAddress.toHexString());
  
    if (token == null) {
        token = new Token(tokenAddress.toHexString());
  
        if (tokenAddress.toHexString() != PI_ADDRESS) {
            
            let contract = TokenContract.bind(tokenAddress);
        
            let symbol = contract.try_symbol();
            let name = contract.try_name();
            let supply = contract.try_totalSupply();

            if (!symbol.reverted) {
                token.tokenSymbol = symbol.value;
            } else {
                token.tokenSymbol = "";
            }

            if (!name.reverted) {
                token.tokenName = name.value;
            } else {
                token.tokenName = "";
            }

            if (tokenKind != BigInt.fromI32(2)) {
                let decimals = contract.try_decimals();
                if (!decimals.reverted) {
                    token.tokenDecimals = decimals.value;
                } else {
                    token.tokenDecimals = 0;
                }
            } else {
                token.tokenDecimals = 0;
            }

            if (!supply.reverted) {
                token.totalSupply = supply.value;
            } else {
                token.totalSupply = BigInt.fromI32(0);
            }

            if ((!symbol.reverted) && (!name.reverted)) {
                token.updated = true;
            } else {
                token.updated = false;
            }

            token.holders = [];

        } else {
            token.tokenSymbol = "PI";
            token.tokenName = "PI";
            token.tokenDecimals = 18;
            token.totalSupply = BigInt.fromI32(0);
            token.holders = [];
            token.updated = true;
        }

        token.tokenKind = tokenKind;

        if (tokenKind == BigInt.fromI32(1)) {
            token.assetCategory = category;
            TokenTemplate.create(tokenAddress);
        } else if (tokenKind == BigInt.fromI32(2)) {
            token.nftCategory = category;    
            ERC721Template.create(tokenAddress);
        } else if (tokenKind == BigInt.fromI32(3)) {
            token.pnftCategory = category;
            PNFTInterfaceTemplate.create(tokenAddress);
        }
    }
  
    token.save();
}

export function addTokenHolder(tokenAddress: string, holder: string): void {
    let token = Token.load(tokenAddress);

    if (token !== null) { //Si el token no existe no hago nada
        let id = tokenAddress.concat('-').concat(holder);
        let tokenBalance = TokenBalance.load(id);

        if (tokenBalance == null) {
            createTokenBalance(Address.fromString(tokenAddress), holder);
        }

        let currentHolders = token.holders;

        //Si el holder no está en el array ya, lo incluyo
        if (!currentHolders.includes(id)) {
            currentHolders.push(id);
            token.holders = currentHolders;
            token.save();
        }
    }
}

export function handleTokenMint(id: string, amount: BigInt): void {
    let token = Token.load(id);

    if (token !== null) {
        token.totalSupply = token.totalSupply.plus(amount);
        token.save();
    }
}
  
export function handleTokenBurn(id: string, amount: BigInt): void {
    let token = Token.load(id);

    if (token !== null) {
        token.totalSupply = token.totalSupply.minus(amount);
        token.save();
    }
}