// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol"; //実装方法相談する
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IERC721Subdivision {

    function setClosingTime(uint256 newClosingTime) external;
    function setReceiver(address newReceiver) external;
    function buy() external payable;
    function latestPrice() external view returns (uint256);
    function getRefund() external;
    function withdraw() external;
    function withdrawAll() external;

}

contract ERC721Subdivision is IERC721Subdivision, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;
    uint256 private _basePrice;
    uint256 private _closingTime; // 2022-08-01 UnitTime(seconds) 1659285295
    address private _recipient;
    mapping(address => BidInfo) public _bidInfoMap;

    struct BidInfo {
        uint256 totalBidValue;
        uint256 totalBidAmount;
        bool refunded;
    }

    event Refund(address indexed customer, uint value);
    event Withdrawal(uint amount, uint when);
    event WithdrawalAll(uint amount, uint when);
    // event PermanentURI(string _value, uint256 indexed _id); // To Opensea (Freezing Metadata)

    constructor(
        string memory name,
        string memory symbol,
        address recipient,
        uint256 basePrice,
        uint256 closingTime
    ) ERC721(name, symbol) {
        _recipient = recipient;
        _basePrice = basePrice;
        _closingTime = closingTime;
    }

    modifier hasClosed (bool closed) {
        require(closed ? block.timestamp > _closingTime : block.timestamp < _closingTime);
        _;
    }

    receive() external payable {}

    fallback() external payable {}

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdTracker.current();
    }

    function setClosingTime(uint256 newClosingTime) external onlyOwner {
        _closingTime = newClosingTime;
    }

    function setReceiver(address newRecipient) external onlyOwner {
        _recipient = newRecipient;
    }

    function buy() external payable hasClosed(false) {
        require(msg.value >= (_basePrice / (_tokenIdTracker.current() + 1)), "Incorrect value");
        _bidInfoMap[msg.sender].totalBidAmount++;
        _bidInfoMap[msg.sender].totalBidValue += msg.value;
        _safeMint(msg.sender, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    function latestPrice() external view returns (uint256) {
        return _basePrice / (_tokenIdTracker.current() + 1);
    }

    function getRefund() external hasClosed(true) {
        require(_bidInfoMap[msg.sender].refunded == false, "Incorrect value");
        _bidInfoMap[msg.sender].refunded = true;
        uint256 refundValue = _bidInfoMap[msg.sender].totalBidValue - (_bidInfoMap[msg.sender].totalBidAmount * (_basePrice / (_tokenIdTracker.current() + 1)));
        (bool sent, bytes memory data) = payable(msg.sender).call{value: refundValue}("");
        require(sent, "Failed to send Ether");
        emit Refund(msg.sender, refundValue);
    }

    function withdraw() external override onlyOwner hasClosed(true) {
        (bool sent, bytes memory data) = _recipient.call{value: _basePrice}("");
        require(sent, "Failed to send Ether");
        emit Withdrawal(_basePrice, block.timestamp);
    }

    function withdrawAll() external override onlyOwner hasClosed(true) {
        (bool sent, bytes memory data) = _recipient.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
        emit WithdrawalAll(address(this).balance, block.timestamp);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        // https://docs.opensea.io/docs/metadata-standards
        // Arweave or Pinata(free)でも全然良いような気がしてきた＆BaseTokenURIを変えられるのが良い？
        // string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "MY NFT #' + tokenId +'","description": "","image": "","external_url": ""}'))));
        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{"name": "MY NFT #',
            Strings.toString(tokenId + 1),
            '","description": "","image": "","external_url": ""}'
        ))));
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

}