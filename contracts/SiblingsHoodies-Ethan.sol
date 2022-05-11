// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//   .d8888b.  d8b 888      888 d8b                   888               888                \\
//  d88P  Y88b Y8P 888      888 Y8P                   888               888                \\
//  Y88b.          888      888                       888               888                \\
//   "Y888b.   888 88888b.  888 888 88888b.   .d88b.  888       8888b.  88888b.  .d8888b   \\
//      "Y88b. 888 888 "88b 888 888 888 "88b d88P"88b 888          "88b 888 "88b 88K       \\
//        "888 888 888  888 888 888 888  888 888  888 888      .d888888 888  888 "Y8888b.  \\
//  Y88b  d88P 888 888 d88P 888 888 888  888 Y88b 888 888      888  888 888 d88P      X88  \\
//   "Y8888P"  888 88888P"  888 888 888  888  "Y88888 88888888 "Y888888 88888P"   88888P'  \\
//                                                888                                      \\
//                                           Y8b d88P                                      \\
//                                            "Y88P"                                       \\

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

/**
 * @dev Contract module that stores an address as an 'owner'
 * and addresses as 'admins'.
 *
 * Inheriting from `AdminPrivileges` will make the
 * {onlyAdmins} modifier available, which can be applied to
 * functions to restrict all wallets except for the stored
 * owner and admin addresses.
 */
contract AdminPrivileges {
    address public _owner;

    mapping(address => bool) public admins;

    constructor() {
        _owner = msg.sender;
    }

    /**
    * @dev Returns true if provided address has admin status
    * or is the contract owner.
    */
    function isAdmin(address _addr) public view returns (bool) {
        return _owner == _addr || admins[_addr];
    }

    /**
    * @dev Prevents a function from being called by anyone
    * but the contract owner or approved admins.
    */
    modifier onlyAdmins() {
        require(isAdmin(msg.sender), "AdminPrivileges: caller is not an admin");
        _;
    }

    /**
    * @dev Toggles admin status of provided addresses.
    */
    function toggleAdmins(address[] calldata accounts) external onlyAdmins {
        for (uint i; i < accounts.length; i++) {
            if (admins[accounts[i]]) {
                delete admins[accounts[i]];
            } else {
                admins[accounts[i]] = true;
            }
        }
    }
}

contract RoyaltiesConfig is AdminPrivileges {
    uint256 private _royaltyBps;
    address payable private _royaltyRecipient;
    bytes4 private constant _INTERFACE_ID_ROYALTIES_EIP2981 = 0x2a55205a;
    bytes4 private constant _INTERFACE_ID_ROYALTIES_RARIBLE = 0xb7799584;

    /**
     * @dev See {IERC165-supportsInterface}. Inherit this function
     * to your base contract to add 
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == _INTERFACE_ID_ROYALTIES_EIP2981 || interfaceId == _INTERFACE_ID_ROYALTIES_RARIBLE;
    }

    /**
    * @dev Set royalty details.
     */
    function updateRoyalties(address payable recipient, uint256 bps) external virtual onlyAdmins {
        _royaltyRecipient = recipient;
        _royaltyBps = bps;
    }

    // RARIBLE ROYALTIES FUNCTIONS //

    function getFeeRecipients(uint256) external virtual view returns (address payable[] memory recipients) {
        if (_royaltyRecipient != address(0)) {
            recipients = new address payable[](1);
            recipients[0] = _royaltyRecipient;
        }
        return recipients;
    }

    function getFeeBps(uint256) external virtual view returns (uint[] memory bps) {
        if (_royaltyRecipient != address(0)) {
            bps = new uint256[](1);
            bps[0] = _royaltyBps;
        }
        return bps;
    }

    // EIP2981 ROYALTY STANDARD FUNCTION //

    function royaltyInfo(uint256, uint256 value) external virtual view returns (address, uint256) {
        return (_royaltyRecipient, value*_royaltyBps/10000);
    }
}

