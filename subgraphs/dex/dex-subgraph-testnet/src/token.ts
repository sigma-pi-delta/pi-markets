import { Address, BigInt } from "@graphprotocol/graph-ts"

import { 
    Token
} from "../generated/schema"

import { Token as TokenContract, Transfer } from "../generated/templates/Token/Token"
import { Token as TokenTemplate } from "../generated/templates"

const PI_ADDRESS = "0x0000000000000000000000000000000000000000";

export function createToken(tokenAddress: Address): void {
    let token = Token.load(tokenAddress.toHexString());
  
    if (token == null) {
        token = new Token(tokenAddress.toHexString());
  
        if (tokenAddress.toHexString() != PI_ADDRESS) {
            
            let contract = TokenContract.bind(tokenAddress);
        
            let symbol = contract.try_symbol();
            let name = contract.try_name();

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

            if ((!symbol.reverted) && (!name.reverted)) {
                token.updated = true;
            } else {
                token.updated = false;
            }

        } else {
            token.tokenSymbol = "PI";
            token.tokenName = "PI";
            token.updated = true;
        }
    }
  
    token.save();
}

export function handleTransfer(event: Transfer): void {
    
}