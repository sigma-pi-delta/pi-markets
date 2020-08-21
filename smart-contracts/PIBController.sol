pragma solidity 0.5.0;

import "./PIBControllerDiamond.sol";

/// @title Contract to manage system addresses of PI Decentralized Bank 
/// @author Sigma Pi Delta Technologies S.L.
/// @notice This contract is mainly used to get system contracts addresses
/// @dev This contract is mainly used to get system contracts addresses

contract PIBController is PIBControllerDiamond {
    uint public commission; //Commission in % per tx 
    address public owner; //Owner of ALL system contracts
    address public switcher; //EOA to swithc off contracts
    address public backend; 
    bool public on; //State of this contract
    
    mapping(uint => address) public addresses; //kind:system_contract_address
    mapping(address => uint) public kinds; //system_contract_address:kind
    mapping(address => bool) public isFactory; //contract_address:True-IS_factory/False-IS_NOT_factory
    mapping(address => bool) public isToken; //contract_address:True-IS_token/False-IS_NOT_token
    mapping(address => bool) public isNFToken;
    mapping(address => bool) public isPNFToken;
    mapping(address => mapping(address => address)) public markets; //currencyA:currencyB:market_address
    
    modifier isOn {
        require(on, "003");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "004");
        _;
    }
    
    event NewOwner(address old, address current);
    event NewBackend(address old, address current);
    event NewSwitcher(address old, address current);
    event NewAddress(uint kind, address contractAddress, bool isFactory);
    event NewToken(address newToken, uint category, bool isToken);
    event NewNFToken(address newToken, uint category, bool isNFToken);
    event NewPNFToken(address newToken, uint category, bool isPNFToken);
    event NewMarket(address tokenA, address tokenB, address market);
    event NewCommission(uint newCommission);
    
    constructor(
        address payable _owner, 
        address _switcher, 
        address _backend,
        address[] memory _facets
    ) 
        PIBControllerDiamond(_facets) 
        public 
    {
        on = true;
        owner = _owner;
        switcher = _switcher;
        backend = _backend;
        diamondOwner = _switcher;
    }
    
    /// @notice Change contract owner 
    /// @dev Only callable by current owner 
    /// @param _new Address of the new owner 
    function setOwner(address _new) external isOn onlyOwner {
        owner = _new;
        
        emit NewOwner(msg.sender, _new);
    }

    function setBackend(address _new) external isOn onlyOwner {
        emit NewBackend(backend, _new);
        backend = _new;
    }
    
    /// @notice Set the address with switch priviledges
    /// @dev Only callable by current switcher 
    /// @param _newSwitcher Address of the new switcher account
    function setSwitcher(address _newSwitcher) external isOn onlyOwner {
        emit NewSwitcher(switcher, _newSwitcher);
        
        switcher = _newSwitcher;
    }
    
    /// @notice Switch ON/OFF the contract
    /// @dev Only callable by switcher
    function toggleSwitch() external {
        require(msg.sender == switcher, "001");
        on = !on;
    } 
    
    /// @notice Set address of a system contract 
    /// @dev Modifies both mappings (addresses and kinds)
    /// @param _kind Type/ID of the contract 
    /// @param _address Address of the contract
    function setNewAddress(
        uint _kind, 
        address _address, 
        bool _isFactory
    ) 
        external 
        isOn 
        onlyOwner 
    {
        addresses[_kind] = _address;
        kinds[_address] = _kind;
        
        if (_isFactory) {
            isFactory[_address] = true;
        }
        
        emit NewAddress(_kind, _address, _isFactory);
    }
    
    /// @notice Set address of a new official token 
    /// @param _tokenAddress Address of the token 
    function setNewToken(address _tokenAddress, uint _category, bool _is) external isOn onlyOwner {
        isToken[_tokenAddress] = _is;
        
        emit NewToken(_tokenAddress, _category, _is);
    }

    /// @notice Set address of a new official token 
    /// @param _tokenAddress Address of the token 
    function setNewNFToken(address _tokenAddress, uint _category, bool _is) external isOn onlyOwner {
        isNFToken[_tokenAddress] = _is;
        
        emit NewNFToken(_tokenAddress, _category, _is);
    }

    /// @notice Set address of a new official token 
    /// @param _tokenAddress Address of the token 
    function setNewPNFToken(address _tokenAddress, uint _category, bool _is) external isOn onlyOwner {
        isPNFToken[_tokenAddress] = _is;
        
        emit NewPNFToken(_tokenAddress, _category, _is);
    }
    
    /// @notice Set address of a new market
    /// @dev Set bidirectional mappings (token1:token2 and token2:token1)
    /// @param _token1 Address of the first currency token contract 
    /// @param _token2 Address of the second currency token contract 
    /// @param _market Address of the market contract 
    function setNewMarket(
        address _token1, 
        address _token2, 
        address _market
    ) 
        external 
        isOn 
        onlyOwner 
    {
        require((isToken[_token1]) && (isToken[_token2]), "002");
        markets[_token1][_token2] = _market;
        markets[_token2][_token1] = _market;
        
        emit NewMarket(_token1, _token2, _market);
    }
    
    /// @notice Set Commission per transaction (in %)
    /// @dev Used 18 decimals (for 1% use 1 ether (1e18)) 
    /// @param _newCommission Commission per tx 
    function setTxCommission(uint _newCommission) external isOn onlyOwner {
        commission = _newCommission;
        
        emit NewCommission(_newCommission);
    }
}