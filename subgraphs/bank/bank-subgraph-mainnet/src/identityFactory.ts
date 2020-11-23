import { Address } from "@graphprotocol/graph-ts"
import { DeployIdentity } from "../generated/IdentityFactory/IdentityFactory"
import { Identity, Wallet } from "../generated/schema"
import { Identity as IdentityTemplate } from "../generated/templates"
import { Wallet as WalletTemplate } from "../generated/templates"

import { loadWallet } from "./wallet"

export function handleDeployIdentity(event: DeployIdentity): void {
  let identityAddress = event.params.identity.toHexString();
  let identity = new Identity(identityAddress);
  loadWallet(event.params.wallet, true);
  let wallet = Wallet.load(event.params.wallet.toHexString());

  //initialize identity vars
  identity.dataHash = event.params.dataHash;
  identity.owner = event.params.owner;
  identity.recovery = event.params.recovery;
  identity.state = 10;
  identity.wallet = wallet.id;
  wallet.name = event.params.name;
  identity.lastModification = event.block.timestamp;
  identity.creationTime = event.block.timestamp;

  identity.save();
  wallet.save();

  IdentityTemplate.create(event.params.identity);
  WalletTemplate.create(event.params.wallet);
}
