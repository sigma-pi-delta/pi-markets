pragma solidity 0.5.0;

import "./safeMath.sol";
import "./PIBController.sol";
import "./PIBMarketPT.sol";

contract PIBWalletMath {
    using SafeMath for uint;
    
    PIBController public controller;
    
    constructor(address _controllerAddress) public {
        controller = PIBController(_controllerAddress);
    }
    
    //Si tengo _sendingAmount cantidad de _sendingToken qué cantidad _transferAmount de _transferingToken se recibirá
    function getTransferExchangeInfoSending(
        address _sendingToken, 
        address _transferingToken, 
        uint _sendingAmount
    ) 
        external 
        view 
        returns(uint) 
    {
        (uint _exchangeAmount,) = getExchangeInfoSending(_sendingToken, _transferingToken, _sendingAmount);
        uint _transferAmount = getValueToSpend(_exchangeAmount);
        
        return _transferAmount;
    }
    
    //Si quiero que se reciban _receivingAmount de _transferingToken tengo que tener _sendingAmount de _sendingToken
    function getTransferExchangeInfoReceiving(
        address _sendingToken, 
        address _transferingToken, 
        uint _receivingAmount
    ) 
        external 
        view 
        returns(uint) 
    {
        uint _exchangeAmount = getSpendToValue(_receivingAmount);
        (uint _sendingAmount,) = getExchangeInfoReceiving(_sendingToken, _transferingToken, _exchangeAmount);
        return _sendingAmount;
    }
    
    //cantidad efectiva que se recibe en un intercambio
    function getExchangeInfoSending(
        address _sendingToken, 
        address _receivingToken, 
        uint _sendingAmount
    ) 
        public 
        view 
        returns(uint, uint) 
    {
        address payable _marketAddress = address(
            uint160(
                controller.markets(
                    _sendingToken, 
                    _receivingToken
                )
            )
        );
        PIBMarketPT _market = PIBMarketPT(_marketAddress);
        return _market.getExchangeInfoSending(_sendingToken, _sendingAmount);
    }
    
    //cantidad a gastar para que del intercambio reciba _receivingAmount
    function getExchangeInfoReceiving(
        address _sendingToken, 
        address _receivingToken, 
        uint _receivingAmount
    ) 
        public 
        view 
        returns(uint, uint) 
    {
        address payable _marketAddress = address(
            uint160(
                controller.markets(
                    _sendingToken, 
                    _receivingToken
                )
            )
        );
        PIBMarketPT _market = PIBMarketPT(_marketAddress);
        return _market.getExchangeInfoReceiving(_sendingToken, _receivingAmount);
    }
    
    //value para un gasto total de:
    function getValueToSpend(uint _totalAmount) public view returns (uint) {
        uint _aux = 100 ether;
        _aux = controller.commission().mul(1 ether).div(_aux);
        _aux = _aux.add(1 ether);
        
        return _totalAmount.mul(1 ether).div(_aux);
    }
    
    //gasto total para hacer una transfer de value:
    function getSpendToValue(uint _transferValue) public view returns (uint) {
        uint _aux = 1 ether;
        return _transferValue.mul(_aux.add(controller.commission().div(100))).div(_aux);
    }
}