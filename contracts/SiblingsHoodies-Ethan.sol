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

// contract ALSalePeriod is AdminPrivileges {
//     uint public alSaleLength;
//     uint private saleTimestamp;

//     constructor(uint _alSaleHours) {
//         setALSaleLengthInHours(_alSaleHours);
//     }

//     /**
//     * @dev Begins allowlist sale period. Public sale period
//     * automatically begins after allowlist sale period
//     * concludes.
//     */
//     function beginALSale() public onlyAdmins {
//         saleTimestamp = block.timestamp;
//     }

//     /**
//     * @dev Updates allowlist sale period length.
//     */
//     function setALSaleLengthInHours(uint length) public onlyAdmins {
//         alSaleLength = length * 3600;
//     }

//     /**
//     * @dev Returns whether the allowlist sale phase is
//     * currently active.
//      */
//     function isAllowlistSaleActive() public view returns (bool) {
//         return saleTimestamp != 0 && block.timestamp < saleTimestamp + alSaleLength;
//     }

//     /**
//     * @dev Returns whether the public sale phase is currently
//     * active.
//      */
//     function isPublicSaleActive() public view returns (bool) {
//         return block.timestamp > saleTimestamp + alSaleLength;
//     }

//     /**
//     * @dev Restricts functions from being called except for during
//     * the allowlist sale period.
//     */
//     modifier onlyDuringALPeriod() {
//         require(
//             saleTimestamp != 0 && block.timestamp < saleTimestamp + alSaleLength,
//             "ALSalePeriod: This function may only be run during the allowlist sale period."
//         );
//         _;
//     }

