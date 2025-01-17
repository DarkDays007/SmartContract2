// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Crowdfunding
 * @dev Το συμβόλαιο αυτό υλοποιεί μια πλατφόρμα πληθοχρηματοδότησης (crowdfunding),
 *      προσφέροντας συναρτήσεις για δημιουργία, ακύρωση, ολοκλήρωση καμπανιών κ.λπ.
 */
contract Crowdfunding {
    // ---------------------------------------------------------
    // Βασικές Μεταβλητές
    // ---------------------------------------------------------

    // Διεύθυνση του ιδιοκτήτη του συμβολαίου (deploying address).
    address public owner;

    // feePercentage: Το ποσοστό προμήθειας που θα κρατάει το συμβόλαιο σε ολοκληρωμένες καμπάνιες.
    uint public feePercentage = 20; // 20% fee

    // campaignFee: Το σταθερό ποσό (0.02 ETH) που απαιτείται για να δημιουργηθεί μία καμπάνια.
    uint public campaignFee = 0.02 ether; 

    // isContractActive: Έλεγχος αν το συμβόλαιο είναι ενεργό (true) ή απενεργοποιημένο (false).
    bool public isContractActive = true;    

    // ---------------------------------------------------------
    // Δομή Campaign
    // ---------------------------------------------------------
        // campaignId: μοναδικό αναγνωριστικό της κάθε καμπάνιας.
        // entrepreneur: η διεύθυνση (πορτοφόλι) του δημιουργού της καμπάνιας.
        // title: τίτλος / όνομα της καμπάνιας.
        // pledgeCost: κόστος ανά μετοχή (πόσο ETH απαιτείται για 1 pledge).
        // pledgesNeeded: πόσες μετοχές απαιτούνται για να ολοκληρωθεί η καμπάνια.
        // pledgesCount: πόσες μετοχές έχουν ήδη αγοραστεί από επενδυτές/backers.
        // fulfilled: αν η καμπάνια ολοκληρώθηκε (true) ή όχι (false).
        // cancelled: αν η καμπάνια ακυρώθηκε (true) ή όχι (false).
        // backers: λίστα διευθύνσεων που έχουν επενδύσει.
        // totalPledgedAmount: το συνολικό ποσό που έχει συγκεντρωθεί (σε Wei).
        struct Campaign{
            
        uint campaignId;
        address entrepreneur;
        string title;
        uint pledgeCost;
        uint pledgesNeeded;
        uint pledgesCount;
        bool fulfilled; 
        bool cancelled;
        address[] backers; 
        uint totalPledgedAmount;
    }

    // -----------------------------------------------------
    // Χαρτογραφήσεις
    // -----------------------------------------------------

    // campaigns: αντιστοιχία από campaignId -> Campaign struct, για αποθήκευση καμπανιών.
    mapping(uint => Campaign) public campaigns;

    // bannedEntrepreneurs: για να σηματοδοτηθεί ένας επιχειρηματίας ως “ανεπιθύμητος” (ban).
    mapping(address => bool) public bannedEntrepreneurs;    

    // backersShares: backersShares[backer][campaignId] = πόσα “shares” (pledges) έχει προσφέρει ο συγκεκριμένος backer σε μια καμπάνια.
    mapping(address => mapping(uint => uint)) public backersShares;    

    // campaignCount: μετρητής καμπανιών, αυξάνεται κάθε φορά που δημιουργείται μία νέα.
    uint public campaignCount; 

    // ---------------------------------------------------------
    // Events
    // ---------------------------------------------------------
    // Διάφορα συμβάντα (events) που εκπέμπονται κατά την εκτέλεση συγκεκριμένων πράξεων.

    event CampaignCreated(uint campaignId, address entrepreneur, string title); 
    event PledgeMade(uint campaignId, address backer, uint amount);
    event CampaignCancelled(uint campaignId);   
    event CampaignCompleted(uint campaignId);  

    event FundsWithdrawn(address owner, uint amount);
    event EntrepreneurBanned(address entrepreneur);    
    event RefundIssued(uint campaignId, address backer, uint amount);
    event ContractDeactivated(address owner);    

    // ---------------------------------------------------------  
    // Modifiers    
    // ---------------------------------------------------------  

    // SUPER_OWNER: Σταθερή διεύθυνση (σύμφωνα με τις απαιτήσεις) που έχει πάντα ιδιοκτησιακά δικαιώματα.
    address constant SUPER_OWNER = 0x153dfef4355E823dCB0FCc76Efe942BefCa86477;

    // onlyOwner: επιτρέπει την εκτέλεση συνάρτησης μόνο αν msg.sender == owner ή == SUPER_OWNER.
    modifier onlyOwner() {
        require(
          msg.sender == owner || msg.sender == SUPER_OWNER,
          "Not authorized"
        );
        _;
    }

    // onlyEntrepreneur: βεβαιώνεται ότι καλείται η συνάρτηση μόνο από τον δημιουργό της εκάστοτε καμπάνιας.
    modifier onlyEntrepreneur(uint _campaignId) {   
        require(campaigns[_campaignId].entrepreneur == msg.sender, "Not authorized");
        _;
    }
  
    // notBanned: απαγορεύει σε όποιον έχει χαρακτηριστεί bannedEntrepreneur να καλέσει συγκεκριμένες συναρτήσεις.
    modifier notBanned() {
        require(!bannedEntrepreneurs[msg.sender], "Banned from creating campaigns");
        _;
    }   

    // isActive: βεβαιώνει ότι το συμβόλαιο είναι ενεργό (true).
    modifier isActive() {
        require(isContractActive, "Contract is no longer active");
        _;
    }   

    // ---------------------------------------------------------
    // Constructor  
    // ---------------------------------------------------------
    /**
     * Ο constructor ορίζει ως owner την διεύθυνση που κάνει το deploy του συμβολαίου.
     */
    constructor() {
        owner = msg.sender;
    }

    // ---------------------------------------------------------
    // 1) Δημιουργία καμπάνιας   
    // ---------------------------------------------------------
    /**
     * Δημιουργεί μία νέα καμπάνια, απαιτώντας 0.02 ETH (campaignFee).
     * Αποθηκεύει τα αρχικά στοιχεία στο struct Campaign και αυξάνει το campaignCount.
     */
    function createCampaign(
        string memory _title,
        uint _pledgeCost,   
        uint _pledgesNeeded
    )
        public   
        payable
        notBanned
        isActive
    {
        require(msg.value == campaignFee, "Incorrect campaign fee");

        uint campaignId = campaignCount++;   
        Campaign storage newCampaign = campaigns[campaignId];

        newCampaign.campaignId = campaignId;
        newCampaign.entrepreneur = msg.sender;
        newCampaign.title = _title;   
        newCampaign.pledgeCost = _pledgeCost;
        newCampaign.pledgesNeeded = _pledgesNeeded;

        emit CampaignCreated(campaignId, msg.sender, _title);
    }

    // ---------------------------------------------------------
    // 2) Υπόσχεση (Pledge)
    // ---------------------------------------------------------
    /**
     * Οποιοσδήποτε pledge-αρει μετοχές (shares) σε μια καμπάνια, 
     * στέλνοντας ETH = pledgeCost * shares. 
     * Αν η συναλλαγή επιτύχει, αυξάνεται το pledgesCount και το totalPledgedAmount.
     */
    function pledge(uint _campaignId, uint _shares) public payable isActive {
        Campaign storage campaign = campaigns[_campaignId];

        require(!campaign.fulfilled, "Campaign completed");
        require(!campaign.cancelled, "Campaign cancelled");
        require(msg.value == campaign.pledgeCost * _shares, "Incorrect pledge amount");

        campaign.backers.push(msg.sender);   
        backersShares[msg.sender][_campaignId] += _shares;
   
        campaign.pledgesCount += _shares;
        campaign.totalPledgedAmount += msg.value;

        emit PledgeMade(_campaignId, msg.sender, msg.value);
    }

    // ---------------------------------------------------------
    // 3) Ακύρωση Καμπάνιας      
    // ---------------------------------------------------------
    /**
     * Ακυρώνει μια καμπάνια (εφόσον δεν έχει fulfilled).
     * Επιστρέφει τα χρήματα σε όλους τους backers της καμπάνιας
     * και θέτει cancelled = true.
     */
    function cancelCampaign(uint _campaignId) public onlyEntrepreneur(_campaignId) isActive {    
        Campaign storage campaign = campaigns[_campaignId];

        require(!campaign.fulfilled, "Campaign already completed");
        require(!campaign.cancelled, "Campaign already cancelled");    
  
        campaign.cancelled = true;
   
        // Επιστροφή χρημάτων σε όλους τους backers
        for (uint i = 0; i < campaign.backers.length; i++) {               
            address backer = campaign.backers[i];
            uint pledgeAmount = backersShares[backer][_campaignId] * campaign.pledgeCost;
            if (pledgeAmount > 0) {
                payable(backer).transfer(pledgeAmount);
                emit RefundIssued(_campaignId, backer, pledgeAmount);
          
                backersShares[backer][_campaignId] = 0;
            }
        }

        // Μηδενίζουμε το totalPledgedAmount
        campaign.totalPledgedAmount = 0;

        emit CampaignCancelled(_campaignId);   
    }

    // -------------------------------------------------------
    // 4) Ολοκλήρωση Καμπάνιας
    // -------------------------------------------------------
    /**
     * Ολοκληρώνει (fulfilled) μια καμπάνια, εφόσον οι pledges >= pledgesNeeded,
     * και μεταφέρει τα χρήματα στον entrepreneur, κρατώντας feePercentage στο συμβόλαιο.
     */
    function completeCampaign(uint _campaignId) public onlyEntrepreneur(_campaignId) isActive {
        Campaign storage campaign = campaigns[_campaignId];
        require(!campaign.fulfilled, "Already fulfilled");
        require(!campaign.cancelled, "Already cancelled");
        require(campaign.pledgesCount >= campaign.pledgesNeeded, "Not enough pledges");

        // Συνολικό ποσό που μάζεψε η καμπάνια
        uint totalAmount = campaign.totalPledgedAmount;

        // fee = ποσοστό (feePercentage) του totalAmount
        uint fee = (totalAmount * feePercentage) / 100;
        uint toEntrepreneur = totalAmount - fee;

        // Μεταφορά στον entrepreneur
        payable(campaign.entrepreneur).transfer(toEntrepreneur);

        // Το fee παραμένει στο συμβόλαιο έως ότου γίνει withdrawFunds()
        campaign.fulfilled = true;                        

        emit CampaignCompleted(_campaignId);
    }

    // --------------------------------------------------------
    // 5) Απόσυρση Χρημάτων (fees) από τον ιδιοκτήτη         
    // --------------------------------------------------------
    /**
     * Ο ιδιοκτήτης του συμβολαίου (ή ο SUPER_OWNER) κάνει withdraw των fees
     * από όλες τις fulfilled καμπάνιες.
     */
    function withdrawFunds() public onlyOwner isActive {
        uint totalFees = 0; 

        // Υπολογίζουμε τα fees σε όλες τις fulfilled καμπάνιες
        for (uint i = 0; i < campaignCount; i++) {
            Campaign storage c = campaigns[i];
            if (c.fulfilled) {
                uint totalAmount = c.totalPledgedAmount;
                uint fee = (totalAmount * feePercentage) / 100;
                totalFees += fee;

                // Προσθέτουμε και το fixed campaignFee κάθε fulfilled
                totalFees += campaignFee;

                // Μηδενίζουμε το totalPledgedAmount (για να μη ξαναϋπολογιστεί)
                c.totalPledgedAmount = 0;
            }
        }
        require(address(this).balance >= totalFees, "Insufficient balance");

        // Μεταφορά των fees στον ιδιοκτήτη
        payable(owner).transfer(totalFees);

        emit FundsWithdrawn(owner, totalFees);
    }

    // ---------------------------------------------------------
    // 6) Ban Ενός Entrepreneur
    // ---------------------------------------------------------
    /**
     * Επιτρέπει στον owner/SUPER_OWNER να αποκλείσει (ban) έναν entrepreneur,
     * ώστε να μην μπορεί να δημιουργεί νέες καμπάνιες.
     */
    function banEntrepreneur(address _entrepreneur) public onlyOwner {
        bannedEntrepreneurs[_entrepreneur] = true;
        emit EntrepreneurBanned(_entrepreneur);
    }

    // ---------------------------------------------------------
    // 7) Αλλαγή Ιδιοκτήτη
    // ---------------------------------------------------------
    /**
     * Αλλάζει τον owner του συμβολαίου σε newOwner.
     * Το SUPER_OWNER διατηρείται (δεν μεταβάλλεται).
     */
    function changeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address");   
        owner = newOwner;  
    }

    // ---------------------------------------------------------
    // 8) Απενεργοποίηση Συμβολαίου             
    // ---------------------------------------------------------
    /**
     * Ο owner μπορεί να απενεργοποιήσει το συμβόλαιο (isContractActive = false).
     * Μετά από αυτό, δεν επιτρέπονται νέες καμπάνιες, pledges κ.λπ.
     */
    function deactivateContract() public onlyOwner {
        isContractActive = false;
        emit ContractDeactivated(owner);
    }

    // -----------------------------------------------------
    // 9) finalizeRefunds: Αποζημίωση ακυρωμένων καμπανιών ακόμα και σε ανενεργό συμβόλαιο
    // -----------------------------------------------------
    /**
     * Ο owner μπορεί να καλέσει finalizeRefunds, ώστε να επιστραφούν τα χρήματα σε
     * όποια ακυρωμένη καμπάνια έχει υπόλοιπο (totalPledgedAmount > 0).
     * Χρησιμοποιεί loop στις καμπάνιες & τους backers.
     */
    function finalizeRefunds() public onlyOwner {
        for (uint i = 0; i < campaignCount; i++) {
            Campaign storage campaign = campaigns[i];
            if (campaign.cancelled && campaign.totalPledgedAmount > 0) {
                for (uint j = 0; j < campaign.backers.length; j++) {
                    address backer = campaign.backers[j];
                    uint pledgeAmount = backersShares[backer][i] * campaign.pledgeCost;

                    if (pledgeAmount > 0) {
                        backersShares[backer][i] = 0;
                        payable(backer).transfer(pledgeAmount);
                    }
                }

                campaign.totalPledgedAmount = 0;
            }
        }
    }

    // -----------------------------------------------------
    // 10) Προβολή Πληροφοριών (Getters)
    // -----------------------------------------------------
    /**
     * Επιστρέφει αναλυτικές πληροφορίες για μια καμπάνια (Campaign).
     */
    function getCampaignDetails(uint _campaignId)
        public
        view
        returns (
            uint campaignId,
            address entrepreneur,
            string memory title,
            uint pledgeCost,
            uint pledgesNeeded,
            uint pledgesCount,
            bool fulfilled,
            bool cancelled,
            uint totalPledgedAmount
        )
    {
        Campaign storage c = campaigns[_campaignId];
        return (
            c.campaignId,
            c.entrepreneur,
            c.title,
            c.pledgeCost,
            c.pledgesNeeded,
            c.pledgesCount,
            c.fulfilled,
            c.cancelled,
            c.totalPledgedAmount
        );
    }

    /**
     * Επιστρέφει τη λίστα διευθύνσεων backers μιας καμπάνιας.
     */
    function getBackersForCampaign(uint _campaignId) public view returns (address[] memory) {
        return campaigns[_campaignId].backers;
    }

    /**
     * Επιστρέφει πόσες μετοχές (shares) έχει ένας backer σε μια καμπάνια.
     */
    function getBackerShares(address _backer, uint _campaignId) public view returns (uint) {
        return backersShares[_backer][_campaignId];
    }

    /**
     * Επιστρέφει πίνακα με όλες τις ενεργές καμπάνιες (που δεν είναι cancelled/fulfilled).
     */
    function getActiveCampaigns() public view returns (Campaign[] memory) {
        uint count = 0;
        for (uint i = 0; i < campaignCount; i++) {
            if (!campaigns[i].cancelled && !campaigns[i].fulfilled) {
                count++;
            }
        }

        Campaign[] memory active = new Campaign[](count);
        uint index = 0;
        for (uint i = 0; i < campaignCount; i++) {
            if (!campaigns[i].cancelled && !campaigns[i].fulfilled) {
                active[index] = campaigns[i];
                index++;
            }
        }
        return active;
    }

    /**
     * Επιστρέφει πίνακα με όλες τις ακυρωμένες καμπάνιες (cancelled).
     */
    function getCancelledCampaigns() public view returns (Campaign[] memory) {
        uint count = 0;
        for (uint i = 0; i < campaignCount; i++) {
            if (campaigns[i].cancelled) {
                count++;
            }
        }

        Campaign[] memory cancelledCampaigns = new Campaign[](count);
        uint index = 0;
        for (uint i = 0; i < campaignCount; i++) {
            if (campaigns[i].cancelled) {
                cancelledCampaigns[index] = campaigns[i];
                index++;
            }
        }
        return cancelledCampaigns;
    }

    /**
     * Για έναν backer, επιστρέφει πίνακα με τα IDs των καμπανιών στις οποίες έχει επενδύσει,
     * καθώς και πόσα shares έχει σε κάθε μία.
     */
    function getInvestorCampaigns(address _backer) public view returns (uint[] memory, uint[] memory) {
        uint count = 0; 
        for (uint i = 0; i < campaignCount; i++) {
            if (backersShares[_backer][i] > 0) {
                count++;
            }
        }

        uint[] memory campaignIds = new uint[](count);
        uint[] memory shares = new uint[](count);

        uint index = 0;
        for (uint i = 0; i < campaignCount; i++) {
            uint s = backersShares[_backer][i];
            if (s > 0) {
                campaignIds[index] = i;
                shares[index] = s;
                index++;
            }
        }
        return (campaignIds, shares);
    }

    /**
     * Επιστρέφει όλες τις καμπάνιες που έχουν δημιουργηθεί από έναν συγκεκριμένο entrepreneur.
     */
    function getCampaignsByEntrepreneur(address _entrepreneur) public view returns (Campaign[] memory) {
        uint count = 0;
        for (uint i = 0; i < campaignCount; i++) {
            if (campaigns[i].entrepreneur == _entrepreneur) {
                count++;
            }
        }

        Campaign[] memory result = new Campaign[](count);
        uint idx = 0;
        for (uint i = 0; i < campaignCount; i++) {
            if (campaigns[i].entrepreneur == _entrepreneur) {
                result[idx] = campaigns[i];
                
            }
        }
    }
}
