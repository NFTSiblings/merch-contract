// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

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
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract SiblingHoodies is ERC1155, Ownable {
    bytes4 private constant _INTERFACE_ID_EIP2981 = 0x2a55205a;

    //address public _ASH_CONTRACT = 0x64D91f12Ece7362F91A6f8E7940Cd55F05060b92; // MAINNET ASH
    address public constant _ASH_CONTRACT = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709; // TESTNET CHAINLINK
    address payable private _royaltyRecipient;
    uint256 private _royaltyBps;

    uint256 public constant _PRICE = 1 * 10**18; // 1 ASH
    uint256 public constant _MAX_MINTS = 100;
    uint256 public supply;
    uint256 public phase;

    bool public active;
    bool public allowListOnly;

    mapping(address => bool) public allowList;
    mapping(address => bool) public hasMinted;
    mapping(uint256 => string) private _uris;

    constructor() ERC1155("") {
        _royaltyRecipient = payable(msg.sender);
        _royaltyBps = 1000;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155) returns (bool) {
        return interfaceId == _INTERFACE_ID_EIP2981 || ERC1155.supportsInterface(interfaceId);
    }

    function mintToken() external {

        require(active, "Sale is not active");
        require(supply < _MAX_MINTS, "Sold out");
        require(!hasMinted[msg.sender], "One mint per wallet");
        if(allowListOnly) {
            require(allowList[msg.sender], "Address not on allowList");
        }

        IERC20(_ASH_CONTRACT).transferFrom(msg.sender, _royaltyRecipient, _PRICE);
        _mint(msg.sender, 1, 1, "");
        hasMinted[msg.sender] = true;
        supply++;
    }

    function redeem(uint256 amount) external {
        require(amount != 0, "Amount can't be 0");
        require(amount <= balanceOf(msg.sender, 1), "Insufficent amount of token(s)");
        require(phase == 1 || phase == 2, "Token is not redeemable");
        _burn(msg.sender, 1, amount);
        _mint(msg.sender, 2, amount, "");
    }

    function activeSale() public onlyOwner {
        active = true;
        activateNextPhase();
        allowListOnly = true;
    }

    function activatePublicSale() public onlyOwner {
        allowListOnly = false;
    }

    function activateNextPhase() public onlyOwner {
        require(active, "Sale has not been activated");
        require(phase < 4, "Final phase has been reached");
        phase++;
    }

    function lockedToken(uint256 tokenId) public view returns(bool isLocked) {
        isLocked = true;
        if(tokenId == 1) {
            if (phase == 1 || phase == 3) {
                isLocked = false;
            } 
        }

    }

    function addAllowList(address[] calldata addresses) external onlyOwner {
        for (uint256 i; i < addresses.length; i++) {
            allowList[addresses[i]] = true;
        }
    }

    function updateUri(uint256 tokenId, string calldata newUri) external onlyOwner {
        _uris[tokenId] = newUri;
    }

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        return _uris[tokenId];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     * If transferable == false then no token can be transfered or sold
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        // Locks NFT from being transfered or sold
        require(!lockedToken(id), "Transfers locked by contract");
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     * If transferable == false then no token can be transfered or sold
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        // Locks NFT(s) from being transfered or sold
        for (uint256 i; i < ids.length; i++) {
            require(!lockedToken(ids[i]), "Transfers locked by contract");
        }
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function updateRoyalties(address payable recipient, uint256 bps)
        external
        onlyOwner
    {
        _royaltyRecipient = recipient;
        _royaltyBps = bps;
    }

    function royaltyInfo(uint256, uint256 value)
        external
        view
        returns (address, uint256)
    {
        return (_royaltyRecipient, (value * _royaltyBps) / 10000);
    }
}
