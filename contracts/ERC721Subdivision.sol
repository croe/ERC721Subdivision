// SPDX-License-Identifier: GPL-3.0
// 作家ごとに設定する

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol"; // more expensive
//FIXME: ここ聞きたい→実装方法相談する
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ERC721Subdivision is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    address public artist;
    address[] private _executive;

    uint256 public closingTime; // 2022-08-01 UnitTime(seconds) 1659285295

    uint256[] public basePrice;
    uint256[] public totalEdition;
    string public baseURI;
    // FIXME: 外部からTokenIdと作品番号のMappingが欲しい
    mapping(uint256 => uint256) public editionMap;

    string public contractURI;
    bool private _isWithdrawn;

    mapping(address => mapping(uint => BidInfo)) private _bidInfoMap;
    mapping(address => bool) private _isRefunded;

    struct BidInfo {
        uint256 totalBidValue;
        uint256 totalBidAmount;
    }

    event Refund(address indexed customer, uint value);
    event Withdrawal(uint amount, uint when);
    event WithdrawalAll(uint amount, uint when);
    // event PermanentURI(string _value, uint256 indexed _id); // For Opensea (Freezing Metadata)

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI_,
        address artist_,
        address[] memory executive_,
        uint256[] memory basePrice_,
        uint256[] memory totalEdition_,
        uint256 closingTime_
    ) ERC721(name, symbol) {
        baseURI = baseURI_;
        basePrice = basePrice_;
        closingTime = closingTime_;
        artist = artist_;
        _executive = executive_;
        totalEdition = totalEdition_;
        // FIXME: ここ聞きたい→コンストラクタでArtworkを回していれる？
//        for(uint i=0; i<_basePrice.length; i++) {
//            totalEdition[i] = 0;
//        }

    }

    modifier hasClosed (bool closed) {
        require(closed ? block.timestamp > closingTime : block.timestamp < closingTime);
        _;
    }

    // この作家の総発行枚数を返却する
    function totalSupply() external view returns (uint256) {
        return _tokenIdTracker.current();
    }

    function setClosingTime(uint256 newClosingTime) external onlyOwner {
        closingTime = newClosingTime;
    }

    function buy(uint256 id) external payable hasClosed(false) {
        require(msg.value >= (basePrice[id] / (totalEdition[id] + 1)), "Incorrect value");
        _tokenIdTracker.increment();
        totalEdition[id] += 1;

        editionMap[_tokenIdTracker.current()] = id;

        _bidInfoMap[msg.sender][id].totalBidAmount++;
        _bidInfoMap[msg.sender][id].totalBidValue += msg.value;
        _safeMint(msg.sender, _tokenIdTracker.current());
    }

    // 返金者が一回でも購入したことがあるかを保存する必要がある？
    function refund() external hasClosed(true) {
        require(!_isRefunded[msg.sender], "You has been refunded");
        _isRefunded[msg.sender] = true;
        uint refundValue;
        for(uint i=0; i<totalEdition.length; i++) {
            // ここで全部の返金金額を取得して返す。
            // 作品ごとに金額が違う
            if (totalEdition[i] > 0) {
                refundValue  += _bidInfoMap[msg.sender][i].totalBidValue - (_bidInfoMap[msg.sender][i].totalBidAmount * (basePrice[i] / (totalEdition[i])));
            }
        }
        (bool sent, bytes memory data) = payable(msg.sender).call{value: refundValue}("");
        require(sent, "Failed to send Ether");
        emit Refund(msg.sender, refundValue);
    }

    function withdraw() external onlyOwner hasClosed(true) {
        require(!_isWithdrawn, "Already withdrawn");
        for(uint i = 0; i < basePrice.length; i++) {
            if (totalEdition[i] > 0 && basePrice[i] > 0) {
                uint fee = basePrice[i] * 3331 / 10000;
                (bool sent1, bytes memory data1) = artist.call{value: basePrice[i] - fee}("");
                require(sent1, "Failed to send Ether");
                for (uint j = 0; j < _executive.length; j++) {
                    (bool sent2, bytes memory data2) = _executive[j].call{value: fee / _executive.length}("");
                    require(sent2, "Failed to send Ether");
                }
            }
        }
        _isWithdrawn = true;
//        emit Withdrawal(basePrice, block.timestamp);
    }
//
//    function withdrawAll() external onlyOwner hasClosed(true) {
//        // 終了から半年先であることを計算で算出、Requireにする
//        (bool sent, bytes memory data) = _recipient.call{value: address(this).balance}("");
//        require(sent, "Failed to send Ether");
//        emit WithdrawalAll(address(this).balance, block.timestamp);
//    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId), '.json'));
    }

    function getEditionFromToken(uint256 tokenId) public view returns (uint256) {
        return editionMap[tokenId];
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    function setContractURI(string calldata uri) external onlyOwner {
        contractURI = uri;
    }
}
