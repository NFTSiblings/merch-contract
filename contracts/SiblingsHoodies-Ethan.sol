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

import "https://github.com/NFTSiblings/Modules/blob/master/AdminPrivileges.sol";
import "https://github.com/NFTSiblings/Modules/blob/master/RoyaltiesConfig.sol";
import "https://github.com/NFTSiblings/Modules/blob/master/Allowlist.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract SibHoodies is ERC1155, ERC1155Supply, AdminPrivileges, RoyaltiesConfig, Allowlist {
    // address public ASH = 0x64D91f12Ece7362F91A6f8E7940Cd55F05060b92;
    address public ASH = 0xBEDAcEf5AfC744B7343fcFa619AaF81962Bf82F2; // Rinkeby Test ERC20 Token
    address private payoutAddress = _owner;
    uint public PRICE = 1 * 10 ** 18; // 1 ASH
    uint public MAX_SUPPLY = 100;
    mapping(uint => string) private uris;
    mapping(address => bool) public mintClaimed;

    bool public tokenLocked;
    bool private tokenRedeemable;
    bool private saleActive;
    bool private alRequired;

    constructor() ERC1155("") {}

    // PUBLIC FUNCTIONS //

    function mint() public {
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

    function redeem(uint amount) public {
        require(tokenRedeemable, "Merch redemption is no longer available");
        require(amount > 0, "Cannot redeem 0");
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
    {
        require(!tokenLocked, "This token may not be transferred now");

        for (uint i; i < ids.length; i++) {
            require(ids[i] == 1, "This token may not be transferred");
        }

        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId) public view override(RoyaltiesConfig, ERC1155) returns (bool) {
        return RoyaltiesConfig.supportsInterface(interfaceId) || ERC1155.supportsInterface(interfaceId);
    }
}