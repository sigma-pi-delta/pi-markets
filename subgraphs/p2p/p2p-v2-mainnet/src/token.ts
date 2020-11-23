import { Address, BigDecimal, Bytes, BigInt } from "@graphprotocol/graph-ts"

import { 
    Token
} from "../generated/schema"

import { Token as TokenContract } from "../generated/templates/Token/Token"
import { ERC721 as ERC721Template } from "../generated/templates"
import { PNFTInterface as PNFTInterfaceTemplate } from "../generated/templates"

const PI_ADDRESS = "0x0000000000000000000000000000000000000000";

export function createToken(tokenAddress: Address, tokenKind: BigInt, category: BigInt): void {
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

        } else {
            token.tokenSymbol = "PI";
            token.tokenName = "PI";
        }

        token.tokenKind = tokenKind;

        if (tokenKind == BigInt.fromI32(1)) {
            token.assetCategory = category;
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