//     /**
//     * @dev Restricts a function from being called except after the
//     * allowlist sale period has ended.
//     */
//     modifier onlyDuringPublicSale() {
//         require(
//             saleTimestamp != 0 && block.timestamp >= saleTimestamp + alSaleLength,
//             "ALSalePeriod: This function may only be run after the allowlist sale period is over."
//         );
//         _;
//     }
// }

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract SibHoodies is ERC1155, AdminPrivileges, RoyaltiesConfig, Allowlist, AdminPause {
    // ASH_ADDRESS SHOULD BE CONSTANT ON DEPLOYMENT
    // address public ASH_ADDRESS = 0x64D91f12Ece7362F91A6f8E7940Cd55F05060b92;
    address public ASH_ADDRESS = 0xBEDAcEf5AfC744B7343fcFa619AaF81962Bf82F2; // Rinkeby Test ERC20 Token
    address public payoutAddress; // Should be private at deployment!
    uint256 public ASH_PRICE = 15 * 10 ** 18; // 1 ASH
    uint256 public ASH_PRICE_AL = 5 * 10 ** 18; // 1 ASH
    uint256 public ETH_PRICE = 0.03 ether;
    uint256 public ETH_PRICE_AL = 0.01 ether;
    uint256 public totalMints;
    uint8 constant public MAX_SUPPLY = 100;

    mapping(uint256 => string) private uris;
    mapping(address => uint8) public mintClaimed;

    bool public tokenRedeemable = true;
    bool public alRequired = true;
    bool public tokenLocked;
    bool public saleActive;

    constructor() ERC1155("") {
        payoutAddress = msg.sender;
    }

    // PUBLIC FUNCTIONS //

    function mint(bool ashPayment) public payable whenNotPaused {
        require(saleActive, "Mint is not available now");
        require(totalMints < MAX_SUPPLY, "All tokens have been minted");
        require(mintClaimed[msg.sender] == 0, "You have already minted");

        uint256 eth_price = ETH_PRICE;
        uint256 ash_price = ASH_PRICE;

        if (alRequired) {
            require(allowlist[msg.sender] > 0, "You must be on the allowlist to mint now");
            eth_price = ETH_PRICE_AL;
            ash_price = ASH_PRICE_AL;
        }

        if (ashPayment) {
            require(
                IERC20(ASH_ADDRESS).transferFrom(msg.sender, payoutAddress, ash_price),
                "Ash Payment failed - check if this contract is approved"
            );
        } else {
            require(msg.value == eth_price, "Incorrect amount of Ether sent");
        }

        mintClaimed[msg.sender]++;
        _mint(msg.sender, 1, 1, "");
    }

    // function publicMint(bool ashPayment) public payable whenNotPaused onlyDuringPublicSale {
    //     if (ashPayment) {
    //         require(
    //             IERC20(ASH_ADDRESS).transferFrom(msg.sender, payoutAddress, ASH_PRICE),
    //             "Ash Payment failed - check if this contract is approved"
    //         );
    //     } else {
    //         require(msg.value == ETH_PRICE, "Incorrect amount of Ether sent");
    //     }
    //     mint();
    // }

    // function allowlistMint(bool ashPayment) public payable whenNotPaused requireAllowlist onlyDuringALPeriod {
    //     if (ashPayment) {
    //         require(
    //             IERC20(ASH_ADDRESS).transferFrom(msg.sender, payoutAddress, ASH_PRICE_AL),
    //             "Ash Payment failed - check if this contract is approved"
    //         );
    //     } else {
    //         require(msg.value == ETH_PRICE_AL, "Incorrect amount of Ether sent");
    //     }
    //     mint();
    // }

    // function mint() internal {
    //     require(saleActive, "Mint is not available now");
    //     require(totalMints < MAX_SUPPLY, "All tokens have been minted");
    //     require(mintClaimed[msg.sender] == 0, "You have already minted");

    //     mintClaimed[msg.sender]++;
    //     _mint(msg.sender, 1, 1, "");
    // }

    function redeem(uint256 amount) public whenNotPaused {
        require(tokenRedeemable, "Merch redemption is not available now");
        require(amount > 0, "Cannot redeem less than one");
        _burn(msg.sender, 1, amount);
        _mint(msg.sender, 2, amount, "");
    }

    function isTokenLocked(uint8 tokenId) public view returns (bool) {
        return tokenId == 1 && !tokenLocked ? false : true;
    }

    // ADMIN FUNCTIONS //

    function airdrop(address[] calldata to, uint8 tokenId) public onlyAdmins {
        require(tokenId == 1 || tokenId == 2);
        for (uint256 i; i < to.length; i++) {
            _mint(to[i], tokenId, 1, "");
        }
    }

    // THIS FUNCTION IS FOR TESTING PURPOSES AND SHOULD BE REMOVED ON DEPLOYMENT
    function setAshAddress(address _addr) public onlyAdmins {
        ASH_ADDRESS = _addr;
    }

    function setPrices(uint256[4] calldata prices) public onlyAdmins {
        ASH_PRICE = prices[0];
        ASH_PRICE_AL = prices[1];
        ETH_PRICE = prices[2];
        ETH_PRICE_AL = prices[3];
    }

    function setPayoutAddress(address _addr) public onlyAdmins {
        payoutAddress = _addr;
    }

    function setSaleActive(bool active) public onlyAdmins {
        saleActive = active;
    }

    function setAlRequirement(bool required) public onlyAdmins {
        alRequired = required;
    }

    function setTokenRedeemable(bool redeemable) public onlyAdmins {
        tokenRedeemable = redeemable;
    }

    function setTokenLock(bool locked) public onlyAdmins {
        tokenLocked = locked;
    }

    function setURI(uint8 tokenId, string memory _uri) public onlyAdmins {
        uris[tokenId] = _uri;
    }

    function withdraw() public onlyAdmins {
        payable(_owner).transfer(address(this).balance);
    }

    // METADATA & MISC FUNCTIONS //

    function uri(uint256 tokenId) public view override returns (string memory) {
        return uris[tokenId];
    }

    function phase() public view returns (uint8) {
        if(tokenLocked) {
            return tokenRedeemable ? 2 : 3;
        } else {
            return tokenRedeemable ? 1 : 4;
        }
    }

    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal override {
        if (id == 1) {
            totalMints += amount;
        }
        super._mint(to, id, amount, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155)
        whenNotPaused
    {
        if (from != address(0) && to != address(0)) {
            require(!tokenLocked, "This token may not be transferred now");
            for (uint256 i; i < ids.length; i++) {
                require(ids[i] == 1, "This token may not be transferred");
            }
        }

        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId) public view override(RoyaltiesConfig, ERC1155) returns (bool) {
        return RoyaltiesConfig.supportsInterface(interfaceId) || ERC1155.supportsInterface(interfaceId);
    }
}