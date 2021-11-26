// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Poster is ERC721, Ownable{
    constructor(string memory eventName) ERC721(eventName, "PST"){
        //Sufficient
    }
    
    //Sufficient as long as tokenId corresponds with the burned ticketID
    function mint(address _to, uint256 _tokenID) external onlyOwner{
         _safeMint(_to, _tokenID);
        }
}


