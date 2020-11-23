import { BigInt, BigDecimal, Address } from "@graphprotocol/graph-ts"
import {
  Controller as ControllerContract,
  NewToken,
  NewNFToken,
  NewPNFToken
} from "../generated/Controller/Controller"
import { createToken } from "./token";
import { createPackable } from "./packable";

export function handleNewToken(event: NewToken): void {
  createToken(event.params.newToken, BigInt.fromI32(1), event.params.category);
}

export function handleNewNFToken(event: NewNFToken): void {
  createToken(event.params.newToken, BigInt.fromI32(2), event.params.category);
}

export function handleNewPNFToken(event: NewPNFToken): void {
  createToken(event.params.newToken, BigInt.fromI32(3), event.params.category);
  createPackable(event);
}
