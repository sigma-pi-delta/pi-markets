pragma solidity ^0.5.0;

import "../utils/Owned.sol";
import "../utils/safeMath.sol"; //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/safeMath.sol
import "../utils/fiat/IRC223.sol"; //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol
import "../utils/fiat/IERC20.sol"; //https://github.com/Dexaran/ERC223-token-standard/blob/master/token/ERC223/ERC223_interface.sol
import "../utils/fiat/ERC223_receiving_contract.sol";
import "../utils/fiat/IPIDEX.sol";

/// @author MIDLANTIC TECHNOLOGIES
/// @title Contract of the Token EURO

contract PiToken is 
    IRC223, 
    IERC20, 
    Owned
{
    using SafeMath for uint;

    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint public totalSupply;
    address public emisorAddress;

    mapping(address => uint) public balances;
    mapping(address => mapping (address => uint)) public approved;

    event Charge(address indexed charger, address indexed charged, uint value);

    constructor(
        string memory name, 
        string memory symbol, 
        address _owner,
        uint initialSupply
    ) 
        Owned(_owner) 
        public 
    {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
        totalSupply = initialSupply;
        balances[_owner] = totalSupply;
        emisorAddress = address(0x0000000000000000000000000000000000000010);
    }

    /// @dev Get the name
    /// @return _name name of the token
    function name() external view returns (string memory){
        return _name;
    }

    /// @dev Get the symbol
    /// @return _symbol symbol of the token
    function symbol() external view returns (string memory){
        return _symbol;
    }

    /// @dev Get the number of decimals
    /// @return _symbol number of decimals of the token
    function decimals() external view returns (uint8){
        return _decimals;
    }

    /// @dev Get balance of an account
    /// @param _user account to return the balance of
    /// @return balances[_user] balance of the account
    function balanceOf(address _user) public view returns (uint balance) {
        return balances[_user];
    }

    /// @dev Set an order of token in an exchange
    /// @param _value amount of token for the order
    /// @param receiving address of the token to buy (address(0) when buying PI)
    /// @param exchangeAddress address of the exchange to set the order
    function setDexOrder(
        uint _value, 
        address receiving, 
        uint price, 
        uint side, 
        address exchangeAddress
    ) 
        external 
        returns(bytes32)
    {
        require(balances[msg.sender] >= _value, "117");
        address _to = address(exchangeAddress);
        address payable _from = msg.sender;
        uint codeLength;
        bytes memory empty;
        bytes32 orderId;

        assembly {
            // Retrieve the size of the code on target address, this needs assembly .
            codeLength := extcodesize(_to)
        }

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        if(codeLength>0) {
            IPIDEX dex = IPIDEX(_to);
            orderId = dex.setTokenOrder(_from, _value, receiving, price, side);
        }
        emit Transfer(_from, _to, _value);
        emit Transfer(_from, _to, _value, empty);

        return orderId;
    }

    /// @dev Transfer token
    /// @param _to account receiving the token
    /// @param _value amount of token to send
    function transfer(address _to, uint _value) external {
        _transfer(_to, msg.sender,_value);
    }

    /// @dev Transfer token from another account
    /// @param _to address to send the token
    /// @param _from address to send token from
    function transferFrom (address _to, address payable _from) external {
        require(approved[_from][_to] > 0, "123");
        uint _value = approved[_from][_to];
        approved[_from][_to] = 0;
        _transfer(_to, _from, _value);
    }

    /// @dev Transfer certain amount of token from another account
    /// @param _to address to send the token
    /// @param _from address to send token from
    /// @param _value amount to transfer
    function transferFromValue (address _to, address payable _from, uint _value) external {
        require(approved[_from][_to] >= _value, "118");
        approved[_from][_to] = approved[_from][_to].sub(_value);
        _transfer(_to, _from, _value);
    }

    /// @dev Approve another account to send token from my account
    /// @param _to approved account
    /// @param _value approved amount
    function approve (address _to, uint _value) external {
        require(_value <= balances[msg.sender], "119");
        approved[msg.sender][_to] = approved[msg.sender][_to].add(_value);
    }

    /// @dev Disapprove a previous approval
    /// @param _spender spender account
    function disapprove (address _spender) external {
        approved[msg.sender][_spender] = 0;
    }
    
    function mint(address _to, uint _value) onlyOwner external {
        _mint(_to, _value);
    } 

    /// @dev Redeem an amount of token
    /// @param _value amount of token to redeem
    function burn(uint _value) onlyOwner external {
        bytes memory empty;
        totalSupply = totalSupply.sub(_value);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        emit Transfer(msg.sender, address(0), _value);
        emit Transfer(msg.sender, address(0), _value, empty);
    }

    function charge(address _to, uint _value) external {
        require(msg.sender == emisorAddress, "120");
        _transfer(_to, tx.origin, _value);
        emit Charge(_to, tx.origin, _value);
    }

    /// @dev Create more token
    /// @param _to account to send the created token
    /// @param _value amount of token to create
    function _mint(address _to, uint _value) internal {
        require(_to != address(0), "121");
        bytes memory empty;
        totalSupply = totalSupply.add(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(address(0), _to, _value);
        emit Transfer(address(0), _to, _value, empty);
    }

    /// @dev Transfer token
    /// @param _to account receiving the token
    /// @param _from account sending the token
    /// @param _value amount of token to send
    function _transfer(address _to, address payable _from, uint _value) internal {
        require(balances[_from] >= _value, "122");
        uint codeLength;
        bytes memory empty;

        assembly {
            // Retrieve the size of the code on target address, this needs assembly .
            codeLength := extcodesize(_to)
        }

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        if(codeLength>0) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            receiver.tokenFallback(_from, _value);
        }
        emit Transfer(_from, _to, _value);
        emit Transfer(_from, _to, _value, empty);
    }
}
