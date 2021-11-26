// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

// import files
// import "./Seat.sol"; //deprecated
// import "@bokkypoobah/BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";
import "./Ticket.sol";

//General _variable convention is to leave the regular variable names for storage variables
// prefacing with _ is normally used to differentiate the temporary variable from the permanent. 

contract TicketBookingSystem{
    address payable private owner;      // owner of the event
    uint32 private available_seats;     // number of available seats in event
    Seat[] private seats;               // seat list
    Ticket private ticket;              // ticket for event
    bool private cancelled;             // bool for preventing double refunding

    // seat struct with all the informations needed in a seat
    struct Seat {
        string title;
        string seatURL;
        uint64 startTime;
        uint128 price;
        uint32 seatRow;
        uint32 seatNumber;
        uint256 ticketID;
    }
    
    constructor(string memory title_, uint256 time_, uint32 available_seats_, uint128 price_) {
        //Create non-existing seat 0 to store information about the event:
        Seat memory _seat = Seat({
            title: title_,
            seatURL: "hurrdurr.dk",
            startTime: time_,
            price: price_,
            seatRow: 0,
            seatNumber: 0,
            ticketID: 0});

        // push 0 seat to seat list
        seats.push(_seat);
        available_seats = available_seats_;
        owner = payable(msg.sender);
        //Ticket has been set up with ownage so owner address is automatically this smart contract
        ticket = new Ticket(title_, "TCK", seats[0].startTime);
    }
    
    // Define a modifier for a function that only the seller can call
    modifier onlyOwner() {
        require( msg.sender == owner , "Only owner can call this.");
        _;
    }
    
    
    //TODO: What if price isn't always the price of the defaut seat?
    // ckecks if enough ethereum is paid for the ticket
    modifier paymentValid() {
        require (msg.value >= seats[0].price, "Not enough Ethereum paid");
         _;
   }
    
    function buy(uint32 _seatRow, uint32 _seatNumber) public payable paymentValid{

        //"Require()" will return the money to sender upon evaluating to false which is great
        // checks if event is already full
        require(seats.length < available_seats, "Event full");
        // ckecks if seat is already taken. (ticket owned by another person)
        require(check_available_seats(_seatRow, _seatNumber), "This seat is taken");
        // mint new ticket
        uint256 newTicket = ticket.mint(msg.sender);

        // creates seat
        Seat memory _seat = Seat({
            title: seats[0].title,
            seatURL: "google.com",
            startTime: seats[0].startTime,
            price: seats[0].price,
            seatRow: _seatRow,
            seatNumber: _seatNumber,
            ticketID: newTicket});
        
        //transfer the ether and push seat to seat list
        owner.transfer(_seat.price);
        seats.push(_seat);
    }
    
    // refund the tickets. (only owner of event can refund the tickets)
    function refund() public onlyOwner{
        require(cancelled == false, "Event already cancelled, tickets can't be refunded twice");
        //Starts at 1 in order to not refund the "test seat" at [0].
        for(uint32 i=1; i < seats.length; i++){               
            (address payable _to, bool _valid) = ticket.verify(seats[i].ticketID);
            //Is this sufficient since only owner has access to the function?
            require(_valid);
            _to.transfer(seats[i].price);
        }
        // set available seats to zero so no further tickets can be bought
        available_seats = 0;
        cancelled = true;
    }
   
    function check_available_seats(uint32 _seatRow, uint32 _seatNumber) private view returns (bool){
        //Check if seat in seats[] already, if not:
        //Mint TICKET for msg.sender
        //Create seat with owner linked to TICKET

        uint32 _numTakenSeats = uint32(seats.length);
        bool _seatFree = true;
        for(uint32 i=0; i < _numTakenSeats; i++){
            if (seats[i].seatNumber == _seatNumber && seats[i].seatRow == _seatRow){
                _seatFree = false;
            }
        }
        return _seatFree;
    }

    //CALLED BY BUYER WHEN BUYING TICKET THAT IS FOR SALE
    //require is used as actively as possible as that returns msg.value if it fails.

    function tradeTicket(uint256 _tokenID) public payable{
        // check that owner of ticket dont buy his/her own ticket
        require( msg.sender != ticket.ownerOf(_tokenID) , "Owner can't buy own token.");
        // get information out of mapping in ticket contract with getMarketplaceInfo
        (uint256 _price, address _reserved,bool _exists) = ticket.getMarketplaceInfo(_tokenID);
        // check if ticket is on sale
        require(_exists, "Token requested is not for sale.");
        //Not the most readable thing in the world but this checks that the token isn't reserved for someone else
        require(_reserved == msg.sender || _reserved == ticket.ownerOf(_tokenID), "You don't have permission to buy this token.");
        // if enough ether is paid
        require (msg.value >= _price, "Not enough Ether paid");

        address payable seller = payable(ticket.ownerOf(_tokenID));

        //Safe transfer event, will only work if seller has approved transfer for ticket owner which should be this contract.
        ticket.safeTransferFrom(ticket.ownerOf(_tokenID), msg.sender, _tokenID);
        seller.transfer(msg.value);

    }
}
