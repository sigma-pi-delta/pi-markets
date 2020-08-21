pragma solidity 0.5.0;

import "./PIBController.sol";
import "./PIBIdentityDiamond/PIBIdentityFacet.sol";

/// @title Name Service of PI Decentralized Bank 
/// @author Sigma Pi Delta Technologies S.L.
/// @notice Name translation to Address and viceversa
/// @dev Bidirectional mapping name:wallet

contract PIBNameService {
    address public owner;
    PIBController public controller;
    
    mapping(address => string) public names;
    mapping(bytes32 => address) public addresses;
    mapping(bytes32 => address) public nameOwners;
    mapping(bytes32 => bool) public isForbidden;
    
    event CreateName(string name, address indexed wallet, address indexed owner);
    event ChangeWallet(string name, address indexed wallet);
    event ChangeOwner(string name, address indexed newOwner);
    
    constructor(address _controllerAddress) public {
        controller = PIBController(_controllerAddress);
    }
    
    /***************************************************************/
    // OWNER FUNCTIONS
    /***************************************************************/

    function forbidName(string memory _name, bool _is) public {
        require(msg.sender == controller.owner(), "143");
        bytes32 _nameHash = keccak256(abi.encodePacked(_name));
        isForbidden[_nameHash] = _is;
    }
    
    /***************************************************************/
    // VIEW FUNCTIONS
    /***************************************************************/
    
    /// @notice Check if name is already reserved or not 
    /// @param _nameHash Hash of the name to check 
    /// @return True if available, false if not 
    function nameIsAvailable(bytes32 _nameHash) public view returns (bool) {
        return (addresses[_nameHash] == address(0) && (!isForbidden[_nameHash]));
    }

    function nameIsAvailable(string memory _name) public view returns (bool) {
        bytes32 _nameHash = keccak256(abi.encodePacked(_name));
        return nameIsAvailable(_nameHash);
    }
    
    /// @notice Check if sender is owner of the name 
    /// @param _nameHash Hash of the name to check 
    /// @return True if owner, false if not 
    function isNameOwner(bytes32 _nameHash) public view returns (bool) {
        return nameOwners[_nameHash] == msg.sender;
    }
    
    /// @notice Get name associated to an address 
    /// @param _addr Address to check 
    /// @return Name 
    function name(address _addr) external view returns (string memory) {
        return names[_addr];
    }
    
    /// @notice Get address associated to a name 
    /// @param _name Name to check 
    /// @return Address 
    function addr(string calldata _name) external view returns (address) {
        bytes32 _nameHash = keccak256(abi.encodePacked(_name));
        return addr(_nameHash);
    }
    
    /// @notice Get address associated to a name 
    /// @param _nameHash Name to check 
    /// @return Address 
    function addr(bytes32 _nameHash) public view returns (address) {
        return addresses[_nameHash];
    }
    
    /***************************************************************/
    // PUBLIC FUNCTIONS
    /***************************************************************/
    
    /// @notice Reserve a name and associate to an address and owner 
    /// @param _name Name to reserve 
    /// @param _wallet Address of the name 
    /// @param _owner Address of the name's owner 
    function createName(
        string calldata _name, 
        address payable _wallet, 
        address _owner
    ) 
        external 
    {
        require(msg.sender == controller.addresses(2), "024");
        
        bytes32 _nameHash = keccak256(abi.encodePacked(_name));
        require(nameIsAvailable(_nameHash), "025");
        
        _setName(_name, _wallet);
        _setAddr(_wallet, _nameHash);
        _setOwner(_nameHash, _owner);
        
        emit CreateName(_name, _wallet, _owner);
    }
    
    /// @notice Change address associated to a name 
    /// @dev Only owner can change it
    /// @param _name Name
    /// @param _wallet Address of the name 
    function changeWallet(string calldata _name, address payable _wallet) external {
        bytes32 _nameHash = keccak256(abi.encodePacked(_name));
        require(isNameOwner(_nameHash), "026");
        
        bytes(names[addr(_nameHash)]).length = 0;
        
        _setName(_name, _wallet);
        _setAddr(_wallet, _nameHash);
        
        emit ChangeWallet(_name, _wallet);
    }
    
    /// @notice Change name's owner 
    /// @param _name Name
    /// @param _newOwner Address of the new owner 
    function changeNameOwner(string calldata _name, address _newOwner) external {
        bytes32 _nameHash = keccak256(abi.encodePacked(_name));
        require(isNameOwner(_nameHash), "027");
        
        _setOwner(_nameHash, _newOwner);
        
        PIBIdentityFacet _identity = PIBIdentityFacet(address(uint160(_newOwner)));
        _identity.setName(_name);
        
        emit ChangeOwner(_name, _newOwner);
    }
    
    /***************************************************************/
    // INTERNAL FUNCTIONS
    /***************************************************************/
    
    /// @dev Assign a name to an address in names mapping
    /// @param _name Name of the address
    /// @param _addr Address to set
    function _setName(string memory _name, address _addr) internal {
        require(bytes(names[_addr]).length == 0, "028");
        names[_addr] = _name;
    }
    
    /// @dev Assign an address to a name in addresses mapping 
    /// @param _addr Address of the name
    /// @param _nameHash Hash of the name to set 
    function _setAddr(address _addr, bytes32 _nameHash) internal {
        require(_addr != address(0), "029");
        addresses[_nameHash] = _addr;
    }
    
    /// @dev Assign an owner to a Name in nameOwners mapping 
    /// @param _nameHash Hash of the name to set 
    /// @param _owner Address of the new owner 
    function _setOwner(bytes32 _nameHash, address _owner) internal {
        require(_owner != address(0), "030");
        nameOwners[_nameHash] = _owner;
    }
}