/**
* @dev Allowlist contract module.
*/
contract Allowlist is AdminPrivileges {
    mapping(address => uint) public allowlist;

    /**
    * @dev Adds one to the number of allowlist places
    * that each provided address is entitled to.
    */
    function addToAllowlist(address[] calldata _addr) public onlyAdmins {
        for (uint i; i < _addr.length; i++) {
            allowlist[_addr[i]]++;
        }
    }

    /**
    * @dev Sets the number of allowlist places for
    * given addresses.
    */
    function setAllowlist(address[] calldata _addr, uint amount) public onlyAdmins {
        for (uint i; i < _addr.length; i++) {
            allowlist[_addr[i]] = amount;
        }
    }

    /**
    * @dev Removes all allowlist places for given
    * addresses - they will no longer be allowed.
    */
    function removeFromAllowList(address[] calldata _addr) public onlyAdmins {
        for (uint i; i < _addr.length; i++) {
            allowlist[_addr[i]] = 0;
        }
    }

    /**
    * @dev Add this modifier to a function to require
    * that the msg.sender is on the allowlist.
    */
    modifier requireAllowlist() {
        require(allowlist[msg.sender] > 0, "Allowlist: caller is not on the allowlist");
        _;
    }
}

contract AdminPause is AdminPrivileges {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool public paused;

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused || isAdmin(msg.sender), "AdminPausable: contract is paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused || isAdmin(msg.sender), "AdminPausable: contract is not paused");
        _;
    }

    /**
    * @dev Toggle paused state.
    */
    function togglePause() public onlyAdmins {
        paused = !paused;
        if (paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract SibHoodies is ERC1155, ERC1155Supply, AdminPrivileges, RoyaltiesConfig, Allowlist, AdminPause {
    // address public ASH = 0x64D91f12Ece7362F91A6f8E7940Cd55F05060b92;
    address public ASH = 0xBEDAcEf5AfC744B7343fcFa619AaF81962Bf82F2; // Rinkeby Test ERC20 Token
    address public payoutAddress; // Should be private at deployment!
    uint public PRICE = 1 * 10 ** 18; // 1 ASH
    uint public MAX_SUPPLY = 100;
    mapping(uint => string) private uris;
    mapping(address => bool) public mintClaimed;

    bool public tokenLocked;
    bool public tokenRedeemable;
    bool public saleActive;
    bool public alRequired;

    constructor() ERC1155("") {
        payoutAddress = msg.sender;
    }

    // PUBLIC FUNCTIONS //

    function mint() public whenNotPaused {
        require(saleActive, "Mint is not available now");
        require(totalSupply(1) < MAX_SUPPLY, "All tokens have been minted");
        require(!mintClaimed[msg.sender], "You have already minted");
        if (alRequired) {
            require(allowlist[msg.sender] > 0, "You must be on the allowlist to mint now");
        }

        require(IERC20(ASH).transferFrom(msg.sender, payoutAddress, PRICE), "Ash Payment failed - check if this contract is approved");
        mintClaimed[msg.sender] = true;
        _mint(msg.sender, 1, 1, "");
    }

    function redeem(uint amount) public whenNotPaused {
        require(tokenRedeemable, "Merch redemption is not available now");
        require(amount > 0, "Cannot redeem less than one");
        _burn(msg.sender, 1, amount);
        _mint(msg.sender, 2, amount, "");
    }

    // ADMIN FUNCTIONS //

    function airdrop(address[] calldata to, uint tokenId) public onlyAdmins {
        require(tokenId == 1 || tokenId == 2);
        for (uint i; i < to.length; i++) {
            _mint(to[i], tokenId, 1, "");
        }
    }

    function setSaleActive(bool active) public onlyAdmins {
        saleActive = active;
    }

    function setAlRequirement(bool required) public onlyAdmins {
        alRequired = required;
    }

    function setMaxSupply(uint supply) public onlyAdmins {
        MAX_SUPPLY = supply;
    }

    function setAshAddress(address _addr) public onlyAdmins {
        ASH = _addr;
    }

    function setPrice(uint price) public onlyAdmins {
        PRICE = price;
    }

    function setTokenRedeemable(bool redeemable) public onlyAdmins {
        tokenRedeemable = redeemable;
    }

    function setTokenLock(bool locked) public onlyAdmins {
        tokenLocked = locked;
    }

    function setURI(uint tokenId, string memory _uri) public onlyAdmins {
        uris[tokenId] = _uri;
    }

    // METADATA & MISC FUNCTIONS //

    function uri(uint256 tokenId) public view override returns (string memory) {
        return uris[tokenId];
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
        whenNotPaused
    {
        require(!tokenLocked || from == address(0), "This token may not be transferred now");

        for (uint i; i < ids.length; i++) {
            require(ids[i] == 1 || from == address(0), "This token may not be transferred");
        }

        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId) public view override(RoyaltiesConfig, ERC1155) returns (bool) {
        return RoyaltiesConfig.supportsInterface(interfaceId) || ERC1155.supportsInterface(interfaceId);
    }
}