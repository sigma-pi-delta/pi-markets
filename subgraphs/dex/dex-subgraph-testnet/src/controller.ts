import {
  NewToken,
  NewPNFToken
} from "../generated/Controller/Controller"
import { createPackable } from "./packable";
import { createToken } from "./token";
import { PNFTInterface as PNFTInterfaceTemplate } from "../generated/templates"

export function handleNewToken(event: NewToken): void {
  createToken(event.params.newToken);
}

export function handleNewPNFToken(event: NewPNFToken): void {
  createToken(event.params.newToken);
  PNFTInterfaceTemplate.create(event.params.newToken);
  createPackable(event);
}