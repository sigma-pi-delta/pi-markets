pragma solidity 0.5.0;

import "../PIBController.sol";
import "../PIBWalletDiamond/PIBWalletStorage.sol";
import "../tools/PIBPayCommission.sol";

contract PIBP2PReputation {
    PIBController public controller;

    mapping(address => uint) public offchainReputation;

    event UpdateReputation(address user, uint reputation);

    constructor(address _controllerAddress) public {
        controller = PIBController(_controllerAddress);
    }

    function updateReputation(address _user, uint _reputation) external {
        require(msg.sender == controller.addresses(8));
        offchainReputation[_user] = _reputation;

        emit UpdateReputation(_user, _reputation);

        PIBWalletStorage _wallet = PIBWalletStorage(_user);
        address _identity = _wallet.owner();
        PIBPayCommission _pay = PIBPayCommission(address(uint160(controller.addresses(17))));
        if (_pay.isAllowed(address(uint160(_identity)))) {
            _pay.setNewUser(address(uint160(_identity)));
        }
    }
}